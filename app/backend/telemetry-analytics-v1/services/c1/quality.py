from typing import List

# Counters are always present, so they are not part of the completeness check.
_COUNTERS = {"total_questions", "correct_answers", "hesitation_count", "misclick_count",
             "replay_count", "completed_rounds", "abandoned_rounds"}


def calculate_quality(events: List[dict], features: dict) -> dict:
    """Session data quality: completed, well-formed rounds x measurable features.

    ``events_valid`` counts completed (not abandoned) rounds with a round time
    and a boolean outcome. ``missing_feature_rate`` is the share of behavioural
    features that could not be measured (for example drift needs 4+ rounds).
    """
    events_received = len(events)
    valid_events = [
        e for e in events
        if not e.get("is_abandoned", False)
        and isinstance(e.get("total_round_latency_ms"), (int, float))
        and e.get("total_round_latency_ms") >= 0
        and isinstance(e.get("is_correct"), bool)
    ]
    events_valid = len(valid_events)
    measured = {k: v for k, v in features.items() if k not in _COUNTERS}
    total_features = len(measured)
    missing_features = sum(1 for v in measured.values() if v is None)
    missing_feature_rate = missing_features / total_features if total_features > 0 else 1.0
    valid_ratio = events_valid / events_received if events_received > 0 else 0.0
    quality_score = valid_ratio * (1.0 - missing_feature_rate)

    return {
        "events_received": events_received,
        "events_valid": events_valid,
        "events_invalid": events_received - events_valid,
        "missing_feature_rate": round(missing_feature_rate, 2),
        "missing_features": sorted(k for k, v in measured.items() if v is None),
        "quality_score": round(max(0.0, min(1.0, quality_score)), 2)
    }
