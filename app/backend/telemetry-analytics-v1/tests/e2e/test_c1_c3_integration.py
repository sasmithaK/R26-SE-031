import pytest
from httpx import AsyncClient
from datetime import datetime
from bson import ObjectId

# Import your FastAPI app
from main import app

@pytest.mark.asyncio
async def test_c1_c3_integration(mock_db, patch_get_db):
    """
    Test the full flow:
    1. Post raw telemetry to /telemetry
    2. Ensure it stores telemetry_events and session_summaries
    3. Fetch from /c3-ready and verify shape
    """
    from bson import ObjectId
    student_id = str(ObjectId())
    # We must insert a fake student so ownership check passes
    await mock_db.students.insert_one({"_id": ObjectId(student_id), "parent_id": "mock_parent_id"})
    
    # Simulate Skill 2 (letter), Skill 3 (word), Skill 3 (sequence)
    payload = {
        "student_id": student_id,
        "session_id": "sess_001",
        "session_duration_seconds": 120,
        "events": [
            {
                "event_id": "evt1",
                "skill_id": "skill_2",
                "activity_id": "skill2_act1_odd_one_out",
                "item_id": "S2_A1_R01",
                "knowledge_component_id": "KC_AKSHARA_IDENTITY",
                "targets": ["ba_letter", "ba_letter", "da_letter"],
                "selected_answers": ["da_letter"],
                "prompt_modality": "visual",
                "response_modality": "tap",
                "is_correct": True,
                "first_touch_latency_ms": 1200,
                "total_round_latency_ms": 1200,
                "error_type": "none",
                "activity_name": "skill2_act1_odd_one_out",
                "round_number": 1,
                "score": 100,
                "hesitation_count": 0,
                "correction_count": 0,
                "audio_replay_count": 0,
                "is_abandoned": False,
                "touch_path": []
            },
            {
                "event_id": "evt2",
                "skill_id": "skill_3",
                "activity_id": "skill3_act2_word_formation_mcq",
                "item_id": "S3_A2_R01",
                "knowledge_component_id": "KC_WORD_RECOGNITION",
                "targets": ["amma_word"],
                "selected_answers": ["ata_word"],
                "prompt_modality": "audio",
                "response_modality": "tap",
                "is_correct": False,
                "first_touch_latency_ms": 2000,
                "total_round_latency_ms": 2000,
                "error_type": "phonological_confusion",
                "activity_name": "skill3_act2_word_formation_mcq",
                "round_number": 1,
                "score": 0,
                "hesitation_count": 1,
                "correction_count": 1,
                "audio_replay_count": 2,
                "is_abandoned": False,
                "touch_path": []
            }
        ]
    }
    
    from httpx import ASGITransport
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        # We need to mock the get_current_user depending on how auth is handled.
        # Assuming conftest already mocks Depends(get_current_user)
        # Actually this endpoint requires auth. We assume the test client handles it or we patch it.
        # Let's bypass auth by overriding dependency
        from dependencies import get_current_user
        app.dependency_overrides[get_current_user] = lambda: {"_id": "mock_parent_id", "role": "parent"}
        
        # Dummy student already inserted above

        response = await ac.post("/api/v1/auth/telemetry", json=payload)
        assert response.status_code == 201, f"Failed to submit telemetry: {response.text}"
        
        # Verify DB
        te = await mock_db.telemetry_events.find_one({"session_id": "sess_001"})
        assert te is not None
        assert te["student_id"] == student_id
        
        ss = await mock_db.session_summaries.find_one({"session_id": "sess_001"})
        assert ss is not None
        assert ss["feature_version"] == "c1-v2"
        assert ss["total_trials"] == 2
        assert ss["overall"]["accuracy"] == 0.5
        assert ss["overall"]["audio_replay_rate"] == 2.0  # 2 replays / 1 audio prompt
        
        # Fetch C3 ready endpoint
        response = await ac.get(f"/api/v1/auth/telemetry/{student_id}/c3-ready")
        assert response.status_code == 200
        
        c3_features = response.json()
        assert c3_features["akshara_accuracy"] == 1.0
        assert c3_features["akshara_median_latency_ms"] == 1200.0
        assert c3_features["word_recognition_accuracy"] == 0.0
        assert c3_features["word_recognition_median_latency_ms"] == 2000.0
        assert c3_features["overall_accuracy"] == 0.5
        assert c3_features["phonological_confusion_rate"] == 0.5
        
        app.dependency_overrides.clear()
