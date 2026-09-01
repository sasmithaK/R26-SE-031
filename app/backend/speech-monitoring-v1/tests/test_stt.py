import pytest
import io
import services.acoustic_service
from unittest.mock import patch, AsyncMock

def test_stt_analyze_success(client):
    # Matches the actual AcousticAnalysisService.analyze_audio() return schema
    mock_acoustics = {
        "transcription": "ගමට",
        "Acoustic_Latency_ms": 1100,
        "Voice_Onset_ms": 350,
        "Detected_Peaks": 3,
        "Expected_Syllables": 3,
        "Peak_Count_Delta": 0,
        "Intra_Word_Silence_Ratio": 0.12,
        "Local_Jitter": 0.015,
        "Local_Shimmer": 0.08,
        "recording_quality": "good"
    }

    with patch("services.acoustic_service.AcousticAnalysisService.analyze_audio") as mock_analyze:
        mock_analyze.return_value = mock_acoustics
        
        dummy_audio = io.BytesIO(b"dummy audio content")
        files = {"file": ("test.wav", dummy_audio, "audio/wav")}
        
        response = client.post("/stt/analyze-acoustics", files=files)
        
        assert response.status_code == 200
        data = response.json()
        # Verify the acoustic feature keys are present in the response
        assert "Acoustic_Latency_ms" in data
        assert "Peak_Count_Delta" in data
        assert "Local_Jitter" in data
        mock_analyze.assert_called_once()
