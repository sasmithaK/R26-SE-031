import os
import sys
from pprint import pprint
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "app/backend/telemetry-analytics-v1")))

from services.comp2_kinematics import extract_comp2_features

# Mock payload that conforms to the new Component 2 specifications
mock_events = [
    {
        "target_stimulus": "බ",
        "selected_stimulus": "ඩ",
        "is_correct": False,
        "stimulus_rendered_ts": 1000,
        "touch_stream": [
            {"t_offset_ms": 420, "x": 0.512, "y": 0.781, "action": "DOWN"},
            {"t_offset_ms": 436, "x": 0.510, "y": 0.779, "action": "MOVE"},
            {"t_offset_ms": 500, "x": 0.400, "y": 0.600, "action": "MOVE"},
            {"t_offset_ms": 950, "x": 0.231, "y": 0.340, "action": "UP"}
        ]
    }
]

print("Testing Component 2 Feature Extraction...")
features = extract_comp2_features(mock_events)
pprint(features)

assert features["time_to_first_touch_ms"] == 420.0, "FTL calculation failed"
assert features["mean_dwell_time_ms"] == 530.0, "Dwell calculation failed"
assert features["orthographic_confusion_index"] > 0.0, "OCI calculation failed"
print("\nAll mathematical tests passed successfully!")
