import yaml
import os
import math
from typing import Optional

def _load_config():
    config_path = os.path.join(os.path.dirname(__file__), "..", "..", "config", "thresholds.yaml")
    if not os.path.exists(config_path):
        return {}
    with open(config_path, 'r') as f:
        return yaml.safe_load(f)

CONFIG = _load_config()

def _logistic_index(latency: Optional[float], midpoint: float, scale: float) -> Optional[float]:
    if latency is None:
        return None
    try:
        return 100.0 / (1.0 + math.exp((latency - midpoint) / scale))
    except OverflowError:
        return 0.0 if latency > midpoint else 100.0

def get_visual_processing_index(mean_first_touch_latency: Optional[float]) -> Optional[float]:
    cfg = CONFIG.get("visual_processing", {"midpoint_ms": 3500.0, "scale": 1000.0})
    return _logistic_index(mean_first_touch_latency, cfg["midpoint_ms"], cfg["scale"])

def get_phonological_task_index(mean_first_touch_latency: Optional[float], is_phonological: bool) -> Optional[float]:
    if not is_phonological:
        return None
    cfg = CONFIG.get("phonological", {"midpoint_ms": 4000.0, "scale": 1000.0})
    return _logistic_index(mean_first_touch_latency, cfg["midpoint_ms"], cfg["scale"])

def get_motor_interaction_index(misclick_rate: Optional[float], hesitation_rate: Optional[float]) -> Optional[float]:
    if misclick_rate is None or hesitation_rate is None:
        return None
    # 0 misclicks + 0 hesitations = 100
    penalty = (misclick_rate * 20.0) + (hesitation_rate * 10.0)
    return max(0.0, 100.0 - penalty)

def get_attention_stability_index(hesitation_rate: Optional[float]) -> Optional[float]:
    if hesitation_rate is None:
        return None
    cfg = CONFIG.get("attention", {"hesitation_scale": 2.0})
    scale = cfg["hesitation_scale"]
    return 100.0 * math.exp(-hesitation_rate / scale)
