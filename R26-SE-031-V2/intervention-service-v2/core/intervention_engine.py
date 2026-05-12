"""
intervention-service-v2/core/intervention_engine.py
=====================================================
Two-Stage Phonological Intervention Pipeline for C4 (IIGE).

Trigger thresholds (from .env):
    phonological_strain_index >= 0.45 for > 5000ms  → Stage 1 (inline)
    Still >= 0.45 after 10000ms OR 3rd failure       → Stage 2 (activity overlay)
    Same skill fails Stage 2 in 3+ sessions          → Stage 3 (RTI Tier 3 alert)

Stage 1 (zero-disruption inline):
    - Syllable splitter splits current_word into segments
    - Flutter renders segments with inter-segment gTTS audio

Stage 2 (activity overlay):
    - Phoneme error analyser classifies error_type from error_pattern_vector
    - Activity selection matrix: error_type × mastery_level → activity_type + difficulty

IMPORTANT: C4 does NOT compute BKT mastery. mastery_vector is received as input from C3.
"""

from __future__ import annotations

import time
from typing import Dict, List, Optional, Tuple

from shared.database import get_db
from .syllable_splitter import split_syllables

# ── Thresholds (should match .env) ────────────────────────────────────────
PHONOLOGICAL_STRAIN_TRIGGER = 0.45
STAGE1_DURATION_MS = 5_000
STAGE2_DURATION_MS = 10_000
RTI_FAILURE_COUNT = 3

# ── Error types ────────────────────────────────────────────────────────────
ERROR_LONG_WORD = "LONG_WORD"
ERROR_VOWEL     = "VOWEL_CONFUSION"
ERROR_CONSONANT = "CONSONANT_CONFUSION"
ERROR_UNFAMILIAR = "UNFAMILIAR"

# ── Activity types ─────────────────────────────────────────────────────────
ACT_TAPPING   = "TAPPING_GAME"
ACT_BLENDING  = "BLENDING_GAME"       # NEW v3.0 — PAST: Syllable Blending
ACT_TRACING   = "FINGER_TRACING"
ACT_SONG      = "TEMPLATE_SONG"
ACT_PIC_WORD  = "PICTURE_WORD_MATCH"
ACT_SRS_CARD  = "SPACED_REPETITION_CARD"
ACT_PAIR      = "MINIMAL_PAIR"

# ── PAST frustration-stop rule (Rosner 1999) ────────────────────────────────
# Stop the activity after this many consecutive incorrect attempts and escalate.
PAST_FRUSTRATION_STOP = 3


# ---------------------------------------------------------------------------
# Phoneme Error Analyser
# ---------------------------------------------------------------------------

def classify_error_type(
    current_word: str,
    error_pattern_vector: List[int],
    mastery_vector: Optional[Dict[str, float]] = None,
) -> str:
    """
    Classify the dominant phonological error type for a given word + MBSV flags.

    Decision logic:
        1. If syllable_count >= 4  → LONG_WORD
        2. If omission_flag=1 or vowel-sign-heavy word → VOWEL_CONFUSION
        3. If reversal_flag=1 or substitution_flag=1   → CONSONANT_CONFUSION
        4. If mastery for word's skill node is very low → UNFAMILIAR
        5. Default                                      → VOWEL_CONFUSION

    Uses Unicode-derived features only (no audio, no labeled data for 50%).
    """
    reversal, omission, substitution, hesitation = (
        error_pattern_vector + [0] * 4
    )[:4]

    syllables = split_syllables(current_word)

    # Rule 1: Long word
    if len(syllables) >= 4:
        return ERROR_LONG_WORD

    # Rule 2: Count vowel signs in word (U+0DCF–U+0DDF)
    vowel_sign_count = sum(
        1 for c in current_word if 0x0DCF <= ord(c) <= 0x0DDF
    )
    if omission == 1 or vowel_sign_count >= 3:
        return ERROR_VOWEL

    # Rule 3: Reversal/substitution → consonant confusion
    if reversal == 1 or substitution == 1:
        return ERROR_CONSONANT

    # Rule 4: No mastery at all (very first encounter)
    if mastery_vector:
        avg_mastery = sum(mastery_vector.values()) / max(len(mastery_vector), 1)
        if avg_mastery < 0.25:
            return ERROR_UNFAMILIAR

    return ERROR_VOWEL  # Default: most common error type in Sinhala literacy


# ---------------------------------------------------------------------------
# Activity Selection Matrix
# ---------------------------------------------------------------------------

# (error_type, mastery_band) → (activity_type, difficulty)
# mastery_band: 'low' (< 0.4), 'mid' (0.4–0.7), 'high' (> 0.7)
# Derived from guide V3.0 Table: Component 4 Activity Selection Matrix.
# PAST origin for each activity listed in docstring.
ACTIVITY_MATRIX: Dict[Tuple[str, str], Tuple[str, int]] = {
    # LONG_WORD: tapping slow → normal → blending (PAST: Syllable Segmentation → Blending)
    (ERROR_LONG_WORD, "low"):  (ACT_TAPPING,  1),
    (ERROR_LONG_WORD, "mid"):  (ACT_TAPPING,  3),
    (ERROR_LONG_WORD, "high"): (ACT_BLENDING, 4),   # harder: merge syllables

    # VOWEL_CONFUSION: trace → template song → picture-word hard
    (ERROR_VOWEL, "low"):  (ACT_TRACING,  1),
    (ERROR_VOWEL, "mid"):  (ACT_SONG,     3),
    (ERROR_VOWEL, "high"): (ACT_PIC_WORD, 4),

    # CONSONANT_CONFUSION: picture-word easy → hard → blending
    (ERROR_CONSONANT, "low"):  (ACT_PIC_WORD, 1),
    (ERROR_CONSONANT, "mid"):  (ACT_PIC_WORD, 3),
    (ERROR_CONSONANT, "high"): (ACT_BLENDING, 5),   # assemble word from phoneme tiles

    # UNFAMILIAR: audio+image card → context sentence → SM-2 review
    (ERROR_UNFAMILIAR, "low"):  (ACT_SRS_CARD, 1),
    (ERROR_UNFAMILIAR, "mid"):  (ACT_SRS_CARD, 2),
    (ERROR_UNFAMILIAR, "high"): (ACT_TAPPING,  3),
}


def get_mastery_band(mastery_vector: Optional[Dict[str, float]], skill_id: Optional[str]) -> str:
    if not mastery_vector or not skill_id:
        return "mid"
    p = mastery_vector.get(skill_id, 0.5)
    if p < 0.4:
        return "low"
    elif p <= 0.7:
        return "mid"
    return "high"


def select_activity(
    error_type: str,
    mastery_vector: Optional[Dict[str, float]],
    skill_id: Optional[str],
) -> Tuple[str, int]:
    """Return (activity_type, difficulty) from activity selection matrix."""
    band = get_mastery_band(mastery_vector, skill_id)
    return ACTIVITY_MATRIX.get((error_type, band), (ACT_SRS_CARD, 2))


# ---------------------------------------------------------------------------
# Intervention Pipeline
# ---------------------------------------------------------------------------

class InterventionEngine:
    """
    Main pipeline for C4 (IIGE).
    Tracks per-student strain timers and failure counts.
    """

    def __init__(self):
        self._strain_start: Dict[str, int] = {}
        # Track consecutive incorrect attempts per student for PAST frustration-stop rule
        self._consecutive_failures: Dict[str, int] = {}

    async def check(
        self,
        student_id: str,
        current_word: str,
        phonological_strain_index: float,
        error_pattern_vector: List[int],
        strain_duration_ms: int,
        mastery_vector: Optional[Dict[str, float]] = None,
        active_skill_id: Optional[str] = None,
        symptom_profile: Optional[Dict[str, int]] = None,
    ) -> dict:
        """
        Main trigger check. Returns stage + payload for Flutter.

        Args:
            symptom_profile: guardian intake priority weights from C3 onboarding.
                             Keys: reversal_priority, omission_priority,
                             long_word_priority, consonant_confusion_priority,
                             vowel_confusion_priority (each 0–3).
                             When provided, biases error type selection toward
                             guardian-flagged symptoms before behavioral data
                             accumulates (Session 1 cold-start).

        Returns dict with keys: stage, syllable_segments, error_type,
        activity_type, activity_difficulty, sm2_quality_required.
        """
        # Stage 0: below threshold
        if phonological_strain_index < PHONOLOGICAL_STRAIN_TRIGGER:
            self._strain_start.pop(student_id, None)
            return {"stage": 0}

        # Record strain onset
        now_ms = int(time.time() * 1000)
        if student_id not in self._strain_start:
            self._strain_start[student_id] = now_ms

        elapsed_ms = strain_duration_ms or (now_ms - self._strain_start[student_id])

        # Stage 1: inline syllable split (5–10s of strain)
        if elapsed_ms < STAGE2_DURATION_MS:
            segments = split_syllables(current_word)
            return {
                "stage": 1,
                "syllable_segments": segments,
                "error_type": None,
                "activity_type": None,
                "activity_difficulty": None,
                "sm2_quality_required": False,
            }

        # Stage 2: activity overlay (≥ 10s of strain)
        error_type = classify_error_type(
            current_word, error_pattern_vector, mastery_vector
        )
        activity_type, difficulty = select_activity(
            error_type, mastery_vector, active_skill_id
        )

        # Log Stage 2 event for RTI tracking
        await self._log_stage2(student_id, current_word, active_skill_id or "unknown")

        # Check RTI Tier 3
        failure_count = await self._get_failure_count(student_id, active_skill_id or "unknown")
        if failure_count >= RTI_FAILURE_COUNT:
            return {
                "stage": 3,
                "syllable_segments": split_syllables(current_word),
                "error_type": error_type,
                "activity_type": activity_type,
                "activity_difficulty": difficulty,
                "sm2_quality_required": True,
                "rti_alert": True,
                "failure_count": failure_count,
            }

        return {
            "stage": 2,
            "syllable_segments": split_syllables(current_word),
            "error_type": error_type,
            "activity_type": activity_type,
            "activity_difficulty": difficulty,
            "sm2_quality_required": True,
        }

    # ------------------------------------------------------------------
    # RTI Tracking
    # ------------------------------------------------------------------

    async def _log_stage2(self, student_id: str, word: str, skill_id: str) -> None:
        db = get_db()
        await db.rti_events.insert_one({
            "student_id": student_id,
            "skill_id": skill_id,
            "word": word,
            "event_timestamp_ms": int(time.time() * 1000)
        })

    async def _get_failure_count(self, student_id: str, skill_id: str) -> int:
        db = get_db()
        return await db.rti_events.count_documents({
            "student_id": student_id,
            "skill_id": skill_id
        })
