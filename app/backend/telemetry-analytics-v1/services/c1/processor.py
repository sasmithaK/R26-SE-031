from typing import List, Dict

from . import features as feats
from . import indices
from . import fatigue
from . import interaction_state
from . import quality

def extract_features(events: List[dict]) -> dict:
    """Extracts the 13 canonical behavioral features from a list of telemetry events."""
    return {
        "accuracy": feats.calculate_accuracy(events),
        "mean_latency_ms": feats.calculate_mean_latency(events),
        "median_latency_ms": feats.calculate_median_latency(events),
        "latency_std_ms": feats.calculate_latency_std(events),
        "mean_first_touch_latency_ms": feats.calculate_mean_first_touch_latency(events),
        "hesitation_rate": feats.calculate_rate(events, "hesitation_count"),
        "misclick_rate": feats.calculate_rate(events, "misclick_count"),
        "replay_rate": feats.calculate_rate(events, "audio_replay_count"),
        "completion_rate": feats.calculate_completion_rate(events),
        "latency_drift": feats.calculate_latency_drift(events),
        "error_drift": feats.calculate_error_drift(events),
        "hesitation_drift": feats.calculate_hesitation_drift(events),
        "accuracy_slope": feats.calculate_accuracy_slope(events),
        "total_questions": feats.calculate_total_questions(events),
        "correct_answers": feats.calculate_correct_count(events),
        "hesitation_count": feats.calculate_total_count(events, "hesitation_count"),
        "misclick_count": feats.calculate_total_count(events, "misclick_count"),
        "replay_count": feats.calculate_total_count(events, "audio_replay_count")
    }

def process_session(session_id: str, student_id: str, events: List[dict]) -> dict:
    """
    Main orchestration function for Component 1.
    Calculates features, indices, and states.
    Does NOT run ML inference (handled at the API layer).
    """
    
    # 1. Base Behavioral Features
    f = extract_features(events)
    
    # 2. Quality Metrics
    q = quality.calculate_quality(events, f)
    
    # 3. Learner Indices
    # Assume task type for now based on first event or default to true for phonological
    is_phono = any("phonetic" in e.get("distractor_matrix", {}) for e in events)
    idx = {
        "visual_processing_index": indices.get_visual_processing_index(f["mean_first_touch_latency_ms"]),
        "phonological_task_index": indices.get_phonological_task_index(f["mean_first_touch_latency_ms"], is_phono),
        "motor_interaction_index": indices.get_motor_interaction_index(f["misclick_rate"], f["hesitation_rate"]),
        "attention_stability_index": indices.get_attention_stability_index(f["hesitation_rate"])
    }
    
    # 4. Fatigue State
    fatigue_score = fatigue.calculate_fatigue_score(
        f.get("latency_drift"), 
        f.get("error_drift"), 
        f.get("hesitation_drift")
    )
    fatigue_state = fatigue.get_fatigue_state(fatigue_score)
    
    # 5. Interaction State
    interaction_score = interaction_state.calculate_cognitive_load_score(
        f.get("mean_latency_ms"), 
        f.get("hesitation_rate"), 
        f.get("misclick_rate")
    )
    interaction_s = interaction_state.get_interaction_state(interaction_score)
    
    # Build Partial C1 Result (ML to be added by caller)
    return {
        "student_id": student_id,
        "session_id": session_id,
        "behavior": f,
        "indices": idx,
        "fatigue": {
            "score": round(fatigue_score, 2),
            "state": fatigue_state
        },
        "interaction_state": {
            "score": interaction_score,
            "state": interaction_s
        },
        "quality": q,
        # model metadata to be populated later
        "model": {}
    }
