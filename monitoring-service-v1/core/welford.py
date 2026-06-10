"""
monitoring-service-v1/core/welford.py
======================================
Welford's Online Algorithm for per-student incremental mean and variance.

Reference:
    Welford, B. P. (1962). Note on a method for calculating corrected sums
    of squares and products. Technometrics, 4(3), 419–420.

Why Welford's instead of a naive running mean?
    1. Numerically stable — avoids catastrophic cancellation for large samples.
    2. No stored history — only count, mean, and M2 needed per feature.
    3. Online — updates in O(1) per observation.

Architecture note:
    Each of C1's 12 input features maintains a separate WelfordFeatureState.
    The Z-score transforms raw feature values into child-specific deviations,
    so the same LightGBM weights can be applied across all children without
    child-specific model retraining.
"""

from __future__ import annotations

import json
import math
from dataclasses import dataclass, field
from typing import Dict, Optional

from shared.database import get_db


@dataclass
class WelfordFeatureState:
    """
    Incremental state for one (student, feature) pair.

    Attributes:
        count:  Number of observations seen so far.
        mean:   Running mean.
        M2:     Running sum of squared deviations from the mean.
                Variance = M2 / count; Std = sqrt(M2 / count).
    """
    count: int = 0
    mean: float = 0.0
    M2: float = 0.0

    def update(self, new_value: float) -> None:
        """Welford's online update step — O(1), numerically stable."""
        self.count += 1
        delta = new_value - self.mean
        self.mean += delta / self.count
        delta2 = new_value - self.mean
        self.M2 += delta * delta2

    @property
    def variance(self) -> float:
        """Population variance (uses count, not count-1)."""
        if self.count < 2:
            return 1.0  # fallback to prevent division by zero
        return self.M2 / self.count

    @property
    def std(self) -> float:
        """Population standard deviation."""
        return math.sqrt(self.variance)

    def z_score(self, value: float) -> float:
        """
        Standardized deviation of value from this student's personal baseline.

        Returns 0.0 if fewer than 3 observations (baseline not yet stable).
        Clamps to [-4.0, +4.0] to limit the influence of single extreme outliers.
        """
        if self.count < 3:
            return 0.0
        z = (value - self.mean) / (self.std + 1e-8)
        return max(-4.0, min(4.0, z))

    def to_dict(self) -> dict:
        return {"count": self.count, "mean": self.mean, "M2": self.M2}

    @classmethod
    def from_dict(cls, d: dict) -> "WelfordFeatureState":
        state = cls()
        state.count = d.get("count", 0)
        state.mean = d.get("mean", 0.0)
        state.M2 = d.get("M2", 0.0)
        return state


class WelfordBaseline:
    """
    Per-student baseline for all 12 C1 input features.

    Usage:
        baseline = WelfordBaseline(student_id="stu_001", db_path="./db/monitoring.db")
        baseline.update({"hesitation_ms": 2300, "replay_count": 2, ...})
        z_scores = baseline.z_score_all({"hesitation_ms": 3500, "replay_count": 5, ...})
    """

    FEATURES = [
        "hesitation_ms",
        "correction_rate",
        "response_latency",
        "touch_pressure",
        "swipe_velocity",
        "replay_count",
        "hint_request_count",
        "stylus_deviation",
        "inter_tap_interval",
        "read_aloud_pause_ms",
        "syllable_rate",
        "disfluency_count",
        "kalman_innovation",   # Kalman Filter output — added by feature_extractor
        "whisper_wer_proxy",   # Whisper STT WER proxy (Perera & Sumanathilaka 2025)
    ]

    def __init__(self, student_id: str):
        self.student_id = student_id
        self._states: Dict[str, WelfordFeatureState] = {
            f: WelfordFeatureState() for f in self.FEATURES
        }

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    async def update(self, feature_values: Dict[str, float]) -> None:
        """Update baseline with one observation per feature."""
        for feature, value in feature_values.items():
            if feature in self._states:
                self._states[feature].update(value)
        await self._save()

    def z_score(self, feature: str, value: float) -> float:
        """Return Z-score for a single feature value."""
        if feature not in self._states:
            return 0.0
        return self._states[feature].z_score(value)

    def z_score_all(self, feature_values: Dict[str, float]) -> Dict[str, float]:
        """Return Z-scores for all provided features."""
        return {
            feature: self.z_score(feature, value)
            for feature, value in feature_values.items()
            if feature in self._states
        }

    def feature_summary(self) -> dict:
        """Return {feature: {count, mean, std}} for monitoring endpoint."""
        return {
            f: {
                "count": s.count,
                "mean": round(s.mean, 3),
                "std": round(s.std, 3),
            }
            for f, s in self._states.items()
        }

    def is_warm(self, min_observations: int = 3) -> bool:
        """True if all features have at least min_observations updates."""
        return all(s.count >= min_observations for s in self._states.values())

    # ------------------------------------------------------------------
    # Persistence (MongoDB)
    # ------------------------------------------------------------------

    async def _load(self) -> None:
        try:
            db = get_db()
            cursor = db.welford_states.find({"student_id": self.student_id})
            async for row in cursor:
                feature = row["feature"]
                if feature in self._states:
                    self._states[feature] = WelfordFeatureState(
                        count=row.get("count", 0),
                        mean=row.get("mean", 0.0),
                        M2=row.get("M2", 0.0)
                    )
        except Exception:
            pass  # First-run: states stay at zero defaults

    async def _save(self) -> None:
        db = get_db()
        for feature, state in self._states.items():
            await db.welford_states.update_one(
                {"student_id": self.student_id, "feature": feature},
                {"$set": {"count": state.count, "mean": state.mean, "M2": state.M2}},
                upsert=True
            )


# ---------------------------------------------------------------------------
# Module-level cache (avoids repeated DB round-trips per request)
# ---------------------------------------------------------------------------
_baseline_cache: Dict[str, WelfordBaseline] = {}


async def get_baseline(student_id: str) -> WelfordBaseline:
    """Return cached WelfordBaseline for a student, loading from DB on first call."""
    if student_id not in _baseline_cache:
        baseline = WelfordBaseline(student_id)
        await baseline._load()
        _baseline_cache[student_id] = baseline
    return _baseline_cache[student_id]
