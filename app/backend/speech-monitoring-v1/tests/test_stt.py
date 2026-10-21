import pytest
import io
from unittest.mock import patch, Mock
from fastapi import HTTPException
from routers.stt import _validate_curriculum_scope


@pytest.mark.parametrize("skill_id,item_id", [
    ("skill_5", "S5A1R01"),
    ("skill_6", "S6A1R01"),
    ("skill_sinhala_vowels", "SVOWA1R01"),
    ("skill_sinhala_consonants", "SCONSA1R18"),
])
def test_c2_accepts_supported_reading_and_letter_item_ids(skill_id, item_id):
    _validate_curriculum_scope(skill_id, "act_1", item_id)


def test_c2_rejects_letter_item_mapped_to_wrong_skill():
    with pytest.raises(HTTPException) as error:
        _validate_curriculum_scope("skill_sinhala_vowels", "act_1", "SCONSA1R01")
    assert error.value.status_code == 422

def test_stt_analyze_success(client):
    pipeline_result = {
        "pipeline_version": "c2-pipeline-v3",
        "audio_sha256": "fixture",
        "quality": {"status": "valid", "quality_score": 0.9, "issues": []},
        "transcription": {"text": "ගමට", "confidence": 0.8, "engine": "fixture"},
        "alignment": {
            "exact_match": True,
            "word": {"error_rate": 0.0, "accuracy": 1.0},
            "grapheme": {"error_rate": 0.0, "accuracy": 1.0, "operations": []},
        },
        "acoustic": {
            "Acoustic_Latency_ms": 1100,
            "Voice_Onset_ms": 350,
            "Detected_Peaks": 3,
            "Expected_Syllables": 3,
            "Peak_Count_Delta": 0,
            "Intra_Word_Silence_Ratio": 0.12,
            "Speech_Duration_ms": 900,
            "Pause_Count": 0,
            "Pause_Ratio": 0.0,
            "Local_Jitter": 0.015,
            "Local_Shimmer": 0.08,
        },
        "fluency": {"recognized_words_per_minute": 60, "adjacent_repetitions": 0},
        "fusion": {
            "measurement_status": "valid",
            "combined_confidence": 0.8,
            "reading_performance_score": 1.0,
        },
    }

    fake_pipeline = Mock()
    fake_pipeline.process.return_value = pipeline_result
    with patch("routers.stt.get_c2_pipeline", return_value=fake_pipeline):
        
        dummy_audio = io.BytesIO(b"dummy audio content")
        files = {"file": ("test.wav", dummy_audio, "audio/wav")}
        data = {
            "student_id": "507f1f77bcf86cd799439011", "session_id": "session-1",
            "skill_id": "skill_5", "activity_id": "act_1", "item_id": "S5A1R01",
            "expected_text": "ගමට", "data_origin": "observed",
        }

        response = client.post("/stt/analyze-acoustics", files=files, data=data)
        
        assert response.status_code == 200
        data = response.json()
        # Verify the acoustic feature keys are present in the response
        assert "Acoustic_Latency_ms" in data
        assert "Peak_Count_Delta" in data
        assert "Local_Jitter" in data
        assert data["pipeline_version"] == "c2-pipeline-v3"
        assert data["measurement_status"] == "valid"
        fake_pipeline.process.assert_called_once()
