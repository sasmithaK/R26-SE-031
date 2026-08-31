from typing import List, Dict, Any, Optional

class ItemSelector:
    def select_next_item(
        self,
        current_item_id: str,
        current_activity: str,
        target_difficulty: float,
        candidates: List[Dict[str, Any]],
        confirmation_required: bool = False,
        forced_item_id: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Adaptive item selection using provisional IRT difficulty parameters,
        difficulty buckets, and confirmation preference.
        """
        if forced_item_id:
            return {
                "selected_item": forced_item_id,
                "selected_difficulty": target_difficulty,
                "target_difficulty": target_difficulty,
                "selection_reason": "DETERMINISTIC_CORE_MACHINE_OVERRIDE"
            }
            
        if not candidates:
            return {
                "selected_item": current_item_id if current_item_id else "act_1_round1", # Safe fallback
                "selected_difficulty": 0.0,
                "target_difficulty": target_difficulty,
                "selection_reason": "NO_CANDIDATE_FALLBACK"
            }
            
        # 1. Filter valid candidates
        valid_candidates = [c for c in candidates if c.get("activity_id") == current_activity]
        
        if not valid_candidates:
            return {
                "selected_item": current_item_id if current_item_id else "act_1_round1",
                "selected_difficulty": 0.0,
                "target_difficulty": target_difficulty,
                "selection_reason": "NO_CANDIDATE_FALLBACK_FOR_ACTIVITY"
            }

        def get_bucket(diff: float) -> str:
            if diff <= -1.0: return "VERY_EASY"
            elif diff <= -0.25: return "EASY"
            elif diff <= 0.25: return "MEDIUM"
            elif diff <= 1.0: return "HARD"
            return "VERY_HARD"

        # If confirmation is required, prioritize items with role='CONFIRMATION' in the same bucket
        if confirmation_required:
            target_bucket = get_bucket(target_difficulty)
            conf_candidates = [c for c in valid_candidates if c.get("item_role") == "CONFIRMATION" and get_bucket(c.get("difficulty_b", 0.0)) == target_bucket]
            
            if conf_candidates:
                # Exclude current item if alternatives exist
                if len(conf_candidates) > 1:
                    conf_candidates = [c for c in conf_candidates if c.get("item_id") != current_item_id]
                best = sorted(conf_candidates, key=lambda c: abs(c.get("difficulty_b", 0.0) - target_difficulty))[0]
                return {
                    "selected_item": best.get("item_id"),
                    "selected_difficulty": best.get("difficulty_b", 0.0),
                    "target_difficulty": target_difficulty,
                    "selection_reason": "CONFIRMATION_ITEM_SELECTED"
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
            
        def sort_key(c: Dict[str, Any]):
            diff_dist = abs(c.get("difficulty_b", 0.0) - target_difficulty)
            seq_num = c.get("round", 0) 
            return (diff_dist, seq_num)
            
        sorted_candidates = sorted(valid_candidates, key=sort_key)
        best_candidate = sorted_candidates[0]
        
        reason = "IRT_DIFFICULTY_MATCH"
        if best_candidate.get("item_id") == current_item_id:
            reason = "BEST_MATCH_BUT_REPEATED_DUE_TO_NO_ALTERNATIVES"
        elif confirmation_required:
            reason = "CONFIRMATION_REQUIRED_BUT_NO_CONFIRMATION_ITEMS_FOUND_FALLBACK"
            
        return {
            "selected_item": best_candidate.get("item_id"),
            "selected_difficulty": best_candidate.get("difficulty_b", 0.0),
            "target_difficulty": target_difficulty,
            "selection_reason": reason
        }

item_selector = ItemSelector()
