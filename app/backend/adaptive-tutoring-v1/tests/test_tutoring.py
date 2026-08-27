import pytest

MOCK_INTERACTION_PAYLOAD = {
    "student_id": "mock_student_123",
    "knowledge_component_id": "KC_mirror_consonants",
    "is_correct": True,
    "current_session_duration_sec": 300
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
    assert "next_kc_id" in data["next_action"]
    assert "scaffold_level" in data["next_action"]
    assert "terminate_session" in data["next_action"]
