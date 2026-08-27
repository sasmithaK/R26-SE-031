from typing import Dict, Any

class PolicyEngine:
    def determine_scaffolding(self, target_kc: str, current_prob: float, dyslexia_risk_profile: Dict[str, float]) -> Dict[str, bool]:
        """
        Zone of Proximal Development (ZPD) orchestrator.
        Returns UI scaffolding flags based on KC mastery and dyslexia risk profile.
        """
        ui_scaffolding = {
            "enable_high_contrast": False,
            "slow_playback": False,
            "highlight_diacritics": False,
            "show_visual_cues": False
        }
        
        # Risk thresholds
        visual_orthographic_risk = dyslexia_risk_profile.get("visual_orthographic", 0.0)
        phonological_risk = dyslexia_risk_profile.get("phonological", 0.0)
        
        # Scaffolding policy
        if current_prob < 0.40:
            if visual_orthographic_risk > 0.5:
                ui_scaffolding["enable_high_contrast"] = True
                ui_scaffolding["show_visual_cues"] = True
                if target_kc == "KC_vowel_diacritics":
                    ui_scaffolding["highlight_diacritics"] = True
                    
            if phonological_risk > 0.5:
                ui_scaffolding["slow_playback"] = True
                
        return ui_scaffolding

policy_engine = PolicyEngine()
