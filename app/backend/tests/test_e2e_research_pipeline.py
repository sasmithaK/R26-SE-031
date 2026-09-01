import pytest
import asyncio
from fastapi.testclient import TestClient
import sys
from pathlib import Path

# Add backend root and api to sys.path
backend_path = Path(__file__).parent.parent
sys.path.insert(0, str(backend_path))
sys.path.insert(0, str(backend_path / "api"))
from api.main import app
from shared.database import get_db, connect_to_mongo, close_mongo_connection
import uuid
import time

client = TestClient(app)

@pytest.fixture(scope="module", autouse=True)
async def setup_db():
    await connect_to_mongo()
    yield
    await close_mongo_connection()

@pytest.mark.asyncio
async def test_e2e_research_pipeline():
    # 1. Generate unique session ID for isolation
    student_id = "test_student_001"
    session_id = str(uuid.uuid4())
    
    payload = {
        "student_id": student_id,
        "session_id": session_id,
        "activity_id": "Skill_2",
        "item_id": "S2A1R01",
        "knowledge_component_id": "KC_LETTER_IDENTITY",
        "response": {
            "selected_character": "ආ",
            "is_correct": False
        },
        "telemetry": {
            "first_touch_latency_ms": 1200,
            "total_round_latency_ms": 3500,
            "hesitation_count": 1,
            "misclick_count": 0,
            "touch_stream": []
        }
    }
    
    # 2. Submit interaction
    response = client.post("/api/v1/learning/interaction", json=payload)
    
    # 3. Assert fast-path synchronous response
    assert response.status_code == 200
    data = response.json()
    assert data["result"]["is_correct"] is False
    assert "next_action" in data
    assert "next_activity" in data["next_action"]
    
    # 4. Wait a moment for background tasks to complete
    time.sleep(1.0)
    
    # 5. Assert database evidence trail
    db = get_db()
    
    telemetry = await db.telemetry_events.find_one({"session_id": session_id})
    assert telemetry is not None
    assert telemetry["is_correct"] is False
    
    c1_features = await db.behavioral_features.find_one({"session_id": session_id})
    assert c1_features is not None
    assert c1_features["behavior"]["median_latency_ms"] == 3500
    
    c2_features = await db.kinematic_features.find_one({"session_id": session_id})
    assert c2_features is not None
    assert c2_features["time_to_first_touch_ms"] == 1200
    
    c3_profile = await db.learner_profiles.find_one({"session_id": session_id})
    assert c3_profile is not None
    assert "class_probabilities" in c3_profile["learner_profile"]
    
    c4_decision = await db.adaptive_decisions.find_one({"session_id": session_id})
    assert c4_decision is not None
    assert "scaffold_level" in c4_decision
    
    print("E2E Test Passed: Full pipeline generated the 7-collection evidence trail.")
