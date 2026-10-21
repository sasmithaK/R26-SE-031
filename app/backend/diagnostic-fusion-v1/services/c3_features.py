"""C3 learner-window inputs, shared by the live service and model training.

The live endpoint (main.py) and ``scripts/train_c3_model.py`` both call
``build_c3_inputs``, so simulated training learners and real learners are
aggregated identically.

Inputs (feature version ``c3-learner-window-v2``):
* reading (C2): medians over recordings that were clear enough to measure;
* touch movement: medians over sessions with touch data (path directness and
  smoothness only from sessions with drags);
* activity behaviour (C1): the learner-level C1 features, used only when C1
  had enough evidence;
* age in years (from birth month/year).
Missing values stay missing (NaN for the model); nothing is imputed. Gender
and time of day are no longer model inputs.
"""
from __future__ import annotations

import math
from datetime import datetime, timezone
from typing import Optional

FEATURE_VERSION = "c3-learner-window-v2"

SPEECH_FEATURE_SOURCES = {
    "acoustic_latency_ms": ("acoustic_latency_ms",),
    "peak_count_delta": ("syllabic_event_mismatch", "peak_count_delta"),
    "intra_word_silence_ratio": ("intra_word_silence_ratio",),
    "local_jitter": ("local_jitter",),
    "local_shimmer": ("local_shimmer",),
}
MOTION_FEATURE_SOURCES = {
    "time_to_first_touch_ms": ("time_to_first_touch_ms",),
    "orthographic_confusion_index": ("orthographic_confusion_index",),
    "path_efficiency_ratio": ("path_efficiency_ratio",),
    "dimensionless_jerk": ("dimensionless_jerk",),
    "dwell_time_ms": ("dwell_time_ms", "mean_dwell_time_ms"),
}
C1_FEATURE_SOURCES = {
    "c1_first_try_accuracy": "accuracy",
    "c1_visual_task_index": "visual_processing_index",
    "c1_sound_task_index": "phonological_task_index",
    "c1_long_pauses_per_round": "hesitation_rate",
}
FEATURES = [*SPEECH_FEATURE_SOURCES, *MOTION_FEATURE_SOURCES, *C1_FEATURE_SOURCES, "age_years"]

FEATURE_LABELS = {
    "acoustic_latency_ms": "Time to start reading aloud",
    "peak_count_delta": "Spoken beats vs expected syllables",
    "intra_word_silence_ratio": "Silence within spoken words",
    "local_jitter": "Voice steadiness (exploratory)",
    "local_shimmer": "Loudness steadiness (exploratory)",
    "time_to_first_touch_ms": "Time to first touch",
    "orthographic_confusion_index": "Look-alike letter choices",
    "path_efficiency_ratio": "Directness of drags",
    "dimensionless_jerk": "Drag smoothness (jerk)",
    "dwell_time_ms": "Finger contact time",
    "c1_first_try_accuracy": "Activities correct on first try",
    "c1_visual_task_index": "Visual task speed index",
    "c1_sound_task_index": "Sound task speed index",
    "c1_long_pauses_per_round": "Long pauses per activity round",
    "age_years": "Age",
}

USABLE_SPEECH_STATUSES = {"valid", "available"}


def _number(value) -> Optional[float]:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    value = float(value)
    return value if math.isfinite(value) else None


def median_feature(rows: list, sources: tuple):
    values = []
    for row in rows:
        for key in sources:
            value = _number(row.get(key))
            if value is not None:
                values.append(value)
                break
    if not values:
        return None, 0
    values.sort()
    mid = len(values) // 2
    return (values[mid] if len(values) % 2 else (values[mid - 1] + values[mid]) / 2), len(values)


def age_years(student: dict, now: Optional[datetime] = None) -> Optional[float]:
    """Age in years (decimal) from age_months or birth year/month; else ``age``."""
    now = now or datetime.now(timezone.utc)
    months = _number(student.get("age_months"))
    if months is None and student.get("birth_year") and student.get("birth_month"):
        try:
            months = (now.year - int(student["birth_year"])) * 12 + (now.month - int(student["birth_month"]))
        except (TypeError, ValueError):
            months = None
    if months is not None:
        return round(months / 12, 2)
    return _number(student.get("age"))


def build_c3_inputs(usable_speech: list, motion_rows: list, c1_features: Optional[dict],
                    age: Optional[float]) -> tuple[dict, dict]:
    """Return ({feature: value or None}, {feature: number of observations})."""
    values, counts = {}, {}
    for name, sources in SPEECH_FEATURE_SOURCES.items():
        values[name], counts[name] = median_feature(usable_speech, sources)
    for name, sources in MOTION_FEATURE_SOURCES.items():
        values[name], counts[name] = median_feature(motion_rows, sources)
    for name, source in C1_FEATURE_SOURCES.items():
        value = _number((c1_features or {}).get(source))
        values[name], counts[name] = value, int(value is not None)
    values["age_years"], counts["age_years"] = age, int(age is not None)
    return values, counts


def evidence_gaps(n_usable_recordings: int, n_movement_sessions: int, age: Optional[float],
                  min_recordings: int, min_movement_sessions: int) -> list[str]:
    gaps = []
    if n_usable_recordings < min_recordings:
        gaps.append(f"usable_reading_recordings ({n_usable_recordings} of {min_recordings})")
    if n_movement_sessions < min_movement_sessions:
        gaps.append(f"touch_movement_sessions ({n_movement_sessions} of {min_movement_sessions})")
    if age is None:
        gaps.append("age")
    return gaps


def outside_training_range(values: dict, ranges: dict, margin: float = 0.10) -> list[dict]:
    outside = []
    for name, value in values.items():
        bounds = ranges.get(name)
        if value is None or not bounds:
            continue
        width = bounds["p99"] - bounds["p01"]
        if value < bounds["p01"] - margin * width or value > bounds["p99"] + margin * width:
            outside.append({"feature": name, "label": FEATURE_LABELS.get(name, name),
                            "value": round(float(value), 4),
                            "training_range": [round(bounds["p01"], 4), round(bounds["p99"], 4)]})
    return outside
