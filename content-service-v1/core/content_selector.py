"""
content-service-v1/core/content_selector.py
=============================================
ZPD-based content selection for C3 (PLCE).

Selection Algorithm:
    1. Get target skill from BKT engine (ZPD priority).
    2. Compute IRT difficulty target:
           target_b = 0.5 - (cognitive_load_index × 0.3)
       Range: 0.2 (high load → easier) to 0.5 (low load → moderate).
    3. Fatigue override: if session_fatigue_index > 0.70,
       select a consolidation item (p_know 0.60–0.85) regardless of ZPD.
    4. VARK modality filter: prefer items matching student's learner type.
    5. Select item minimizing |item.irt_difficulty_b - target_b|.

Reference:
    Vygotsky, L. S. (1978). Mind in society. Harvard University Press.
    (Zone of Proximal Development — ZPD)
"""

from __future__ import annotations

import json
import os
import random
from typing import Dict, List, Optional

FATIGUE_THRESHOLD = 0.70
ZPD_LOWER = 0.45
ZPD_UPPER = 0.833           # PAST criterion: 5/6 correct = 0.833 (Rosner 1999)
MASTERY_THRESHOLD = 0.833


def load_content_repository(path: str) -> List[dict]:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    return data["items"]


class ContentSelector:
    """
    Selects the next content item for a student.

    Args:
        content_path: Path to content_repository.json
    """

    def __init__(self, content_path: str):
        self.items = load_content_repository(content_path)
        # Build index: {skill_id: [items]}
        self._by_skill: Dict[str, List[dict]] = {}
        for item in self.items:
            self._by_skill.setdefault(item["skill_id"], []).append(item)

    def select(
        self,
        student_id: str,
        target_skill_id: str,
        mastery_vector: Dict[str, float],
        cognitive_load_index: float = 0.5,
        session_fatigue_index: float = 0.0,
        learner_type: Optional[str] = None,
        excluded_item_ids: Optional[List[str]] = None,
    ) -> Optional[dict]:
        """
        Select the best content item for the student.

        Returns content item dict or None if repository is empty.
        """
        excluded = set(excluded_item_ids or [])

        # Fatigue override: consolidation skill
        if session_fatigue_index > FATIGUE_THRESHOLD:
            target_skill_id = self._consolidation_skill(mastery_vector)

        # Get candidate items for target skill
        candidates = [
            item for item in self._by_skill.get(target_skill_id, [])
            if item["item_id"] not in excluded
        ]

        # Fallback: if no items for target skill, use adjacent skill
        if not candidates:
            for skill_id, items in self._by_skill.items():
                candidates = [i for i in items if i["item_id"] not in excluded]
                if candidates:
                    break

        if not candidates:
            return None

        # Modality filter (VARK preference)
        if learner_type:
            modality_map = {"V": "VISUAL", "A": "AUDITORY", "K": "KINESTHETIC"}
            preferred_modality = modality_map.get(learner_type)
            preferred = [i for i in candidates if i.get("modality") == preferred_modality]
            if preferred:
                candidates = preferred

        # Compute IRT difficulty target
        # target_b = 0.5 − (cognitive_load_index × 0.3)
        # High load (1.0) → target_b = 0.2 (easier items)
        # Low load (0.0)  → target_b = 0.5 (moderate items)
        target_b = 0.5 - (cognitive_load_index * 0.3)

        # Select item minimizing |item.b - target_b|
        best = min(
            candidates,
            key=lambda i: abs(i.get("irt_difficulty_b", 0.0) - target_b)
        )
        return best

    def _consolidation_skill(self, mastery_vector: Dict[str, float]) -> str:
        """
        For fatigue override: pick a skill in the 0.60–0.85 consolidation range.
        Rationale: reviewing already-partially-learned material is less taxing.
        """
        consolidation = [
            (skill, p) for skill, p in mastery_vector.items()
            if 0.60 <= p <= 0.85
        ]
        if consolidation:
            # Pick highest p_know (most consolidated — least cognitive effort)
            return max(consolidation, key=lambda x: x[1])[0]
        # Fallback: just the first skill
        return list(mastery_vector.keys())[0] if mastery_vector else "S0_shape_recognition"
