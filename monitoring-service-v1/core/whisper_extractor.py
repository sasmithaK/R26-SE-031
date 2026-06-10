"""
monitoring-service-v1/core/whisper_extractor.py
================================================
Whisper-based STT + WER proxy for C1 acoustic feature enrichment.
Reference: Perera & Sumanathilaka (2025) arXiv:2510.04750
           openai/whisper-base achieves 0.66 WER on Sinhala read-aloud.

Usage:
    wer = compute_whisper_wer_proxy(audio_base64, expected_text)
    # Returns float [0, 1] — higher = more error = higher phonological strain
    # Returns 0.0 when Whisper unavailable (graceful degradation)
"""

import base64
import tempfile
import os
from typing import Optional

# ── Lazy-loaded Whisper model ──────────────────────────────────────────────
_whisper_model = None
_whisper_available = None  # None = untested, True/False = tested


def _is_whisper_available() -> bool:
    global _whisper_available
    if _whisper_available is None:
        try:
            import whisper  # noqa: F401
            _whisper_available = True
        except ImportError:
            _whisper_available = False
            print("[C1-Whisper] openai-whisper not installed — WER proxy disabled. "
                  "Install: pip install openai-whisper")
    return _whisper_available


def _get_model():
    global _whisper_model
    if _whisper_model is None and _is_whisper_available():
        import whisper
        _whisper_model = whisper.load_model("base")  # ~140 MB, multilingual
        print("[C1-Whisper] whisper-base loaded")
    return _whisper_model


def _levenshtein(a: str, b: str) -> int:
    """Character-level edit distance."""
    m, n = len(a), len(b)
    dp = list(range(n + 1))
    for i in range(1, m + 1):
        prev = dp[:]
        dp[0] = i
        for j in range(1, n + 1):
            if a[i - 1] == b[j - 1]:
                dp[j] = prev[j - 1]
            else:
                dp[j] = 1 + min(prev[j], dp[j - 1], prev[j - 1])
    return dp[n]


def transcribe_sinhala(audio_bytes: bytes) -> str:
    """
    Transcribe Sinhala audio bytes (WAV/FLAC) using Whisper.
    Returns empty string on any failure.
    """
    model = _get_model()
    if model is None:
        return ""
    try:
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
            f.write(audio_bytes)
            tmp_path = f.name
        result = model.transcribe(tmp_path, language="si", fp16=False)
        return result.get("text", "").strip()
    except Exception as e:
        print(f"[C1-Whisper] Transcription error: {e}")
        return ""
    finally:
        try:
            os.unlink(tmp_path)
        except Exception:
            pass


def compute_whisper_wer_proxy(audio_base64: Optional[str], expected_text: str) -> float:
    """
    Main entry point for C1.
    Returns character-level WER proxy [0, 1]:
        0.0 = perfect match (or Whisper unavailable / no audio)
        1.0 = complete mismatch

    Args:
        audio_base64: Base64-encoded WAV/FLAC bytes from Flutter TelemetryPayload.audio_base64
        expected_text: The Sinhala word/sentence shown on screen (current_content_text)
    """
    if not audio_base64 or not expected_text:
        return 0.0
    if not _is_whisper_available():
        return 0.0
    try:
        audio_bytes = base64.b64decode(audio_base64)
        transcription = transcribe_sinhala(audio_bytes)
        if not transcription:
            return 0.0
        dist = _levenshtein(transcription.lower(), expected_text.lower())
        wer = min(1.0, dist / max(len(expected_text), 1))
        return round(wer, 4)
    except Exception as e:
        print(f"[C1-Whisper] WER proxy error: {e}")
        return 0.0
