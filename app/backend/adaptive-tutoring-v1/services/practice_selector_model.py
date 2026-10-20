"""Auditable ranking of reviewed remediation and confirmation items.

The model predicts independent success for each *eligible authored item*.
Hard curriculum, role, activity, and exposure constraints are applied before
the model sees a candidate.  Synthetic artifacts may control only explicitly
labelled simulation modes, matching the scaffold action-model safety gate.
"""

from __future__ import annotations

import json
import math
import os
from pathlib import Path
from typing import Any, Dict, List

from services.practice_metadata import derive_practice_metadata


APPROVED_ACTIVE_STATUSES = {"pilot_approved", "validated_observed"}
DEFAULT_MODEL_PATH = (
    Path(__file__).resolve().parent.parent / "models" / "c4_practice_selector_v1.json"
)

FEATURES = (
    "primary_target_match", "component_overlap", "error_tag_overlap",
    "difficulty_fit", "role_fit", "novelty", "same_group",
    "micro_mastery", "support_dependency", "fatigue",
    "diagnostic_confidence", "confirmation_phase",
)


def _jaccard(left: List[str], right: List[str]) -> float:
    """Measure target overlap as intersection divided by union."""
    a, b = set(map(str, left)), set(map(str, right))
    if not a or not b:
        return 0.0
    return len(a.intersection(b)) / len(a.union(b))


def _bounded(value: Any, low: float = 0.0, high: float = 1.0) -> float:
    """Convert an input to float and clamp it to a valid feature range."""
    try:
        return max(low, min(high, float(value)))
    except (TypeError, ValueError):
        return low


class PracticeSelectorModel:
    """Rank reviewed remediation or confirmation items for one learner need."""

    def __init__(self, path: Path | None = None):
        """Resolve and load the portable targeted-practice model artifact."""
        self.path = Path(
            os.getenv("C4_PRACTICE_MODEL_PATH", str(path or DEFAULT_MODEL_PATH))
        )
        self.artifact: Dict[str, Any] = {}
        self.reload()

    def reload(self) -> None:
        """Reload the JSON coefficients or expose an empty safe fallback."""
        try:
            self.artifact = json.loads(self.path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            self.artifact = {}

#Predict independent success for one reviewed candidate item.#
    def _predict(self, features: Dict[str, float]) -> float:

        model = self.artifact.get("model") or {}
        z = float(model.get("intercept", 0.0))
        weights = model.get("weights") or {}
        means = self.artifact.get("feature_means") or {}
        scales = self.artifact.get("feature_scales") or {}
        for name in FEATURES:
            scale = float(scales.get(name, 1.0) or 1.0)
            standardized = (
                float(features.get(name, 0.0)) - float(means.get(name, 0.0))
            ) / scale
            z += float(weights.get(name, 0.0)) * standardized
        return 1.0 / (1.0 + math.exp(-max(-30.0, min(30.0, z))))

    def rank(
        self,
        *,
        candidates: List[Dict[str, Any]],
        selection_intent: Dict[str, Any],
        target_difficulty: float,
        exposure_counts: Dict[str, int],
        micro_skill_evidence: Dict[str, Any],
        fatigue: float,
        requested_mode: str | None,
        data_origin: str,
    ) -> Dict[str, Any]:
        """Feature, score, and rank candidates after hard curriculum filtering.

        Probability is combined with exact-target, difficulty, novelty, and
        exposure terms so the model does not repeatedly choose an easy but
        irrelevant task.
        """
        role = str(selection_intent.get("role") or "REMEDIATION").upper()
        target_units = list(selection_intent.get("target_units") or [])
        component_units = list(selection_intent.get("component_units") or [])
        error_tags = list(selection_intent.get("error_tags") or [])
        origin_group = str(
            selection_intent.get("origin_equivalent_group_id") or ""
        )
        target_masteries = [
            float((micro_skill_evidence.get(str(unit)) or {}).get(
                "mastery_estimate", 0.30
            ))
            for unit in target_units
        ]
        micro_mastery = min(target_masteries) if target_masteries else 0.30
        support_dependency = 1.0 - micro_mastery
#Build candidate features & Predict independent success
        scored = []
        for candidate in candidates:
            metadata = derive_practice_metadata(candidate)
            difficulty_distance = abs(
                float(candidate.get("difficulty_b", 0.0)) - target_difficulty
            )
            exposure = int(exposure_counts.get(str(candidate.get("item_id")), 0))
            features = {
                "primary_target_match": _jaccard(
                    target_units, metadata["primary_targets"]
                ),
                "component_overlap": _jaccard(
                    component_units, metadata["component_units"]
                ),
                "error_tag_overlap": _jaccard(
                    error_tags, metadata["micro_skill_tags"]
                ),
                "difficulty_fit": math.exp(-difficulty_distance),
                "role_fit": 1.0 if str(candidate.get("item_role", "")).upper() == role else 0.65,
                "novelty": 1.0 / (1.0 + exposure),
                "same_group": 1.0 if candidate.get("equivalent_group_id") == origin_group else 0.0,
                "micro_mastery": _bounded(micro_mastery),
                "support_dependency": _bounded(support_dependency),
                "fatigue": _bounded(fatigue),
                "diagnostic_confidence": _bounded(
                    selection_intent.get("diagnostic_confidence", 0.0)
                ),
                "confirmation_phase": 1.0 if role == "CONFIRMATION" else 0.0,
            }
            probability = self._predict(features) if self.artifact else 0.5
            # Success alone would over-select easy/repeated questions. The
            # utility rewards exact diagnosis and novelty, and confirmation
            # receives a stronger original-difficulty requirement.
            utility = (
                probability
                + 0.16 * features["primary_target_match"]
                + 0.08 * features["component_overlap"]
                + 0.08 * features["error_tag_overlap"]
                + (0.10 if role == "CONFIRMATION" else 0.06) * features["difficulty_fit"]
                + 0.05 * features["novelty"]
                - 0.12 * exposure
            )
            scored.append({
                "item_id": candidate.get("item_id"),
                "predicted_independent_success": round(probability, 6),
                "utility": round(utility, 6),
                "difficulty_distance": round(difficulty_distance, 6),
                "features": {key: round(value, 6) for key, value in features.items()},
                "micro_kc_id": metadata["micro_kc_id"],
                "primary_targets": metadata["primary_targets"],
            })
        scored.sort(key=lambda row: (-row["utility"], row["difficulty_distance"], str(row["item_id"])))

        requested = str(requested_mode or os.getenv("C4_POLICY_MODE", "shadow")).lower()
        if requested == "simulation":
            requested = "simulation_model"
        status = str(self.artifact.get("validation_status") or "model_unavailable")
        activation_allowed = bool(self.artifact.get("activation_allowed", False))
        controls = requested == "simulation_model" or (
            requested == "model"
            and status in APPROVED_ACTIVE_STATUSES
            and activation_allowed
        )
        return {
            "ranked_candidates": scored,
            "recommended_item": scored[0]["item_id"] if scored else None,
            "model_version": self.artifact.get("model_version"),
            "model_validation_status": status,
            "model_activation_allowed": activation_allowed,
            "policy_mode": requested,
            "controls_live_adaptation": controls,
            "execution_source": (
                "synthetic_practice_model_simulation"
                if requested == "simulation_model"
                else "validated_observed_practice_model"
                if controls
                else "dynamic_practice_shadow"
            ),
            "fallback_reason": (
                None if controls else
                "SYNTHETIC_OR_UNVALIDATED_PRACTICE_MODEL_SHADOW_ONLY"
            ),
            "data_origin": data_origin,
            "simulation_disclosure": (
                "Synthetic-trained practice selector controls this explicitly "
                "labelled simulation; it is not child-outcome efficacy evidence."
                if requested == "simulation_model" else None
            ),
        }


practice_selector_model = PracticeSelectorModel()
