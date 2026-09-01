import random
from typing import Dict, List

def mock_predict(feature_vector: List[float], class_names: List[str]) -> tuple[str, Dict[str, float]]:
    """
    Fallback prediction when no trained model is available.
    """
    probs = {name: random.uniform(0, 1) for name in class_names}
    total = sum(probs.values())
    probs = {k: round(v / total, 3) for k, v in probs.items()}
    
    predicted_class = max(probs, key=probs.get)
    return predicted_class, probs
