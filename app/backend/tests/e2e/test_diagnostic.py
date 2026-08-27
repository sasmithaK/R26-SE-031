import pytest
import httpx

@pytest.mark.asyncio
async def test_diagnostic_diagnose(base_url):
    async with httpx.AsyncClient() as client:
        payload = {
            "student_id": "test_student",
            "acoustic_features": {
                "acoustic_latency_ms": 120.5,
                "peak_count_delta": 1.2,
                "intra_word_silence_ratio": 0.15,
                "local_jitter": 0.04,
                "local_shimmer": 0.05
            },
            "kinematic_features": {
                "time_to_first_touch_ms": 300.0,
                "orthographic_confusion_index": 2.5,
                "path_efficiency": 0.85,
                "dimensionless_jerk": 50.0,
                "dwell_time_ms": 400.0
            },
            "demographics": {
                "age": 8,
                "gender": 1,
                "time_of_day_hour": 14
            }
        }
        
        response = await client.post(f"{base_url}/diagnostic/diagnose", json=payload, timeout=10.0)
        
        assert response.status_code in [200, 422], f"Unexpected status: {response.status_code}"
        
        if response.status_code == 200:
            data = response.json()
            assert "clinical_assessment" in data
            assert "shap_explanations" in data
