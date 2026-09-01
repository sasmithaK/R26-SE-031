import pytest
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_c1_session_endpoint():
    payload = {
        "student_id": "test_student",
        "session_id": "sess_001",
        "skill_id": "skill_1",
        "activity_id": "act_1",
        "session_number": 1,
        "session_duration_seconds": 120,
        "events": [
            {
                "event_id": "evt_1",
                "item_id": "item_1",
                "activity_name": "test_activity",
                "round_number": 1,
                "is_correct": True,
                "score": 100,
                "total_round_latency_ms": 2000,
                "first_touch_latency_ms": 500,
                "misclick_count": 0,
                "hesitation_count": 0
            }
        ]
    }
    
    # We bypass authentication dependency for simple testing here or mock get_current_user
    app.dependency_overrides = {}
    
    from dependencies import get_current_user
    async def override_get_current_user():
        return {"_id": "test_parent", "role": "parent"}
    app.dependency_overrides[get_current_user] = override_get_current_user
    
    # We also need to mock DB to avoid actual Mongo inserts during tests
    from repositories import telemetry_repository, c1_repository
    
    async def mock_save(*args, **kwargs):
        pass
        
    telemetry_repository.save_session = mock_save
    telemetry_repository.save_events = mock_save
    c1_repository.save_c1_state = mock_save
    
    response = client.post("/api/v1/c1/session", json=payload)
    
    assert response.status_code == 201
    data = response.json()
    assert data["student_id"] == "test_student"
    assert "behavior" in data
    assert "indices" in data
    assert "fatigue" in data
    assert "interaction_state" in data
    assert "model" in data
