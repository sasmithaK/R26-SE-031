from services.comp2_kinematics import normalize_touch_events as _kinematic_events
from services.comp2_kinematics import extract_comp2_features


def test_flutter_touch_path_is_normalized_into_c2_features():
    events = _kinematic_events([{
        "is_correct": False,
        "targets": ["බ"],
        "selected_answers": ["ඩ"],
        "touch_path": [
            {"x_ratio": 0.1, "y_ratio": 0.2, "timestamp_ms": 900, "type": "down"},
            {"x_ratio": 0.3, "y_ratio": 0.4, "timestamp_ms": 1000, "type": "move"},
            {"x_ratio": 0.5, "y_ratio": 0.6, "timestamp_ms": 1100, "type": "move"},
            {"x_ratio": 0.7, "y_ratio": 0.8, "timestamp_ms": 1200, "type": "up"},
        ],
    }])
    assert events[0]["touch_stream"][0] == {
        "x": 0.1,
        "y": 0.2,
        "t": 900,
        "type": "DOWN",
    }
    features = extract_comp2_features(events)
    assert features["time_to_first_touch_ms"] == 900.0
    assert features["mean_dwell_time_ms"] == 300.0
    assert features["orthographic_confusion_index"] > 0.99


def test_strokes_are_measured_separately_and_taps_have_no_path():
    from services.comp2_kinematics import extract_comp2_features

    def drag(t0, x0, x1):
        pts = [{"t": t0, "x": x0, "y": 0.5, "type": "DOWN"}]
        pts += [{"t": t0 + 16 * i, "x": x0 + (x1 - x0) * i / 10, "y": 0.5, "type": "MOVE"} for i in range(1, 10)]
        pts.append({"t": t0 + 160, "x": x1, "y": 0.5, "type": "UP"})
        return pts

    # Two straight drags in opposite directions inside one round: each is
    # perfectly direct; merged into one path they would look inefficient.
    two_drags = {"touch_stream": drag(1000, 0.2, 0.6) + drag(2000, 0.6, 0.2), "is_correct": True}
    features = extract_comp2_features([two_drags])
    assert features["path_efficiency_ratio"] > 0.99
    assert features["drag_stroke_count"] == 2
    assert features["time_to_first_touch_ms"] == 1000

    tap = {"touch_stream": [{"t": 900, "x": 0.5, "y": 0.5, "type": "DOWN"},
                            {"t": 980, "x": 0.5, "y": 0.5, "type": "UP"}], "is_correct": True}
    only_tap = extract_comp2_features([tap])
    assert only_tap["path_efficiency_ratio"] is None and only_tap["dimensionless_jerk"] is None
    assert only_tap["mean_dwell_time_ms"] == 80
    assert only_tap["orthographic_confusion_index"] is None
