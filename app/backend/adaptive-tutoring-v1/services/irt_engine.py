import math
from typing import List

class IRTEngine:
    def __init__(self, se_threshold: float = 0.30):
        self.se_threshold = se_threshold

    def calculate_probability(self, theta: float, b_i: float) -> float:
        """
        Calculates probability of correct response using 1-Parameter Logistic Model (Rasch).
        P_i(θ) = 1 / (1 + e^-(θ - b_i))
        """
        try:
            return 1.0 / (1.0 + math.exp(-(theta - b_i)))
        except OverflowError:
            return 0.0 if (theta - b_i) < 0 else 1.0

    def calculate_standard_error(self, theta: float, item_difficulties: List[float]) -> float:
        """
        Calculates Standard Error of the ability estimate θ.
        SE(θ) = 1 / sqrt(I(θ)) where I(θ) is the test information.
        I(θ) = sum(P_i * (1 - P_i))
        """
        info_sum = 0.0
        for b_i in item_difficulties:
            p_i = self.calculate_probability(theta, b_i)
            info_sum += p_i * (1.0 - p_i)
            
        if info_sum == 0:
            return float('inf') # Infinite SE if no information
            
        return 1.0 / math.sqrt(info_sum)

    def should_terminate_session(self, theta: float, item_difficulties: List[float]) -> bool:
        """
        Checks standard error stopping rules for fatigue mitigation.
        Triggers if SE < 0.30.
        """
        if not item_difficulties:
            return False
            
        se = self.calculate_standard_error(theta, item_difficulties)
        return se < self.se_threshold

irt_engine = IRTEngine()
