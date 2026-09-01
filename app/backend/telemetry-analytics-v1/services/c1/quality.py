from typing import List

def calculate_quality(events: List[dict], features: dict) -> dict:
    events_received = len(events)
    # Define an event as valid if it has positive latency and boolean correctness
    valid_events = [e for e in events if e.get("total_round_latency_ms", -1) >= 0 and isinstance(e.get("is_correct"), bool)]
    events_valid = len(valid_events)
    events_invalid = events_received - events_valid
    
    # Check completeness of the 13 base behavioral features
    total_features = len(features)
    missing_features = sum(1 for v in features.values() if v is None)
    
    missing_feature_rate = missing_features / total_features if total_features > 0 else 1.0
    
    # Basic quality score metric: (valid_events_ratio) * (1 - missing_feature_rate)
    valid_ratio = events_valid / events_received if events_received > 0 else 0.0
    quality_score = valid_ratio * (1.0 - missing_feature_rate)
    
    return {
        "events_received": events_received,
        "events_valid": events_valid,
        "events_invalid": events_invalid,
        "missing_feature_rate": round(missing_feature_rate, 2),
        "quality_score": round(max(0.0, min(1.0, quality_score)), 2)
    }
