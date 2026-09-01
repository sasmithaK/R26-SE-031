import pytest
from bson import ObjectId

# Re-use the payload shape that frontend sends
MOCK_TELEMETRY_PAYLOAD = {
    "student_id": str(ObjectId()),
    "session_id": "session_test_123",
    "session_duration_seconds": 120,
    "device_metrics": {"os": "android", "model": "Pixel 6"},
    "events": [
        {
            "event_id": "test_evt_1",
            "activity_name": "Letter Matching",
            "round_number": 1,
            "is_correct": False,
            "score": 0,
            "timestamp": "2026-08-30T10:00:00Z",
            "first_touch_latency_ms": 1200,
            "total_round_latency_ms": 4500,
            "misclick_count": 0,
            "hesitation_count": 0,
            "audio_replay_count": 0,
            "correction_count": 0,
            "hint_count": 0,
            "is_abandoned": False,
            "touch_path": [],
            "attempt_count": 3,
            "incorrect_attempt_count": 2,
            "first_attempt_correct": False,
            "final_correct": True,
            "time_to_first_response_ms": 1200,
            "time_to_correct_ms": 4500,
            "skill_id": "skill_2",
            "activity_id": "skill2_act1_odd_one_out",
            "item_id": "S2A1R01",
            "item_version": 1,
            "knowledge_component_id": "KC_AKSHARA_IDENTITY",
            "prompt_modality": "visual",
            "response_modality": "tap",
            "research_role": "primary",
            "difficulty_label": "easy",
            "difficulty_b": 0.2,
            "is_anchor": False,
            "targets": ["A", "A", "A", "B"],
            "selected_answers": ["A", "A", "B"],
            "error_type": "unknown_error"
        }
    ]
}

@pytest.mark.asyncio
async def test_submit_telemetry(client, mock_db, mock_user):
    student_id = MOCK_TELEMETRY_PAYLOAD["student_id"]
    await mock_db.students.insert_one({"_id": ObjectId(student_id), "parent_id": mock_user["_id"]})
    
    response = client.post("/api/v1/auth/telemetry", json=MOCK_TELEMETRY_PAYLOAD)
    if response.status_code != 201:
        print("PAYLOAD ERROR:", response.json())
    assert response.status_code == 201
    data = response.json()
    assert "message" in data

@pytest.mark.asyncio
async def test_get_comp2_analytics(client, mock_db, mock_user):
    student_id = MOCK_TELEMETRY_PAYLOAD["student_id"]
    await mock_db.students.insert_one({"_id": ObjectId(student_id), "parent_id": mock_user["_id"]})
    
    # First, insert data
    client.post("/api/v1/auth/telemetry", json=MOCK_TELEMETRY_PAYLOAD)
    
    student_id = MOCK_TELEMETRY_PAYLOAD["student_id"]
    response = client.get(f"/api/v1/auth/telemetry/{student_id}/comp2")
    
    assert response.status_code == 200
    data = response.json()
    assert data["student_id"] == student_id
    
    # Verify that the mathematical feature vector is present
    features = data["visual_feature_vector"]
    assert "dimensionless_jerk" in features
    assert "orthographic_confusion_index" in features
    assert "visual_dyslexia_risk_score" in features
    
@pytest.mark.asyncio
async def test_get_comp2_analytics_insufficient_data(client, mock_db, mock_user):
    student_id = MOCK_TELEMETRY_PAYLOAD["student_id"]
    await mock_db.students.insert_one({"_id": ObjectId(student_id), "parent_id": mock_user["_id"]})
    
    # We use a completely new student ID here that has no data
    response = client.get(f"/api/v1/auth/telemetry/{student_id}/comp2")
    
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "insufficient_data"

@pytest.mark.asyncio
async def test_generate_pdf_report(client, mock_db, mock_user):
    student_id = MOCK_TELEMETRY_PAYLOAD["student_id"]
    await mock_db.students.insert_one({"_id": ObjectId(student_id), "parent_id": mock_user["_id"]})
    
    # Ensure there's some data for the report
    client.post("/api/v1/auth/telemetry", json=MOCK_TELEMETRY_PAYLOAD)
    
    # Generate the cognitive profile by calling /analytics
    client.get(f"/api/v1/auth/telemetry/{student_id}/analytics")
    
    response = client.get(f"/api/v1/auth/telemetry/{student_id}/report/pdf")
    
    assert response.status_code == 200
    assert response.headers["content-type"] == "application/pdf"
    assert response.headers["content-disposition"].startswith("attachment")
    
    # Should return PDF binary
    assert response.content.startswith(b"%PDF")
