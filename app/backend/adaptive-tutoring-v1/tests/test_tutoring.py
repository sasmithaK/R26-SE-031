import pytest

MOCK_INTERACTION_PAYLOAD = {
    "student_id": "mock_student_123",
    "session_id": "mock_session_001",          # required field
    "activity_id": "Skill_2_Activity_1",        # required field
    "knowledge_component_id": "KC_mirror_consonants",
    "item_id": "S2A1R01",                       # required field
    "is_correct": True,
    "current_session_duration_sec": 300,
    "fatigue_score": 0.1,
    "learner_profile": {"Visual-Orthographic Learning Pattern": 0.3}
}

def test_health_check(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"

@pytest.mark.asyncio
async def test_update_interaction(client):
    response = client.post("/update_interaction", json=MOCK_INTERACTION_PAYLOAD)
    assert response.status_code == 200
    data = response.json()
    assert data["student_id"] == MOCK_INTERACTION_PAYLOAD["student_id"]
    assert "updated_knowledge_state" in data
    assert "next_action" in data
    # Match actual NextAction schema fields (not stale next_kc_id / terminate_session)
    assert "next_activity" in data["next_action"]
    assert "scaffold_level" in data["next_action"]
    assert "decision" in data["next_action"]
    assert data["next_action"]["decision"] in ["CONTINUE", "TERMINATE"]
    assert "difficulty" in data["next_action"]
    assert 0.0 <= data["next_action"]["difficulty"] <= 1.0
