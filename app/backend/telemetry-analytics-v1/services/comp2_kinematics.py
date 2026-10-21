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
}
# NOTE: the map currently covers 3 target letters. Errors on other targets
# cannot be classified, so the index is reported together with
# ``orthographic_confusion_coverage`` (share of errors the map could classify)
# and dashboards hide the index when coverage is 0.

DRAG_MIN_PATH = 0.03  # screen fraction; shorter strokes are taps


def _kind(p):
    return str(p.get("type") or p.get("action") or "").upper()


def _strokes(stream: List[Dict[str, Any]]) -> List[List[Dict[str, Any]]]:
    """Split a round's touch stream into strokes (finger down -> up)."""
    strokes, current = [], None
    for point in stream:
        kind = _kind(point)
        if kind in {"DOWN", "START"}:
            current = [point]
        elif current is not None:
            current.append(point)
            if kind in {"UP", "END"}:
                strokes.append(current)
                current = None
    return strokes


def _path_length(stroke) -> float:
    total = 0.0
    for a, b in zip(stroke, stroke[1:]):
        total += math.hypot(float(b.get("x", 0)) - float(a.get("x", 0)), float(b.get("y", 0)) - float(a.get("y", 0)))
    return total


RESAMPLE_MS = 20  # fixed 50 Hz grid for path and jerk


def _resample(stroke: List[Dict[str, Any]], step_ms: int = RESAMPLE_MS) -> List[Dict[str, Any]]:
    """Linear resampling of a stroke onto a fixed time grid.

    Phones report touch moves at 60-120 Hz. Path length and jerk computed on
    raw samples change with that rate (more samples = more measured wobble),
    so drags are compared on the same 50 Hz grid whatever the device.
    """
    pts = sorted(((float(p.get("t", 0)), float(p.get("x", 0)), float(p.get("y", 0))) for p in stroke),
                 key=lambda v: v[0])
    t0, t1 = pts[0][0], pts[-1][0]
    if t1 - t0 < 3 * step_ms:
        return stroke
    grid, out, j = [], [], 0
    t = t0
    while t < t1:
        grid.append(t)
        t += step_ms
    grid.append(t1)
    for i, tg in enumerate(grid):
        while j < len(pts) - 2 and pts[j + 1][0] < tg:
            j += 1
        (ta, xa, ya), (tb, xb, yb) = pts[j], pts[min(j + 1, len(pts) - 1)]
        u = 0.0 if tb == ta else min(1.0, max(0.0, (tg - ta) / (tb - ta)))
        kind = "DOWN" if i == 0 else "UP" if i == len(grid) - 1 else "MOVE"
        out.append({"t": tg, "x": xa + (xb - xa) * u, "y": ya + (yb - ya) * u, "type": kind})
    return out


def _first_wrong_selection(event: Dict[str, Any]):
    for attempt in event.get("attempt_history") or []:
        if isinstance(attempt, dict) and attempt.get("is_correct") is False:
            selected = attempt.get("selected_answers") or []
            return selected[0] if selected else None
    return None


def normalize_touch_events(events: list) -> list:
    """Normalize Flutter ratio/timestamp touch points for the C2 extractor."""
    normalized = []
    for event in events:
        source = event.get("touch_stream") or event.get("touch_path") or []
        points = []
        for point in source:
            if not isinstance(point, dict):
                continue
            points.append({
                "x": point.get("x_ratio", point.get("x", 0.0)),
                "y": point.get("y_ratio", point.get("y", 0.0)),
                "t": point.get("timestamp_ms", point.get("t", 0)),
                "type": str(point.get("type") or "").upper(),
            })
        # Any touch gives first-touch and contact time; path directness and
        # jerk are computed per drag stroke only (see comp2_kinematics), so a
        # tap is never reported as a perfectly efficient trajectory.
        if event.get("is_abandoned") or not any(point["type"] == "DOWN" for point in points):
            continue
        targets = event.get("targets") or event.get("target_ids") or []
        selected = event.get("selected_answers") or []
        normalized.append({
            **event,
            "touch_stream": points,
            "target_stimulus": targets[0] if targets else None,
            "selected_stimulus": selected[0] if selected else None,
        })
    return normalized


def extract_comp2_features(events: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Kinematic features for one session, measured per stroke.

    * time to first touch: first finger-down of each round (mean over rounds);
    * dwell time: finger contact time per stroke (mean);
    * path efficiency and jerk: drag strokes only (a tap has no path), each
      stroke on its own, so several drags in one round are not merged into
      one meaningless path. ``None`` when the session had no drags;
    * look-alike letter index: share of first-try letter errors that the
      confusion map classifies as visual; ``None`` when no error could be
      classified (never a fake 0).
    """
    if not events:
        return _zero_features()

    t_ft_list, dwell_time_list, path_eff_list, jerk_list = [], [], [], []
    total_errors = visual_errors = classifiable_errors = 0
    drag_strokes = 0

    for event in events:
        touch_stream = event.get("touch_stream", [])
        if not touch_stream:
            continue

        target = event.get("target_stimulus")
        first_try = event.get("first_attempt_correct")
        wrong_first = (first_try is False) if isinstance(first_try, bool) else not event.get("is_correct", True)
        selected = _first_wrong_selection(event) or event.get("selected_stimulus")
        if wrong_first and target and selected:
            total_errors += 1
            mapping = ORTHOGRAPHIC_CONFUSION_MAP.get(target, {})
            if selected in mapping:
                classifiable_errors += 1
            if mapping.get(selected) == "Visual":
                visual_errors += 1

        screen_w = event.get("screen_width_px") or 1000
        screen_h = event.get("screen_height_px") or 1000
        strokes = _strokes(touch_stream)
        if strokes:
            first_down = float(strokes[0][0].get("t", 0))
            if first_down > 0:
                t_ft_list.append(first_down)
        for stroke in strokes:
            duration = float(stroke[-1].get("t", 0)) - float(stroke[0].get("t", 0))
            if duration > 0:
                dwell_time_list.append(duration)
            if len(stroke) >= 3 and _path_length(stroke) >= DRAG_MIN_PATH:
                drag_strokes += 1
                _, _, _, _, path_eff, dj = _process_stream(_resample(stroke), screen_w, screen_h)
                if path_eff > 0:
                    path_eff_list.append(path_eff)
                if dj > 0:
                    jerk_list.append(dj)

    def mean(values, digits):
        return round(sum(values) / len(values), digits) if values else None

    return {
        "time_to_first_touch_ms": mean(t_ft_list, 2),
        "orthographic_confusion_index": round(visual_errors / classifiable_errors, 3) if classifiable_errors else None,
        "path_efficiency_ratio": mean(path_eff_list, 3),
        "dimensionless_jerk": mean(jerk_list, 2),
        "mean_dwell_time_ms": mean(dwell_time_list, 2),
        "orthographic_confusion_coverage": round(classifiable_errors / total_errors, 3) if total_errors else None,
        "first_attempt_error_count": total_errors,
        "movement_event_count": len(path_eff_list),
        "drag_stroke_count": drag_strokes,
    }

def _process_stream(stream: List[Dict[str, Any]], screen_w: int, screen_h: int) -> Tuple[int, int, float, float, float, float]:
    """
    Processes a single touch stream and returns:
    (t_start, t_end, t_FT, t_dwell, path_efficiency, dimensionless_jerk)
    """
    if len(stream) < 2:
        return 0, 0, 0.0, 0.0, 1.0, 0.0

    def _is_down(p):
        t = str(p.get("type") or p.get("action") or "").upper()
        return t in {"DOWN", "START"}

    def _is_up(p):
        t = str(p.get("type") or p.get("action") or "").upper()
        return t in {"UP", "END"}

    def _get_t(p):
        for k in ("t", "timestamp_ms", "t_offset_ms", "time"):
            if k in p and p[k] is not None:
                return float(p[k])
        return 0.0

    def _get_x(p):
        for k in ("x", "x_ratio"):
            if k in p and p[k] is not None:
                return float(p[k])
        return 0.0

    def _get_y(p):
        for k in ("y", "y_ratio"):
            if k in p and p[k] is not None:
                return float(p[k])
        return 0.0
        
    down_events = [p for p in stream if _is_down(p)]
    up_events = [p for p in stream if _is_up(p)]
    
    if not down_events or not up_events:
        return 0, 0, 0.0, 0.0, 1.0, 0.0
        
    first_down = down_events[0]
    last_up = up_events[-1]
    
    t_start = _get_t(first_down)
    t_end = _get_t(last_up)
    
    # 1. Time to First Touch (t_FT)
    # If frontend provides t_offset_ms relative to stimulus render, t_FT is just t_start
    t_ft = float(t_start)
    
    # 2. Touch Dwell Time
    t_dwell = float(max(0, t_end - t_start))
    
    # 3. Path Efficiency Ratio
    x_start, y_start = _get_x(first_down) * screen_w, _get_y(first_down) * screen_h
    x_end, y_end = _get_x(last_up) * screen_w, _get_y(last_up) * screen_h
    
    d_euclidean = math.sqrt((x_end - x_start)**2 + (y_end - y_start)**2)
    
    d_actual = 0.0
    for i in range(len(stream) - 1):
        p1, p2 = stream[i], stream[i+1]
        x1, y1 = _get_x(p1) * screen_w, _get_y(p1) * screen_h
        x2, y2 = _get_x(p2) * screen_w, _get_y(p2) * screen_h
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
    
def _zero_features() -> Dict[str, Any]:
    """No touch data: nothing measured (missing, not zero)."""
    return {
        "time_to_first_touch_ms": None,
        "orthographic_confusion_index": None,
        "path_efficiency_ratio": None,
        "dimensionless_jerk": None,
        "mean_dwell_time_ms": None,
        "orthographic_confusion_coverage": None,
        "first_attempt_error_count": 0,
        "movement_event_count": 0,
        "drag_stroke_count": 0,
    }
