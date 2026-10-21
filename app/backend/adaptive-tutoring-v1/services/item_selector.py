"""Select safe next items from the reviewed Component 4 item bank.

Hard curriculum and exposure constraints are applied before optional ML
ranking.  The selector never generates child-facing content; it returns an
existing authored item plus evidence explaining the choice.
"""

import math
from typing import List, Dict, Any, Optional

from services.practice_metadata import derive_practice_metadata, normalize_target_unit
from services.practice_selector_model import practice_selector_model

class ItemSelector:
    """Choose reviewed curriculum items under instructional constraints."""

    def select_targeted_practice_item(
        self,
        *,
        current_item_id: str,
        current_activity: str,
        knowledge_component_id: str,
        target_difficulty: float,
        candidates: List[Dict[str, Any]],
        selection_intent: Dict[str, Any],
        excluded_item_ids: Optional[List[str]] = None,
        exposure_counts: Optional[Dict[str, int]] = None,
        micro_skill_evidence: Optional[Dict[str, Any]] = None,
        fatigue: float = 0.0,
        requested_mode: Optional[str] = None,
        data_origin: str = "observed",
    ) -> Dict[str, Any]:
        """Select one unseen, reviewed task for a diagnosed learner need.

        Curriculum and safety constraints are applied before model ranking.
        This keeps the ML system from selecting a core task, another activity,
        inactive content, or a task that the learner has already received.
        """
        role = str(selection_intent.get("role") or "REMEDIATION").upper()
        allowed_roles = {role}
        if role == "REMEDIATION" and selection_intent.get(
            "allow_confirmation_as_floor"
        ):
            allowed_roles.add("CONFIRMATION")
        excluded = set(map(str, excluded_item_ids or []))
        excluded.add(str(current_item_id))
        eligible = [
            candidate for candidate in candidates
            if candidate.get("activity_id") == current_activity
            and candidate.get("knowledge_component_id") == knowledge_component_id
            and candidate.get("is_active", True) is not False
            and candidate.get("is_core", False) is False
            and str(candidate.get("item_role") or "").upper() in allowed_roles
            and str(candidate.get("item_id")) not in excluded
            and (
                (candidate.get("validation") or {}).get("duplicate_of_core")
                is not True
            )
        ]

        # Preserve instructional identity before considering numerical
        # difficulty or model utility. A remediation/confirmation item from a
        # different core round makes the progress indicator jump backwards
        # and can practise a different Sinhala target. Prefer, in order:
        #   1. same origin group + exact diagnosed target;
        #   2. same origin group;
        #   3. exact target elsewhere in the same reviewed activity;
        #   4. the remaining reviewed pool as a last-resort safe fallback.
        origin_group = str(
            selection_intent.get("origin_equivalent_group_id") or ""
        )
        diagnosed_targets = {
            str(value) for value in selection_intent.get("target_units", [])
            if str(value)
        }

        def has_exact_target(candidate: Dict[str, Any]) -> bool:
            """Check whether a candidate covers the diagnosed target unit."""
            if not diagnosed_targets:
                return False
            metadata = derive_practice_metadata(candidate)
            candidate_targets = set(map(str, metadata["primary_targets"]))
            candidate_components = set(map(str, metadata["component_units"]))
            return bool(
                diagnosed_targets.intersection(candidate_targets)
                or diagnosed_targets.intersection(candidate_components)
            )

        same_origin = [
            candidate for candidate in eligible
            if str(candidate.get("equivalent_group_id") or "") == origin_group
        ]
        same_origin_exact = [
            candidate for candidate in same_origin
            if has_exact_target(candidate)
        ]
        authored_targeted_exact = [
            candidate for candidate in same_origin_exact
            if candidate.get("targeted_practice") is True
            and (
                not normalize_target_unit(
                    candidate.get("targeted_unit")
                    or (candidate.get("content") or {}).get("targeted_unit")
                    or ""
                )
                or normalize_target_unit(
                    candidate.get("targeted_unit")
                    or (candidate.get("content") or {}).get("targeted_unit")
                    or ""
                ) in diagnosed_targets
            )
        ]
        exact_elsewhere = [
            candidate for candidate in eligible
            if has_exact_target(candidate)
        ]
        generic_authored_fallback = bool(
            selection_intent.get("generic_authored_fallback")
        )
        if generic_authored_fallback:
            # This is the bounded safety cycle used after a targeted pair
            # needed support. It must use the educator-authored generic V1/V2
            # records, never another target-specific V3+ item.
            eligible = [
                candidate for candidate in same_origin
                if candidate.get("targeted_practice") is not True
            ]
            candidate_scope = "SAME_ORIGIN_GENERIC_FALLBACK"
        elif authored_targeted_exact:
            # When an educator-reviewed exact-target pair exists, do not let a
            # generic V1/V2 that happens to contain the same image win by
            # chance. The dedicated pair was authored specifically for this
            # diagnosed unit and declares that provenance in the item bank.
            eligible = authored_targeted_exact
            candidate_scope = "SAME_ORIGIN_EXACT_TARGET"
        elif same_origin_exact:
            eligible = same_origin_exact
            candidate_scope = "SAME_ORIGIN_EXACT_TARGET"
        elif same_origin:
            eligible = same_origin
            candidate_scope = "SAME_ORIGIN_REVIEWED_EQUIVALENT"
        elif exact_elsewhere:
            eligible = exact_elsewhere
            candidate_scope = "SAME_ACTIVITY_EXACT_TARGET_FALLBACK"
        else:
            candidate_scope = "SAME_ACTIVITY_REVIEWED_FALLBACK"

        # A floor task may permit a confirmation item as a safe fallback, but
        # it must not replace an available remediation item. Preserve the
        # requested instructional phase whenever that reviewed pool exists.
        requested_role_candidates = [
            candidate for candidate in eligible
            if str(candidate.get("item_role") or "").upper() == role
        ]
        if requested_role_candidates:
            eligible = requested_role_candidates

        # Difficulty is an instructional safety constraint, not merely a
        # feature the model may trade away. Confirmation stays at the origin
        # load; remediation stays at the nearest reviewed lower-load tier.
        # Rank only candidates in the closest available authored tier.
        if eligible:
            closest_distance = min(
                abs(
                    float(candidate.get("difficulty_b", target_difficulty))
                    - target_difficulty
                )
                for candidate in eligible
            )
            eligible = [
                candidate
                for candidate in eligible
                if abs(
                    float(candidate.get("difficulty_b", target_difficulty))
                    - target_difficulty
                )
                <= closest_distance + 1e-9
            ]

        model_evidence = practice_selector_model.rank(
            candidates=eligible,
            selection_intent=selection_intent,
            target_difficulty=target_difficulty,
            exposure_counts=exposure_counts or {},
            micro_skill_evidence=micro_skill_evidence or {},
            fatigue=fatigue,
            requested_mode=requested_mode,
            data_origin=data_origin,
        )
        ranked = model_evidence.get("ranked_candidates") or []
        selected_id = model_evidence.get("recommended_item")

        # If exact targeting exhausted the pool, a reviewed item from the same
        # activity/KC/role is still safer than fabricating Sinhala content.
        if not selected_id:
            return {
                "selected_item": None,
                "selected_difficulty": target_difficulty,
                "target_difficulty": target_difficulty,
                "selection_reason": "NO_UNSEEN_REVIEWED_TARGETED_CANDIDATE",
                "selection_strategy": "dynamic_targeted_practice_v1",
                "candidate_count": 0,
                "candidate_scope": candidate_scope,
                "selection_intent": selection_intent,
                **model_evidence,
            }
        selected = next(
            candidate for candidate in eligible
            if candidate.get("item_id") == selected_id
        )
        top = ranked[0] if ranked else {}
        exact_target = bool(
            (top.get("features") or {}).get("primary_target_match", 0.0) > 0
        )
        return {
            "selected_item": selected_id,
            "selected_difficulty": float(
                selected.get("difficulty_b", target_difficulty)
            ),
            "target_difficulty": target_difficulty,
            "selection_reason": (
                "EXACT_TARGET_REVIEWED_ITEM_SELECTED"
                if exact_target else "MICRO_SKILL_REVIEWED_ITEM_SELECTED"
            ),
            "selection_strategy": "dynamic_targeted_practice_v1",
            "candidate_count": len(eligible),
            "candidate_scope": candidate_scope,
            "selected_candidate_evidence": top,
            "top_candidate_scores": ranked[:5],
            "selection_intent": selection_intent,
            **{
                key: value for key, value in model_evidence.items()
                if key != "ranked_candidates"
            },
        }

    def select_next_item(
        self,
        current_item_id: str,
        current_activity: str,
        target_difficulty: float,
        candidates: List[Dict[str, Any]],
        confirmation_required: bool = False,
        forced_item_id: Optional[str] = None,
        excluded_item_ids: Optional[List[str]] = None,
        knowledge_component_id: Optional[str] = None,
        equivalent_group_id: Optional[str] = None,
        exposure_counts: Optional[Dict[str, int]] = None,
    ) -> Dict[str, Any]:
        """
        Adaptive item selection using provisional IRT difficulty parameters,
        difficulty buckets, and confirmation preference.
        """
        if forced_item_id:
            forced = next(
                (candidate for candidate in candidates
                 if candidate.get("item_id") == forced_item_id),
                None,
            )
            selected_difficulty = (
                forced.get("difficulty_b", target_difficulty)
                if forced is not None else target_difficulty
            )
            return {
                "selected_item": forced_item_id,
                "selected_difficulty": selected_difficulty,
                "target_difficulty": target_difficulty,
                "selection_reason": "AUTHORED_EQUIVALENT_FLOW_OVERRIDE",
                "selection_strategy": "bounded_authored_state_machine",
                "candidate_count": 1 if forced is not None else 0,
                "constraints": {
                    "activity_id": current_activity,
                    "knowledge_component_id": knowledge_component_id,
                    "equivalent_group_id": equivalent_group_id,
                    "unseen_required": True,
                },
            }
            
        if not candidates:
            return {
                "selected_item": current_item_id if current_item_id else "act_1_round1", # Safe fallback
                "selected_difficulty": 0.0,
                "target_difficulty": target_difficulty,
                "selection_reason": "NO_CANDIDATE_FALLBACK"
            }
            
        # 1. Filter valid candidates. Ordinary IRT selection must not cycle
        # through items already completed in this activity. Explicit state-
        # machine overrides may still repeat an item for confirmation.
        valid_candidates = [
            c for c in candidates
            if c.get("activity_id") == current_activity
            and c.get("is_active", True) is not False
            and (
                not knowledge_component_id
                or c.get("knowledge_component_id") == knowledge_component_id
            )
        ]
        excluded = set(excluded_item_ids or [])
        unseen_candidates = [
            candidate for candidate in valid_candidates
            if candidate.get("item_id") not in excluded
        ]
        if unseen_candidates:
            valid_candidates = unseen_candidates
        elif valid_candidates and excluded:
            return {
                "selected_item": "COMPLETE",
                "selected_difficulty": 0.0,
                "target_difficulty": target_difficulty,
                "selection_reason": "ALL_ACTIVE_ITEMS_ADMINISTERED",
            }
        
        if not valid_candidates:
            return {
                "selected_item": current_item_id if current_item_id else "act_1_round1",
                "selected_difficulty": 0.0,
                "target_difficulty": target_difficulty,
                "selection_reason": "NO_CANDIDATE_FALLBACK_FOR_ACTIVITY"
            }

        def get_bucket(diff: float) -> str:
            """Map continuous item difficulty to a confirmation band."""
            if diff <= -1.0: return "VERY_EASY"
            elif diff <= -0.25: return "EASY"
            elif diff <= 0.25: return "MEDIUM"
            elif diff <= 1.0: return "HARD"
            return "VERY_HARD"

        # If confirmation is required, prioritize items with role='CONFIRMATION' in the same bucket
        if confirmation_required:
            target_bucket = get_bucket(target_difficulty)
            conf_candidates = [
                c for c in valid_candidates
                if c.get("item_role") == "CONFIRMATION"
                and get_bucket(c.get("difficulty_b", 0.0)) == target_bucket
                and (
                    not equivalent_group_id
                    or c.get("equivalent_group_id") == equivalent_group_id
                )
            ]
            
            if conf_candidates:
                # Exclude current item if alternatives exist
                if len(conf_candidates) > 1:
                    conf_candidates = [c for c in conf_candidates if c.get("item_id") != current_item_id]
                best = sorted(conf_candidates, key=lambda c: abs(c.get("difficulty_b", 0.0) - target_difficulty))[0]
                return {
                    "selected_item": best.get("item_id"),
                    "selected_difficulty": best.get("difficulty_b", 0.0),
                    "target_difficulty": target_difficulty,
                    "selection_reason": "CONSTRAINED_CONFIRMATION_ITEM_SELECTED",
                    "selection_strategy": "same_kc_same_bucket_unseen",
                    "candidate_count": len(conf_candidates),
                }

        # Normal selection
        if len(valid_candidates) > 1:
            # Filter out current item, and if normal progression, prefer is_core=True
            filtered_candidates = [c for c in valid_candidates if c.get("item_id") != current_item_id]
            core_only = [c for c in filtered_candidates if c.get("is_core", True)]
            if core_only:
                filtered_candidates = core_only
            if filtered_candidates:
                valid_candidates = filtered_candidates
            
        exposure_counts = exposure_counts or {}

        def candidate_evidence(c: Dict[str, Any]) -> Dict[str, Any]:
            """Build auditable IRT-distance and prior-exposure evidence."""
            difficulty = float(c.get("difficulty_b", 0.0) or 0.0)
            distance = abs(difficulty - target_difficulty)
            # At the target ability, a Rasch item is most informative near
            # p=.5. This metric is reported for auditability; authored round
            # order remains the final tie-breaker for curriculum coherence.
            probability = 1.0 / (1.0 + math.exp(
                -max(-30.0, min(30.0, target_difficulty - difficulty))
            ))
            information = probability * (1.0 - probability)
            exposure = int(exposure_counts.get(str(c.get("item_id")), 0) or 0)
            return {
                "item_id": c.get("item_id"),
                "difficulty_distance": round(distance, 6),
                "rasch_information": round(information, 6),
                "prior_exposure_count": exposure,
                "round": int(c.get("round", 0) or 0),
            }

        scored = [(candidate_evidence(candidate), candidate) for candidate in valid_candidates]

        def sort_key(pair):
            """Rank safe candidates deterministically after hard filtering."""
            evidence, _ = pair
            return (
                evidence["difficulty_distance"],
                evidence["prior_exposure_count"],
                -evidence["rasch_information"],
                evidence["round"],
                str(evidence["item_id"]),
            )
            
        sorted_candidates = sorted(scored, key=sort_key)
        best_evidence, best_candidate = sorted_candidates[0]
        
        reason = "IRT_DIFFICULTY_MATCH"
        if best_candidate.get("item_id") == current_item_id:
            reason = "BEST_MATCH_BUT_REPEATED_DUE_TO_NO_ALTERNATIVES"
        elif confirmation_required:
            reason = "CONFIRMATION_REQUIRED_BUT_NO_CONFIRMATION_ITEMS_FOUND_FALLBACK"
            
        return {
            "selected_item": best_candidate.get("item_id"),
            "selected_difficulty": best_candidate.get("difficulty_b", 0.0),
            "target_difficulty": target_difficulty,
            "selection_reason": reason,
            "selection_strategy": "constrained_irt_information_exposure_ranking",
            "candidate_count": len(sorted_candidates),
            "selected_candidate_evidence": best_evidence,
            "top_candidate_scores": [
                evidence for evidence, _ in sorted_candidates[:5]
            ],
        }

item_selector = ItemSelector()
