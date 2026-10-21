"""Bounded state machine for dynamic targeted practice and confirmation."""

from __future__ import annotations

from typing import Any, Dict


INDEPENDENT = {"MASTERED", "INDEPENDENT_SUCCESS", "CLEAN_SUCCESS"}


class DynamicPracticePolicy:
    """Route one diagnosed error through bounded remediation and confirmation."""

    version = "C4_DYNAMIC_TARGETED_PRACTICE_V3"
    max_remediation_items = 2
    max_confirmation_items = 3

    def _result(
        self,
        *,
        activity_id: str,
        state: Dict[str, Any],
        decision: str,
        next_phase: str,
        current_b: float,
        target_b: float,
        reasons: list[str],
        selection_intent: Dict[str, Any] | None = None,
    ) -> Dict[str, Any]:
        """Build the standard next-action payload and persist its phase state."""
        state["next_phase"] = next_phase
        state["adaptive_policy_version"] = self.version
        return {
            "next_activity": activity_id,
            "next_item": "",
            "difficulty": target_b,
            "target_difficulty": target_b,
            "difficulty_direction": (
                "EASIER" if target_b < current_b else "MAINTAIN"
            ),
            "scaffold_level": 0,
            "decision": decision,
            "policy_reason": reasons,
            "confirmation_required": next_phase == "CONFIRMATION",
            "next_phase": next_phase,
            "selection_intent": selection_intent,
            "state_updates": state,
        }

    def get_next_action(
        self,
        *,
        activity_id: str,
        current_item_id: str,
        item_role: str,
        response_quality: str,
        current_b: float,
        state: Dict[str, Any],
        error_profile: Dict[str, Any],
        policy_reason: list[str],
        has_reduced_remediation: bool,
        has_floor_remediation: bool,
    ) -> Dict[str, Any]:
        """Advance the targeted-practice state machine after a completed item."""
        phase = str(state.get("next_phase") or item_role or "CORE").upper()
        # The stored phase is authoritative because a reviewed confirmation
        # item may safely be borrowed as a same-load floor practice item.
        if phase not in {"CORE", "REMEDIATION", "CONFIRMATION"}:
            phase = str(item_role or "CORE").upper()
        independent = response_quality in INDEPENDENT

        # Safely migrate an Activity 5 cycle that was already persisted before
        # the single-focus rule was introduced. The current target is retained,
        # but the learner will no longer be sent through the remaining units.
        if (
            str(activity_id) == "2.5"
            and state.get("practice_origin_item_id")
        ):
            state["practice_single_target_cycle"] = True

        if phase == "CORE":
            if independent:
                self._clear_cycle(state)
                policy_reason.append("CORE_INDEPENDENT_SUCCESS")
                return self._result(
                    activity_id=activity_id,
                    state=state,
                    decision="CONTINUE",
                    next_phase="CORE",
                    current_b=current_b,
                    target_b=current_b,
                    reasons=policy_reason,
                )

            self._start_cycle(
                activity_id=activity_id,
                state=state,
                current_item_id=current_item_id,
                current_b=current_b,
                error_profile=error_profile,
            )
            if response_quality == "STRUGGLED_SUCCESS":
                policy_reason.extend([
                    "CORE_INDEPENDENT_BUT_STRUGGLED",
                    "TARGETED_INDEPENDENT_CONFIRMATION_REQUIRED",
                ])
                return self._practice_result(
                    activity_id=activity_id,
                    state=state,
                    phase="CONFIRMATION",
                    current_b=current_b,
                    target_b=current_b,
                    reasons=policy_reason,
                )

            # At the floor, use a reviewed same-load task rather than inventing
            # an invalid easier task. Otherwise request a lower-load candidate.
            same_load_floor = not has_reduced_remediation
            target_b = current_b if same_load_floor else max(-3.0, current_b - 0.5)
            policy_reason.extend([
                "CORE_ASSISTED_OR_FAILED",
                "TARGETED_REMEDIATION_REQUIRED",
                "SAME_LOAD_FLOOR_PRACTICE" if same_load_floor else "REDUCED_LOAD_PRACTICE",
            ])
            return self._practice_result(
                activity_id=activity_id,
                state=state,
                phase="REMEDIATION",
                current_b=current_b,
                target_b=target_b,
                reasons=policy_reason,
                allow_confirmation_as_floor=bool(
                    same_load_floor and not has_floor_remediation
                ),
            )

        if phase == "REMEDIATION":
            count = int(state.get("practice_remediation_count", 0)) + 1
            state["practice_remediation_count"] = count
            recovery_target = state.get("practice_recovery_target_unit")

            # These activities can diagnose several targets in one task, but
            # one practice cycle isolates only one target. Do not make a
            # Grade-1 learner complete a pair for every object/letter touched
            # incorrectly.
            # If the targeted remediation itself needed support, finish its
            # matching confirmation first and then run the authored generic
            # V1 -> V2 safety pair exactly once.
            if state.get("practice_single_target_cycle"):
                if state.get("practice_generic_fallback_active"):
                    if not independent:
                        state["practice_generic_remediation_needed_support"] = True
                    policy_reason.extend([
                        "GENERIC_REMEDIATION_COMPLETE",
                        "GENERIC_INDEPENDENT_CONFIRMATION_REQUIRED",
                    ])
                    origin_b = float(
                        state.get("practice_origin_difficulty_b", current_b)
                    )
                    return self._practice_result(
                        activity_id=activity_id,
                        state=state,
                        phase="CONFIRMATION",
                        current_b=current_b,
                        target_b=origin_b,
                        reasons=policy_reason,
                        generic_authored_fallback=True,
                    )

                if independent:
                    self._mark_current_unit_complete(state, "remediation")
                else:
                    state["practice_targeted_remediation_needed_support"] = True
                    policy_reason.append(
                        "TARGETED_REMEDIATION_NEEDED_SUPPORT"
                    )
                policy_reason.extend([
                    "SINGLE_DIAGNOSED_UNIT_REMEDIATION_COMPLETE",
                    "MATCHING_TARGETED_CONFIRMATION_REQUIRED",
                ])
                origin_b = float(
                    state.get("practice_origin_difficulty_b", current_b)
                )
                return self._practice_result(
                    activity_id=activity_id,
                    state=state,
                    phase="CONFIRMATION",
                    current_b=current_b,
                    target_b=origin_b,
                    reasons=policy_reason,
                )

            # A failed confirmation receives exactly one alternate recovery
            # item for that same target. Afterwards it returns to an unseen
            # independent confirmation; it never restarts the whole cycle.
            if recovery_target:
                state.pop("practice_recovery_target_unit", None)
                state["practice_current_target_unit"] = recovery_target
                policy_reason.extend([
                    "ALTERNATE_RECOVERY_ITEM_COMPLETE",
                    "RETURN_TO_INDEPENDENT_CONFIRMATION",
                ])
                origin_b = float(
                    state.get("practice_origin_difficulty_b", current_b)
                )
                return self._practice_result(
                    activity_id=activity_id,
                    state=state,
                    phase="CONFIRMATION",
                    current_b=current_b,
                    target_b=origin_b,
                    reasons=policy_reason,
                )

            if independent:
                self._mark_current_unit_complete(state, "remediation")
            if (
                independent
                and count < self.max_remediation_items
                and self._advance_unit(state, "remediation")
            ):
                policy_reason.extend([
                    "ADDITIONAL_DIAGNOSED_UNIT_REQUIRES_REMEDIATION",
                    "MULTI_TARGET_REMEDIATION_BOUNDED_TO_TWO_UNITS",
                ])
                origin_b = float(
                    state.get("practice_origin_difficulty_b", current_b)
                )
                return self._practice_result(
                    activity_id=activity_id,
                    state=state,
                    phase="REMEDIATION",
                    current_b=current_b,
                    target_b=max(-3.0, origin_b - 0.5),
                    reasons=policy_reason,
                )
            if not independent and count < self.max_remediation_items:
                policy_reason.extend([
                    "TARGETED_REMEDIATION_NEEDED_SUPPORT",
                    "ALTERNATE_REMEDIATION_REQUIRED",
                ])
                origin_b = float(state.get("practice_origin_difficulty_b", current_b))
                return self._practice_result(
                    activity_id=activity_id,
                    state=state,
                    phase="REMEDIATION",
                    current_b=current_b,
                    target_b=max(-3.0, origin_b - 0.5),
                    reasons=policy_reason,
                )

            policy_reason.extend([
                "TARGETED_REMEDIATION_COMPLETE",
                "UNSEEN_INDEPENDENT_CONFIRMATION_REQUIRED",
            ])
            self._activate_first_unit(state, "confirmation")
            origin_b = float(state.get("practice_origin_difficulty_b", current_b))
            return self._practice_result(
                activity_id=activity_id,
                state=state,
                phase="CONFIRMATION",
                current_b=current_b,
                target_b=origin_b,
                reasons=policy_reason,
            )

        # CONFIRMATION must be solved independently to count as mastery.
        count = int(state.get("practice_confirmation_count", 0)) + 1
        state["practice_confirmation_count"] = count

        if state.get("practice_single_target_cycle"):
            if state.get("practice_generic_fallback_active"):
                preserve_review = not independent
                if preserve_review:
                    state["teacher_review_required"] = True
                    state["teacher_review_item_id"] = state.get(
                        "practice_origin_item_id", current_item_id
                    )
                    state["teacher_review_error_profile"] = state.get(
                        "practice_error_profile", error_profile
                    )
                    policy_reason.extend([
                        "GENERIC_CONFIRMATION_REQUIRED_SUPPORT",
                        "BOUNDED_GENERIC_FALLBACK_COMPLETE",
                        "TEACHER_REVIEW_RECOMMENDED",
                    ])
                else:
                    policy_reason.append(
                        "GENERIC_CONFIRMATION_PASSED_INDEPENDENTLY"
                    )
                self._clear_cycle(state, preserve_review=preserve_review)
                return self._result(
                    activity_id=activity_id,
                    state=state,
                    decision="CONTINUE",
                    next_phase="CORE",
                    current_b=current_b,
                    target_b=current_b,
                    reasons=policy_reason,
                )

            if independent:
                self._mark_current_unit_complete(state, "confirmation")
            needs_generic_fallback = bool(
                state.get("practice_targeted_remediation_needed_support")
                or not independent
            )
            if needs_generic_fallback:
                state["practice_generic_fallback_active"] = True
                policy_reason.extend([
                    "TARGETED_PAIR_REQUIRED_SUPPORT",
                    "AUTHORED_GENERIC_REMEDIATION_REQUIRED",
                ])
                origin_b = float(
                    state.get("practice_origin_difficulty_b", current_b)
                )
                return self._practice_result(
                    activity_id=activity_id,
                    state=state,
                    phase="REMEDIATION",
                    current_b=current_b,
                    target_b=max(-3.0, origin_b - 0.5),
                    reasons=policy_reason,
                    generic_authored_fallback=True,
                )

            policy_reason.append(
                "SINGLE_TARGET_CONFIRMATION_PASSED_INDEPENDENTLY"
            )
            self._clear_cycle(state)
            return self._result(
                activity_id=activity_id,
                state=state,
                decision="CONTINUE",
                next_phase="CORE",
                current_b=current_b,
                target_b=current_b,
                reasons=policy_reason,
            )

        if independent:
            self._mark_current_unit_complete(state, "confirmation")
            if (
                count < self.max_confirmation_items
                and self._advance_unit(state, "confirmation")
            ):
                policy_reason.extend([
                    "ADDITIONAL_DIAGNOSED_UNIT_REQUIRES_CONFIRMATION",
                    "MULTI_TARGET_CONFIRMATION_BOUNDED_TO_THREE_UNITS",
                ])
                origin_b = float(
                    state.get("practice_origin_difficulty_b", current_b)
                )
                return self._practice_result(
                    activity_id=activity_id,
                    state=state,
                    phase="CONFIRMATION",
                    current_b=current_b,
                    target_b=origin_b,
                    reasons=policy_reason,
                )
            policy_reason.append("TARGETED_CONFIRMATION_PASSED_INDEPENDENTLY")
            self._clear_cycle(state)
            return self._result(
                activity_id=activity_id,
                state=state,
                decision="CONTINUE",
                next_phase="CORE",
                current_b=current_b,
                target_b=current_b,
                reasons=policy_reason,
            )

        remediation_count = int(state.get("practice_remediation_count", 0))
        recovery_count = int(state.get("practice_recovery_cycle_count", 0))
        if (
            remediation_count < self.max_remediation_items
            and count < self.max_confirmation_items
            and recovery_count < 1
        ):
            state["practice_recovery_cycle_count"] = recovery_count + 1
            state["practice_recovery_target_unit"] = state.get(
                "practice_current_target_unit"
            )
            policy_reason.extend([
                "CONFIRMATION_REQUIRED_SUPPORT",
                "ONE_ALTERNATE_TARGETED_RECOVERY_ALLOWED",
            ])
            origin_b = float(state.get("practice_origin_difficulty_b", current_b))
            return self._practice_result(
                activity_id=activity_id,
                state=state,
                phase="REMEDIATION",
                current_b=current_b,
                target_b=max(-3.0, origin_b - 0.5),
                reasons=policy_reason,
            )

        state["teacher_review_required"] = True
        state["teacher_review_item_id"] = state.get(
            "practice_origin_item_id", current_item_id
        )
        state["teacher_review_error_profile"] = state.get(
            "practice_error_profile", error_profile
        )
        policy_reason.extend([
            "CONFIRMATION_REQUIRED_SUPPORT",
            "BOUNDED_PRACTICE_LIMIT_REACHED",
            "TEACHER_REVIEW_RECOMMENDED",
        ])
        self._clear_cycle(state, preserve_review=True)
        return self._result(
            activity_id=activity_id,
            state=state,
            decision="CONTINUE",
            next_phase="CORE",
            current_b=current_b,
            target_b=current_b,
            reasons=policy_reason,
        )

    def _practice_result(
        self,
        *,
        activity_id: str,
        state: Dict[str, Any],
        phase: str,
        current_b: float,
        target_b: float,
        reasons: list[str],
        allow_confirmation_as_floor: bool = False,
        generic_authored_fallback: bool = False,
    ) -> Dict[str, Any]:
        """Create the selector intent for one remediation or confirmation item."""
        profile = dict(state.get("practice_error_profile") or {})
        active_unit = state.get("practice_current_target_unit")
        intent = {
            "role": phase,
            "origin_item_id": state.get("practice_origin_item_id"),
            "origin_equivalent_group_id": state.get("practice_origin_group_id"),
            # One reviewed task isolates one diagnosed unit. The queues below
            # ensure that up to two failed units receive easier remediation
            # and up to three receive independent confirmation.
            "target_units": (
                []
                if generic_authored_fallback
                else
                [active_unit]
                if active_unit
                else list(profile.get("target_units", []))[:1]
            ),
            "component_units": profile.get("component_units", []),
            "error_tags": profile.get("error_tags", []),
            "micro_kc_id": profile.get("micro_kc_id"),
            "diagnostic_confidence": profile.get("diagnostic_confidence", 0.0),
            "allow_confirmation_as_floor": allow_confirmation_as_floor,
            "generic_authored_fallback": generic_authored_fallback,
        }
        return self._result(
            activity_id=activity_id,
            state=state,
            decision=phase,
            next_phase=phase,
            current_b=current_b,
            target_b=target_b,
            reasons=reasons,
            selection_intent=intent,
        )

    @staticmethod
    def _start_cycle(
        *,
        activity_id: str,
        state: Dict[str, Any],
        current_item_id: str,
        current_b: float,
        error_profile: Dict[str, Any],
    ) -> None:
        """Initialize bounded target queues from the latest diagnosed error."""
        state["practice_origin_item_id"] = current_item_id
        state["practice_origin_group_id"] = error_profile.get(
            "equivalent_group_id", current_item_id
        )
        state["practice_origin_difficulty_b"] = current_b
        state["practice_error_profile"] = dict(error_profile)
        ranked_units = list(error_profile.get("target_units") or [])
        single_target_cycle = str(activity_id) in {"1.3", "2.2", "2.5"}
        if str(activity_id) == "2.5":
            # A memory-sequence error identifies the exact expected token at
            # each failed position. Focus on the first observed failure; a
            # later/repeated error must not replace it or create another pair.
            first_observed = list(
                error_profile.get("first_observed_target_units") or []
            )
            if first_observed:
                ranked_units = first_observed
        state["practice_single_target_cycle"] = single_target_cycle
        if single_target_cycle:
            ranked_units = ranked_units[:1]
        state["practice_remediation_units"] = ranked_units[
            :DynamicPracticePolicy.max_remediation_items
        ]
        state["practice_confirmation_units"] = ranked_units[
            :DynamicPracticePolicy.max_confirmation_items
        ]
        state["practice_completed_remediation_units"] = []
        state["practice_completed_confirmation_units"] = []
        DynamicPracticePolicy._activate_first_unit(state, "remediation")
        state["practice_remediation_count"] = 0
        state["practice_confirmation_count"] = 0
        state["practice_recovery_cycle_count"] = 0
        state["practice_route"] = []

    @staticmethod
    def _clear_cycle(state: Dict[str, Any], preserve_review: bool = False) -> None:
        """Remove completed practice-cycle state while optionally keeping review."""
        for key in (
            "practice_origin_item_id", "practice_origin_group_id",
            "practice_origin_difficulty_b", "practice_error_profile",
            "practice_remediation_count", "practice_confirmation_count",
            "practice_route",
            "practice_remediation_units", "practice_confirmation_units",
            "practice_completed_remediation_units",
            "practice_completed_confirmation_units",
            "practice_current_target_unit",
            "practice_recovery_cycle_count", "practice_recovery_target_unit",
            "practice_single_target_cycle",
            "practice_targeted_remediation_needed_support",
            "practice_generic_fallback_active",
            "practice_generic_remediation_needed_support",
            "transfer_probe_active", "transfer_probe_unit",
        ):
            state.pop(key, None)
        if not preserve_review:
            state.pop("teacher_review_required", None)
            state.pop("teacher_review_item_id", None)
            state.pop("teacher_review_error_profile", None)

    @staticmethod
    def _queue_key(phase: str) -> str:
        """Return the state key containing queued units for a practice phase."""
        return f"practice_{phase}_units"

    @staticmethod
    def _completed_key(phase: str) -> str:
        """Return the state key containing completed units for a phase."""
        return f"practice_completed_{phase}_units"

    @staticmethod
    def _activate_first_unit(state: Dict[str, Any], phase: str) -> None:
        """Make the first not-yet-completed target unit active."""
        queue = list(state.get(DynamicPracticePolicy._queue_key(phase), []))
        completed = set(
            state.get(DynamicPracticePolicy._completed_key(phase), [])
        )
        state["practice_current_target_unit"] = next(
            (unit for unit in queue if unit not in completed), None
        )

    @staticmethod
    def _mark_current_unit_complete(
        state: Dict[str, Any], phase: str
    ) -> None:
        """Record the active unit as completed for the current phase."""
        unit = state.get("practice_current_target_unit")
        if not unit:
            return
        key = DynamicPracticePolicy._completed_key(phase)
        completed = list(state.get(key, []))
        if unit not in completed:
            completed.append(unit)
        state[key] = completed

    @staticmethod
    def _advance_unit(state: Dict[str, Any], phase: str) -> bool:
        """Advance to the next queued target and report whether one remains."""
        DynamicPracticePolicy._activate_first_unit(state, phase)
        return bool(state.get("practice_current_target_unit"))

dynamic_practice_policy = DynamicPracticePolicy()
