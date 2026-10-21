"""Starter Learning Profile calculations and server-owned item definitions.

The profile is a low-stakes cold-start aid, not a diagnosis.  The mobile app
renders the tasks, while this module owns scoring so a client cannot label its
own responses correct.  Raw observations remain separate from ordinary C4
activity telemetry and are never marked calibration eligible.
"""

from __future__ import annotations

import math
from statistics import median
from typing import Any, Dict, Iterable, List


BASELINE_VERSION = "starter-profile-v1"
DEFAULT_MASTERY = 0.30


BASELINE_ITEMS: List[Dict[str, Any]] = [
    {
        "item_id": "BL1S1V01",
        "skill_id": "skill_1",
        "knowledge_component_id": "KC_VISUAL_IDENTIFICATION",
        "difficulty_b": -1.0,
        "expected_latency_ms": 8000,
        "prompt_modality": "visual",
        "response_modality": "tap",
        "option_ids": ["cat", "dog", "cow", "rabbit"],
        "correct_answer_ids": ["dog"],
        "ordered": False,
    },
    {
        "item_id": "BL1S1V02",
        "skill_id": "skill_1",
        "knowledge_component_id": "KC_VISUAL_MATCHING",
        "difficulty_b": 0.0,
        "expected_latency_ms": 11000,
        "prompt_modality": "visual",
        "response_modality": "tap",
        "option_ids": ["bird", "elephant", "turtle", "fish"],
        "correct_answer_ids": ["elephant"],
        "ordered": False,
    },
    {
        "item_id": "BL1S2L01",
        "skill_id": "skill_2",
        "knowledge_component_id": "KC_LETTER_IDENTIFICATION",
        "difficulty_b": -1.0,
        "expected_latency_ms": 7000,
        "prompt_modality": "visual",
        "response_modality": "tap",
        "option_ids": ["ම", "අ", "ක"],
        "correct_answer_ids": ["අ"],
        "ordered": False,
    },
    {
        "item_id": "BL1S2L02",
        "skill_id": "skill_2",
        "knowledge_component_id": "KC_PHONEME_LETTER_MAPPING",
        "difficulty_b": 0.0,
        "expected_latency_ms": 10000,
        "prompt_modality": "audio_visual",
        "response_modality": "tap",
        "option_ids": ["ග", "කා", "ත", "පා"],
        "correct_answer_ids": ["කා"],
        "ordered": False,
    },
    {
        "item_id": "BL1S3W01",
        "skill_id": "skill_3",
        "knowledge_component_id": "KC_WORD_RECOGNITION",
        "difficulty_b": -1.0,
        "expected_latency_ms": 9000,
        "prompt_modality": "visual",
        "response_modality": "tap",
        "option_ids": ["ගල", "ගස", "කට"],
        "correct_answer_ids": ["ගස"],
        "ordered": False,
    },
    {
        "item_id": "BL1S3W02",
        "skill_id": "skill_3",
        "knowledge_component_id": "KC_WORD_SEQUENCING",
        "difficulty_b": 0.0,
        "expected_latency_ms": 13000,
        "prompt_modality": "audio_visual",
        "response_modality": "sequence_tap",
        "option_ids": ["ල", "ත", "මා"],
        "correct_answer_ids": ["මා", "ල"],
        "ordered": True,
    },
    {
        "item_id": "BL1S4S01",
        "skill_id": "skill_4",
        "knowledge_component_id": "KC_SENTENCE_COMPREHENSION",
        "difficulty_b": -1.0,
        "expected_latency_ms": 11000,
        "prompt_modality": "visual_text",
        "response_modality": "tap",
        "option_ids": ["බල්ලා දුවනවා.", "පූසා නිදියනවා."],
        "correct_answer_ids": ["බල්ලා දුවනවා."],
        "ordered": False,
    },
    {
        "item_id": "BL1S4S02",
        "skill_id": "skill_4",
        "knowledge_component_id": "KC_SENTENCE_SEQUENCING",
        "difficulty_b": 0.0,
        "expected_latency_ms": 16000,
        "prompt_modality": "visual_text",
        "response_modality": "sequence_tap",
        "option_ids": ["යනවා", "ගසට", "පවනි", "පාසල්"],
        "correct_answer_ids": ["පවනි", "පාසල්", "යනවා"],
        "ordered": True,
    },
]

ITEMS_BY_ID = {item["item_id"]: item for item in BASELINE_ITEMS}


SKILL_KCS = {
    "skill_1": [
        "KC_VISUAL_IDENTIFICATION", "KC_VISUAL_MATCHING",
        "KC_VISUAL_CATEGORIZATION", "KC_VISUAL_PATTERN", "KC_VISUAL_MEMORY",
    ],
    "skill_2": [
        "KC_LETTER_IDENTIFICATION", "KC_LETTER_MATCHING",
        "KC_PHONEME_LETTER_MAPPING", "KC_LETTER_DECODING", "KC_LETTER_MEMORY",
    ],
    "skill_3": [
        "KC_WORD_RECOGNITION", "KC_WORD_FORMATION",
        "KC_AUDITORY_WORD_RECOGNITION", "KC_WORD_COMPLETION", "KC_WORD_SEQUENCING",
    ],
    "skill_4": [
        "KC_SENTENCE_COMPREHENSION", "KC_SENTENCE_COMPLETION",
        "KC_AUDITORY_SENTENCE_RECOGNITION", "KC_SENTENCE_SEQUENCING",
    ],
}


def _clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, float(value)))


def score_answer(item: Dict[str, Any], selected_answer_ids: Iterable[str]) -> bool:
    """Score one baseline task from the immutable server-side answer key."""
    selected = [str(value) for value in selected_answer_ids]
    expected = list(item["correct_answer_ids"])
    if item.get("ordered"):
        return selected == expected
    return len(selected) == len(expected) and set(selected) == set(expected)


def response_is_valid(event: Dict[str, Any]) -> bool:
    if event.get("response_status") != "answered":
        return False
    latency = event.get("total_latency_ms")
    if not isinstance(latency, (int, float)) or isinstance(latency, bool):
        return False
    return 300 <= latency <= 180000


def _theta_from_events(events: List[Dict[str, Any]]) -> float:
    theta = 0.0
    for event in events:
        difficulty = float(event.get("difficulty_b", 0.0))
        probability = 1.0 / (1.0 + math.exp(-(theta - difficulty)))
        observed = 1.0 if event.get("is_correct") else 0.0
        theta += 0.35 * (observed - probability)
    return round(_clamp(theta, -0.75, 0.75), 4)


def build_starter_profile(events: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Derive deliberately conservative priors from at most eight probes."""
    valid = [event for event in events if response_is_valid(event)]
    valid_by_skill = {
        skill: [event for event in valid if event.get("skill_id") == skill]
        for skill in SKILL_KCS
    }
    sufficient = len(valid) >= 6 and all(valid_by_skill[skill] for skill in SKILL_KCS)

    skill_profiles: Dict[str, Dict[str, Any]] = {}
    mastery_by_kc: Dict[str, float] = {}
    theta_by_kc: Dict[str, float] = {}

    for skill, kcs in SKILL_KCS.items():
        rows = valid_by_skill[skill]
        adjusted_scores = []
        for row in rows:
            raw = 1.0 if row.get("is_correct") else 0.0
            # Correct responses to harder probes receive slightly more weight;
            # easy-item failures receive slightly more caution. The effect is
            # intentionally small because there are only two probes per skill.
            adjusted_scores.append(_clamp(raw + 0.08 * float(row.get("difficulty_b", 0.0)), 0.0, 1.0))
        evidence_sum = sum(adjusted_scores)
        mastery = _clamp((4.0 * DEFAULT_MASTERY + evidence_sum) / (4.0 + len(rows)), 0.20, 0.55)
        theta = _theta_from_events(rows)
        measured_kcs = {str(row.get("knowledge_component_id")) for row in rows}
        confidence = min(0.45, 0.18 + 0.12 * len(rows)) if rows else 0.0
        skill_profiles[skill] = {
            "mastery_prior": round(mastery, 4),
            "theta_initial": theta,
            "confidence": round(confidence, 3),
            "valid_item_count": len(rows),
            "correct_item_count": sum(bool(row.get("is_correct")) for row in rows),
        }
        for kc in kcs:
            if kc in measured_kcs:
                mastery_by_kc[kc] = round(mastery, 4)
                theta_by_kc[kc] = theta
            else:
                # Related KCs receive only half of the movement away from the
                # global prior. This avoids pretending eight probes diagnose
                # all nineteen knowledge components.
                mastery_by_kc[kc] = round(DEFAULT_MASTERY + 0.5 * (mastery - DEFAULT_MASTERY), 4)
                theta_by_kc[kc] = round(theta * 0.5, 4)

    latency_ratios = [
        float(row["total_latency_ms"]) / float(row["expected_latency_ms"])
        for row in valid
        if float(row.get("expected_latency_ms") or 0) > 0
    ]
    speed_factor = _clamp(median(latency_ratios), 0.80, 1.40) if latency_ratios else 1.0
    effective_latency_factor = 0.75 + 0.25 * speed_factor
    audio_rows = [row for row in valid if "audio" in str(row.get("prompt_modality", ""))]
    replay_tendency = (
        sum(min(3, int(row.get("audio_replay_count") or 0)) for row in audio_rows)
        / max(1, len(audio_rows))
    )
    sequence_rows = [row for row in valid if row.get("response_modality") == "sequence_tap"]
    sequence_accuracy = (
        sum(bool(row.get("is_correct")) for row in sequence_rows) / len(sequence_rows)
        if sequence_rows else None
    )

    return {
        "status": "completed" if sufficient else "insufficient",
        "baseline_version": BASELINE_VERSION,
        "valid_item_count": len(valid),
        "total_item_count": len(events),
        "data_quality": {
            "sufficient": sufficient,
            "minimum_valid_items": 6,
            "requires_each_skill": True,
            "valid_items_by_skill": {
                skill: len(rows) for skill, rows in valid_by_skill.items()
            },
        },
        "skill_profiles": skill_profiles,
        "mastery_by_kc": mastery_by_kc,
        "theta_by_kc": theta_by_kc,
        "speed_factor": round(speed_factor, 4),
        "effective_latency_factor": round(effective_latency_factor, 4),
        "audio_replay_tendency": round(replay_tendency, 4),
        "sequence_accuracy": None if sequence_accuracy is None else round(sequence_accuracy, 4),
        "data_origin": "observed_baseline",
        "research_role": "baseline_probe",
        "diagnostic_claim": False,
    }
