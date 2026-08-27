import pytest

MOCK_FUSION_PAYLOAD = {
    "student_id": "mock_student_123",
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
        "path_efficiency": 0.95,
        "dimensionless_jerk": 45.0,
        "dwell_time_ms": 200.0
    },
    "student_age_months": 84
}

def test_health_check(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"

def test_diagnose_patient(client):
    response = client.post("/diagnose", json=MOCK_FUSION_PAYLOAD)
    assert response.status_code == 200
    data = response.json()
    assert data["student_id"] == MOCK_FUSION_PAYLOAD["student_id"]
    assert "risk_score" in data
    assert "clinical_subtype" in data
    assert "shap_explanations" in data
