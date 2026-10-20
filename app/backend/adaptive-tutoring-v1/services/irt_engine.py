"""Estimate learner ability and item information with a 1PL Rasch model.

The online update keeps a separate ability estimate for each knowledge
component and helps the item selector compare learner ability with difficulty.
"""

import math
from typing import List

class IRTEngine:
    """Apply online 1PL/Rasch ability estimation and information calculations."""

    def __init__(self, se_threshold: float = 0.30):
        """Store the measurement-error threshold used by selection evidence."""
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

#Test-information and standard-error calculation: lines#
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
        # MODEL 4: the 1PL Rasch/IRT model updates learner ability theta by
        # comparing the observed answer with its predicted correctness.
        p_i = self.calculate_probability(theta_old, b_i)
        response = 1.0 if is_correct else 0.0
        
        # Simple SGD update: theta_new = theta_old + alpha * (Response - Probability)
        theta_new = theta_old + learning_rate * (response - p_i)
        
        # Clamp theta to reasonable bounds [-4.0, 4.0]
        return max(-4.0, min(4.0, theta_new))

irt_engine = IRTEngine()
