"""Stage 1 of C2: deterministic recording-quality validation.

The quality gate intentionally measures the recording, not the child.  A failed
gate must result in a friendly retry and must never be converted into a poor
reading score.
"""

from __future__ import annotations

import io
import math
from typing import Any, Dict, Tuple

import librosa
import numpy as np
import soundfile as sf

from services import c2_settings


QUALITY_VERSION = "c2-audio-quality-v1"


class AudioQualityService:
    target_sample_rate = 16_000

    def decode(self, wav_bytes: bytes) -> Tuple[np.ndarray, int]:
        if not wav_bytes:
            raise ValueError("Audio payload is empty")
        try:
            audio, sample_rate = sf.read(io.BytesIO(wav_bytes), always_2d=False)
        except Exception as exc:
            raise ValueError("Audio payload is not a readable WAV file") from exc
        if getattr(audio, "ndim", 1) > 1:
            audio = np.mean(audio, axis=1)
        audio = np.asarray(audio, dtype=np.float32)
        if sample_rate != self.target_sample_rate:
            audio = librosa.resample(
                audio, orig_sr=sample_rate, target_sr=self.target_sample_rate
            )
            sample_rate = self.target_sample_rate
        if audio.size == 0 or not np.all(np.isfinite(audio)):
            raise ValueError("Audio contains no finite samples")
        return audio, int(sample_rate)

    def analyze(self, wav_bytes: bytes) -> Dict[str, Any]:
        audio, sample_rate = self.decode(wav_bytes)
        duration_ms = 1000.0 * len(audio) / sample_rate
        peak = float(np.max(np.abs(audio)))
        rms = float(np.sqrt(np.mean(np.square(audio))) + 1e-12)
        rms_dbfs = float(20.0 * math.log10(rms))
        clipping_ratio = float(np.mean(np.abs(audio) >= 0.985))

        frame_rms = librosa.feature.rms(y=audio, frame_length=400, hop_length=160)[0]
        noise_rms = float(np.percentile(frame_rms, 20)) + 1e-9
        speech_rms = float(np.percentile(frame_rms, 80)) + 1e-9
        snr_db = float(20.0 * math.log10(speech_rms / noise_rms))
        spectral_flatness = float(
            np.mean(librosa.feature.spectral_flatness(y=audio + 1e-9))
        )
        active_threshold = max(0.004, min(noise_rms * 2.5, speech_rms * 0.35))
        active_ratio = float(np.mean(frame_rms >= active_threshold))

        issues = []
        if duration_ms < c2_settings.get("quality", "min_duration_ms", 350):
            issues.append("too_short")
        if duration_ms > c2_settings.get("quality", "max_duration_ms", 30_000):
            issues.append("too_long")
        if (peak < c2_settings.get("quality", "min_peak_amplitude", 0.008)
                or active_ratio < c2_settings.get("quality", "min_active_frame_ratio", 0.04)):
            issues.append("insufficient_speech")
        if clipping_ratio > c2_settings.get("quality", "max_clipping_ratio", 0.02):
            issues.append("clipping")
        if (snr_db < c2_settings.get("quality", "noisy_snr_db", 7.0)
                and spectral_flatness > c2_settings.get("quality", "noisy_spectral_flatness", 0.30)
                and active_ratio >= c2_settings.get("quality", "min_active_frame_ratio", 0.04)):
            issues.append("too_noisy")

        severe = {"too_short", "insufficient_speech", "clipping", "too_noisy"}
        retry_required = bool(severe.intersection(issues))
        duration_score = min(1.0, max(0.0, duration_ms / 900.0))
        level_score = min(1.0, max(0.0, (rms_dbfs + 50.0) / 30.0))
        clarity_score = max(
            min(1.0, max(0.0, snr_db / 20.0)),
            min(1.0, max(0.0, 1.0 - spectral_flatness)),
        )
        clipping_score = max(0.0, 1.0 - clipping_ratio * 20.0)
        weights = c2_settings.get("quality", "score_weights", {}) or {}
        quality_score = float(
            weights.get("duration", 0.20) * duration_score
            + weights.get("level", 0.25) * level_score
            + weights.get("clarity", 0.35) * clarity_score
            + weights.get("clipping", 0.20) * clipping_score
        )

        status = "retry_required" if retry_required else "valid"
        return {
            "status": status,
            "retry_required": retry_required,
            "issues": issues,
            "quality_score": round(quality_score, 4),
            "duration_ms": round(duration_ms, 2),
            "sample_rate_hz": sample_rate,
            "peak_amplitude": round(peak, 6),
            "rms_dbfs": round(rms_dbfs, 3),
            "estimated_snr_db": round(snr_db, 3),
            "spectral_flatness": round(spectral_flatness, 6),
            "clipping_ratio": round(clipping_ratio, 6),
            "active_frame_ratio": round(active_ratio, 4),
            "version": QUALITY_VERSION,
        }
