import io
import soundfile as sf
import tempfile
import os
import math
import threading

import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Prefer a locally downloaded model for reproducible/offline testing.  The
# Hugging Face repository remains the fallback for deployments that populate
# the standard model cache.
MODEL_NAME = os.getenv(
    "WHISPER_MODEL_PATH",
    "AqeelShafy7/Whisper-Sinhala_Audio_to_Text",
)

# Pediatric LoRA configuration (Stub)
LORA_MODEL_DIR = "models/pediatric_whisper_lora"

class STTService:
    def __init__(self):
        import torch
        from transformers import AutoProcessor, AutoModelForSpeechSeq2Seq
        
        self.torch = torch
        self.processor = AutoProcessor.from_pretrained(MODEL_NAME)
        self.model = AutoModelForSpeechSeq2Seq.from_pretrained(MODEL_NAME)
        
        # Check for Pediatric LoRA fine-tuned weights
        if os.path.exists(LORA_MODEL_DIR):
            try:
                from peft import PeftModel
                self.model = PeftModel.from_pretrained(self.model, LORA_MODEL_DIR)
                logger.info("Successfully loaded Pediatric Sinhala LoRA acoustic model.")
            except Exception as e:
                logger.error(f"Failed to load LoRA weights: {e}")
                logger.warning("WARNING: Falling back to zero-shot adult Whisper model; pediatric performance is unvalidated.")
        else:
            logger.warning("WARNING: Pediatric Sinhala LoRA model not found. Falling back to zero-shot adult Whisper model; pediatric performance is unvalidated.")
            
        self.model.eval()

    def transcribe_with_metadata(self, audio_bytes: bytes) -> dict:
        """
        Process audio and return a transcription plus model-confidence metadata.

        Confidence is an engineering signal derived from sequence likelihood;
        it is not a probability that a child's reading is correct.
        """
        import librosa
        temp_path = None
        try:
            # Save bytes to a temp file to let librosa handle format decoding easily
            with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as temp_file:
                temp_file.write(audio_bytes)
                temp_path = temp_file.name
            
            # Load and resample to 16000 Hz, which is what Whisper expects
            audio_data, sample_rate = librosa.load(temp_path, sr=16000)
            
            # Normalize only the ASR branch. Acoustic measurements are computed
            # from the original signal in AcousticAnalysisService.
            audio_data = librosa.util.normalize(audio_data)
            
            # Clean up temp file
            if os.path.exists(temp_path):
                os.remove(temp_path)
                
            inputs = self.processor(audio_data, sampling_rate=16000, return_tensors="pt")

            generate_kwargs = {
                "return_dict_in_generate": True,
                "output_scores": True,
            }
            # Whisper processors support an explicit language/task prompt.  Keep
            # the fallback generic so compatible Sinhala checkpoints still run.
            if hasattr(self.processor, "get_decoder_prompt_ids"):
                try:
                    generate_kwargs["forced_decoder_ids"] = self.processor.get_decoder_prompt_ids(
                        language="sinhala", task="transcribe"
                    )
                except Exception:
                    pass
            
            with self.torch.no_grad():
                output = self.model.generate(**inputs, **generate_kwargs)

            sequences = output.sequences if hasattr(output, "sequences") else output
            text = self.processor.batch_decode(sequences, skip_special_tokens=True)[0]
            confidence = None
            sequence_scores = getattr(output, "sequences_scores", None)
            if sequence_scores is not None and len(sequence_scores):
                confidence = float(math.exp(min(0.0, float(sequence_scores[0]))))
            elif getattr(output, "scores", None) and hasattr(self.model, "compute_transition_scores"):
                try:
                    transition = self.model.compute_transition_scores(
                        sequences, output.scores, normalize_logits=True
                    )
                    finite = transition[0][self.torch.isfinite(transition[0])]
                    if finite.numel():
                        confidence = float(self.torch.exp(finite.mean()).item())
                except Exception:
                    confidence = None

            return {
                "text": text,
                "confidence": confidence,
                "candidates": [{"text": text, "confidence": confidence}],
                "engine": "whisper_transformers",
                "model": MODEL_NAME,
                "language": "si",
                "status": "available" if text.strip() else "empty_transcription",
                "confidence_semantics": "mean_token_likelihood_not_reading_correctness",
            }
            
        except Exception as e:
            raise RuntimeError(f"Failed to process and transcribe audio: {e}")
        finally:
            if temp_path and os.path.exists(temp_path):
                os.remove(temp_path)

    def transcribe_audio_bytes(self, audio_bytes: bytes) -> str:
        """Backward-compatible text-only interface."""
        return self.transcribe_with_metadata(audio_bytes)["text"]

# Singleton instance to avoid reloading the model on every request.
stt_engine = None
_stt_init_lock = threading.Lock()
_stt_state_lock = threading.Lock()
_stt_status = "not_loaded"
_stt_error_type = None


def get_stt_status() -> dict:
    """Return deployment-safe model readiness information."""
    with _stt_state_lock:
        return {
            "status": _stt_status,
            "model": MODEL_NAME,
            "error_type": _stt_error_type,
        }


def mark_stt_preloading() -> None:
    """Expose warming-up state before the worker thread begins."""
    global _stt_status, _stt_error_type
    with _stt_state_lock:
        if stt_engine is None:
            _stt_status = "loading"
            _stt_error_type = None


def get_stt_engine():
    global stt_engine, _stt_status, _stt_error_type
    with _stt_init_lock:
        if stt_engine is not None:
            return stt_engine

        with _stt_state_lock:
            _stt_status = "loading"
            _stt_error_type = None
        try:
            loaded_engine = STTService()
            stt_engine = loaded_engine
            with _stt_state_lock:
                _stt_status = "ready"
            return stt_engine
        except Exception as exc:
            with _stt_state_lock:
                _stt_status = "failed"
                _stt_error_type = type(exc).__name__
            logger.exception("Sinhala Whisper model failed to load")
            raise


def preload_stt_engine() -> None:
    """Warm the singleton outside a learner request."""
    try:
        get_stt_engine()
        logger.info("Sinhala Whisper model is ready")
    except Exception:
        # The readiness endpoint exposes the failure without crashing C2.
        pass
