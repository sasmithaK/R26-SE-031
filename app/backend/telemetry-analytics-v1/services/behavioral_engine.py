import statistics
from datetime import datetime, timedelta, timezone
from typing import List, Dict, Any, Optional

from schemas.telemetry import TelemetrySessionSubmit, TelemetryEvent
from schemas.c1 import SessionSummary

def _median_or_none(values: List[float]) -> Optional[float]:
    if not values:
        return None
    return statistics.median(values)

def _safe_divide(numerator: float, denominator: float) -> float:
    return numerator / denominator if denominator > 0 else 0.0


def _rate(numerator: float, denominator: float) -> Optional[float]:
    """A share over completed rounds; ``None`` (not 0) when nothing was completed.

    A session in which every round was abandoned has no accuracy. Storing 0
    made dashboards average a fake 0% into the learner's accuracy and a fake
    0 into attempts per round.
    """
    return numerator / denominator if denominator > 0 else None

def _response_ms(e: TelemetryEvent) -> int:
    """Time to first answer; first touch for older app versions."""
    return e.time_to_first_response_ms or e.first_touch_latency_ms


def _is_first_attempt_correct(e: TelemetryEvent) -> bool:
    if e.first_attempt_correct is not None:
        return e.first_attempt_correct
    return e.is_correct


# Observed error categories. Only an error type reported by the task itself is
# categorised; a missing type stays "unknown_error" (shown as "type not
# recorded"). Errors are never inferred from the knowledge component, because a
# wrong answer in a picture task is not evidence of letter confusion.
_ERROR_CATEGORIES = {
    # Look-alike letter / glyph confusion (orthographic)
    "visual_confusion": "visual_confusion",
    "orthographic_confusion": "visual_confusion",
    # Picture-task errors (search, matching, sorting, memory)
    "visual_search_miss": "visual_task_error",
    "visual_matching_error": "visual_task_error",
    "categorization_error": "visual_task_error",
    "visual_memory_error": "visual_task_error",
    # Sound / language errors
    "phonological_confusion": "phonological_confusion",
    "sound_letter_error": "phonological_confusion",
    "word_recognition_error": "phonological_confusion",
    "oral_reading_error": "phonological_confusion",
    # Order errors
    "sequence_error": "sequence_error",
    "spelling_sequence_error": "sequence_error",
    "sentence_order_error": "sequence_error",
    "visual_pattern_error": "sequence_error",
    "sequence_memory_error": "sequence_error",
    # Letter tasks (Skill 2): look-alike letter choices
    "orthographic_discrimination_error": "visual_confusion",
    # Sound-letter, word and sentence tasks (Skills 2-5)
    "phoneme_grapheme_confusion": "phonological_confusion",
    "image_word_mapping_error": "phonological_confusion",
    "word_formation_error": "phonological_confusion",
    "auditory_word_error": "phonological_confusion",
    "word_completion_error": "phonological_confusion",
    "sentence_comprehension_error": "phonological_confusion",
    "sentence_completion_error": "phonological_confusion",
    "auditory_sentence_error": "phonological_confusion",
    "reading_comprehension_error": "phonological_confusion",
    "unknown_error": "unknown_error",
}

ERROR_CATEGORY_KEYS = (
    "visual_confusion",
    "visual_task_error",
    "phonological_confusion",
    "sequence_error",
    "unknown_error",
)


def _error_category(error_type: Optional[str], knowledge_component_id: Optional[str] = None) -> str:
    """Map a task-reported error type to a research category.

    ``knowledge_component_id`` is accepted for backward compatibility but is
    deliberately not used to invent an error type.
    """
    normalized = (error_type or "").strip().lower()
    return _ERROR_CATEGORIES.get(normalized, "unknown_error")


def _session_bounds(session: TelemetrySessionSubmit) -> tuple[str, str]:
    """Return genuine UTC session boundaries, with a safe legacy fallback."""
    def parse(value: Optional[str]) -> Optional[datetime]:
        if not value:
            return None
        try:
            parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
            if parsed.tzinfo is None:
                parsed = parsed.replace(tzinfo=timezone.utc)
            return parsed.astimezone(timezone.utc)
        except (TypeError, ValueError):
            return None

    started = parse(session.started_at)
    completed = parse(session.completed_at)
    duration = timedelta(seconds=max(0, session.session_duration_seconds))
    if started is None and completed is None:
        completed = datetime.now(timezone.utc)
        started = completed - duration
    elif started is None:
        started = completed - duration
    elif completed is None:
        completed = started + duration
    if started > completed:
        started = completed - duration
    return started.isoformat(), completed.isoformat()

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
    
    accuracy = _rate(correct_trials, valid_trials)
    error_rate = _rate(incorrect_trials, valid_trials)
    abandonment_rate = _safe_divide(len(abandoned_events), total_trials)
    
    events_with_correction = [e for e in valid_events if e.correction_count > 0]
    correction_rate = _rate(len(events_with_correction), valid_trials)
    
    median_response_latency = _median_or_none([_response_ms(e) for e in valid_events if _response_ms(e)])
    drag_rounds = [e for e in valid_events if e.response_modality == "drag"]
    stray_drops_per_drag_round = (
        sum(e.stray_drop_count for e in drag_rounds) / len(drag_rounds) if drag_rounds else None
    )
    median_time_to_correct_ms = _median_or_none([e.time_to_correct_ms for e in valid_events if e.time_to_correct_ms > 0])
    
    mean_attempts_per_round = _rate(sum(e.attempt_count for e in valid_events), valid_trials)
    mean_incorrect_attempts_per_round = _rate(sum(e.incorrect_attempt_count for e in valid_events), valid_trials)
    retry_events = [e for e in valid_events if e.attempt_count > 1]
    retry_rate = _rate(len(retry_events), valid_trials)
    eventual_completion_rate = _rate(len([e for e in valid_events if e.final_correct]), valid_trials)
    
    # Error breakdowns (shares of first-attempt errors, by reported type)
    error_counts = {key: 0 for key in ERROR_CATEGORY_KEYS}
    for event in incorrect_events:
        error_counts[_error_category(event.error_type)] += 1
    visual_confusion_rate = _safe_divide(error_counts["visual_confusion"], incorrect_trials)
    phonological_confusion_rate = _safe_divide(error_counts["phonological_confusion"], incorrect_trials)
    sequence_error_rate = _safe_divide(error_counts["sequence_error"], incorrect_trials)

    # Audio replay
    audio_prompt_trials = sum(1 for e in valid_events if e.prompt_modality == "audio" or e.audio_replay_count > 0)
    total_audio_replays = sum([e.audio_replay_count for e in valid_events])
    
    mean_audio_replays_per_audio_trial = _safe_divide(total_audio_replays, audio_prompt_trials) if audio_prompt_trials > 0 else None
    trials_with_replays = sum(1 for e in valid_events if e.audio_replay_count > 0)
    audio_replay_trial_rate = _safe_divide(trials_with_replays, audio_prompt_trials) if audio_prompt_trials > 0 else None
    
    # Deprecated fallback
    audio_replay_rate = _rate(total_audio_replays, audio_prompt_trials)
    
    mean_hesitation_count = _rate(sum(e.hesitation_count for e in valid_events), valid_trials)
    
    # Aggregations
    activity_breakdown = _aggregate_by_activity(valid_events)
    activity_breakdown_by_skill = _aggregate_by_skill_activity(events)
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
        "eventual_completion_rate": eventual_completion_rate,
        "stray_drops_per_drag_round": stray_drops_per_drag_round,
    }
    
    error_profile = {
        "visual_confusion_rate": visual_confusion_rate,
        "phonological_confusion_rate": phonological_confusion_rate,
        "sequence_error_rate": sequence_error_rate,
        "visual_task_error_rate": _safe_divide(error_counts["visual_task_error"], incorrect_trials),
        "unknown_error_rate": _safe_divide(error_counts["unknown_error"], incorrect_trials),
        "error_count": incorrect_trials,
    }
    
    started_at, completed_at = _session_bounds(session)
    return SessionSummary(
        student_id=session.student_id,
        session_id=session.session_id,
        started_at=started_at,
        completed_at=completed_at,
        total_trials=total_trials,
        valid_trials=valid_trials,
        abandoned_trials=len(abandoned_events),
        overall=overall,
        error_profile=error_profile,
        behavioral_fatigue_proxy=fatigue_proxy,
        fatigue_state=fatigue_components.get("state"),
        fatigue_components=fatigue_components,
        knowledge_components=knowledge_components,
        activity_breakdown=activity_breakdown,
        activity_breakdown_by_skill=activity_breakdown_by_skill,
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
        visual_errors = sum(1 for e in evs if not _is_first_attempt_correct(e) and _error_category(e.error_type, e.knowledge_component_id) == "visual_confusion")
        
        result[aid] = {
            "trials": len(evs),
            "accuracy": accuracy,
            "median_response_latency_ms": median_lat,
            "visual_confusion_rate": _safe_divide(visual_errors, incorrect)
        }
    return result


def _aggregate_by_skill_activity(events: List[TelemetryEvent]) -> dict:
    """Aggregate separately when identical activity IDs occur in different skills."""
    grouped: dict[tuple[str, str], list[TelemetryEvent]] = {}
    for event in events:
        key = (event.skill_id or "unknown", event.activity_id or "unknown")
        grouped.setdefault(key, []).append(event)
    result = {}
    for (skill_id, activity_id), rows in grouped.items():
        completed = [event for event in rows if not event.is_abandoned]
        first_correct = sum(1 for event in completed if _is_first_attempt_correct(event))
        attempts = sum(max(1, event.attempt_count) for event in completed)
        result[f"{skill_id}::{activity_id}"] = {
            "skill_id": skill_id,
            "activity_id": activity_id,
            "activity_name": next((event.activity_name for event in rows if event.activity_name), activity_id),
            "trials": len(completed),
            "abandoned_trials": sum(1 for event in rows if event.is_abandoned),
            "accuracy": _safe_divide(first_correct, len(completed)) if completed else None,
            "retry_rate": _safe_divide(sum(1 for event in completed if event.attempt_count > 1), len(completed)) if completed else None,
            "mean_attempts_per_round": _safe_divide(attempts, len(completed)) if completed else None,
            "correction_rate": _safe_divide(sum(1 for event in completed if event.correction_count > 0), len(completed)) if completed else None,
            "support_rate": _safe_divide(sum(1 for event in completed if event.scaffold_level_used > 0 or event.hint_count > 0), len(completed)) if completed else None,
            "eventual_completion_rate": _safe_divide(sum(1 for event in completed if event.final_correct), len(completed)) if completed else None,
            "prompt_modalities": sorted({event.prompt_modality for event in rows if event.prompt_modality}),
            "response_modalities": sorted({event.response_modality for event in rows if event.response_modality}),
            "median_response_latency_ms": _median_or_none([
                event.first_touch_latency_ms for event in completed if event.first_touch_latency_ms > 0
            ]),
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
        
        err_dist = {}
        if incorrect > 0:
            counts = {key: 0 for key in ERROR_CATEGORY_KEYS}
            for e in evs:
                if not _is_first_attempt_correct(e):
                    counts[_error_category(e.error_type)] += 1
            err_dist = {key: _safe_divide(value, incorrect) for key, value in counts.items()}

        result[kc] = {
            "trials": len(evs),
            "accuracy": accuracy,
            "median_response_latency_ms": median_lat,
            "error_distribution": err_dist
        }
    return result

def _calculate_fatigue(events: List[TelemetryEvent]) -> tuple[Optional[float], dict]:
    """Within-session fatigue proxy; one shared definition (``services/c1/fatigue.py``)."""
    from services.c1.fatigue import fatigue_from_events
    return fatigue_from_events(events)
