class BKTEngine:
    # Never persist an absorbing probability of exactly 0 or 1. A 0.99 ceiling
    # still represents very strong mastery, while allowing later independent
    # evidence to correct an over-confident (including legacy 1.0) state.
    MASTERY_FLOOR = 0.01
    MASTERY_CEILING = 0.99

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
        self.model_metadata = {}

    def apply_calibrated_parameters(
        self,
        kc: str,
        parameters: dict,
        *,
        model_version: str = "bkt_calibrated_unknown_version",
        calibrated_at=None,
    ) -> bool:
        """Activate a validated registry record without changing call sites."""
        try:
            values = tuple(float(parameters[key]) for key in (
                "p_initial", "p_transition", "p_guess", "p_slip"
            ))
        except (KeyError, TypeError, ValueError):
            return False
        if not all(0.0 < value < 1.0 for value in values):
            return False
        if values[2] + values[3] >= 0.5:
            return False
        self.priors[kc] = values
        self.model_metadata[kc] = {
            "model_version": model_version,
            "calibration_status": "empirically_calibrated",
            "calibrated_at": calibrated_at,
        }
        return True

    def get_model_evidence(self, kc: str) -> dict:
        metadata = self.model_metadata.get(kc, {})
        parameters = self.priors.get(kc, self.priors["default"])
        return {
            "model_version": metadata.get(
                "model_version", "bkt_theory_provisional_v1"
            ),
            "calibration_status": metadata.get(
                "calibration_status", "provisional"
            ),
            "calibrated_at": metadata.get("calibrated_at"),
            "parameters": {
                "p_initial": parameters[0],
                "p_transition": parameters[1],
                "p_guess": parameters[2],
                "p_slip": parameters[3],
            },
        }

    def update_knowledge_state(self, current_prob: float, target_kc: str, is_correct: bool) -> float:
        """
        Updates the probability that the student has mastered the knowledge component
        using the standard Bayesian Knowledge Tracing (BKT) equations.
        """
        priors = self.priors.get(target_kc, self.priors["default"])
        p_l_0, p_t, p_g, p_s = priors
        
        # Calculate P(L_t-1). Clamp legacy saturated values before applying
        # Bayes so an incorrect independent attempt can lower mastery again.
        p_prev = min(
            max(float(current_prob), self.MASTERY_FLOOR),
            self.MASTERY_CEILING,
        )
        
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
        
        # Keep full precision internally. Rounding every update previously
        # turned high probabilities into the absorbing value 1.0.
        return min(
            max(p_new, self.MASTERY_FLOOR),
            self.MASTERY_CEILING,
        )

bkt_engine = BKTEngine()
