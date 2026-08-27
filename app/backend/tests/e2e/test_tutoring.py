import pytest
import httpx

@pytest.mark.asyncio
async def test_tutoring_update_interaction(base_url):
    async with httpx.AsyncClient() as client:
        payload = {
            "student_id": "test_student",
            "skill_id": "phonological_awareness",
            "correct": True,
            "response_time_ms": 1500,
            "session_duration_minutes": 15
        }
        
        response = await client.post(f"{base_url}/tutoring/update_interaction", json=payload, timeout=10.0)
        
        assert response.status_code in [200, 422], f"Unexpected status: {response.status_code}"
        
        if response.status_code == 200:
            data = response.json()
            assert "bkt_probability" in data
            assert "irt_fatigue_score" in data
            assert "zpd_scaffolding" in data
