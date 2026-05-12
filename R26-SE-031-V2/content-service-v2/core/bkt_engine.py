"""
content-service-v2/core/bkt_engine.py
=======================================
Bayesian Knowledge Tracing (BKT) — Hidden Markov Model for C3 (PLCE).

Reference:
    Corbett, A. T., & Anderson, J. R. (1994). Knowledge tracing: Modeling
    the acquisition of procedural knowledge. UMUAI, 4(4), 253–278.

BKT Parameters (ASSISTments priors):
    P_init  = 0.3   prior probability of knowing a skill
    P_learn = 0.1   probability unknown → known per attempt
    P_slip  = 0.1   P(wrong | know)
    P_guess = 0.2   P(correct | not know)

Thresholds:
    Mastery:  p_know > 0.833  (PAST criterion: 5/6 correct = 0.833)
    ZPD:      0.45 <= p_know < 0.833
"""

from __future__ import annotations

import time
from typing import Dict, List, Tuple

from shared.database import get_db

DEFAULT_P_INIT = 0.3
DEFAULT_P_LEARN = 0.1
DEFAULT_P_SLIP = 0.1
DEFAULT_P_GUESS = 0.2
MASTERY_THRESHOLD = 0.833   # PAST criterion: 5/6 correct = 0.833 (Rosner 1999)
ZPD_LOWER = 0.45
ZPD_UPPER = 0.833


class BKTSkillState:
    def __init__(
        self, student_id: str, skill_id: str,
        p_know: float = DEFAULT_P_INIT,
        p_learn: float = DEFAULT_P_LEARN,
        p_slip: float = DEFAULT_P_SLIP,
        p_guess: float = DEFAULT_P_GUESS,
        observations: int = 0, last_updated_ms: int = 0,
    ):
        self.student_id = student_id
        self.skill_id = skill_id
        self.p_know = p_know
        self.p_learn = p_learn
        self.p_slip = p_slip
        self.p_guess = p_guess
        self.observations = observations
        self.last_updated_ms = last_updated_ms

    def update(self, is_correct: bool) -> Tuple[float, float]:
        """Apply one BKT observation. Returns (p_know_before, p_know_after)."""
        before = self.p_know
        if is_correct:
            num = self.p_know * (1.0 - self.p_slip)
            denom = num + (1.0 - self.p_know) * self.p_guess
        else:
            num = self.p_know * self.p_slip
            denom = num + (1.0 - self.p_know) * (1.0 - self.p_guess)
        p_posterior = num / max(denom, 1e-10)
        self.p_know = max(0.0, min(1.0, p_posterior + (1.0 - p_posterior) * self.p_learn))
        self.observations += 1
        self.last_updated_ms = int(time.time() * 1000)
        return before, self.p_know

    @property
    def mastery_achieved(self) -> bool:
        return self.p_know > MASTERY_THRESHOLD

    @property
    def in_zpd(self) -> bool:
        return ZPD_LOWER <= self.p_know <= ZPD_UPPER


class BKTEngine:
    """Central BKT engine for C3 (PLCE). C4 receives mastery via API, never computes it."""

    ALL_SKILLS = [
        "S0_shape_recognition", "S1_vowel_id", "S2_consonant_recognition",
        "S3_syllable_formation", "S4_syllable_counting",
        "S5_two_syllable_reading", "S6_three_syllable_reading",
        "S7_word_picture_match", "S8_sentence_reading", "S9_sentence_comprehension",
    ]

    PREREQUISITES: Dict[str, List[str]] = {
        "S0_shape_recognition": [],
        "S1_vowel_id": ["S0_shape_recognition"],
        "S2_consonant_recognition": ["S0_shape_recognition"],
        "S3_syllable_formation": ["S1_vowel_id", "S2_consonant_recognition"],
        "S4_syllable_counting": ["S3_syllable_formation"],
        "S5_two_syllable_reading": ["S4_syllable_counting"],
        "S6_three_syllable_reading": ["S5_two_syllable_reading"],
        "S7_word_picture_match": ["S5_two_syllable_reading"],
        "S8_sentence_reading": ["S6_three_syllable_reading", "S7_word_picture_match"],
        "S9_sentence_comprehension": ["S8_sentence_reading"],
    }

    def __init__(self):
        self._cache: Dict[str, Dict[str, BKTSkillState]] = {}

    async def update(self, student_id: str, skill_id: str, is_correct: bool) -> Tuple[float, float]:
        state = await self._get(student_id, skill_id)
        before, after = state.update(is_correct)
        await self._save(state)
        return before, after

    async def get_mastery_vector(self, student_id: str) -> Dict[str, float]:
        # Pre-load all states to avoid sequential DB trips if possible, but for now simple sequential is fine
        vector = {}
        for s in self.ALL_SKILLS:
            state = await self._get(student_id, s)
            vector[s] = state.p_know
        return vector

    async def initialize_student(self, student_id: str) -> None:
        for skill in self.ALL_SKILLS:
            await self._save(BKTSkillState(student_id=student_id, skill_id=skill))
        self._cache.pop(student_id, None)

    async def get_next_skill(self, student_id: str) -> str:
        vec = await self.get_mastery_vector(student_id)
        zpd = [
            (s, p) for s, p in vec.items()
            if ZPD_LOWER <= p <= ZPD_UPPER and self._prereqs_met(s, vec)
        ]
        if zpd:
            return min(zpd, key=lambda x: x[1])[0]
        eligible = [
            (s, p) for s, p in vec.items()
            if p <= MASTERY_THRESHOLD and self._prereqs_met(s, vec)
        ]
        return min(eligible, key=lambda x: x[1])[0] if eligible else self.ALL_SKILLS[-1]

    def _prereqs_met(self, skill_id: str, vec: Dict[str, float]) -> bool:
        return all(vec.get(p, 0.0) >= 0.45 for p in self.PREREQUISITES.get(skill_id, []))

    async def _get(self, student_id: str, skill_id: str) -> BKTSkillState:
        self._cache.setdefault(student_id, {})
        if skill_id not in self._cache[student_id]:
            self._cache[student_id][skill_id] = await self._load(student_id, skill_id)
        return self._cache[student_id][skill_id]

    async def _load(self, student_id: str, skill_id: str) -> BKTSkillState:
        db = get_db()
        row = await db.bkt_states.find_one({"student_id": student_id, "skill_id": skill_id})
        if row:
            return BKTSkillState(
                student_id, skill_id, 
                row.get("p_know", DEFAULT_P_INIT),
                row.get("p_learn", DEFAULT_P_LEARN),
                row.get("p_slip", DEFAULT_P_SLIP),
                row.get("p_guess", DEFAULT_P_GUESS),
                row.get("observations", 0),
                row.get("last_updated_ms", 0)
            )
        return BKTSkillState(student_id=student_id, skill_id=skill_id)

    async def _save(self, s: BKTSkillState) -> None:
        db = get_db()
        await db.bkt_states.update_one(
            {"student_id": s.student_id, "skill_id": s.skill_id},
            {"$set": {
                "p_know": s.p_know,
                "p_learn": s.p_learn,
                "p_slip": s.p_slip,
                "p_guess": s.p_guess,
                "observations": s.observations,
                "last_updated_ms": s.last_updated_ms
            }},
            upsert=True
        )
        self._cache.setdefault(s.student_id, {})[s.skill_id] = s
