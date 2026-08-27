"""
services/feature_engineering.py
================================
Advanced feature extraction for the 18-dimensional cognitive feature vector.
Extends the base 6 features from ml_pipeline.py with 10 derived behavioral metrics.
"""

import math
import statistics
import numpy as np
from typing import List, Dict, Any
from sklearn.cluster import DBSCAN
import numpy as np

def compute_kinematics(touch_path: List[Dict]) -> Dict[str, float]:
    """Calculate velocity, acceleration, and jerk from time-series touch data."""
    if len(touch_path) < 4:
        return {"avg_velocity": 0.0, "max_acceleration": 0.0, "jerkiness": 0.0}

    # Extract time and positions (assume ratios are normalized to screen)
    times = np.array([p.get("timestamp_ms", 0) / 1000.0 for p in touch_path])
    xs = np.array([p.get("x_ratio", 0) for p in touch_path])
    ys = np.array([p.get("y_ratio", 0) for p in touch_path])

    # Filter out duplicate timestamps to avoid division by zero
    valid_idx = np.where(np.diff(times) > 0)[0]
    if len(valid_idx) < 3:
        return {"avg_velocity": 0.0, "max_acceleration": 0.0, "jerkiness": 0.0}
    
    times = times[valid_idx]
    xs = xs[valid_idx]
    ys = ys[valid_idx]

    dt = np.diff(times)
    
    # Velocity (1st derivative)
    vx = np.diff(xs) / dt
    vy = np.diff(ys) / dt
    velocities = np.sqrt(vx**2 + vy**2)
    avg_velocity = np.mean(velocities)

    # Acceleration (2nd derivative)
    dt2 = dt[:-1]
    ax = np.diff(vx) / dt2
    ay = np.diff(vy) / dt2
    accelerations = np.sqrt(ax**2 + ay**2)
    max_acceleration = np.max(accelerations) if len(accelerations) > 0 else 0.0

    # Jerkiness (3rd derivative) - indicator of tremors/dyspraxia
    dt3 = dt2[:-1]
    jx = np.diff(ax) / dt3
    jy = np.diff(ay) / dt3
    jerks = np.sqrt(jx**2 + jy**2)
    jerkiness = np.mean(jerks) if len(jerks) > 0 else 0.0

    return {
        "avg_velocity": round(avg_velocity, 4),
        "max_acceleration": round(max_acceleration, 4),
        "jerkiness": round(jerkiness, 4)
    }





def compute_response_consistency(latencies: List[int]) -> float:
    """Standard deviation of round latencies — erratic timing = attention issues."""
    if len(latencies) < 2:
        return 0.0
    return round(statistics.stdev(latencies), 2)


def compute_coefficient_of_variation(values: List[float]) -> float:
    """CV = stdev/mean — measures relative variability."""
    if len(values) < 2:
        return 0.0
    mean = statistics.mean(values)
    if mean == 0:
        return 0.0
    return round(statistics.stdev(values) / mean, 4)


def compute_touch_cluster_count(touch_path: List[Dict]) -> int:
    """DBSCAN clustering on touch coordinates to find fixation areas."""
    if len(touch_path) < 3:
        return 0
    coords = np.array([[p.get("x_ratio", 0), p.get("y_ratio", 0)] for p in touch_path])
    clustering = DBSCAN(eps=0.05, min_samples=3).fit(coords)
    n_clusters = len(set(clustering.labels_)) - (1 if -1 in clustering.labels_ else 0)
    return n_clusters


def extract_advanced_features(all_events: List[Dict]) -> Dict[str, float]:
    """
    Compute the 10 additional derived features from raw telemetry events.
    These are appended to the base features.
    """
    if not all_events:
        return _zero_advanced()

    all_touch_points = []
    all_latencies = []
    all_first_touch = []
    all_scores = []
    total_rounds = len(all_events)
    total_abandoned = 0
    total_audio_replays = 0
    misclick_per_session = []

    # Accumulate kinematics over all drag paths
    total_jerkiness = 0.0
    valid_paths = 0

    for e in all_events:
        path = e.get("touch_path", [])
        all_touch_points.extend(path)
        
        # Calculate kinematics per path
        kinematics = compute_kinematics(path)
        if kinematics["jerkiness"] > 0:
            total_jerkiness += kinematics["jerkiness"]
            valid_paths += 1

        all_latencies.append(e.get("total_round_latency_ms", 0))
        all_scores.append(e.get("score", 0))
        ftl = e.get("first_touch_latency_ms", 0)
        if ftl > 0:
            all_first_touch.append(ftl)
        if e.get("is_abandoned", False):
            total_abandoned += 1
        total_audio_replays += e.get("audio_replay_count", 0)
        misclick_per_session.append(e.get("misclick_count", 0))

    # Gaze proxies (scan path, regression count) removed to maintain clinical validity

    # Feature 11: Response Consistency
    response_consistency = compute_response_consistency(all_latencies)

    # Feature 12: First-Touch Variability
    first_touch_variability = compute_coefficient_of_variation(
        [float(x) for x in all_first_touch]
    )

    # Feature 13: Abandonment Rate
    abandonment_rate = round(total_abandoned / max(total_rounds, 1), 4)

    # Feature 14: Audio Dependency Score
    audio_dependency_score = round(total_audio_replays / max(total_rounds, 1), 4)

    # Feature 15: Misclick Trend Slope
    if len(misclick_per_session) >= 2:
        n = len(misclick_per_session)
        x_mean = (n - 1) / 2
        y_mean = statistics.mean(misclick_per_session)
        num = sum((i - x_mean) * (misclick_per_session[i] - y_mean) for i in range(n))
        den = sum((i - x_mean) ** 2 for i in range(n))
        misclick_trend_slope = num / den if den != 0 else 0.0
    else:
        misclick_trend_slope = 0.0

    # Feature 16: Session Duration Ratio (actual / expected ~300s)
    total_time = sum(all_latencies) / 1000.0  # convert ms to seconds
    expected_time = total_rounds * 15.0  # ~15s expected per round
    session_duration_ratio = round(
        total_time / max(expected_time, 1.0), 4
    )

    # Feature 18: Touch Cluster Count
    touch_cluster_count = compute_touch_cluster_count(all_touch_points)

    # Multi-dimensional Fatigue: Accuracy Drift
    if len(all_scores) >= 6:
        early_accuracy = statistics.mean(all_scores[:3])
        late_accuracy = statistics.mean(all_scores[-3:])
        accuracy_drift = late_accuracy - early_accuracy
    else:
        accuracy_drift = 0.0

    # Kinematics: Average Tremor/Jerkiness across all paths
    avg_jerkiness = total_jerkiness / valid_paths if valid_paths > 0 else 0.0

    return {
        "response_consistency": response_consistency,
        "first_touch_variability": first_touch_variability,
        "abandonment_rate": abandonment_rate,
        "audio_dependency_score": audio_dependency_score,
        "misclick_trend_slope": round(misclick_trend_slope, 4),
        "session_duration_ratio": session_duration_ratio,
        "touch_cluster_count": touch_cluster_count,
        "accuracy_drift": round(accuracy_drift, 4),
        "avg_jerkiness": round(avg_jerkiness, 4),
    }


def _zero_advanced() -> Dict[str, float]:
    return {
        "response_consistency": 0.0,
        "first_touch_variability": 0.0,
        "abandonment_rate": 0.0,
        "audio_dependency_score": 0.0,
        "misclick_trend_slope": 0.0,
        "session_duration_ratio": 1.0,
        "touch_cluster_count": 0.0,
        "accuracy_drift": 0.0,
        "avg_jerkiness": 0.0,
    }
