"""Learner-level C1 features over a time window (default 14 days).

Why learner-level: one activity session has 4-5 rounds of one task type, which
is too little to describe a learning pattern, and picture-only sessions never
measure the sound/letter-sound task index. Pooling a learner's recent rounds
from Skills 1-4 gives enough evidence, mixes task types, and is the same unit
of analysis C3 uses.

The SAME function builds the features for live learners and for the simulated
learners the model is trained on (``scripts/simulate_c1_sessions.py``), so the
training data and the live data are computed identically by construction.

Rules:
* only completed (not abandoned) rounds are used, de-duplicated by event_id;
* fatigue/drift are within-session measures: computed per session (4+ rounds,
  shared definition in ``fatigue.py``) and summarised by their median;
* a feature that cannot be measured is ``None`` (never imputed); the model
  handles missing values natively and the dashboard says what is missing.
"""
from __future__ import annotations

import os
import statistics
from typing import Any, Iterable, Optional

import yaml

from . import features as feats
from . import fatigue
from . import indices
from . import interaction_state

FEATURE_VERSION = "c1-learner-v2"

PHONOLOGICAL_KCS = {
    "KC_PHONEME_GRAPHEME", "KC_PHONEME_LETTER_MAPPING",
    "KC_LETTER_DECODING", "KC_WORD_RECOGNITION",
    "KC_READING_COMPREHENSION", "KC_ORAL_READING_FLUENCY",
}
PICTURE_KCS = {
    "KC_VISUAL_SUPPORT", "KC_VISUAL_IDENTIFICATION", "KC_VISUAL_MATCHING",
    "KC_VISUAL_CATEGORIZATION", "KC_VISUAL_PATTERN", "KC_VISUAL_MEMORY",
}


def _load_rules() -> dict:
    path = os.path.join(os.path.dirname(__file__), "..", "..", "config", "thresholds.yaml")
    try:
        with open(path, "r") as f:
            cfg = (yaml.safe_load(f) or {}).get("c1_learner_window", {}) or {}
    except OSError:
        cfg = {}
    return {
        "window_days": int(cfg.get("window_days", 14)),
        "min_completed_rounds": int(cfg.get("min_completed_rounds", 20)),
        "min_sessions": int(cfg.get("min_sessions", 2)),
    }


RULES = _load_rules()


def _dedupe(events: Iterable[dict]) -> list[dict]:
    seen, kept = set(), []
    for event in reversed(list(events or [])):
        if not isinstance(event, dict):
            continue
        key = event.get("event_id")
        if key and key in seen:
            continue
        if key:
            seen.add(key)
        kept.append(event)
    return list(reversed(kept))


def _first_try(event: dict) -> Optional[bool]:
    value = event.get("first_attempt_correct")
    if isinstance(value, bool):
        return value
    value = event.get("is_correct")
    return value if isinstance(value, bool) else None


def _mean(values):
    values = [v for v in values if v is not None]
    return statistics.mean(values) if values else None


def _median(values):
    values = [v for v in values if v is not None]
    return statistics.median(values) if values else None


def _positive(values):
    return [v for v in values if isinstance(v, (int, float)) and v > 0]


MODEL_SKILLS = {"1", "2", "3", "4"}  # the touch-activity skills the model is trained on


def in_model_scope(event: dict) -> bool:
    """Skill 1-4 rounds only (Skill 5 reading MCQs and letter practice are excluded)."""
    digits = "".join(ch for ch in str(event.get("skill_id") or "") if ch.isdigit())
    return digits in MODEL_SKILLS


def build_learner_features(sessions: list[tuple[dict, list[dict]]]) -> dict:
    """Features + evidence summary for one learner.

    ``sessions`` = [(session_meta, events), ...] in chronological order. Only the
    events matter; ``session_meta`` may carry ``session_id``/``completed_at``.
    """
    per_session = []
    for meta, events in sessions:
        events = [e for e in _dedupe(events) if in_model_scope(e)]
        if not events:
            continue
        done = fatigue.completed_rounds(events)
        per_session.append((meta, events, done))

    all_events = [e for _, events, _ in per_session for e in events]
    done = [e for _, _, d in per_session for e in d]
    n_done = len(done)

    # Within-session drifts, summarised across sessions with enough rounds.
    drifts = [fatigue.compute_drifts(events) for _, events, _ in per_session]
    drifts = [d for d in drifts if d]
    latency_drift = _median([d["latency_drift"] for d in drifts])
    error_drift = _median([d["error_drift"] for d in drifts])
    hesitation_drift = _median([d["hesitation_drift"] for d in drifts])
    fatigue_score = fatigue.calculate_fatigue_score(latency_drift, error_drift, hesitation_drift) if drifts else None

    round_times = [e.get("total_round_latency_ms") for e in done
                   if isinstance(e.get("total_round_latency_ms"), (int, float))]
    first_try = [_first_try(e) for e in done]
    first_try = [v for v in first_try if v is not None]

    phono = [e for e in done if e.get("knowledge_component_id") in PHONOLOGICAL_KCS]
    non_phono = [e for e in done if e.get("knowledge_component_id") not in PHONOLOGICAL_KCS]
    picture = [e for e in done if e.get("knowledge_component_id") in PICTURE_KCS]

    def mean_first_touch(rows):
        # First touch, as in the training simulator (not time to first answer).
        return _mean(_positive([e.get("first_touch_latency_ms") for e in rows]))

    hesitation_rate = feats.calculate_rate(done, "hesitation_count") if done else None
    misclick_rate = feats.calculate_rate(done, "misclick_count") if done else None
    replay_rate = feats.calculate_rate(done, "audio_replay_count") if done else None
    mean_latency = _mean(round_times)

    # Accuracy trend across the window, in the order rounds were played.
    slope = None
    if len(first_try) >= 2:
        n = len(first_try)
        xm, ym = (n - 1) / 2, sum(first_try) / n
        den = sum((i - xm) ** 2 for i in range(n))
        slope = (sum((i - xm) * ((1.0 if v else 0.0) - ym) for i, v in enumerate(first_try)) / den) if den else 0.0

    load = (interaction_state.calculate_cognitive_load_score(mean_latency, hesitation_rate, misclick_rate)
            if n_done >= interaction_state.MIN_ROUNDS else None)

    values = {
        "accuracy": (sum(first_try) / len(first_try)) if first_try else None,
        "mean_latency_ms": mean_latency,
        "median_latency_ms": _median(round_times),
        "latency_std_ms": statistics.stdev(round_times) if len(round_times) > 1 else None,
        "mean_first_touch_latency_ms": mean_first_touch(done),
        "hesitation_rate": hesitation_rate,
        "misclick_rate": misclick_rate,
        "replay_rate": replay_rate,
        "completion_rate": (n_done / len(all_events)) if all_events else None,
        "latency_drift": latency_drift,
        "error_drift": error_drift,
        "hesitation_drift": hesitation_drift,
        "accuracy_slope": slope,
        "visual_processing_index": indices.get_visual_processing_index(mean_first_touch(non_phono)),
        "phonological_task_index": indices.get_phonological_task_index(mean_first_touch(phono), bool(phono)),
        "motor_interaction_index": indices.get_motor_interaction_index(misclick_rate, hesitation_rate),
        "attention_stability_index": indices.get_attention_stability_index(hesitation_rate),
        "fatigue_score": fatigue_score,
        "cognitive_load_score": load,
    }

    sessions_with_rounds = sum(1 for _, _, d in per_session if d)
    evidence = {
        "completed_rounds": n_done,
        "abandoned_rounds": len(all_events) - n_done,
        "sessions": len(per_session),
        "sessions_with_completed_rounds": sessions_with_rounds,
        "picture_task_rounds": len(picture),
        "sound_task_rounds": len(phono),
        "sessions_with_4plus_rounds": len(drifts),
        "skills": sorted({str(e.get("skill_id")) for e in done if e.get("skill_id")}),
    }
    return {"features": values, "evidence": evidence}


def evidence_gaps(evidence: dict, rules: Optional[dict] = None) -> list[str]:
    """Plain-language list of what is still needed before the model may run."""
    rules = rules or RULES
    gaps = []
    if evidence["completed_rounds"] < rules["min_completed_rounds"]:
        gaps.append(f"{evidence['completed_rounds']} of {rules['min_completed_rounds']} completed rounds")
    if evidence["sessions_with_completed_rounds"] < rules["min_sessions"]:
        gaps.append(f"{evidence['sessions_with_completed_rounds']} of {rules['min_sessions']} sessions with completed rounds")
    return gaps


def evidence_notes(evidence: dict, feature_values: dict) -> list[str]:
    """Measurements that are missing but allowed (the model handles them)."""
    notes = []
    if not evidence.get("sound_task_rounds"):
        notes.append("No sound or letter-sound tasks yet (Skill 2 activities 3-4, Skill 3 activities 1 and 3): "
                     "the estimate uses picture, letter and word tasks only.")
    if feature_values.get("fatigue_score") is None:
        notes.append("No session with 4+ completed rounds: within-session fatigue not measured.")
    return notes
