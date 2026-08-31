class BKTEngine:
    def __init__(self):
        # Baseline priors for Sinhala Abugida script KCs
        # Format: "target_kc": (P(L0), P(T), P(G), P(S))
        # P(L0) = Initial probability of knowing the skill
        # P(T) = Probability of learning the skill (Transition)
        # P(G) = Probability of guessing correctly without knowing
        # P(S) = Probability of slipping (answering incorrectly despite knowing)
        # PROVISIONAL / THEORY-INFORMED PROTOTYPE PARAMETERS
        # These are not empirically fitted parameters.
        proto_priors = (0.3, 0.1, 0.2, 0.1)
        
        self.priors = {
            # Legacy KCs
            "KC_mirror_consonants": (0.3, 0.1, 0.2, 0.1),
            "KC_vowel_diacritics": (0.4, 0.15, 0.25, 0.1),
            "KC_conjunct_consonants": (0.2, 0.05, 0.1, 0.15),
            
            # Official KCs - Provisional mapping
            "KC_VISUAL_IDENTIFICATION": proto_priors,
            "KC_VISUAL_MATCHING": proto_priors,
            "KC_VISUAL_CATEGORIZATION": proto_priors,
            "KC_VISUAL_PATTERN": proto_priors,
            "KC_VISUAL_MEMORY": proto_priors,
            "KC_LETTER_IDENTIFICATION": proto_priors,
            "KC_LETTER_MATCHING": proto_priors,
            "KC_PHONEME_LETTER_MAPPING": proto_priors,
            "KC_LETTER_DECODING": proto_priors,
            "KC_LETTER_MEMORY": proto_priors,
            "KC_WORD_RECOGNITION": proto_priors,
            "KC_WORD_FORMATION": proto_priors,
            "KC_AUDITORY_WORD_RECOGNITION": proto_priors,
            "KC_WORD_COMPLETION": proto_priors,
            "KC_WORD_SEQUENCING": proto_priors,
            "KC_SENTENCE_COMPREHENSION": proto_priors,
            "KC_SENTENCE_COMPLETION": proto_priors,
            "KC_AUDITORY_SENTENCE_RECOGNITION": proto_priors,
            "KC_SENTENCE_SEQUENCING": proto_priors,
            
            "default": proto_priors
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
        
        p_clamped = min(max(p_new, 0.0), 1.0)
        return round(p_clamped, 4)

bkt_engine = BKTEngine()
