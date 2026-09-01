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

    def update_theta(self, theta_old: float, is_correct: bool, b_i: float, learning_rate: float = 0.5) -> float:
        """
        Online update of ability estimate θ using Stochastic Gradient Descent step.
        """
        p_i = self.calculate_probability(theta_old, b_i)
        response = 1.0 if is_correct else 0.0
        
        # Simple SGD update: theta_new = theta_old + alpha * (Response - Probability)
        theta_new = theta_old + learning_rate * (response - p_i)
        
        # Clamp theta to reasonable bounds [-4.0, 4.0]
        return max(-4.0, min(4.0, theta_new))

irt_engine = IRTEngine()
