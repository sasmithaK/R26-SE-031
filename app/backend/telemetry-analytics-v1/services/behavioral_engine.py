import statistics
from datetime import datetime, timezone
from typing import List, Dict, Any, Optional

from schemas.telemetry import TelemetrySessionSubmit, TelemetryEvent
from schemas.c1 import SessionSummary

def _median_or_none(values: List[float]) -> Optional[float]:
    if not values:
        return None
    return statistics.median(values)

def _safe_divide(numerator: float, denominator: float) -> float:
    return numerator / denominator if denominator > 0 else 0.0

def _is_first_attempt_correct(e: TelemetryEvent) -> bool:
    if e.first_attempt_correct is not None:
        return e.first_attempt_correct
    return e.is_correct

def extract_session_features(session: TelemetrySessionSubmit) -> SessionSummary:
    events = session.events
    total_trials = len(events)
    
    valid_events = [e for e in events if not e.is_abandoned]
    abandoned_events = [e for e in events if e.is_abandoned]
    valid_trials = len(valid_events)
    
    correct_events = [e for e in valid_events if _is_first_attempt_correct(e)]
    incorrect_events = [e for e in valid_events if not _is_first_attempt_correct(e)]
    
    correct_trials = len(correct_events)
    incorrect_trials = len(incorrect_events)
    
    accuracy = _safe_divide(correct_trials, valid_trials)
    error_rate = _safe_divide(incorrect_trials, valid_trials)
    abandonment_rate = _safe_divide(len(abandoned_events), total_trials)
    
    events_with_correction = [e for e in valid_events if e.correction_count > 0]
    correction_rate = _safe_divide(len(events_with_correction), valid_trials)
    
    median_response_latency = _median_or_none([e.first_touch_latency_ms for e in valid_events if e.first_touch_latency_ms > 0])
    median_time_to_correct_ms = _median_or_none([e.time_to_correct_ms for e in valid_events if e.time_to_correct_ms > 0])
    
    mean_attempts_per_round = _safe_divide(sum(e.attempt_count for e in valid_events), valid_trials)
    mean_incorrect_attempts_per_round = _safe_divide(sum(e.incorrect_attempt_count for e in valid_events), valid_trials)
    retry_events = [e for e in valid_events if e.attempt_count > 1]
    retry_rate = _safe_divide(len(retry_events), valid_trials)
    eventual_completion_rate = _safe_divide(len([e for e in valid_events if e.final_correct]), valid_trials)
    
    # Error breakdowns
    visual_confusion_errors = len([e for e in incorrect_events if e.error_type == "visual_confusion"])
    phonological_confusion_errors = len([e for e in incorrect_events if e.error_type == "phonological_confusion"])
    sequence_errors = len([e for e in incorrect_events if e.error_type == "sequence_error"])
    unknown_errors = len([e for e in incorrect_events if e.error_type == "unknown_error"])
    
    visual_confusion_rate = _safe_divide(visual_confusion_errors, incorrect_trials)
    phonological_confusion_rate = _safe_divide(phonological_confusion_errors, incorrect_trials)
    sequence_error_rate = _safe_divide(sequence_errors, incorrect_trials)
    
    # Audio replay
    audio_prompt_trials = sum(1 for e in valid_events if e.prompt_modality == "audio" or e.audio_replay_count > 0)
    total_audio_replays = sum([e.audio_replay_count for e in valid_events])
    
    mean_audio_replays_per_audio_trial = _safe_divide(total_audio_replays, audio_prompt_trials) if audio_prompt_trials > 0 else None
    trials_with_replays = sum(1 for e in valid_events if e.audio_replay_count > 0)
    audio_replay_trial_rate = _safe_divide(trials_with_replays, audio_prompt_trials) if audio_prompt_trials > 0 else None
    
    # Deprecated fallback
    audio_replay_rate = _safe_divide(total_audio_replays, audio_prompt_trials)
    
    mean_hesitation_count = _safe_divide(sum(e.hesitation_count for e in valid_events), valid_trials)
    
    # Aggregations
    activity_breakdown = _aggregate_by_activity(valid_events)
    knowledge_components = _aggregate_by_kc(valid_events)
    
    # Fatigue
    fatigue_proxy, fatigue_components = _calculate_fatigue(valid_events)
    
    overall = {
        "accuracy": accuracy,
        "median_response_latency_ms": median_response_latency,
        "error_rate": error_rate,
        "correction_rate": correction_rate,
        "abandonment_rate": abandonment_rate,
        "mean_hesitation_count": mean_hesitation_count,
        "audio_replay_rate": audio_replay_rate,
        "mean_audio_replays_per_audio_trial": mean_audio_replays_per_audio_trial,
        "audio_replay_trial_rate": audio_replay_trial_rate,
        "mean_attempts_per_round": mean_attempts_per_round,
        "mean_incorrect_attempts_per_round": mean_incorrect_attempts_per_round,
        "retry_rate": retry_rate,
        "median_time_to_correct_ms": median_time_to_correct_ms,
        "eventual_completion_rate": eventual_completion_rate
    }
    
    error_profile = {
        "visual_confusion_rate": visual_confusion_rate,
        "phonological_confusion_rate": phonological_confusion_rate,
        "sequence_error_rate": sequence_error_rate,
        "unknown_error_rate": _safe_divide(unknown_errors, incorrect_trials)
    }
    
    return SessionSummary(
        student_id=session.student_id,
        session_id=session.session_id,
        started_at=datetime.now(timezone.utc).isoformat(), # Ideally from payload
        completed_at=datetime.now(timezone.utc).isoformat(),
        total_trials=total_trials,
        overall=overall,
        error_profile=error_profile,
        behavioral_fatigue_proxy=fatigue_proxy,
        fatigue_components=fatigue_components,
        knowledge_components=knowledge_components,
        activity_breakdown=activity_breakdown
    )


def _aggregate_by_activity(events: List[TelemetryEvent]) -> dict:
    grouped = {}
    for e in events:
        aid = e.activity_id
        if aid not in grouped:
            grouped[aid] = []
        grouped[aid].append(e)
        
    result = {}
    for aid, evs in grouped.items():
        correct = sum(1 for e in evs if _is_first_attempt_correct(e))
        incorrect = len(evs) - correct
        accuracy = _safe_divide(correct, len(evs))
        median_lat = _median_or_none([e.first_touch_latency_ms for e in evs if e.first_touch_latency_ms > 0])
        visual_errors = sum(1 for e in evs if not _is_first_attempt_correct(e) and e.error_type == "visual_confusion")
        
        result[aid] = {
            "trials": len(evs),
            "accuracy": accuracy,
            "median_response_latency_ms": median_lat,
            "visual_confusion_rate": _safe_divide(visual_errors, incorrect)
        }
    return result

def _aggregate_by_kc(events: List[TelemetryEvent]) -> dict:
    grouped = {}
    for e in events:
        kc = e.knowledge_component_id
        if kc not in grouped:
            grouped[kc] = []
        grouped[kc].append(e)
        
    result = {}
    for kc, evs in grouped.items():
        correct = sum(1 for e in evs if _is_first_attempt_correct(e))
        incorrect = len(evs) - correct
        accuracy = _safe_divide(correct, len(evs))
        median_lat = _median_or_none([e.first_touch_latency_ms for e in evs if e.first_touch_latency_ms > 0])
        
        visual_confusions = sum(1 for e in evs if not _is_first_attempt_correct(e) and e.error_type == "visual_confusion")
        unknown_errors = sum(1 for e in evs if not _is_first_attempt_correct(e) and e.error_type == "unknown_error")
        phonological_confusions = sum(1 for e in evs if not _is_first_attempt_correct(e) and e.error_type == "phonological_confusion")
        
        err_dist = {}
        if incorrect > 0:
            err_dist["visual_confusion"] = _safe_divide(visual_confusions, incorrect)
            err_dist["phonological_confusion"] = _safe_divide(phonological_confusions, incorrect)
            err_dist["unknown_error"] = _safe_divide(unknown_errors, incorrect)
            
        result[kc] = {
            "trials": len(evs),
            "accuracy": accuracy,
            "median_response_latency_ms": median_lat,
            "error_distribution": err_dist
        }
    return result

def _calculate_fatigue(events: List[TelemetryEvent]) -> tuple[Optional[float], dict]:
    n = len(events)
    if n < 4:
        return None, {}
        
    early = events[:2]
    late = events[-2:]
    
    early_lat = statistics.mean(e.total_round_latency_ms for e in early)
    late_lat = statistics.mean(e.total_round_latency_ms for e in late)
    latency_drift = ((late_lat / early_lat) - 1.0) if early_lat > 0 else 0.0
    
    early_err = statistics.mean(1.0 if not _is_first_attempt_correct(e) else 0.0 for e in early)
    late_err = statistics.mean(1.0 if not _is_first_attempt_correct(e) else 0.0 for e in late)
    error_drift = late_err - early_err
    
    early_hes = statistics.mean(e.hesitation_count for e in early)
    late_hes = statistics.mean(e.hesitation_count for e in late)
    hesitation_drift = late_hes - early_hes
    
    fatigue_proxy = (0.50 * latency_drift) + (0.30 * error_drift) + (0.20 * hesitation_drift)
    
    components = {
        "latency_drift": latency_drift,
        "error_drift": error_drift,
        "hesitation_drift": hesitation_drift
    }
    
    return fatigue_proxy, components
