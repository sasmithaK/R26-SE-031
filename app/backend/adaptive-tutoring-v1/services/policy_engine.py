from typing import Dict, Any, Optional, Tuple

def get_activity_latency_baseline(activity_id: str) -> int:
    """Provisional baselines in ms"""
    baselines = {
        "2.1": 4000,
        "2.2": 8000,
        "2.3": 6000,
        "2.4": 8000,
        "2.5": 5000,
    }
    return baselines.get(activity_id, 5000)

class PolicyEngine:
    def classify_response(self, is_correct: bool, telemetry: Any, activity_id: str) -> Tuple[str, int, str, float]:
        if not telemetry:
            return "CLEAN_SUCCESS" if is_correct else "FAILED", 0, "LOW", 1.0
            
        baseline = get_activity_latency_baseline(activity_id)
        latency_ratio = telemetry.total_round_latency_ms / baseline if baseline > 0 else 1.0
        
        score = 0
        if telemetry.misclick_count == 1: score += 1
        elif telemetry.misclick_count >= 2: score += 2
        
        if telemetry.hesitation_count == 1: score += 1
        elif telemetry.hesitation_count >= 2: score += 2
        
        if latency_ratio > 2.0: score += 2
        elif latency_ratio > 1.25: score += 1
        
        if telemetry.audio_replay_count >= 1: score += 1
            
        if score >= 4: band = "HIGH"
        elif score >= 2: band = "MODERATE"
        else: band = "LOW"
        
        if not is_correct:
            qual = "FAILED"
        elif telemetry.scaffold_level_used > 0:
            qual = "ASSISTED_SUCCESS"
        elif telemetry.misclick_count == 0 and telemetry.hesitation_count <= 1 and latency_ratio <= 1.25:
            qual = "CLEAN_SUCCESS"
        else:
            qual = "STRUGGLED_SUCCESS"
            
        return qual, score, band, latency_ratio

    def get_support_action(
        self,
        telemetry: Any,
        options_count: int,
        struggle_score: int,
        available_incorrect_ids: list,
        s2a2_state: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Calculates the scaffold escalation based sequentially on the current pair's attempt count.
        Called when phase = "ATTEMPT".
        """
        current_pair_id = getattr(telemetry, "current_pair_id", None)
        
        # Load pair state
        pair_state = s2a2_state.get("current_pair_state", {
            "pair_id": None,
            "wrong_count": 0,
            "scaffold_step": 0
        })
        
        # Reset rule: if the pair ID changed, start fresh!
        if current_pair_id and pair_state["pair_id"] != current_pair_id:
            pair_state = {
                "pair_id": current_pair_id,
                "wrong_count": 0,
                "scaffold_step": 0
            }
            
        pair_state["wrong_count"] += 1
        
        step = pair_state["scaffold_step"]
        
        if options_count <= 2:
            # Task 1 & 2: 1st wrong -> highlight
            step = 3
        elif options_count == 3:
            # Task 3: 1st wrong -> remove 1 (step 1), next wrong -> highlight (step 3)
            if pair_state["wrong_count"] == 1:
                step = 1
            else:
                step = 3
        elif options_count == 4:
            # Task 4: 1st wrong -> remove 1, next wrong -> highlight
            if pair_state["wrong_count"] == 1:
                step = 1
            else:
                step = 3
        elif options_count >= 5:
            # Task 5: 1st wrong -> remove 1, 2nd wrong -> remove 2nd, 3rd wrong -> highlight
            if pair_state["wrong_count"] == 1:
                step = 1
            elif pair_state["wrong_count"] == 2:
                step = 2
            else:
                step = 3
                
        # Persistence: If we previously reached highlight for this pair, keep it there!
        if pair_state["scaffold_step"] == 3:
            step = 3
            
        pair_state["scaffold_step"] = step
        s2a2_state["current_pair_state"] = pair_state
        
        # We also maintain highest_scaffold_level_used for broader logging compatibility
        s2a2_state["highest_scaffold_level_used"] = step

        decision = "RETRY_CURRENT"
        highlight = False
        remove_option_ids = []

        if step in [1, 2]:
            decision = "SCAFFOLD_REMOVE_DISTRACTOR"
            if available_incorrect_ids:
                import random
                # We always remove exactly 1 option per step, because available_incorrect_ids
                # already excludes previously removed options!
                remove_option_ids = [random.choice(available_incorrect_ids)]
        elif step == 3:
            decision = "SCAFFOLD_HIGHLIGHT_CORRECT"
            highlight = True
            
        return {
            "decision": decision,
            "scaffold_level": step,
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
        s2a2_state: Optional[Dict[str, Any]] = None,
        learner_profile: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """
        Main progression policy engine.
        Supports both generic IRT movement and explicit S2A2 State Machine.
        """
        policy_reason = [f"RESPONSE_QUALITY: {response_quality}"]
        
        if fatigue_score > 0.80:
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
            
        # S2A2 PILOT STATE MACHINE OVERRIDE
        if current_activity == "2.2" and s2a2_state:
            return self._s2a2_state_machine(response_quality, s2a2_state, current_difficulty_b, policy_reason)
            
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

policy_engine = PolicyEngine()
