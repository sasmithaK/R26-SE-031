class BKTEngine:
    def __init__(self):
        # Baseline priors for Sinhala Abugida script KCs
        # Format: "target_kc": (P(L0), P(T), P(G), P(S))
        # P(L0) = Initial probability of knowing the skill
        # P(T) = Probability of learning the skill (Transition)
        # P(G) = Probability of guessing correctly without knowing
        # P(S) = Probability of slipping (answering incorrectly despite knowing)
        self.priors = {
            "KC_mirror_consonants": (0.3, 0.1, 0.2, 0.1),
            "KC_vowel_diacritics": (0.4, 0.15, 0.25, 0.1),
            "KC_conjunct_consonants": (0.2, 0.05, 0.1, 0.15),
            "default": (0.3, 0.1, 0.2, 0.1)
        }

    def update_knowledge_state(self, current_prob: float, target_kc: str, is_correct: bool) -> float:
        """
        Updates the probability that the student has mastered the knowledge component
        using the standard Bayesian Knowledge Tracing (BKT) equations.
        """
        priors = self.priors.get(target_kc, self.priors["default"])
        p_l_0, p_t, p_g, p_s = priors
        
        # Calculate P(L_t-1)
        p_prev = current_prob
        
        # Calculate P(L_t | obs)
        if is_correct:
            # P(L_t | Correct) = (P_prev * (1 - P(S))) / (P_prev * (1 - P(S)) + (1 - P_prev) * P(G))
            numerator = p_prev * (1 - p_s)
            denominator = numerator + (1 - p_prev) * p_g
            p_obs = numerator / denominator if denominator > 0 else 0
        else:
            # P(L_t | Incorrect) = (P_prev * P(S)) / (P_prev * P(S) + (1 - P_prev) * (1 - P(G)))
            numerator = p_prev * p_s
            denominator = numerator + (1 - p_prev) * (1 - p_g)
            p_obs = numerator / denominator if denominator > 0 else 0
            
        # Add transition probability (learning from the current step)
        # P(L_t) = P(L_t | obs) + (1 - P(L_t | obs)) * P(T)
        p_new = p_obs + (1 - p_obs) * p_t
        
        return round(p_new, 4)

bkt_engine = BKTEngine()
