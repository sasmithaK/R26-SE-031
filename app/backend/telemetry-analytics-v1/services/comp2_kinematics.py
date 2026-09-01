"""
services/comp2_kinematics.py
============================
Component 2: Visual-Orthographic Kinematic Engine

Implements deterministic kinematic feature engineering and spatial-orthographic
graph metrics to classify visual processing deficits using robust tabular machine learning.
"""

import math
from typing import List, Dict, Any, Tuple

# Pre-defined Orthographic Confusion Dictionary for Sinhala Abugida
# Maps a target stimulus to a categorization of distractors.
# Error types: "Visual", "Phonetic", "Neutral"
ORTHOGRAPHIC_CONFUSION_MAP = {
    "බ": {"ඩ": "Visual", "භ": "Phonetic", "ට": "Neutral"},
    "ප": {"ය": "Visual", "ඵ": "Phonetic", "ර": "Neutral"},
    "ත": {"න": "Visual", "ථ": "Phonetic", "ල": "Neutral"},
    # Add more as required by the curriculum
}

def extract_comp2_features(events: List[Dict[str, Any]]) -> Dict[str, float]:
    """
    Extracts the 5 deterministic kinematic features from a list of telemetry events.
    """
    if not events:
        return _zero_features()

    t_ft_list = []
    dwell_time_list = []
    path_eff_list = []
    jerk_list = []
    
    total_errors = 0
    visual_errors = 0

    for event in events:
        touch_stream = event.get("touch_stream", [])
        if not touch_stream:
            continue
            
        target = event.get("target_stimulus")
        selected = event.get("selected_stimulus")
        
        # 1. Orthographic Confusion Classification
        if not event.get("is_correct", True) and target and selected:
            total_errors += 1
            mapping = ORTHOGRAPHIC_CONFUSION_MAP.get(target, {})
            if mapping.get(selected) == "Visual":
                visual_errors += 1

        # Calculate Stream Metrics
        screen_w = event.get("screen_width_px") or 1000
        screen_h = event.get("screen_height_px") or 1000
        t_start, t_end, t_ft, dwell, path_eff, dj = _process_stream(touch_stream, screen_w, screen_h)
        
        if t_ft > 0: t_ft_list.append(t_ft)
        if dwell > 0: dwell_time_list.append(dwell)
        if path_eff > 0: path_eff_list.append(path_eff)
        if dj > 0: jerk_list.append(dj)

    n_events = max(1, len(events))
    
    # 2. Orthographic Confusion Index (OCI)
    # Sum(Visual Errors) / (Sum(Total Errors) + epsilon)
    oci = visual_errors / (total_errors + 1e-5) if total_errors > 0 else 0.0
    
    return {
        "time_to_first_touch_ms": round(sum(t_ft_list) / len(t_ft_list) if t_ft_list else 0, 2),
        "orthographic_confusion_index": round(oci, 3),
        "path_efficiency_ratio": round(sum(path_eff_list) / len(path_eff_list) if path_eff_list else 1.0, 3),
        "dimensionless_jerk": round(sum(jerk_list) / len(jerk_list) if jerk_list else 0, 2),
        "mean_dwell_time_ms": round(sum(dwell_time_list) / len(dwell_time_list) if dwell_time_list else 0, 2)
    }

def _process_stream(stream: List[Dict[str, Any]], screen_w: int, screen_h: int) -> Tuple[int, int, float, float, float, float]:
    """
    Processes a single touch stream and returns:
    (t_start, t_end, t_FT, t_dwell, path_efficiency, dimensionless_jerk)
    """
    if len(stream) < 2:
        return 0, 0, 0.0, 0.0, 1.0, 0.0
        
    down_events = [p for p in stream if p.get("type") == "DOWN"]
    up_events = [p for p in stream if p.get("type") == "UP"]
    
    if not down_events or not up_events:
        return 0, 0, 0.0, 0.0, 1.0, 0.0
        
    first_down = down_events[0]
    last_up = up_events[-1]
    
    t_start = first_down.get("t", 0)
    t_end = last_up.get("t", 0)
    
    # 1. Time to First Touch (t_FT)
    # If frontend provides t_offset_ms relative to stimulus render, t_FT is just t_start
    t_ft = float(t_start)
    
    # 2. Touch Dwell Time
    t_dwell = float(max(0, t_end - t_start))
    
    # 3. Path Efficiency Ratio
    x_start, y_start = first_down.get("x", 0) * screen_w, first_down.get("y", 0) * screen_h
    x_end, y_end = last_up.get("x", 0) * screen_w, last_up.get("y", 0) * screen_h
    
    d_euclidean = math.sqrt((x_end - x_start)**2 + (y_end - y_start)**2)
    
    d_actual = 0.0
    for i in range(len(stream) - 1):
        p1, p2 = stream[i], stream[i+1]
        x1, y1 = p1.get("x", 0) * screen_w, p1.get("y", 0) * screen_h
        x2, y2 = p2.get("x", 0) * screen_w, p2.get("y", 0) * screen_h
        d_actual += math.sqrt((x2 - x1)**2 + (y2 - y1)**2)
        
    path_eff = d_euclidean / d_actual if d_actual > 0 else 1.0
    
    # 4. Dimensionless Trajectory Jerk (DJ)
    # DJ = -( (t_end - t_start)^5 / D_actual^2 ) * Integral( j_x^2 + j_y^2 dt )
    dj = _compute_dimensionless_jerk(stream, t_end - t_start, d_actual, screen_w, screen_h)
    
    return t_start, t_end, t_ft, t_dwell, path_eff, dj

def _compute_dimensionless_jerk(stream: List[Dict[str, Any]], total_t: float, d_actual: float, screen_w: int, screen_h: int) -> float:
    if len(stream) < 4 or total_t <= 0 or d_actual <= 0:
        return 0.0
        
    # Extract
    times = [p.get("t", 0) / 1000.0 for p in stream] # seconds
    xs = [p.get("x", 0.0) * screen_w for p in stream]
    ys = [p.get("y", 0.0) * screen_h for p in stream]
    
    # Needs valid dt > 0
    valid_pts = []
    for i in range(len(stream)):
        if i == 0 or times[i] > times[i-1]:
            valid_pts.append((times[i], xs[i], ys[i]))
            
    if len(valid_pts) < 4:
        return 0.0
        
    times = [p[0] for p in valid_pts]
    xs = [p[1] for p in valid_pts]
    ys = [p[2] for p in valid_pts]
    
    # V (1st deriv)
    vx, vy = [], []
    for i in range(len(times)-1):
        dt = times[i+1] - times[i]
        vx.append((xs[i+1] - xs[i]) / dt)
        vy.append((ys[i+1] - ys[i]) / dt)
        
    # A (2nd deriv)
    ax, ay = [], []
    for i in range(len(vx)-1):
        dt = times[i+1] - times[i]
        ax.append((vx[i+1] - vx[i]) / dt)
        ay.append((vy[i+1] - vy[i]) / dt)
        
    # J (3rd deriv)
    jx, jy = [], []
    integral_j2 = 0.0
    for i in range(len(ax)-1):
        dt = times[i+1] - times[i]
        j_x = (ax[i+1] - ax[i]) / dt
        j_y = (ay[i+1] - ay[i]) / dt
        jx.append(j_x)
        jy.append(j_y)
        
        integral_j2 += (j_x**2 + j_y**2) * dt
        
    # Dimensionless Jerk calculation
    # Since total_t is in ms, we convert it to seconds for the physical calculation
    total_t_sec = total_t / 1000.0
    
    # The negative sign is a convention, but often absolute magnitude is used.
    dj = ((total_t_sec**5) / (d_actual**2)) * integral_j2
    
    return dj
    
def _zero_features() -> Dict[str, float]:
    return {
        "time_to_first_touch_ms": 0.0,
        "orthographic_confusion_index": 0.0,
        "path_efficiency_ratio": 1.0,
        "dimensionless_jerk": 0.0,
        "mean_dwell_time_ms": 0.0
    }
