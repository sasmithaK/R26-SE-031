"""Within-session fatigue proxy shared by the session summary and the C1 state.

One definition is used everywhere:

* only completed (not abandoned) rounds are compared, in the order played;
* early = first ``w`` rounds, late = last ``w`` rounds, with ``w = 3`` when a
  session has 6+ rounds and ``w = 2`` for 4-5 rounds (most activities have
  4-5 rounds, so a fixed 6-round minimum meant fatigue was almost never
  measured);
* latency drift = late/early mean round time - 1 (relative slowing);
* error drift = late - early share of first-try errors (-1..1);
* hesitation drift = late - early mean hesitations per round;
* only positive drifts add to the 0-1 score.
"""
import os
import statistics
from typing import Any, Iterable, Optional

import yaml


def _load_config():
    config_path = os.path.join(os.path.dirname(__file__), "..", "..", "config", "thresholds.yaml")
    if not os.path.exists(config_path):
        return {}
    with open(config_path, 'r') as f:
        return yaml.safe_load(f) or {}

CONFIG = _load_config()
_FATIGUE = CONFIG.get("fatigue", {}) or {}
MIN_ROUNDS = int(_FATIGUE.get("min_rounds", 4))
FULL_WINDOW_ROUNDS = int(_FATIGUE.get("full_window_min_rounds", 6))


def _get(event: Any, field: str, default=None):
    if isinstance(event, dict):
        return event.get(field, default)
    return getattr(event, field, default)


def _first_try_error(event: Any) -> float:
    first = _get(event, "first_attempt_correct")
    if not isinstance(first, bool):
        first = bool(_get(event, "is_correct", False))
    return 0.0 if first else 1.0


def completed_rounds(events: Iterable[Any]) -> list:
    """Rounds that ended normally (abandoned rounds never count)."""
    return [e for e in events if not _get(e, "is_abandoned", False)]


def window_size(n: int) -> Optional[int]:
    if n < MIN_ROUNDS:
        return None
    return 3 if n >= FULL_WINDOW_ROUNDS else 2


def compute_drifts(events: Iterable[Any]) -> Optional[dict]:
    """Early-vs-late drifts over completed rounds, or ``None`` if too few."""
    rounds = completed_rounds(events)
    w = window_size(len(rounds))
    if w is None:
        return None
    early, late = rounds[:w], rounds[-w:]

    def mean(rows, fn):
        return statistics.mean(fn(e) for e in rows)

    early_lat = mean(early, lambda e: float(_get(e, "total_round_latency_ms", 0) or 0))
    late_lat = mean(late, lambda e: float(_get(e, "total_round_latency_ms", 0) or 0))
    return {
        "latency_drift": ((late_lat / early_lat) - 1.0) if early_lat > 0 else None,
        "error_drift": mean(late, _first_try_error) - mean(early, _first_try_error),
        "hesitation_drift": (mean(late, lambda e: float(_get(e, "hesitation_count", 0) or 0))
                             - mean(early, lambda e: float(_get(e, "hesitation_count", 0) or 0))),
        "window_rounds": w,
        "trials": len(rounds),
    }


def calculate_fatigue_score(latency_drift: Optional[float], error_drift: Optional[float],
                            hesitation_drift: Optional[float]) -> Optional[float]:
    """0-1 score from positive drifts; ``None`` when no drift was measurable."""
    if latency_drift is None and error_drift is None and hesitation_drift is None:
        return None
    ld = max(0.0, latency_drift) if latency_drift is not None else 0.0
    ed = max(0.0, error_drift) if error_drift is not None else 0.0
    hd = max(0.0, hesitation_drift) if hesitation_drift is not None else 0.0
    score = (0.5 * ld) + (0.3 * ed) + (0.2 * hd)
    return min(1.0, score)


def get_fatigue_state(score: Optional[float]) -> str:
    if score is None:
        return "INSUFFICIENT_DATA"
    cfg = {"low_max": 0.30, "moderate_max": 0.60, "high_max": 0.80, **_FATIGUE}
    if score <= cfg["low_max"]:
        return "LOW"
    elif score <= cfg["moderate_max"]:
        return "MODERATE"
    elif score <= cfg["high_max"]:
        return "HIGH"
    return "VERY_HIGH"


def fatigue_from_events(events: Iterable[Any]) -> tuple[Optional[float], dict]:
    """Score and components for one session (shared entry point)."""
    drifts = compute_drifts(events)
    if drifts is None:
        n = len(completed_rounds(events))
        return None, {"reason": f"needs at least {MIN_ROUNDS} completed rounds",
                      "trials": n, "state": "INSUFFICIENT_DATA"}
    score = calculate_fatigue_score(drifts["latency_drift"], drifts["error_drift"], drifts["hesitation_drift"])
    return (round(score, 4) if score is not None else None), {**drifts, "state": get_fatigue_state(score)}
