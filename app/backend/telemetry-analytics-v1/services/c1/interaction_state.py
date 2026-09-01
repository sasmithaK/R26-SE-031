import yaml
import os

def _load_config():
    config_path = os.path.join(os.path.dirname(__file__), "..", "..", "config", "thresholds.yaml")
    if not os.path.exists(config_path):
        return {}
    with open(config_path, 'r') as f:
        return yaml.safe_load(f)

CONFIG = _load_config()

def calculate_cognitive_load_score(latency: float, hesitation_rate: float, misclick_rate: float) -> float:
    # A simple normalized score from behavioral indicators
    # 0.0 means perfectly engaged, 1.0 means completely overwhelmed
    score = 0.0
    
    # Normalize latency proxy (assume > 5000 is high)
    lat_val = min(1.0, max(0.0, (latency - 1000) / 4000)) if latency else 0.0
    
    # Normalize hesitation rate (assume > 1.0 is high)
    hes_val = min(1.0, max(0.0, hesitation_rate)) if hesitation_rate else 0.0
    
    # Normalize misclick rate (assume > 0.5 is high)
    mis_val = min(1.0, max(0.0, misclick_rate * 2.0)) if misclick_rate else 0.0
    
    score = (lat_val + hes_val + mis_val) / 3.0
    return round(score, 2)

def get_interaction_state(score: float) -> str:
    cfg = CONFIG.get("interaction_state", {"engaged_max": 0.40, "moderate_max": 0.70})
    if score <= cfg["engaged_max"]:
        return "ENGAGED"
    elif score <= cfg["moderate_max"]:
        return "MODERATE_LOAD"
    return "HIGH_LOAD"
