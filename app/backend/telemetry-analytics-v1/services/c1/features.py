import statistics
from typing import List, Optional

def calculate_accuracy(events: List[dict]) -> Optional[float]:
    valid = [e for e in events if "is_correct" in e]
    if not valid:
        return None
    correct = sum(1 for e in valid if e["is_correct"])
    return correct / len(valid)

def calculate_correct_count(events: List[dict]) -> int:
    valid = [e for e in events if "is_correct" in e]
    return sum(1 for e in valid if e["is_correct"])

def calculate_total_questions(events: List[dict]) -> int:
    return len([e for e in events if "is_correct" in e])

def calculate_total_count(events: List[dict], field: str) -> int:
    return sum(e.get(field, 0) for e in events if e.get(field) is not None)

def calculate_mean_latency(events: List[dict]) -> Optional[float]:
    lats = [e.get("total_round_latency_ms") for e in events if e.get("total_round_latency_ms") is not None]
    return statistics.mean(lats) if lats else None

def calculate_median_latency(events: List[dict]) -> Optional[float]:
    lats = [e.get("total_round_latency_ms") for e in events if e.get("total_round_latency_ms") is not None]
    return statistics.median(lats) if lats else None

def calculate_latency_std(events: List[dict]) -> Optional[float]:
    lats = [e.get("total_round_latency_ms") for e in events if e.get("total_round_latency_ms") is not None]
    return statistics.stdev(lats) if len(lats) > 1 else (0.0 if lats else None)

def calculate_mean_first_touch_latency(events: List[dict]) -> Optional[float]:
    lats = [e.get("first_touch_latency_ms") for e in events if e.get("first_touch_latency_ms") is not None]
    return statistics.mean(lats) if lats else None

def calculate_rate(events: List[dict], field: str) -> Optional[float]:
    valid = [e for e in events if e.get(field) is not None]
    if not valid:
        return None
    total = sum(e[field] for e in valid)
    return total / len(events)

def calculate_completion_rate(events: List[dict]) -> Optional[float]:
    if not events:
        return None
    completed = sum(1 for e in events if not e.get("is_abandoned", False))
    return completed / len(events)

def _drift(events: List[dict], field: str, invert: bool = False) -> Optional[float]:
    vals = [e.get(field) for e in events if e.get(field) is not None]
    if len(vals) < 6:
        return None
    early = statistics.mean(vals[:3])
    late = statistics.mean(vals[-3:])
    if early <= 0:
        return None
    drift_val = (late / early) - 1.0
    return -drift_val if invert else drift_val

def calculate_latency_drift(events: List[dict]) -> Optional[float]:
    return _drift(events, "total_round_latency_ms")

def calculate_error_drift(events: List[dict]) -> Optional[float]:
    # Invert is_correct to treat 1.0 as error and 0.0 as correct
    error_vals = [0.0 if e.get("is_correct") else 1.0 for e in events if "is_correct" in e]
    if len(error_vals) < 6:
        return None
    early = statistics.mean(error_vals[:3])
    late = statistics.mean(error_vals[-3:])
    if early <= 0:
        return None
    return (late / early) - 1.0

def calculate_hesitation_drift(events: List[dict]) -> Optional[float]:
    return _drift(events, "hesitation_count")

def calculate_accuracy_slope(events: List[dict]) -> Optional[float]:
    valid = [e for e in events if "is_correct" in e]
    n = len(valid)
    if n < 2:
        return None
    scores = [1.0 if e["is_correct"] else 0.0 for e in valid]
    x_mean = (n - 1) / 2
    y_mean = statistics.mean(scores)
    denominator = sum((i - x_mean) ** 2 for i in range(n))
    if denominator == 0:
        return 0.0
    numerator = sum((i - x_mean) * (scores[i] - y_mean) for i in range(n))
    return numerator / denominator
