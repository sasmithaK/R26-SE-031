import io
import unittest
from unittest.mock import patch

import numpy as np
import soundfile as sf

from services.audio_quality_service import AudioQualityService
from services.c2_pipeline_service import C2PipelineService
from services.evidence_fusion_service import EvidenceFusionService
from services.sinhala_alignment_service import SinhalaAlignmentService, grapheme_clusters


def wav_bytes(audio, sample_rate=16_000):
    buffer = io.BytesIO()
    sf.write(buffer, np.asarray(audio, dtype=np.float32), sample_rate, format="WAV", subtype="PCM_16")
    return buffer.getvalue()


class FakeSTT:
    def transcribe_with_metadata(self, _audio):
        return {
            "text": "ගස",
            "confidence": 0.8,
            "candidates": [{"text": "ගස", "confidence": 0.8}],
            "engine": "fixture",
            "model": "fixture-v1",
            "status": "available",
        }


class C2PipelineTests(unittest.TestCase):
    def test_sinhala_alignment(self):
        result = SinhalaAlignmentService().compare("ගඟ ළඟ ගස", "ගඟ ගස")
        self.assertEqual(result["word"]["deletions"], 1)
        self.assertAlmostEqual(result["word"]["error_rate"], 1 / 3)
        self.assertLess(len(grapheme_clusters("කිරිබත්")), len("කිරිබත්"))

    def test_silence_is_retry_not_low_score(self):
        result = AudioQualityService().analyze(wav_bytes(np.zeros(16_000)))
        self.assertEqual(result["status"], "retry_required")
        self.assertIn("insufficient_speech", result["issues"])

    def test_noise_is_rejected_by_quality_gate(self):
        rng = np.random.default_rng(42)
        noise = rng.normal(0.0, 0.08, 16_000)
        result = AudioQualityService().analyze(wav_bytes(noise))
        self.assertEqual(result["status"], "retry_required")
        self.assertIn("too_noisy", result["issues"])

    def test_method_disagreement_abstains(self):
        result = EvidenceFusionService().fuse(
            {"quality_score": 0.9, "retry_required": False},
            {"text": "ගස", "confidence": 0.8},
            {"grapheme": {"accuracy": 0.95}, "word": {"accuracy": 1.0}},
            {
                "Peak_Count_Delta": 4,
                "Expected_Syllables": 4,
                "Speech_Duration_ms": 900,
            },
        )
        self.assertEqual(result["measurement_status"], "uncertain")
        self.assertTrue(result["method_disagreement"])

    @patch("services.c2_pipeline_service.get_stt_engine", return_value=FakeSTT())
    def test_full_seven_stage_result(self, _get_stt):
        timeline = np.arange(int(16_000 * 1.2)) / 16_000
        audio = 0.20 * np.sin(2 * np.pi * 220 * timeline)
        pipeline = C2PipelineService()
        with patch.object(
            pipeline.acoustic,
            "analyze_audio",
            return_value={
                "Voice_Onset_ms": 120,
                "Acoustic_Latency_ms": 420,
                "Detected_Peaks": 1,
                "Expected_Syllables": 1,
                "Peak_Count_Delta": 0,
                "Speech_Duration_ms": 850.0,
                "Articulation_Duration_ms": 850.0,
                "Pause_Count": 0,
                "Mean_Pause_Duration_ms": 0.0,
                "Pause_Ratio": 0.0,
                "Intra_Word_Silence_Ratio": 0.0,
                "Local_Jitter": None,
                "Local_Shimmer": None,
            },
        ):
            result = pipeline.process(
                wav_bytes(audio), expected_text="ගස", expected_syllables=1
            )
        self.assertEqual(result["quality"]["status"], "valid")
        self.assertTrue(result["alignment"]["exact_match"])
        self.assertEqual(result["fusion"]["measurement_status"], "valid")
        self.assertEqual(result["fusion"]["reading_performance_score"], 1.0)
        self.assertIsNotNone(result["fluency"]["recognized_words_per_minute"])

    @patch("services.c2_pipeline_service.get_stt_engine", side_effect=OSError("missing model"))
    def test_missing_stt_model_abstains_without_losing_acoustics(self, _get_stt):
        timeline = np.arange(int(16_000 * 1.0)) / 16_000
        audio = 0.15 * np.sin(2 * np.pi * 220 * timeline)
        pipeline = C2PipelineService()
        with patch.object(
            pipeline.acoustic,
            "analyze_audio",
            return_value={
                "Speech_Duration_ms": 800.0,
                "Expected_Syllables": 2,
                "Peak_Count_Delta": 0,
            },
        ):
            result = pipeline.process(wav_bytes(audio), expected_text="ගස")
        self.assertEqual(result["transcription"]["status"], "engine_unavailable")
        self.assertEqual(result["fusion"]["measurement_status"], "uncertain")
        self.assertEqual(result["acoustic"]["Speech_Duration_ms"], 800.0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
