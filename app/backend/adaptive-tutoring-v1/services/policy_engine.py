import re
from typing import Dict, Any, Optional, Tuple

from services.equivalent_task_policy import equivalent_task_policy

def get_activity_latency_baseline(activity_id: str) -> int:
    """Grade-1 task-time baselines in milliseconds.

    These are deliberately generous observational baselines, not speed limits.
    A child is not sent to extra instruction merely for taking longer to look,
    listen, drag several objects, or formulate an answer.
    """
    baselines = {
        "1.1": 12000, "1.2": 15000, "1.3": 20000,
        "1.4": 12000, "1.5": 12000,
        "2.1": 10000, "2.2": 15000, "2.3": 10000,
        "2.4": 12000, "2.5": 12000,
        "3.1": 12000, "3.2": 12000, "3.3": 12000,
        "3.4": 12000, "3.5": 18000,
        "4.1": 15000, "4.2": 15000, "4.3": 15000,
        "4.4": 20000,
    }
    return baselines.get(activity_id, 12000)

class PolicyEngine:
    def classify_response(self, is_correct: bool, telemetry: Any, activity_id: str) -> Tuple[str, int, str, float]:
        if not telemetry:
            return "CLEAN_SUCCESS" if is_correct else "FAILED", 0, "LOW", 1.0
            
        baseline = get_activity_latency_baseline(activity_id)
        latency_ratio = telemetry.total_round_latency_ms / baseline if baseline > 0 else 1.0
        
        score = 0
        if telemetry.misclick_count == 1: score += 1
        elif telemetry.misclick_count >= 2: score += 2
        
        if telemetry.hesitation_count == 2: score += 1
        elif telemetry.hesitation_count >= 3: score += 2
        
        if latency_ratio > 3.0: score += 2
        elif latency_ratio > 1.75: score += 1
        
        if telemetry.audio_replay_count >= 2: score += 1
            
        if score >= 4: band = "HIGH"
        elif score >= 2: band = "MODERATE"
        else: band = "LOW"
        
        first_attempt_correct = getattr(telemetry, "first_attempt_correct", None)
        incorrect_attempts = int(
            getattr(telemetry, "incorrect_attempt_count", 0) or 0
        )
        scaffold_level = int(
            getattr(telemetry, "scaffold_level_used", 0) or 0
        )
        hint_count = int(getattr(telemetry, "hint_count", 0) or 0)
        correction_count = int(
            getattr(telemetry, "correction_count", 0) or 0
        )

        if not is_correct:
            qual = "FAILED"
        elif (
            scaffold_level > 0
            or incorrect_attempts > 0
            or first_attempt_correct is False
            or hint_count > 0
        ):
            qual = "ASSISTED_SUCCESS"
        elif (
            correction_count > 0
            or telemetry.misclick_count >= 2
            or (
                telemetry.hesitation_count >= 3
                and latency_ratio > 2.5
            )
            or (
                telemetry.audio_replay_count >= 2
                and telemetry.hesitation_count >= 2
            )
        ):
            qual = "STRUGGLED_SUCCESS"
        else:
            # Normal Grade-1 thinking time (including one hesitation event)
            # remains independent evidence and must not create a repeat task.
            qual = "CLEAN_SUCCESS"
            
        return qual, score, band, latency_ratio

    def get_support_action(
        self,
        telemetry: Any,
        options_count: int,
        struggle_score: int,
        available_incorrect_ids: list,
        adaptive_state: Dict[str, Any],
        activity_id: str = "2.2",
        round_idx: int = 1
    ) -> Dict[str, Any]:
        """
        Calculates the scaffold escalation based sequentially on the current pair/target attempt count.
        Called when phase = "ATTEMPT".
        """
        supported_actions = set(getattr(telemetry, "supported_actions", None) or [])
        if supported_actions:
            return self._get_capability_support_action(
                telemetry=telemetry,
                options_count=options_count,
                available_incorrect_ids=available_incorrect_ids,
                adaptive_state=adaptive_state,
            )
        if activity_id == "2.1":
            return self._s2a1_get_support_action(telemetry, options_count, struggle_score, available_incorrect_ids, adaptive_state, round_idx)
        elif activity_id == "2.3":
            return self._s2a3_get_support_action(telemetry, options_count, struggle_score, available_incorrect_ids, adaptive_state, round_idx)
        elif activity_id == "2.4":
            return self._s2a4_get_support_action(telemetry, options_count, struggle_score, available_incorrect_ids, adaptive_state, round_idx)
        elif activity_id == "2.5":
            return self._s2a5_get_support_action(telemetry, options_count, struggle_score, available_incorrect_ids, adaptive_state, round_idx)
            
        # S2A2 logic
        current_pair_id = getattr(telemetry, "current_pair_id", None)
        
        pair_state = adaptive_state.get("current_pair_state", {
            "pair_id": None,
            "wrong_count": 0,
            "scaffold_step": 0
        })
        
        if current_pair_id and pair_state.get("pair_id") != current_pair_id:
            pair_state = {
                "pair_id": current_pair_id,
                "wrong_count": 0,
                "scaffold_step": 0
            }
            
        pair_state["wrong_count"] += 1
        step = pair_state["scaffold_step"]
        
        if options_count <= 2:
            step = 3
        elif options_count == 3:
            if pair_state["wrong_count"] == 1: step = 1
            else: step = 3
        elif options_count == 4:
            if pair_state["wrong_count"] == 1: step = 1
            else: step = 3
        elif options_count >= 5:
            if pair_state["wrong_count"] == 1: step = 1
            elif pair_state["wrong_count"] == 2: step = 2
            else: step = 3
                
        if pair_state["scaffold_step"] == 3:
            step = 3
            
        pair_state["scaffold_step"] = step
        adaptive_state["current_pair_state"] = pair_state
        adaptive_state["highest_scaffold_level_used"] = max(adaptive_state.get("highest_scaffold_level_used", 0), step)

        decision = "RETRY_CURRENT"
        highlight = False
        remove_option_ids = []

        if step in [1, 2]:
            decision = "SCAFFOLD_REMOVE_DISTRACTOR"
            if available_incorrect_ids:
                remove_option_ids = [sorted(map(str, available_incorrect_ids))[0]]
        elif step == 3:
            decision = "SCAFFOLD_HIGHLIGHT_CORRECT"
            highlight = True
            
        return {
            "decision": decision,
            "scaffold_level": step,
            "remove_option_ids": remove_option_ids,
            "highlight_correct": highlight
        }

    def _get_capability_support_action(
        self,
        telemetry: Any,
        options_count: int,
        available_incorrect_ids: list,
        adaptive_state: Dict[str, Any],
    ) -> Dict[str, Any]:
        """Common Grade-1 scaffold policy used by every activity family.

        The policy selects semantic commands only. Stable option IDs and their
        order are supplied by the item adapter, making decisions deterministic
        and auditable instead of using random.choice.
        """
        capabilities = set(getattr(telemetry, "supported_actions", None) or [])
        visible_ids = list(getattr(telemetry, "visible_option_ids", None) or [])
        correct_ids = list(getattr(telemetry, "correct_option_ids", None) or [])
        # Preserve at least two visible choices for Grade-1 tasks. With only
        # two choices, highlighting is less revealing than deleting the sole
        # distractor and leaving the answer by itself.
        minimum_visible = max(
            2,
            int(getattr(telemetry, "minimum_visible_options", 2) or 2),
        )

        state = adaptive_state.get("generic_scaffold_state", {
            "wrong_count": 0,
            "removed_option_ids": [],
        })
        state["wrong_count"] = int(state.get("wrong_count", 0)) + 1
        already_removed = set(state.get("removed_option_ids", []))

        # Preserve the adapter's ordered distractor priority. If it provides no
        # priority, stable lexical order guarantees repeatable research runs.
        candidates = [
            str(option_id) for option_id in available_incorrect_ids
            if str(option_id) not in already_removed
        ]
        if not candidates:
            candidates = sorted([
                str(option_id) for option_id in visible_ids
                if str(option_id) not in set(correct_ids) | already_removed
            ])

        commands = []
        reason_codes = [f"INCORRECT_ATTEMPT_{state['wrong_count']}"]
        scaffold_level = min(state["wrong_count"], 3)
        decision = "RETRY_CURRENT"

        effective_visible_ids = [
            str(option_id) for option_id in visible_ids
            if str(option_id) not in already_removed
        ]
        supports_remove = (
            "REMOVE_OPTION" in capabilities or "REMOVE_OPTIONS" in capabilities
        )
        supports_disable = (
            "DISABLE_OPTION" in capabilities or "DISABLE_OPTIONS" in capabilities
        )
        can_reduce = (
            supports_remove or supports_disable
        ) and len(effective_visible_ids) > minimum_visible

        # Keep the established Grade-1 escalation used by Activity 1:
        # remove at most two distractors, then guide attention by highlighting
        # instead of progressively deleting the entire answer pool.
        if state["wrong_count"] <= 2 and can_reduce and candidates:
            selected = candidates[0]
            already_removed.add(selected)
            command_type = "REMOVE_OPTIONS" if supports_remove else "DISABLE_OPTIONS"
            commands.append({
                "type": command_type,
                "target_option_ids": [selected],
                "reason_code": (
                    "REDUCE_DISTRACTOR_LOAD"
                    if supports_remove
                    else "LOCK_DISTRACTOR_PRESERVE_SPATIAL_LAYOUT"
                ),
            })
            if supports_remove:
                reason_codes.append("DISTRACTOR_REMOVED_DETERMINISTICALLY")
                decision = "SCAFFOLD_REMOVE_DISTRACTOR"
            else:
                reason_codes.append("DISTRACTOR_LOCKED_DETERMINISTICALLY")
                decision = "SCAFFOLD_DISABLE_DISTRACTOR"
        elif "REVEAL_FIRST_TOKEN" in capabilities and correct_ids:
            commands.append({
                "type": "REVEAL_FIRST_TOKEN",
                "target_option_ids": correct_ids[:1],
                "reason_code": "SEQUENCE_START_SUPPORT",
            })
            reason_codes.append("NEXT_REQUIRED_TOKEN_REVEALED")
            decision = "SCAFFOLD_REVEAL_FIRST_TOKEN"
        elif ("HIGHLIGHT_OPTION" in capabilities or
              "HIGHLIGHT_OPTIONS" in capabilities) and correct_ids:
            commands.append({
                "type": "HIGHLIGHT_OPTIONS",
                "target_option_ids": correct_ids,
                "style": "hint",
                "reason_code": "GUIDED_ATTENTION",
            })
            reason_codes.append("CORRECT_TARGET_GUIDED_WITH_HINT")
            decision = "SCAFFOLD_HIGHLIGHT_CORRECT"
        elif "REPLAY_INSTRUCTION" in capabilities:
            commands.append({
                "type": "REPLAY_INSTRUCTION",
                "target_option_ids": [],
                "reason_code": "REPEAT_PROMPT",
            })
            reason_codes.append("INSTRUCTION_REPLAY_REQUESTED")
            decision = "SCAFFOLD_REPLAY_INSTRUCTION"
        state["removed_option_ids"] = sorted(already_removed)
        adaptive_state["generic_scaffold_state"] = state
        adaptive_state["highest_scaffold_level_used"] = max(
            adaptive_state.get("highest_scaffold_level_used", 0),
            scaffold_level,
        )

        action_id = f"c4-{state['wrong_count']}-{len(already_removed)}"
        for index, command in enumerate(commands):
            command["action_id"] = f"{action_id}-{index}"

        remove_ids = []
        highlight = False
        for command in commands:
            if command["type"] == "REMOVE_OPTIONS":
                remove_ids.extend(command["target_option_ids"])
            elif command["type"] == "HIGHLIGHT_OPTIONS":
                highlight = True

        return {
            "action_id": action_id,
            "decision": decision,
            "scaffold_level": scaffold_level,
            "commands": commands,
            "reason_codes": reason_codes,
            "policy_version": "C4_CAPABILITY_POLICY_V2",
            # Temporary compatibility fields for old app builds.
            "remove_option_ids": remove_ids,
            "highlight_correct": highlight,
        }

    def _s2a1_get_support_action(
        self,
        telemetry: Any,
        options_count: int,
        struggle_score: int,
        available_incorrect_ids: list,
        adaptive_state: Dict[str, Any],
        round_idx: int
    ) -> Dict[str, Any]:
        
        # In S2A1, there are no pair_ids. We track the state per-round.
        # But R6 and R7 have 2 targets. If one target is found, it stays found.
        # The frontend provides context of what happened.
        
        pair_state = adaptive_state.get("current_pair_state", {
            "p1_wrong": 0,
            "p2_wrong": 0,
            "p3_wrong": 0,
            "scaffold_step": 0
        })
        
        pair_state["p1_wrong"] = pair_state.get("p1_wrong", 0) + 1
        step = pair_state.get("scaffold_step", 0)
        
        # R1-R2: 4 options, first wrong -> highlight
        # R3-R4: 4 options, wrong 1 -> remove distractor, wrong 2 -> highlight
        # R5-R7: 6 options, wrong 1 -> remove, wrong 2 -> remove, wrong 3 -> highlight
        
        if round_idx in [1, 2]:
            step = 3
        elif round_idx in [3, 4]:
            if pair_state["p1_wrong"] == 1: step = 1
            else: step = 3
        else: # 5, 6, 7
            if pair_state["p1_wrong"] == 1: step = 1
            elif pair_state["p1_wrong"] == 2: step = 2
            else: step = 3
            
        if pair_state.get("scaffold_step") == 3:
            step = 3
            
        pair_state["scaffold_step"] = step
        adaptive_state["current_pair_state"] = pair_state
        adaptive_state["highest_scaffold_level_used"] = max(adaptive_state.get("highest_scaffold_level_used", 0), step)

        decision = "RETRY_CURRENT"
        highlight = False
        remove_option_ids = []

        if step in [1, 2]:
            decision = "SCAFFOLD_REMOVE_DISTRACTOR"
            if available_incorrect_ids:
                remove_option_ids = [sorted(map(str, available_incorrect_ids))[0]]
        elif step >= 3:
            decision = "SCAFFOLD_HIGHLIGHT_CORRECT"
            highlight = True
            
        return {
            "decision": decision,
            "scaffold_level": step,
            "remove_option_ids": remove_option_ids,
            "highlight_correct": highlight
        }

    def _s2a4_get_support_action(
        self,
        telemetry: Any,
        options_count: int,
        struggle_score: int,
        available_incorrect_ids: list,
        adaptive_state: Dict[str, Any],
        round_idx: int
    ) -> Dict[str, Any]:
        
        pair_state = adaptive_state.get("current_pair_state", {
            "round": round_idx,
            "wrong_count": 0,
            "scaffold_locked": False
        })
        
        if pair_state.get("round") != round_idx:
            pair_state = {
                "round": round_idx,
                "wrong_count": 0,
                "scaffold_locked": False
            }
            
        pair_state["wrong_count"] += 1
        wrong_count = pair_state["wrong_count"]
        scaffold_locked = pair_state.get("scaffold_locked", False)
        
        phase = adaptive_state.get("next_phase", "CORE")
        
        if phase == "CORE":
            if wrong_count == 1:
                decision = "RETRY_CURRENT"
                remove_option_ids = []
                highlight = False
            else:
                decision = "SCAFFOLD_REMOVE_AND_HIGHLIGHT"
                highlight = True
                if not scaffold_locked:
                    remove_option_ids = available_incorrect_ids if available_incorrect_ids else []
                    pair_state["scaffold_locked"] = True
                else:
                    remove_option_ids = []
                    
        elif phase.startswith("REMEDIATION"):
            decision = "SCAFFOLD_REMOVE_AND_HIGHLIGHT"
            highlight = True
            if not scaffold_locked:
                remove_option_ids = available_incorrect_ids if available_incorrect_ids else []
                pair_state["scaffold_locked"] = True
            else:
                remove_option_ids = []
                
        elif phase.startswith("CONFIRMATION"):
            decision = "SCAFFOLD_REMOVE_AND_HIGHLIGHT"
            highlight = True
            if not scaffold_locked:
                if options_count >= 3:
                    remove_option_ids = available_incorrect_ids if available_incorrect_ids else []
                else:
                    remove_option_ids = []
                pair_state["scaffold_locked"] = True
            else:
                remove_option_ids = []
        else:
            decision = "RETRY_CURRENT"
            remove_option_ids = []
            highlight = False
            
        adaptive_state["current_pair_state"] = pair_state
        
        return {
            "decision": decision,
            "scaffold_level": 1,
            "remove_option_ids": remove_option_ids,
            "highlight_correct": highlight
        }


    def get_next_action(
        self,
        kc_mastery: float,
        theta: float,
        fatigue_score: float,
        current_activity: str,
        response_quality: str,
        struggle_band: str,
        current_difficulty_b: float,
        adaptive_state: Optional[Dict[str, Any]] = None,
        learner_profile: Optional[Dict[str, Any]] = None,
        current_item_id: str = "",
        has_reduced_remediation: bool = True,
        has_floor_remediation: bool = False,
    ) -> Dict[str, Any]:
        """
        Main progression policy engine.
        Supports both generic IRT movement and explicit S2A2 State Machine.
        """
        policy_reason = [f"RESPONSE_QUALITY: {response_quality}"]
        
        component4_scope = bool(
            re.fullmatch(r"[1-4]\.\d+", current_activity or "")
        )
        if fatigue_score > 0.80 and component4_scope:
            # C1 fatigue is observational evidence.  Ending a Grade-1 game in
            # the middle of a task looked like successful activity completion
            # in Flutter, so C4 records the signal and recommends a break only
            # after the activity instead of terminating progression.
            policy_reason.extend([
                "HIGH_FATIGUE_OBSERVED",
                "BREAK_RECOMMENDED_AFTER_ACTIVITY",
            ])
        elif fatigue_score > 0.80:
            policy_reason.append("HIGH_FATIGUE")
            return {
                "next_activity": current_activity,
                "next_item": "",
                "difficulty": 0.0,
                "target_difficulty": theta,
                "difficulty_direction": "TERMINATE",
                "scaffold_level": 0,
                "decision": "TERMINATE",
                "policy_reason": policy_reason,
                "confirmation_required": False
            }

        # Skills 1-4 share one bounded research protocol. Content and scaffold
        # rendering remain activity-specific. Assisted/failed work receives a
        # valid reduced-load V1 before original-level V2; a floor task skips
        # the invalid easy step and receives only one unseen V2 retry.
        if component4_scope:
            equivalent_action = equivalent_task_policy.get_next_action(
                activity_id=current_activity,
                current_item_id=current_item_id,
                response_quality=response_quality,
                current_b=current_difficulty_b,
                state=adaptive_state,
                policy_reason=policy_reason,
                has_reduced_remediation=has_reduced_remediation,
                has_floor_remediation=has_floor_remediation,
            )
            if equivalent_action is not None:
                return equivalent_action

        # Skill 1 Activity 1 uses the same explicit instructional phases as
        # the Skill 2 pilots. A learner who needed answer-revealing support
        # receives one easier visual-search task, then repeats the original
        # task without carried-over scaffolds before normal IRT selection can
        # continue.
        if current_activity == "1.1" and adaptive_state is not None:
            return self._s1a1_state_machine(
                response_quality,
                adaptive_state,
                current_difficulty_b,
                theta,
                policy_reason,
            )
            
        # S2A2 PILOT STATE MACHINE OVERRIDE
        if current_activity == "2.2" and adaptive_state is not None:
            return self._s2a2_state_machine(response_quality, adaptive_state, current_difficulty_b, policy_reason)
            
        # S2A1 STATE MACHINE
        if current_activity == "2.1" and adaptive_state is not None:
            return self._s2a1_state_machine(response_quality, adaptive_state, current_difficulty_b, policy_reason)
            
        # S2A3 STATE MACHINE
        if current_activity == "2.3" and adaptive_state is not None:
            return self._s2a3_state_machine(response_quality, adaptive_state, current_difficulty_b, policy_reason)
            
        # S2A4 STATE MACHINE
        if current_activity == "2.4" and adaptive_state is not None:
            return self._s2a4_state_machine(response_quality, adaptive_state, current_difficulty_b, policy_reason)
            
        # S2A5 STATE MACHINE
        if current_activity == "2.5" and adaptive_state is not None:
            return self._s2a5_state_machine(response_quality, adaptive_state, current_difficulty_b, policy_reason)
            
        # ... fallback to previous logic for other activities (kept minimal)
        decision = "CONTINUE"
        confirmation_required = False
        scaffold_level = 0
        
        if response_quality == "CLEAN_SUCCESS":
            difficulty_direction = "HARDER"
            target_b = theta + 0.5
            policy_reason.append("CLEAN_SUCCESS_ALLOWS_HARDER")
        elif response_quality == "STRUGGLED_SUCCESS":
            difficulty_direction = "MAINTAIN"
            target_b = current_difficulty_b
            confirmation_required = True
            policy_reason.append("STRUGGLED_SUCCESS_REQUIRES_CONFIRMATION")
        elif response_quality == "ASSISTED_SUCCESS":
            difficulty_direction = "MAINTAIN"
            target_b = current_difficulty_b
            confirmation_required = True
            policy_reason.append("ASSISTED_SUCCESS_REQUIRES_UNASSISTED_CONFIRMATION")
        else: # FAILED
            difficulty_direction = "EASIER"
            target_b = theta - 0.5
            policy_reason.append("FAILED_ATTEMPT_DECREASES_DIFFICULTY")
        
        next_activity = current_activity
        if kc_mastery >= 0.85 and struggle_band != "HIGH" and response_quality != "FAILED" and not confirmation_required:
            from curriculum_mapping import get_next_curriculum_activity
            next_act = get_next_curriculum_activity(current_activity)
            if next_act is None:
                decision = "CURRICULUM_COMPLETE"
                policy_reason.append("CURRICULUM_COMPLETE")
            else:
                next_activity = next_act
                target_b = theta
                policy_reason.append("KC_MASTERY_PROVISIONAL_GATE_PASSED")
            
        return {
            "next_activity": next_activity,
            "next_item": "", 
            "difficulty": 0.0,
            "target_difficulty": target_b,
            "difficulty_direction": difficulty_direction,
            "scaffold_level": scaffold_level,
            "decision": decision,
            "policy_reason": policy_reason,
            "confirmation_required": confirmation_required
        }

    def _s1a1_state_machine(
        self,
        response_quality: str,
        state: Dict[str, Any],
        current_b: float,
        theta: float,
        policy_reason: list,
    ) -> Dict[str, Any]:
        """Bounded remediation flow for the five hidden-search core tasks."""
        phase = state.get("next_phase", "CORE")
        current_item = state.get("expected_item_id", "S1A1R01")
        match = re.fullmatch(r"S1A1R(\d+)", current_item or "")
        current_round = int(match.group(1)) if match else 1
        original_item = state.get("remediation_origin_item_id")
        next_item = ""
        next_phase = "CORE"
        decision = "CONTINUE"
        target_b = current_b

        independent_success = response_quality in {
            "MASTERED", "INDEPENDENT_SUCCESS", "CLEAN_SUCCESS",
            "STRUGGLED_SUCCESS",
        }

        def next_unseen_core() -> str:
            administered = set(state.get("administered_item_ids", []))
            administered.add(current_item)
            for round_number in range(1, 6):
                candidate = f"S1A1R{round_number:02d}"
                if candidate not in administered:
                    return candidate
            return ""

        if phase == "CORE":
            if response_quality in {"ASSISTED_SUCCESS", "FAILED"}:
                original_item = current_item
                state["remediation_origin_item_id"] = original_item
                if current_round > 1:
                    next_item = f"S1A1R{current_round - 1:02d}"
                    next_phase = "REMEDIATION"
                    decision = "REMEDIATION"
                    target_b = current_b - 0.5
                    policy_reason.extend([
                        "S1A1_CORE_COMPLETED_WITH_SUPPORT",
                        "EASIER_REMEDIATION_SELECTED",
                    ])
                else:
                    next_item = original_item
                    next_phase = "CONFIRMATION"
                    decision = "CONFIRMATION"
                    policy_reason.extend([
                        "S1A1_EASIEST_CORE_COMPLETED_WITH_SUPPORT",
                        "EASIEST_ITEM_SKIPS_REMEDIATION",
                    ])
            else:
                if response_quality == "CLEAN_SUCCESS":
                    target_b = theta + 0.5
                    policy_reason.append(
                        "S1A1_CLEAN_SUCCESS_ALLOWS_HARDER"
                    )
                else:
                    target_b = current_b
                    policy_reason.append(
                        "S1A1_STRUGGLED_BUT_INDEPENDENT_MAINTAINS_DIFFICULTY"
                    )
                next_item = next_unseen_core()
                if next_item:
                    decision = "NEXT_CORE"
                    policy_reason.append("S1A1_SEQUENTIAL_CORE_ORDER")

        elif phase == "REMEDIATION":
            next_item = original_item or f"S1A1R{min(current_round + 1, 5):02d}"
            next_phase = "CONFIRMATION"
            decision = "CONFIRMATION"
            target_b = current_b + 0.5
            policy_reason.append(
                "S1A1_REMEDIATION_COMPLETE_REQUIRES_ORIGINAL_CONFIRMATION"
            )

        elif phase == "CONFIRMATION":
            if independent_success:
                state.pop("remediation_origin_item_id", None)
                state["remediation_cycle_count"] = 0
                policy_reason.append("S1A1_UNASSISTED_CONFIRMATION_PASSED")
                next_item = next_unseen_core()
                if next_item:
                    decision = "NEXT_CORE"
                    policy_reason.append("S1A1_SEQUENTIAL_CORE_ORDER")
            else:
                cycles = int(state.get("remediation_cycle_count", 0)) + 1
                state["remediation_cycle_count"] = cycles
                origin = original_item or current_item
                origin_match = re.fullmatch(r"S1A1R(\d+)", origin or "")
                origin_round = int(origin_match.group(1)) if origin_match else 1
                if cycles <= 1 and origin_round > 1:
                    next_item = f"S1A1R{origin_round - 1:02d}"
                    next_phase = "REMEDIATION"
                    decision = "REMEDIATION"
                    target_b = current_b - 0.5
                    policy_reason.append(
                        "S1A1_CONFIRMATION_NEEDS_ONE_MORE_REMEDIATION"
                    )
                else:
                    # Bound the loop for a Grade 1 learner. The item remains
                    # recorded as assisted evidence, but the child is not
                    # trapped indefinitely in the same two tasks.
                    state.pop("remediation_origin_item_id", None)
                    state["remediation_cycle_count"] = 0
                    policy_reason.append(
                        "S1A1_REMEDIATION_LOOP_LIMIT_REACHED"
                    )
                    next_item = next_unseen_core()
                    if next_item:
                        decision = "NEXT_CORE"
                        policy_reason.append("S1A1_SEQUENTIAL_CORE_ORDER")

        state["next_phase"] = next_phase
        if next_item:
            state["expected_item_id"] = next_item

        return {
            "next_activity": "1.1",
            "next_item": next_item,
            "difficulty": 0.0,
            "target_difficulty": target_b,
            "difficulty_direction": (
                "EASIER" if next_phase == "REMEDIATION" else "MAINTAIN"
            ),
            "scaffold_level": 0,
            "decision": decision,
            "policy_reason": policy_reason,
            "confirmation_required": next_phase == "CONFIRMATION",
            "next_phase": next_phase,
            "progress_core": 0,
            "progress_total": 5,
            "state_updates": state,
        }
        
    def _s2a2_state_machine(self, response_quality: str, state: Dict[str, Any], diff_b: float, policy_reason: list) -> Dict[str, Any]:
        """Strict logic for S2A2: Core 1 -> 5, with hidden variant insertions."""
        core_round = state.get("current_core_round", 1)
        phase = state.get("next_phase", "CORE")
        
        # Ensure core_completed is initialized
        core_completed = state.get("core_completed", {"1": False, "2": False, "3": False, "4": False, "5": False})
        state["core_completed"] = core_completed
        
        decision = "CONTINUE"
        next_phase = phase
        confirmation_required = False
        target_b = diff_b
        next_item = ""
        
        # Get the current round from the database instead of guessing
        current_core_str = str(core_round)
        
        if phase == "CORE":
            if response_quality == "CLEAN_SUCCESS":
                core_completed[current_core_str] = True
                policy_reason.append("CORE_TASK_CLEAN_SUCCESS")
                next_phase = "CORE"
            else:
                core_completed[current_core_str] = True
                policy_reason.append("CORE_COMPLETED_WITH_SUPPORT")
                if core_round == 1:
                    next_phase = "CONFIRMATION"
                    policy_reason.append("EASIEST_ITEM_SKIPS_REMEDIATION")
                else:
                    next_phase = "REMEDIATION"
                    target_b = diff_b - 0.5
                    policy_reason.append("EASIER_REMEDIATION_SELECTED")
                    
        elif phase == "REMEDIATION":
            next_phase = "CONFIRMATION"
            target_b = diff_b + 0.5
            confirmation_required = True
            policy_reason.append("SAME_DIFFICULTY_CONFIRMATION_SELECTED")
            
        elif phase == "CONFIRMATION":
            if response_quality == "CLEAN_SUCCESS":
                policy_reason.append("CONFIRMATION_PASSED")
                next_phase = "CORE"
            else:
                policy_reason.append("SECOND_CONFIRMATION_FAILED")
                next_phase = "CORE"
                
        # Advance the core round if we're back in the CORE phase
        if next_phase == "CORE":
            decision = "NEXT_CORE"
            # Find the next uncompleted core round
            for i in range(1, 6):
                if not core_completed.get(str(i), False):
                    core_round = i
                    break
            else:
                core_round = 6 # All completed
                
            if core_round <= 5:
                next_item = f"S2A2R0{core_round}"
        
        # Determine Exact Next Item
        if core_round > 5 and next_phase == "CORE":
            decision = "ACTIVITY_COMPLETE"
            policy_reason.append("ALL_CORE_TASKS_COMPLETE")
            next_phase = "COMPLETE"
            next_item = "S2A2R05" # dummy placeholder
        else:
            # Deterministic selection!
            if next_phase == "CORE":
                next_item = f"S2A2R{core_round:02d}"
            elif next_phase == "REMEDIATION":
                # Fallback to an easier core item variant for remediation
                remediation_round = max(1, core_round - 1)
                next_item = f"S2A2R{remediation_round:02d}V1"
            elif next_phase == "CONFIRMATION":
                # Select hidden same-difficulty variant
                next_item = f"S2A2R{core_round:02d}V1"
                
        # Update the state object so that main.py persists it!
        state["current_core_round"] = core_round
        state["next_phase"] = next_phase
        if next_item:
            state["expected_item_id"] = next_item
            
        return {
            "next_activity": "2.2",
            "next_item": next_item, 
            "difficulty": 0.0,
            "target_difficulty": target_b,
            "difficulty_direction": "MAINTAIN",
            "scaffold_level": 0,
            "decision": decision,
            "policy_reason": policy_reason,
            "confirmation_required": confirmation_required,
            "next_phase": next_phase,
            "progress_core": min(core_round, 5),
            "progress_total": 5,
            "state_updates": state
        }

    def _s2a1_state_machine(self, response_quality: str, state: Dict[str, Any], current_b: float, policy_reason: list) -> Dict[str, Any]:
        core_round = state.get("current_core_round", 1)
        phase = state.get("next_phase", "CORE")
        
        remediation_map = {
            2: "S2A1R01V1", 3: "S2A1R02V1", 4: "S2A1R03V1",
            5: "S2A1R04V1", 6: "S2A1R05V1", 7: "S2A1R06V1"
        }
        
        next_item = ""
        decision = "CONTINUE"
        
        if phase == "CORE":
            if response_quality in ["MASTERED", "CLEAN_SUCCESS", "INDEPENDENT_SUCCESS"]:
                policy_reason.append(f"S2A1_CORE_R{core_round}_PASSED")
                if core_round >= 7:
                    state["next_phase"] = "COMPLETE"
                    state["expected_item_id"] = "COMPLETE"
                    next_item = "COMPLETE"
                    decision = "ACTIVITY_COMPLETE"
                else:
                    state["current_core_round"] = core_round + 1
                    state["expected_item_id"] = f"S2A1R{core_round + 1:02d}"
                    next_item = state["expected_item_id"]
            else:
                policy_reason.append(f"S2A1_CORE_R{core_round}_STRUGGLED")
                state["next_phase"] = "REMEDIATION"
                rem_item = "S2A1R01V1" if core_round == 1 else remediation_map.get(core_round, "S2A1R01V1")
                state["expected_item_id"] = rem_item
                next_item = rem_item
                decision = "REMEDIATION"
                
        elif phase == "REMEDIATION":
            if response_quality in ["MASTERED", "CLEAN_SUCCESS", "INDEPENDENT_SUCCESS"]:
                policy_reason.append("S2A1_REMEDIATION_SUCCESS_PROCEED_TO_CONFIRMATION")
                state["next_phase"] = "CONFIRMATION"
                conf_item = f"S2A1R{core_round:02d}V1"
                state["expected_item_id"] = conf_item
                next_item = conf_item
            else:
                policy_reason.append("S2A1_REMEDIATION_FAILED_RETRY_CORE")
                state["next_phase"] = "CORE"
                state["expected_item_id"] = f"S2A1R{core_round:02d}"
                next_item = state["expected_item_id"]
                
        elif phase == "CONFIRMATION":
            policy_reason.append("S2A1_CONFIRMATION_COMPLETE_RETURN_TO_CORE")
            state["next_phase"] = "CORE"
            
            if response_quality in ["MASTERED", "CLEAN_SUCCESS", "INDEPENDENT_SUCCESS"]:
                if core_round >= 7:
                    state["next_phase"] = "COMPLETE"
                    state["expected_item_id"] = "COMPLETE"
                    next_item = "COMPLETE"
                    decision = "ACTIVITY_COMPLETE"
                else:
                    state["current_core_round"] = core_round + 1
                    state["expected_item_id"] = f"S2A1R{core_round + 1:02d}"
                    next_item = state["expected_item_id"]
            else:
                state["expected_item_id"] = f"S2A1R{core_round:02d}"
                next_item = state["expected_item_id"]
                
        elif phase == "COMPLETE":
            policy_reason.append("S2A1_ALREADY_COMPLETE")
            next_item = "COMPLETE"
            decision = "ACTIVITY_COMPLETE"
        else:
            state["expected_item_id"] = f"S2A1R{core_round:02d}"
            next_item = state["expected_item_id"]

        return {
            "next_activity": "2.1",
            "next_item": next_item, 
            "difficulty": 0.0,
            "target_difficulty": current_b,
            "difficulty_direction": "MAINTAIN",
            "scaffold_level": 0,
            "decision": decision,
            "policy_reason": policy_reason,
            "confirmation_required": False,
            "next_phase": state.get("next_phase", "CORE"),
            "progress_core": min(state.get("current_core_round", 1), 7),
            "progress_total": 7,
            "state_updates": state
        }

    def _s2a3_get_support_action(
        self,
        telemetry: Any,
        options_count: int,
        struggle_score: int,
        available_incorrect_ids: list,
        adaptive_state: Dict[str, Any],
        round_idx: int
    ) -> Dict[str, Any]:
        
        pair_state = adaptive_state.get("current_pair_state", {
            "p1_wrong": 0,
            "scaffold_step": 0
        })
        
        pair_state["p1_wrong"] = pair_state.get("p1_wrong", 0) + 1
        step = pair_state.get("scaffold_step", 0)
        
        # Scaffold sequence based on options_count
        if options_count <= 2:
            step = 3
        elif options_count == 3 or options_count == 4:
            if pair_state["p1_wrong"] == 1: step = 1
            else: step = 3
        elif options_count >= 5:
            if pair_state["p1_wrong"] == 1: step = 1
            elif pair_state["p1_wrong"] == 2: step = 2
            else: step = 3
            
        if pair_state.get("scaffold_step") == 3:
            step = 3
            
        pair_state["scaffold_step"] = step
        adaptive_state["current_pair_state"] = pair_state
        adaptive_state["highest_scaffold_level_used"] = max(adaptive_state.get("highest_scaffold_level_used", 0), step)

        decision = "RETRY_CURRENT"
        highlight = False
        remove_option_ids = []

        if step in [1, 2]:
            decision = "SCAFFOLD_REMOVE_DISTRACTOR"
            if available_incorrect_ids:
                remove_option_ids = [sorted(map(str, available_incorrect_ids))[0]]
        elif step >= 3:
            decision = "SCAFFOLD_HIGHLIGHT_CORRECT"
            highlight = True
            
        return {
            "decision": decision,
            "scaffold_level": step,
            "remove_option_ids": remove_option_ids,
            "highlight_correct": highlight
        }

    def _s2a3_state_machine(self, response_quality: str, state: Dict[str, Any], current_b: float, policy_reason: list) -> Dict[str, Any]:
        core_round = state.get("current_core_round", 1)
        phase = state.get("next_phase", "CORE")
        
        next_item = ""
        decision = "CONTINUE"
        
        is_success = response_quality in ["MASTERED", "CLEAN_SUCCESS", "INDEPENDENT_SUCCESS"]
        
        def advance_core():
            if core_round >= 5:
                state["next_phase"] = "COMPLETE"
                state["expected_item_id"] = "COMPLETE"
                return "COMPLETE", "ACTIVITY_COMPLETE"
            else:
                state["current_core_round"] = core_round + 1
                state["next_phase"] = "CORE"
                state["expected_item_id"] = f"S2A3R{core_round + 1:02d}"
                return state["expected_item_id"], "CONTINUE"

        if phase == "CORE":
            if is_success:
                policy_reason.append(f"S2A3_CORE_R{core_round}_PASSED")
                next_item, decision = advance_core()
            else:
                policy_reason.append(f"S2A3_CORE_R{core_round}_STRUGGLED")
                if core_round == 1:
                    state["next_phase"] = "CONFIRMATION"
                    next_item = "S2A3R01V1"
                else:
                    state["next_phase"] = "REMEDIATION"
                    next_item = f"S2A3R{core_round - 1:02d}V1"
                state["expected_item_id"] = next_item
                decision = "REMEDIATION"
                
        elif phase == "REMEDIATION":
            if is_success:
                policy_reason.append("S2A3_REMEDIATION_SUCCESS_PROCEED_TO_CONFIRMATION")
                state["next_phase"] = "CONFIRMATION"
                next_item = f"S2A3R{core_round:02d}V1"
            else:
                policy_reason.append("S2A3_REMEDIATION_FAILED_TRY_V2")
                state["next_phase"] = "REMEDIATION_V2"
                next_item = f"S2A3R{core_round - 1:02d}V2"
            state["expected_item_id"] = next_item
            
        elif phase == "REMEDIATION_V2":
            if is_success:
                policy_reason.append("S2A3_REMEDIATION_V2_SUCCESS_PROCEED_TO_CONFIRMATION")
                state["next_phase"] = "CONFIRMATION"
                next_item = f"S2A3R{core_round:02d}V1"
            else:
                policy_reason.append("S2A3_REMEDIATION_V2_FAILED_RETRY_CORE")
                state["next_phase"] = "CORE"
                next_item = f"S2A3R{core_round:02d}"
            state["expected_item_id"] = next_item

        elif phase == "CONFIRMATION":
            if is_success:
                policy_reason.append("S2A3_CONFIRMATION_COMPLETE_ADVANCE")
                next_item, decision = advance_core()
            else:
                policy_reason.append("S2A3_CONFIRMATION_FAILED_TRY_V2")
                state["next_phase"] = "CONFIRMATION_V2"
                next_item = f"S2A3R{core_round:02d}V2"
                state["expected_item_id"] = next_item

        elif phase == "CONFIRMATION_V2":
            if is_success:
                policy_reason.append("S2A3_CONFIRMATION_V2_COMPLETE_ADVANCE")
                next_item, decision = advance_core()
            else:
                policy_reason.append("S2A3_CONFIRMATION_V2_FAILED_RETRY_CORE")
                state["next_phase"] = "CORE"
                next_item = f"S2A3R{core_round:02d}"
                state["expected_item_id"] = next_item
                
        elif phase == "COMPLETE":
            policy_reason.append("S2A3_ALREADY_COMPLETE")
            next_item = "COMPLETE"
            decision = "ACTIVITY_COMPLETE"
        else:
            state["expected_item_id"] = f"S2A3R{core_round:02d}"
            next_item = state["expected_item_id"]

        return {
            "next_activity": "2.3",
            "next_item": next_item,
            "difficulty": current_b,
            "target_difficulty": current_b,
            "difficulty_direction": "MAINTAIN",
            "scaffold_level": 0,
            "decision": decision,
            "policy_reason": policy_reason,
            "confirmation_required": False,
            "next_phase": state.get("next_phase", "CORE"),
            "progress_core": min(state.get("current_core_round", 1), 5),
            "progress_total": 5,
            "state_updates": state
        }

    def _s2a4_state_machine(self, response_quality: str, state: Dict[str, Any], current_b: float, policy_reason: list) -> Dict[str, Any]:
        core_round = state.get("current_core_round", 1)
        phase = state.get("next_phase", "CORE")
        origin_core_round = state.get("origin_core_round", core_round)
        used_variants = state.get("used_variant_ids", [])
        
        next_item = ""
        decision = "CONTINUE"
        
        is_success = response_quality in ["MASTERED", "CLEAN_SUCCESS", "INDEPENDENT_SUCCESS"]
        
        def advance_core():
            if core_round >= 5:
                state["next_phase"] = "COMPLETE"
                state["expected_item_id"] = "COMPLETE"
                return "COMPLETE", "ACTIVITY_COMPLETE"
            else:
                next_round = core_round + 1
                state["current_core_round"] = next_round
                state["origin_core_round"] = next_round
                state["next_phase"] = "CORE"
                state["expected_item_id"] = f"S2A4R{next_round:02d}"
                return state["expected_item_id"], "CONTINUE"

        if phase == "COMPLETE":
            policy_reason.append("S2A4_ALREADY_COMPLETE")
            next_item = "COMPLETE"
            decision = "ACTIVITY_COMPLETE"
            
        elif phase == "CORE":
            if is_success:
                policy_reason.append(f"S2A4_CORE_R{core_round}_PASSED")
                next_item, decision = advance_core()
                state["expected_item_id"] = next_item
            else:
                policy_reason.append(f"S2A4_CORE_R{core_round}_STRUGGLED")
                state["origin_core_round"] = core_round
                new_phase = "CONFIRMATION_V1" if core_round == 1 else "REMEDIATION_V1"
                
                # Find next unused variant
                chain = ["REMEDIATION_V1", "REMEDIATION_V2", "CONFIRMATION_V1", "CONFIRMATION_V2"]
                start_idx = chain.index(new_phase)
                
                for p in chain[start_idx:]:
                    cand_item = f"S2A4R{core_round - 1:02d}{p[-2:]}" if p.startswith("REMEDIATION") else f"S2A4R{core_round:02d}{p[-2:]}"
                    if cand_item not in used_variants:
                        state["next_phase"] = p
                        state["expected_item_id"] = cand_item
                        used_variants.append(cand_item)
                        state["used_variant_ids"] = used_variants
                        decision = "REMEDIATION"
                        next_item = cand_item
                        break
                else:
                    policy_reason.append("S2A4_ALL_VARIANTS_EXHAUSTED_ADVANCE_TO_CORE")
                    next_item, decision = advance_core()
                    state["expected_item_id"] = next_item
                    
        else:
            # We are in a variant phase and just finished it
            if phase == "REMEDIATION_V1":
                if is_success:
                    policy_reason.append("S2A4_REMEDIATION_V1_SUCCESS_PROCEED_TO_CONFIRMATION")
                    new_phase = "CONFIRMATION_V1"
                else:
                    policy_reason.append("S2A4_REMEDIATION_V1_FAILED_TRY_V2")
                    new_phase = "REMEDIATION_V2"
            elif phase == "REMEDIATION_V2":
                if is_success:
                    policy_reason.append("S2A4_REMEDIATION_V2_SUCCESS_PROCEED_TO_CONFIRMATION")
                else:
                    policy_reason.append("S2A4_REMEDIATION_V2_FAILED_PROCEED_TO_CONFIRMATION_ANYWAY")
                new_phase = "CONFIRMATION_V1"
            elif phase == "CONFIRMATION_V1":
                if is_success:
                    policy_reason.append("S2A4_CONFIRMATION_V1_COMPLETE_ADVANCE")
                    next_item, decision = advance_core()
                    state["expected_item_id"] = next_item
                    new_phase = None
                else:
                    policy_reason.append("S2A4_CONFIRMATION_V1_FAILED_TRY_V2")
                    new_phase = "CONFIRMATION_V2"
            elif phase == "CONFIRMATION_V2":
                if is_success:
                    policy_reason.append("S2A4_CONFIRMATION_V2_COMPLETE_ADVANCE")
                else:
                    policy_reason.append("S2A4_CONFIRMATION_V2_FAILED_ADVANCE_ANYWAY")
                next_item, decision = advance_core()
                state["expected_item_id"] = next_item
                new_phase = None
                
            if new_phase:
                chain = ["REMEDIATION_V1", "REMEDIATION_V2", "CONFIRMATION_V1", "CONFIRMATION_V2"]
                start_idx = chain.index(new_phase)
                
                for p in chain[start_idx:]:
                    cand_item = f"S2A4R{origin_core_round - 1:02d}{p[-2:]}" if p.startswith("REMEDIATION") else f"S2A4R{origin_core_round:02d}{p[-2:]}"
                    if cand_item not in used_variants:
                        state["next_phase"] = p
                        state["expected_item_id"] = cand_item
                        used_variants.append(cand_item)
                        state["used_variant_ids"] = used_variants
                        decision = "CONTINUE"
                        next_item = cand_item
                        break
                else:
                    policy_reason.append("S2A4_ALL_VARIANTS_EXHAUSTED_ADVANCE_TO_CORE")
                    next_item, decision = advance_core()
                    state["expected_item_id"] = next_item

        return {
            "next_activity": "2.4",
            "next_item": next_item,
            "difficulty": current_b,
            "target_difficulty": current_b,
            "difficulty_direction": "MAINTAIN",
            "scaffold_level": 0,
            "decision": decision,
            "policy_reason": policy_reason,
            "confirmation_required": False,
            "next_phase": state.get("next_phase", "CORE"),
            "progress_core": min(state.get("current_core_round", 1), 5),
            "progress_total": 5,
            "state_updates": state
        }



    def _s2a5_state_machine(self, response_quality: str, state: Dict[str, Any], current_b: float, policy_reason: list) -> Dict[str, Any]:
        core_round = state.get("current_core_round", 1)
        phase = state.get("next_phase", "CORE")
        origin_core_round = state.get("origin_core_round", core_round)
        used_variants = state.get("used_variant_ids", [])
        
        next_item = ""
        decision = "CONTINUE"
        
        is_success = response_quality in ["MASTERED", "CLEAN_SUCCESS", "INDEPENDENT_SUCCESS", "STRUGGLED_SUCCESS"]
        
        def advance_core():
            if core_round >= 5:
                state["next_phase"] = "COMPLETE"
                state["expected_item_id"] = "COMPLETE"
                return "COMPLETE", "ACTIVITY_COMPLETE"
            else:
                next_round = core_round + 1
                state["current_core_round"] = next_round
                state["origin_core_round"] = next_round
                state["next_phase"] = "CORE"
                state["expected_item_id"] = f"S2A5R{next_round:02d}"
                return state["expected_item_id"], "CONTINUE"

        if phase == "COMPLETE":
            policy_reason.append("S2A5_ALREADY_COMPLETE")
            next_item = "COMPLETE"
            decision = "ACTIVITY_COMPLETE"
            
        elif phase == "CORE":
            if is_success:
                policy_reason.append(f"S2A5_CORE_R{core_round}_PASSED")
                next_item, decision = advance_core()
                state["expected_item_id"] = next_item
            else:
                policy_reason.append(f"S2A5_CORE_R{core_round}_STRUGGLED")
                state["origin_core_round"] = core_round
                new_phase = "CONFIRMATION_V1" if core_round == 1 else "REMEDIATION_V1"
                
                # Find next unused variant
                chain = ["REMEDIATION_V1", "REMEDIATION_V2", "CONFIRMATION_V1", "CONFIRMATION_V2"]
                start_idx = chain.index(new_phase)
                
                for p in chain[start_idx:]:
                    cand_item = f"S2A5R{core_round - 1:02d}{p[-2:]}" if p.startswith("REMEDIATION") else f"S2A5R{core_round:02d}{p[-2:]}"
                    if cand_item not in used_variants:
                        state["next_phase"] = p
                        state["expected_item_id"] = cand_item
                        used_variants.append(cand_item)
                        state["used_variant_ids"] = used_variants
                        decision = "REMEDIATION"
                        next_item = cand_item
                        break
                else:
                    policy_reason.append("S2A5_ALL_VARIANTS_EXHAUSTED_ADVANCE_TO_CORE")
                    next_item, decision = advance_core()
                    state["expected_item_id"] = next_item
                    
        else:
            # We are in a variant phase and just finished it
            if phase == "REMEDIATION_V1":
                if is_success:
                    policy_reason.append("S2A5_REMEDIATION_V1_SUCCESS_PROCEED_TO_CONFIRMATION")
                    new_phase = "CONFIRMATION_V1"
                else:
                    policy_reason.append("S2A5_REMEDIATION_V1_FAILED_TRY_V2")
                    new_phase = "REMEDIATION_V2"
            elif phase == "REMEDIATION_V2":
                if is_success:
                    policy_reason.append("S2A5_REMEDIATION_V2_SUCCESS_PROCEED_TO_CONFIRMATION")
                else:
                    policy_reason.append("S2A5_REMEDIATION_V2_FAILED_PROCEED_TO_CONFIRMATION_ANYWAY")
                new_phase = "CONFIRMATION_V1"
            elif phase == "CONFIRMATION_V1":
                if is_success:
                    policy_reason.append("S2A5_CONFIRMATION_V1_COMPLETE_ADVANCE")
                    next_item, decision = advance_core()
                    state["expected_item_id"] = next_item
                    new_phase = None
                else:
                    policy_reason.append("S2A5_CONFIRMATION_V1_FAILED_TRY_V2")
                    new_phase = "CONFIRMATION_V2"
            elif phase == "CONFIRMATION_V2":
                if is_success:
                    policy_reason.append("S2A5_CONFIRMATION_V2_COMPLETE_ADVANCE")
                else:
                    policy_reason.append("S2A5_CONFIRMATION_V2_FAILED_ADVANCE_ANYWAY")
                next_item, decision = advance_core()
                state["expected_item_id"] = next_item
                new_phase = None
                
            if new_phase:
                chain = ["REMEDIATION_V1", "REMEDIATION_V2", "CONFIRMATION_V1", "CONFIRMATION_V2"]
                start_idx = chain.index(new_phase)
                
                for p in chain[start_idx:]:
                    cand_item = f"S2A5R{origin_core_round - 1:02d}{p[-2:]}" if p.startswith("REMEDIATION") else f"S2A5R{origin_core_round:02d}{p[-2:]}"
                    if cand_item not in used_variants:
                        state["next_phase"] = p
                        state["expected_item_id"] = cand_item
                        used_variants.append(cand_item)
                        state["used_variant_ids"] = used_variants
                        decision = "CONTINUE"
                        next_item = cand_item
                        break
                else:
                    policy_reason.append("S2A5_ALL_VARIANTS_EXHAUSTED_ADVANCE_TO_CORE")
                    next_item, decision = advance_core()
                    state["expected_item_id"] = next_item

        return {
            "next_activity": "2.5",
            "next_item": next_item,
            "difficulty": current_b,
            "target_difficulty": current_b,
            "difficulty_direction": "MAINTAIN",
            "scaffold_level": 0,
            "decision": decision,
            "policy_reason": policy_reason,
            "confirmation_required": False,
            "next_phase": state.get("next_phase", "CORE"),
            "progress_core": min(state.get("current_core_round", 1), 5),
            "progress_total": 5,
            "state_updates": state
        }

    def _s2a5_get_support_action(
        self,
        telemetry: Any,
        options_count: int,
        struggle_score: int,
        available_incorrect_ids: list,
        adaptive_state: Dict[str, Any],
        round_idx: int
    ) -> Dict[str, Any]:
        
        pair_state = adaptive_state.get("current_pair_state", {
            "round": round_idx,
            "wrong_count": 0,
            "scaffold_locked": False
        })
        
        if pair_state.get("round") != round_idx:
            pair_state = {
                "round": round_idx,
                "wrong_count": 0,
                "scaffold_locked": False
            }
            
        pair_state["wrong_count"] += 1
        wrong_count = pair_state["wrong_count"]
        scaffold_locked = pair_state.get("scaffold_locked", False)
        
        phase = adaptive_state.get("next_phase", "CORE")
        
        if phase == "CORE":
            if wrong_count == 1:
                decision = "RETRY_CURRENT"
                remove_option_ids = []
                highlight = False
            else:
                decision = "SCAFFOLD_REMOVE_AND_HIGHLIGHT"
                highlight = True
                if not scaffold_locked:
                    remove_option_ids = [available_incorrect_ids[0]] if available_incorrect_ids else []
                    pair_state["scaffold_locked"] = True
                else:
                    remove_option_ids = []
                    
        elif phase.startswith("REMEDIATION"):
            decision = "SCAFFOLD_REMOVE_AND_HIGHLIGHT"
            highlight = True
            if not scaffold_locked:
                remove_option_ids = [available_incorrect_ids[0]] if available_incorrect_ids else []
                pair_state["scaffold_locked"] = True
            else:
                remove_option_ids = []
                
        elif phase.startswith("CONFIRMATION"):
            decision = "SCAFFOLD_REMOVE_AND_HIGHLIGHT"
            highlight = True
            if not scaffold_locked:
                remove_option_ids = [available_incorrect_ids[0]] if available_incorrect_ids else []
                pair_state["scaffold_locked"] = True
            else:
                remove_option_ids = []
        else:
            decision = "RETRY_CURRENT"
            remove_option_ids = []
            highlight = False
            
        adaptive_state["current_pair_state"] = pair_state
        
        level = 1 if (highlight or remove_option_ids or scaffold_locked) else 0
        return {
            "decision": decision,
            "scaffold_level": level,
            "remove_option_ids": remove_option_ids,
            "highlight_correct": highlight
        }

policy_engine = PolicyEngine()
