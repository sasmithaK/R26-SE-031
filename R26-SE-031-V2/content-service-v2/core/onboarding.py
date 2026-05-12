"""
content-service-v2/core/onboarding.py
=======================================
Guardian Intake Scoring and Observation Matrix Seeding — C3 (PLCE).

This module implements two onboarding computations specified in the V3.0
Research Enhancement Guide:

1. Guardian Intake (Advanced Assessments Dyslexia Screening Test, adapted):
   - Scores 14 guardian-answered questions to produce an at-risk flag.
   - Maps Part 2 symptom checklist to C4 error-type priority weights.
   - Source: Advanced Assessments Ltd (2020). Dyslexia Screening Test.

2. Observation Matrix BKT Seeding (Lokubalasuriya et al. 2019):
   - Maps observer-rated skill domain levels to BKT initial p_know values.
   - Replaces the uniform 0.30 prior with clinically informed starting points.
   - Reference: Lokubalasuriya, T. et al. (2019). Early Language Characteristics
     of Dyslexia in Sri Lankan Sinhala Speaking Children. 8th LLCE Conference.

Usage:
    from content_service_v2.core.onboarding import (
        compute_at_risk_flag, seed_mastery_from_observation_matrix
    )
"""

from __future__ import annotations

from typing import Dict, Tuple


# ---------------------------------------------------------------------------
# Part 1 — Guardian Intake Scoring
# ---------------------------------------------------------------------------

#: Score weights for each guardian-answered question.
#: Source: Advanced Assessments Dyslexia Screening Test scoring rubric.
QUESTION_WEIGHTS: Dict[str, int] = {
    "left_right_confusion":           10,
    "tires_quickly_reading":          10,
    "mind_wanders_reading":           10,
    "many_errors_reading":            20,
    "difficulty_staying_focused":     20,
    "hard_to_remember_names":         20,
    "hard_to_pronounce_words":        10,
    "forgets_short_words_spelling":   20,
    "difficulty_spelling_unfamiliar": 30,
    "difficulty_reading_unfamiliar":  30,
    "understands_words_cannot_spell": 20,
    "gets_stuck_on_words":            10,
    "eyes_out_of_coordination":       10,
    "words_appear_blurred":           30,
}

#: At-risk thresholds.
AT_RISK_MODERATE_THRESHOLD = 76
AT_RISK_STRONG_THRESHOLD   = 151


def compute_at_risk_flag(
    responses: Dict[str, bool],
) -> Tuple[int, str]:
    """
    Score the guardian's Part 1 responses and determine the at-risk flag.

    Args:
        responses: dict mapping question keys (from QUESTION_WEIGHTS) to bool.
                   Unknown keys are ignored; missing keys score 0.

    Returns:
        (at_risk_score: int, at_risk_flag: str)
        flag is one of: "typically_developing" | "at_risk_moderate" | "at_risk_strong"
    """
    score = sum(
        QUESTION_WEIGHTS[q]
        for q, answered_yes in responses.items()
        if answered_yes and q in QUESTION_WEIGHTS
    )

    if score < AT_RISK_MODERATE_THRESHOLD:
        flag = "typically_developing"
    elif score < AT_RISK_STRONG_THRESHOLD:
        flag = "at_risk_moderate"
    else:
        flag = "at_risk_strong"

    return score, flag


# ---------------------------------------------------------------------------
# Part 2 — Symptom Profile (feeds C4 error-type priority weights)
# ---------------------------------------------------------------------------

#: Map Part 2 symptom checklist keys to C4 error-type priority fields.
SYMPTOM_TO_PRIORITY_FIELD: Dict[str, str] = {
    "confusion_similar_letters": "reversal_priority",
    "omission_of_words":         "omission_priority",
    "slow_reading_speed":        "long_word_priority",
    "inaccurate_reading":        "consonant_confusion_priority",
    "perceived_text_distortion": "vowel_confusion_priority",
}


def build_symptom_profile(symptom_responses: Dict[str, bool]) -> Dict[str, int]:
    """
    Convert Part 2 symptom checklist into C4 error-type priority weights.

    Each True response sets the corresponding priority field to 2 (elevated).
    Priority 0 = no boost; 2 = elevated; 3 = maximum (currently unused,
    reserved for clinician override).

    Args:
        symptom_responses: dict mapping Part 2 symptom keys to bool.

    Returns:
        dict with priority fields: {reversal_priority, omission_priority,
        long_word_priority, consonant_confusion_priority, vowel_confusion_priority}
    """
    profile = {field: 0 for field in SYMPTOM_TO_PRIORITY_FIELD.values()}
    for symptom, answered_yes in symptom_responses.items():
        field = SYMPTOM_TO_PRIORITY_FIELD.get(symptom)
        if field and answered_yes:
            profile[field] = 2   # elevated priority
    return profile


# ---------------------------------------------------------------------------
# Observation Matrix → BKT p_know Seeding
# ---------------------------------------------------------------------------

#: BKT initial p_know values derived from the Observation Matrix rating level.
#: Rationale: replaces the uniform 0.30 prior with a clinically informed
#: starting point that avoids showing trivial content to Proficient children
#: and does not overwhelm Missing-level children with complex tasks.
MATRIX_TO_P_KNOW: Dict[str, float] = {
    "Missing":        0.05,
    "Unsatisfactory": 0.15,
    "Emerging":       0.40,
    "Proficient":     0.75,
}

#: Observation Matrix domain → BKT skill node mapping.
#: Each domain seeds the most closely related skill nodes.
DOMAIN_TO_SKILL_NODES: Dict[str, list] = {
    "phonological_processing":  ["S1_vowel_id", "S2_consonant_recog", "S3_syllable_formation", "S4_syllable_counting"],
    "reading_decoding":         ["S5_two_syllable_word", "S6_three_syllable_word"],
    "writing_copy_dictation":   ["S0_shape_recognition"],
    "visual_spatial_attention": ["S0_shape_recognition"],
    "language_comprehension":   ["S7_word_picture_match", "S8_simple_sentence", "S9_sentence_comprehension"],
}


def seed_mastery_from_observation_matrix(
    domain_ratings: Dict[str, str],
) -> Dict[str, float]:
    """
    Convert Observation Matrix domain ratings into BKT p_know seed values.

    Args:
        domain_ratings: dict mapping domain names to rating level strings.
            Keys: "phonological_processing", "reading_decoding",
                  "writing_copy_dictation", "visual_spatial_attention",
                  "language_comprehension".
            Values: one of "Missing" | "Unsatisfactory" | "Emerging" | "Proficient".

    Returns:
        dict mapping skill_id → initial p_know float.
        Skill nodes not covered by any domain default to DEFAULT_P_INIT (0.30).

    Example:
        >>> seed_mastery_from_observation_matrix({
        ...     "phonological_processing": "Emerging",
        ...     "reading_decoding": "Unsatisfactory",
        ...     "writing_copy_dictation": "Proficient",
        ...     "visual_spatial_attention": "Proficient",
        ...     "language_comprehension": "Missing",
        ... })
        {
            "S0_shape_recognition":     0.75,  # max of Proficient from 2 domains
            "S1_vowel_id":              0.40,
            "S2_consonant_recog":       0.40,
            "S3_syllable_formation":    0.40,
            "S4_syllable_counting":     0.40,
            "S5_two_syllable_word":     0.15,
            "S6_three_syllable_word":   0.15,
            "S7_word_picture_match":    0.05,
            "S8_simple_sentence":       0.05,
            "S9_sentence_comprehension":0.05,
        }
    """
    DEFAULT_P_INIT = 0.30
    # All known skill IDs initialised to default prior
    all_skills = [
        skill
        for skills in DOMAIN_TO_SKILL_NODES.values()
        for skill in skills
    ]
    # Start with default; track which skills have been seeded by a domain rating
    mastery: Dict[str, float] = {s: DEFAULT_P_INIT for s in all_skills}
    seeded: Dict[str, float] = {}   # domain-sourced values only

    for domain, rating in domain_ratings.items():
        p_know = MATRIX_TO_P_KNOW.get(rating, DEFAULT_P_INIT)
        for skill_id in DOMAIN_TO_SKILL_NODES.get(domain, []):
            # When multiple domains cover the same skill, take the max of
            # the domain-sourced values (optimistic across domains).
            # The observation matrix rating always replaces the default prior.
            seeded[skill_id] = max(seeded.get(skill_id, -1.0), p_know)

    # Apply domain-sourced values, replacing defaults
    mastery.update(seeded)

    return mastery
