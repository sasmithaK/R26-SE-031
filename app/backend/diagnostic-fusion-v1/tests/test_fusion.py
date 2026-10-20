import pytest
from bson import ObjectId
from unittest.mock import AsyncMock

MOCK_FUSION_PAYLOAD = {
    "student_id": str(ObjectId()),
    "c1_audio_vector": {
        "acoustic_latency_ms": 500.0,
        "peak_count_delta": 0.0,
        "intra_word_silence_ratio": 0.1,
        "local_jitter": 0.02,
        "local_shimmer": 0.03
    },
    "c2_kinematic_vector": {
        "time_to_first_touch_ms": 1200.0,
        "orthographic_confusion_index": 0.05,
        "path_efficiency_ratio": 0.95,   # ← fixed: was "path_efficiency"
        "dimensionless_jerk": 45.0,
        "dwell_time_ms": 200.0
    },
    "student_age_months": 84,
    "gender": 0,
    "time_of_day_hour": 10,
    "session_id": "mock_session_001",
    "data_origin": "synthetic",
    "dataset_id": "synthetic:c3-contract-test"
}

def test_health_check(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"

def test_diagnose_patient(client):
    from main import get_db
    get_db().students.find_one = AsyncMock(
        return_value={"_id": ObjectId(MOCK_FUSION_PAYLOAD["student_id"]), "parent_id": "mock-parent"}
    )
    get_db().learner_profiles.insert_one = AsyncMock()
    get_db().model_audit_log.insert_one = AsyncMock()
    response = client.post("/diagnose", json=MOCK_FUSION_PAYLOAD)
    assert response.status_code == 200
    data = response.json()
    assert data["student_id"] == MOCK_FUSION_PAYLOAD["student_id"]
    # Check actual FusionResponse schema keys (not stale "risk_score" / "clinical_subtype")
    assert "learner_profile" in data
    assert "shap_explanations" in data
    assert data["learner_profile"]["primary_pattern"] in [
        "Typical Learning Pattern",
        "Phonological Learning Pattern",
        "Visual-Orthographic Learning Pattern",
        "Combined Learning Pattern",
    ]
    assert 0.0 <= data["learner_profile"]["confidence"] <= 1.0
    assert len(data["shap_explanations"]["top_contributing_features"]) == 3


def test_evidence_chat_context_is_whitelisted_and_includes_parent_answers():
    from main import _chat_context_from_records

    context = _chat_context_from_records(
        [{
            "student_id": "must-not-leak",
            "overall": {"accuracy": 0.75, "retry_rate": 0.2, "secret": "drop"},
            "activity_breakdown_by_skill": {
                "S5::A1": {"skill_id": "S5", "activity_id": "A1", "accuracy": 0.75, "secret": "drop"}
            },
        }],
        [{"student_id": "must-not-leak", "recognized_text": "කමල්", "word_accuracy": 0.8, "audio_bytes": "drop"}],
        {"first_name": "must-not-leak", "comprehensive_assessment_results": {
            "reading": [{"question_en": "Does reading feel difficult?", "answer": True}]
        }},
    )

    assert context["activity_observations_c1"][0]["overall"] == {"accuracy": 0.75, "retry_rate": 0.2}
    assert "student_id" not in str(context)
    assert "first_name" not in str(context)
    assert "audio_bytes" not in str(context)
    assert context["reading_observations_c2"][0]["recognized_text"] == "කමල්"
    assert context["parent_reported_observations"][0]["question"] == "Does reading feel difficult?"


def test_evidence_chat_is_not_available_to_parent(client):
    response = client.post(
        f"/chat/students/{ObjectId()}",
        json={"messages": [{"role": "user", "content": "Summarize this child's records."}]},
    )
    assert response.status_code == 403
