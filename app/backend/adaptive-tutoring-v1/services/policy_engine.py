from typing import Dict, Any

class PolicyEngine:
    def get_next_action(self, kc_mastery: float, fatigue_score: float, current_activity: str, learner_profile: Dict[str, float] = None) -> Dict[str, Any]:
        """
        Adaptive policy combining BKT mastery and fatigue state.
        Returns next_activity, next_item, difficulty, scaffold, and decision.
        """
        decision = "CONTINUE"
        
        # 1. Fatigue check -> Terminate if too fatigued
        if fatigue_score > 0.8:
            decision = "TERMINATE"
            
        # 2. Mastery logic -> Advance if mastered
        next_activity = current_activity
        target_difficulty_b = 0.0 # default medium
        
        if kc_mastery > 0.85:
            # High mastery -> Hard items
            target_difficulty_b = 1.0
        elif kc_mastery < 0.3:
            # Low mastery -> Easy items
            target_difficulty_b = -1.0
            
        # 3. Scaffolding level (0 to 3) based on learner profile
        scaffold_level = 0
        if learner_profile:
            vo_risk = learner_profile.get("Visual-Orthographic Learning Pattern", 0.0)
            if kc_mastery < 0.5 and vo_risk > 0.5:
                scaffold_level = 1
        
        return {
            "next_activity": next_activity,
            "target_difficulty_b": target_difficulty_b,
            "scaffold_level": scaffold_level,
            "decision": decision
        }

policy_engine = PolicyEngine()
