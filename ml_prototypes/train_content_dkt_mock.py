import joblib
import os
import numpy as np

os.makedirs('../content-service/ml', exist_ok=True)

class SimpleDKTMock:
    """
    A simplified Knowledge Tracing model for the PoC.
    In a full production environment, this would be an LSTM/Transformer in PyTorch.
    For this 3-day PoC, we use an Exponential Moving Average of correctness 
    to track the probability of mastery for specific Sinhala letters/skills.
    """
    def __init__(self, alpha=0.3):
        self.alpha = alpha # Learning rate

    def update_mastery(self, current_mastery, is_correct, response_latency):
        # If correct and fast, high boost. If correct but slow, medium boost.
        # If incorrect, penalize.
        target = 1.0 if is_correct else 0.0
            
        # Latency penalty (assume > 3000ms is slow)
        latency_penalty = 0.0
        if is_correct and response_latency > 3000:
            latency_penalty = 0.2
            
        adjusted_target = max(0.0, target - latency_penalty)
        
        # Exponential moving average update
        new_mastery = (1 - self.alpha) * current_mastery + (self.alpha * adjusted_target)
        return max(0.0, min(1.0, new_mastery)) # Clamp between 0 and 1

print("Initializing Simple Knowledge Tracing logic...")
model = SimpleDKTMock(alpha=0.3)

# Save logic object for the Content Service
model_path = '../content-service/ml/dkt_mock.pkl'
joblib.dump(model, model_path)
print(f"DKT Mock saved to {model_path}")
