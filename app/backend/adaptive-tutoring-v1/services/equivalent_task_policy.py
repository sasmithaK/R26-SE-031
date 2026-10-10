"""Bounded equivalent-task remediation for Component 4.

The policy intentionally separates instructional help from mastery evidence:

* ``V1`` is an unseen, reduced-load remediation item when a valid easier task
  exists.
* ``V2`` is an unseen, same-difficulty independent confirmation item.

No previously administered core item is reused as remediation.  The policy is
content-agnostic; the item bank guarantees that V1/V2 belong to the same
equivalent group and knowledge component as their core item.
"""

from __future__ import annotations

import re
from typing import Any, Dict, Optional


ITEM_RE = re.compile(r"^(S\d+A\d+R\d{2})(?:V(\d+))?$", re.IGNORECASE)


class EquivalentTaskPolicy:
    version = "C4_EQUIVALENT_TASK_V2"
    remediation_step = 0.5

    @staticmethod
    def _result(
        *,
        activity_id: str,
        next_item: str,
        next_phase: str,
        decision: str,
        current_b: float,
        state: Dict[str, Any],
        reasons: list[str],
        confirmation_required: bool,
        target_b: Optional[float] = None,
        difficulty_direction: str = "MAINTAIN",
    ) -> Dict[str, Any]:
        state["next_phase"] = next_phase
        if next_item:
            state["expected_item_id"] = next_item
        state["adaptive_policy_version"] = EquivalentTaskPolicy.version
        return {
            "next_activity": activity_id,
            "next_item": next_item,
            "difficulty": current_b if target_b is None else target_b,
            "target_difficulty": current_b if target_b is None else target_b,
            "difficulty_direction": difficulty_direction,
            "scaffold_level": 0,
            "decision": decision,
            "policy_reason": reasons,
            "confirmation_required": confirmation_required,
            "next_phase": next_phase,
            "state_updates": state,
        }

    def get_next_action(
        self,
        *,
        activity_id: str,
        current_item_id: str,
        response_quality: str,
        current_b: float,
        state: Optional[Dict[str, Any]],
        policy_reason: list[str],
        has_reduced_remediation: bool = True,
        has_floor_remediation: bool = False,
    ) -> Optional[Dict[str, Any]]:
        """Return a forced equivalent item, or ``None`` for normal selection."""
        match = ITEM_RE.fullmatch(current_item_id or "")
        if match is None:
            return None

        state = state if state is not None else {}
        core_item = match.group(1).upper()
        variant_number = int(match.group(2)) if match.group(2) else None
        independent = response_quality in {
            "MASTERED",
            "INDEPENDENT_SUCCESS",
            "CLEAN_SUCCESS",
        }
        struggled_independently = response_quality == "STRUGGLED_SUCCESS"

        state["current_core_item_id"] = core_item

        if variant_number is None:
            if independent:
                state["next_phase"] = "CORE"
                state.pop("remediation_origin_item_id", None)
                state.pop("remediation_origin_difficulty_b", None)
                policy_reason.append("CORE_INDEPENDENT_SUCCESS")
                return self._result(
                    activity_id=activity_id,
                    next_item="",
                    next_phase="CORE",
                    decision="CONTINUE",
                    current_b=current_b,
                    state=state,
                    reasons=policy_reason,
                    confirmation_required=False,
                )

            state["remediation_origin_item_id"] = core_item
            if struggled_independently:
                policy_reason.extend([
                    "CORE_INDEPENDENT_BUT_STRUGGLED",
                    "UNSEEN_EQUIVALENT_CONFIRMATION_REQUIRED",
                ])
                return self._result(
                    activity_id=activity_id,
                    next_item=f"{core_item}V2",
                    next_phase="CONFIRMATION",
                    decision="CONFIRMATION",
                    current_b=current_b,
                    state=state,
                    reasons=policy_reason,
                    confirmation_required=True,
                )

            if not has_reduced_remediation:
                if has_floor_remediation:
                    state["remediation_origin_difficulty_b"] = current_b
                    policy_reason.extend([
                        "CORE_ASSISTED_OR_FAILED",
                        "NO_VALID_LOWER_LOAD_ITEM",
                        "UNSEEN_FLOOR_REMEDIATION_REQUIRED",
                    ])
                    return self._result(
                        activity_id=activity_id,
                        next_item=f"{core_item}V1",
                        next_phase="REMEDIATION",
                        decision="REMEDIATION",
                        current_b=current_b,
                        state=state,
                        reasons=policy_reason,
                        confirmation_required=False,
                        target_b=current_b,
                        difficulty_direction="MAINTAIN",
                    )
                policy_reason.extend([
                    "CORE_ASSISTED_OR_FAILED",
                    "NO_VALID_LOWER_LOAD_ITEM",
                    "ONE_UNSEEN_SAME_LEVEL_RETRY_REQUIRED",
                ])
                state["remediation_origin_difficulty_b"] = current_b
                return self._result(
                    activity_id=activity_id,
                    next_item=f"{core_item}V2",
                    next_phase="CONFIRMATION",
                    decision="CONFIRMATION",
                    current_b=current_b,
                    state=state,
                    reasons=policy_reason,
                    confirmation_required=True,
                )

            remediation_b = max(-3.0, current_b - self.remediation_step)
            state["remediation_origin_difficulty_b"] = current_b
            policy_reason.extend([
                "CORE_ASSISTED_OR_FAILED",
                "UNSEEN_REDUCED_LOAD_REMEDIATION_REQUIRED",
            ])
            return self._result(
                activity_id=activity_id,
                next_item=f"{core_item}V1",
                next_phase="REMEDIATION",
                decision="REMEDIATION",
                current_b=current_b,
                state=state,
                reasons=policy_reason,
                confirmation_required=False,
                target_b=remediation_b,
                difficulty_direction="EASIER",
            )

        if variant_number == 1:
            origin_b = float(
                state.get("remediation_origin_difficulty_b", current_b)
            )
            policy_reason.extend([
                "REMEDIATION_ITEM_COMPLETED",
                "UNSEEN_EQUIVALENT_CONFIRMATION_REQUIRED",
            ])
            return self._result(
                activity_id=activity_id,
                next_item=f"{core_item}V2",
                next_phase="CONFIRMATION",
                decision="CONFIRMATION",
                current_b=origin_b,
                state=state,
                reasons=policy_reason,
                confirmation_required=True,
            )

        if variant_number == 2:
            state["next_phase"] = "CORE"
            state.pop("remediation_origin_item_id", None)
            state.pop("remediation_origin_difficulty_b", None)
            if independent:
                policy_reason.append("UNASSISTED_EQUIVALENT_CONFIRMATION_PASSED")
            else:
                # The sequence remains bounded and never reuses an item.  The
                # learner can continue, while this flag remains available for
                # parent/teacher review and later-session practice.
                state["teacher_review_required"] = True
                state["teacher_review_item_id"] = core_item
                policy_reason.extend([
                    "EQUIVALENT_CONFIRMATION_REQUIRED_SUPPORT",
                    "TEACHER_REVIEW_RECOMMENDED",
                ])
            return self._result(
                activity_id=activity_id,
                next_item="",
                next_phase="CORE",
                decision="CONTINUE",
                current_b=current_b,
                state=state,
                reasons=policy_reason,
                confirmation_required=False,
            )

        # Unknown future variants do not create a loop.
        policy_reason.append("UNKNOWN_VARIANT_RETURNED_TO_CORE_SELECTION")
        state["next_phase"] = "CORE"
        return None


equivalent_task_policy = EquivalentTaskPolicy()
