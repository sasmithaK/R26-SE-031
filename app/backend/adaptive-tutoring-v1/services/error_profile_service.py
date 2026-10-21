"""Build and update the learner's specific Component 4 error profile."""

from __future__ import annotations

from typing import Any, Dict, Iterable, List

from services.practice_metadata import derive_practice_metadata, normalize_target_unit


def _unique(values: Iterable[Any]) -> List[str]:
    """Normalize an ordered collection while removing blanks and duplicates."""
    seen = set()
    result = []
    for raw in values:
        value = str(raw).strip()
        if not value or value in seen:
            continue
        seen.add(value)
        result.append(value)
    return result


class ErrorProfileService:
    """Turn a completed response into target-specific diagnostic evidence."""

    version = "C4_ERROR_PROFILE_V1"

    def build(
        self,
        *,
        item: Dict[str, Any],
        telemetry: Any,
        response_quality: str,
        learning_observation_correct: bool,
        knowledge_component_id: str,
        adaptive_state: Dict[str, Any],
    ) -> Dict[str, Any]:
        """Build the latest error profile and update micro-skill evidence."""
        metadata = derive_practice_metadata(item)
        target_ids = list(getattr(telemetry, "target_ids", None) or [])
        selected = list(getattr(telemetry, "selected_answers", None) or [])
        selected_option_ids = list(
            getattr(telemetry, "selected_option_ids", None) or []
        )
        correct_option_ids = set(
            str(value)
            for value in (getattr(telemetry, "correct_option_ids", None) or [])
        )
        wrong_option_ids = [
            str(value) for value in selected_option_ids
            if str(value) not in correct_option_ids
        ]
        reported_struggle = _unique(
            normalize_target_unit(value)
            for value in (
                getattr(telemetry, "struggled_target_units", None) or []
            )
        )
        stored_struggle = adaptive_state.get("latest_struggled_target") or {}
        stored_units = []
        first_observed_units = []
        diagnostic_target_counts: Dict[str, int] = {}
        if (
            isinstance(stored_struggle, dict)
            and str(stored_struggle.get("item_id") or "")
            == str(item.get("item_id") or "")
        ):
            stored_units = _unique(
                normalize_target_unit(value)
                for value in (stored_struggle.get("units") or [])
            )
            first_observed_units = _unique(
                normalize_target_unit(value)
                for value in (
                    stored_struggle.get("first_observed_units") or []
                )
            )
            for raw_key, raw_count in (
                stored_struggle.get("target_counts") or {}
            ).items():
                key = normalize_target_unit(raw_key)
                if key:
                    diagnostic_target_counts[key] = int(raw_count or 0)
        # Keep the complete ranked diagnostic set. Earlier code reduced a
        # multi-object task to one focus unit, which meant a child who
        # struggled with (for example) both the cat and elephant received
        # practice for only one of them. ``stored_units`` is already ordered
        # by evidence strength and recency by the interaction endpoint.
        semantic_units = reported_struggle or stored_units
        target_units = semantic_units or _unique([
            *metadata["primary_targets"],
            *target_ids,
        ])
        component_units = _unique(metadata["component_units"])
        incorrect_attempts = int(
            getattr(telemetry, "incorrect_attempt_count", 0) or 0
        )
        scaffold_level = int(
            getattr(telemetry, "scaffold_level_used", 0) or 0
        )
        exact_evidence = bool(target_units and (selected or wrong_option_ids))
        confidence = min(
            1.0,
            0.35
            + (0.20 if exact_evidence else 0.0)
            + min(0.30, 0.12 * incorrect_attempts)
            + (0.10 if scaffold_level > 0 else 0.0),
        )

        profile = {
            "profile_version": self.version,
            "knowledge_component_id": knowledge_component_id,
            "micro_kc_id": metadata["micro_kc_id"],
            "target_units": target_units,
            "component_units": component_units,
            "error_tags": list(metadata["micro_skill_tags"]),
            "selected_answers": _unique(selected),
            "wrong_option_ids": _unique(wrong_option_ids),
            "response_quality": response_quality,
            "independent_correct": bool(learning_observation_correct),
            "incorrect_attempt_count": incorrect_attempts,
            "scaffold_level_used": scaffold_level,
            "diagnostic_confidence": round(confidence, 4),
            "diagnostic_target_source": (
                "attempt_semantic_target"
                if semantic_units
                else "reviewed_item_metadata"
            ),
            "diagnostic_target_counts": diagnostic_target_counts,
            "first_observed_target_units": first_observed_units,
        }

        histories = adaptive_state.setdefault("micro_skill_evidence", {})
        keys = target_units or [metadata["micro_kc_id"]]
        for key in keys:
            evidence = histories.setdefault(str(key), {
                "opportunities": 0,
                "independent_successes": 0,
                "independent_failures": 0,
                "assisted_successes": 0,
                "mastery_estimate": 0.30,
            })
            evidence["opportunities"] += 1
            if learning_observation_correct:
                evidence["independent_successes"] += 1
            else:
                evidence["independent_failures"] += 1
                if response_quality == "ASSISTED_SUCCESS":
                    evidence["assisted_successes"] += 1
            # A transparent beta-binomial estimate is used for target-specific
            # evidence while the established BKT engine remains authoritative
            # for the broader knowledge component.
            successes = float(evidence["independent_successes"])
            failures = float(evidence["independent_failures"])
            evidence["mastery_estimate"] = round(
                (1.0 + successes) / (2.0 + successes + failures), 6
            )

        adaptive_state["latest_error_profile"] = profile
        return profile


error_profile_service = ErrorProfileService()
