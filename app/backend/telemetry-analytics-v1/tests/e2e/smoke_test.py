import json

# Mocking what the Flutter wrapper outputs on "wrong, wrong, correct"
event = {
    "activity_name": "odd_one_out",
    "round_number": 1,
    "is_correct": True,
    "score": 100,
    "timestamp": "2026-08-30T10:00:00Z",
    "attempt_count": 3,
    "incorrect_attempt_count": 2,
    "first_attempt_correct": False,
    "final_correct": True,
    "skill_id": "skill_2",
    "activity_id": "skill2_act1_odd_one_out",
    "item_id": "S2A1R01",
    "item_version": 1,
    "knowledge_component_id": "KC_VISUAL_DISCRIMINATION",
    "selected_answers": ["wrong_A", "wrong_A", "correct_B"],
    "error_type": "unknown_error"
}

print(json.dumps(event, indent=2))
