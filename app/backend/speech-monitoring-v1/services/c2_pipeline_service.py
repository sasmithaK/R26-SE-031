"""Seven-stage C2 speech and oral-reading processing pipeline."""

from __future__ import annotations

import hashlib
from typing import Any, Dict, Iterable

from services.acoustic_service import AcousticAnalysisService
from services.audio_quality_service import AudioQualityService
from services.evidence_fusion_service import EvidenceFusionService
from services.sinhala_alignment_service import SinhalaAlignmentService
from services.stt_service import get_stt_engine


PIPELINE_VERSION = "c2-pipeline-v3"


class C2PipelineService:
    def __init__(self) -> None:
        self.quality = AudioQualityService()
        self.acoustic = AcousticAnalysisService()
        self.alignment = SinhalaAlignmentService()
        self.fusion = EvidenceFusionService()

    def process(
        self,
        wav_bytes: bytes,
        expected_text: str,
        expected_syllables: int = 0,
        t_stimulus: int = 0,
        t_record_start: int = 0,
        allowed_variants: Iterable[str] | None = None,
    ) -> Dict[str, Any]:
        # Stage 1: validate the recording.  Still extract research metadata from
        # noisy recordings, but never convert a failed gate into a child score.
        quality = self.quality.analyze(wav_bytes)

        severe_silence = "insufficient_speech" in quality.get("issues", [])
        if severe_silence:
            acoustic: Dict[str, Any] = {}
            transcription = {
                "text": "",
                "confidence": None,
                "candidates": [],
                "engine": "whisper",
                "status": "skipped_quality_gate",
            }
        else:
            # Stages 2 and 6: the acoustic service uses the unmodified signal for
            # timing/fluency and a separate temporary branch for voice quality.
            acoustic = self.acoustic.analyze_audio(
                wav_bytes=wav_bytes,
                expected_text=expected_text,
                expected_syllables=expected_syllables,
                t_stimulus=t_stimulus,
                t_record_start=t_record_start,
            )

            # Stage 3: structured Sinhala STT with confidence metadata.
            try:
                transcription = get_stt_engine().transcribe_with_metadata(wav_bytes)
            except Exception as exc:
                # Acoustic/quality evidence remains useful when the optional
                # model artifact is unavailable. Do not turn infrastructure
                # failure into a low child score.
                transcription = {
                    "text": "",
                    "confidence": None,
                    "candidates": [],
                    "engine": "whisper_transformers",
                    "model": None,
                    "status": "engine_unavailable",
                    "error_type": type(exc).__name__,
                }

        recognized_text = transcription.get("text") or acoustic.get("transcription") or ""

        # Stages 4 and 5: expected-text and grapheme-aware alignment.
        alignment = self.alignment.compare(
            expected_text=expected_text,
            recognized_text=recognized_text,
            allowed_variants=allowed_variants,
        )
        duration_ms = acoustic.get("Speech_Duration_ms")
        expected_word_count = len(alignment.get("expected_normalized", "").split())
        recognized_word_count = len(alignment.get("recognized_normalized", "").split())
        expected_rate = None
        recognized_rate = None
        if isinstance(duration_ms, (int, float)) and duration_ms > 0:
            expected_rate = expected_word_count * 60_000.0 / duration_ms
            recognized_rate = recognized_word_count * 60_000.0 / duration_ms
        fluency = {
            "voice_onset_ms": acoustic.get("Voice_Onset_ms"),
            "acoustic_latency_ms": acoustic.get("Acoustic_Latency_ms"),
            "speech_duration_ms": duration_ms,
            "articulation_duration_ms": acoustic.get("Articulation_Duration_ms", duration_ms),
            "pause_count": acoustic.get("Pause_Count"),
            "mean_pause_duration_ms": acoustic.get("Mean_Pause_Duration_ms"),
            "pause_ratio": acoustic.get("Pause_Ratio"),
            "within_utterance_silence_ratio": acoustic.get("Intra_Word_Silence_Ratio"),
            "expected_words_per_minute": round(expected_rate, 3) if expected_rate else None,
            "recognized_words_per_minute": round(recognized_rate, 3) if recognized_rate else None,
            "adjacent_repetitions": alignment.get("adjacent_repetitions", 0),
            "self_corrections": None,
            "local_jitter": acoustic.get("Local_Jitter"),
            "local_shimmer": acoustic.get("Local_Shimmer"),
            "jitter_shimmer_role": "exploratory_recording_features_not_primary_score",
        }

        # Stage 7: conservative evidence fusion and abstention.
        fusion = self.fusion.fuse(quality, transcription, alignment, acoustic)
        return {
            "pipeline_version": PIPELINE_VERSION,
            "audio_sha256": hashlib.sha256(wav_bytes).hexdigest(),
            "quality": quality,
            "transcription": {**transcription, "text": recognized_text},
            "alignment": alignment,
            "acoustic": acoustic,
            "fluency": fluency,
            "fusion": fusion,
        }


_pipeline: C2PipelineService | None = None


def get_c2_pipeline() -> C2PipelineService:
    global _pipeline
    if _pipeline is None:
        _pipeline = C2PipelineService()
    return _pipeline
