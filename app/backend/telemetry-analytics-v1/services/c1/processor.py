from typing import List, Dict

from . import features as feats
from . import indices
from . import fatigue
from . import interaction_state
from . import quality

def extract_features(events: List[dict]) -> dict:
    """Extracts the canonical behavioral features for one session.

    Every feature except ``completion_rate`` is computed over completed
    rounds only. Abandoned rounds (the child left mid-round, or the app
    closed) carry no answer and used to inflate latency and lower accuracy.
    Drift features use the shared early-vs-late definition in ``fatigue.py``
    so the model input, the C1 state and the session summary agree.
    """
    done = fatigue.completed_rounds(events)
    drifts = fatigue.compute_drifts(events) or {}
    return {
        # Keep `accuracy` for the existing C1 model contract, while exposing
        # the two research meanings explicitly so assisted success is never
        # mistaken for independent mastery in Component 4 analysis.
        "accuracy": feats.calculate_accuracy(done),
        "independent_accuracy": feats.calculate_independent_accuracy(done),
        "eventual_completion_accuracy": feats.calculate_eventual_completion_accuracy(done),
        "mean_latency_ms": feats.calculate_mean_latency(done),
        "median_latency_ms": feats.calculate_median_latency(done),
        "latency_std_ms": feats.calculate_latency_std(done),
        "mean_first_touch_latency_ms": feats.calculate_mean_first_touch_latency(done),
        "hesitation_rate": feats.calculate_rate(done, "hesitation_count"),
        "misclick_rate": feats.calculate_rate(done, "misclick_count"),
        "replay_rate": feats.calculate_rate(done, "audio_replay_count"),
        "completion_rate": feats.calculate_completion_rate(events),
        "latency_drift": drifts.get("latency_drift"),
        "error_drift": drifts.get("error_drift"),
        "hesitation_drift": drifts.get("hesitation_drift"),
        "accuracy_slope": feats.calculate_accuracy_slope(done),
        "total_questions": feats.calculate_total_questions(done),
        "correct_answers": feats.calculate_correct_count(done),
        "hesitation_count": feats.calculate_total_count(done, "hesitation_count"),
        "misclick_count": feats.calculate_total_count(done, "misclick_count"),
        "replay_count": feats.calculate_total_count(done, "audio_replay_count"),
        "completed_rounds": len(done),
        "abandoned_rounds": len(events) - len(done),
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
    # Curriculum metadata, rather than distractor text, determines whether a
    # response belongs to a sound/language task. This keeps activity mappings
    # stable across Sinhala content revisions.
    phonological_kcs = {
        "KC_PHONEME_GRAPHEME", "KC_PHONEME_LETTER_MAPPING",
        "KC_LETTER_DECODING", "KC_WORD_RECOGNITION",
        "KC_READING_COMPREHENSION", "KC_ORAL_READING_FLUENCY",
    }
    done = fatigue.completed_rounds(events)
    is_phono = any(e.get("knowledge_component_id") in phonological_kcs for e in done)
    idx = {
        "visual_processing_index": indices.get_visual_processing_index(f["mean_first_touch_latency_ms"]),
        "phonological_task_index": indices.get_phonological_task_index(f["mean_first_touch_latency_ms"], is_phono),
        "motor_interaction_index": indices.get_motor_interaction_index(f["misclick_rate"], f["hesitation_rate"]),
        "attention_stability_index": indices.get_attention_stability_index(f["hesitation_rate"])
    }
    
    # 4. Fatigue State (shared definition; None when too few rounds)
    fatigue_score = fatigue.calculate_fatigue_score(
        f.get("latency_drift"), 
        f.get("error_drift"), 
        f.get("hesitation_drift")
    )
    fatigue_state = fatigue.get_fatigue_state(fatigue_score)
    
    # 5. Interaction State (needs a minimum number of completed rounds)
    if len(done) >= interaction_state.MIN_ROUNDS:
        interaction_score = interaction_state.calculate_cognitive_load_score(
            f.get("mean_latency_ms"), 
            f.get("hesitation_rate"), 
            f.get("misclick_rate")
        )
        interaction_s = interaction_state.get_interaction_state(interaction_score)
    else:
        interaction_score, interaction_s = None, "INSUFFICIENT_DATA"
    
    # Build Partial C1 Result (ML to be added by caller)
    return {
        "student_id": student_id,
        "session_id": session_id,
        "behavior": f,
        "indices": idx,
        "fatigue": {
            "score": round(fatigue_score, 2) if fatigue_score is not None else None,
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
