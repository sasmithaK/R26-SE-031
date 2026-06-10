"""
intervention-service-v1/core/sm2_scheduler.py
===============================================
SM-2 Spaced Repetition Scheduler — per-child, per-skill-node.

Reference:
    Wozniak, P. A., & Gorzelanczyk, E. J. (1994). Optimization of repetition
    spacing in the practice of learning. Acta Neurobiologiae Experimentalis,
    54(1), 59–62.

Applied at SKILL NODE level (S0–S9), not per word.

Quality Score Mapping:
    90–100% → 5   75–89% → 4   60–74% → 3
    40–59%  → 2   20–39% → 1   0–19%  → 0
"""

from __future__ import annotations

from datetime import date, timedelta
from typing import Dict, List, Optional

from shared.database import get_db

MIN_EF = 1.3
INITIAL_EF = 2.5


def accuracy_to_quality(accuracy_pct: float) -> int:
    if accuracy_pct >= 90: return 5
    elif accuracy_pct >= 75: return 4
    elif accuracy_pct >= 60: return 3
    elif accuracy_pct >= 40: return 2
    elif accuracy_pct >= 20: return 1
    return 0


class SM2SkillState:
    def __init__(
        self, student_id: str, skill_id: str,
        interval: int = 1, repetitions: int = 0,
        easiness_factor: float = INITIAL_EF,
        next_review_date: Optional[str] = None,
        last_quality: int = -1,
    ):
        self.student_id = student_id
        self.skill_id = skill_id
        self.interval = interval
        self.repetitions = repetitions
        self.easiness_factor = easiness_factor
        self.next_review_date = next_review_date or date.today().isoformat()
        self.last_quality = last_quality

    def update(self, quality: int) -> str:
        """
        SM-2 update. Returns next_review_date (ISO string).

        Algorithm (Wozniak 1987):
            if quality >= 3:
                interval = 1 | 6 | round(prev_interval × EF)
                repetitions += 1
            else:
                interval = 1, repetitions = 0
            EF += 0.1 − (5 − q) × (0.08 + (5 − q) × 0.02)
            EF = max(MIN_EF, EF)
        """
        self.last_quality = quality
        if quality >= 3:
            if self.repetitions == 0:
                self.interval = 1
            elif self.repetitions == 1:
                self.interval = 6
            else:
                self.interval = round(self.interval * self.easiness_factor)
            self.repetitions += 1
        else:
            self.repetitions = 0
            self.interval = 1

        ef_delta = 0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02)
        self.easiness_factor = max(MIN_EF, self.easiness_factor + ef_delta)
        self.next_review_date = (date.today() + timedelta(days=self.interval)).isoformat()
        return self.next_review_date

    @property
    def is_due_today(self) -> bool:
        try:
            return date.fromisoformat(self.next_review_date) <= date.today()
        except ValueError:
            return True


class SM2Scheduler:
    """Manages SM-2 states for all students across all skill nodes."""

    ALL_SKILLS = [
        "S0_shape_recognition", "S1_vowel_id", "S2_consonant_recognition",
        "S3_syllable_formation", "S4_syllable_counting",
        "S5_two_syllable_reading", "S6_three_syllable_reading",
        "S7_word_picture_match", "S8_sentence_reading", "S9_sentence_comprehension",
    ]

    def __init__(self):
        self._cache: Dict[str, Dict[str, SM2SkillState]] = {}

    async def update(self, student_id: str, skill_id: str, accuracy_pct: float) -> str:
        state = await self._get(student_id, skill_id)
        next_date = state.update(accuracy_to_quality(accuracy_pct))
        await self._save(state)
        return next_date

    async def get_due_skills(self, student_id: str) -> List[str]:
        due = []
        for s in self.ALL_SKILLS:
            state = await self._get(student_id, s)
            if state.is_due_today:
                due.append(s)
        return due

    async def get_schedule_summary(self, student_id: str) -> Dict[str, str]:
        summary = {}
        for s in self.ALL_SKILLS:
            state = await self._get(student_id, s)
            summary[s] = state.next_review_date
        return summary

    async def initialize_student(self, student_id: str) -> None:
        for skill in self.ALL_SKILLS:
            await self._save(SM2SkillState(student_id=student_id, skill_id=skill))
        self._cache.pop(student_id, None)

    async def _get(self, student_id: str, skill_id: str) -> SM2SkillState:
        self._cache.setdefault(student_id, {})
        if skill_id not in self._cache[student_id]:
            self._cache[student_id][skill_id] = await self._load(student_id, skill_id)
        return self._cache[student_id][skill_id]

    async def _load(self, student_id: str, skill_id: str) -> SM2SkillState:
        db = get_db()
        row = await db.sm2_schedules.find_one({"student_id": student_id, "skill_id": skill_id})
        if row:
            return SM2SkillState(
                student_id,
                skill_id,
                row.get("interval", 1),
                row.get("repetitions", 0),
                row.get("easiness_factor", 2.5),
                row.get("next_review_date"),
                row.get("last_quality", -1)
            )
        return SM2SkillState(student_id=student_id, skill_id=skill_id)

    async def _save(self, s: SM2SkillState) -> None:
        db = get_db()
        await db.sm2_schedules.update_one(
            {"student_id": s.student_id, "skill_id": s.skill_id},
            {"$set": {
                "interval": s.interval,
                "repetitions": s.repetitions,
                "easiness_factor": s.easiness_factor,
                "next_review_date": s.next_review_date,
                "last_quality": s.last_quality
            }},
            upsert=True
        )
        self._cache.setdefault(s.student_id, {})[s.skill_id] = s
