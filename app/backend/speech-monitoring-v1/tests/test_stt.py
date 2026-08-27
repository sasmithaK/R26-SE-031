import pytest
import io
import services.acoustic_service
from unittest.mock import patch, AsyncMock

def test_stt_analyze_success(client):
    mock_acoustics = {
        "status": "ok",
        "transcription": "mocked",
        "word_error_rate": 0.0,
        "hesitation_ratio": 0.1,
        "latency_ms": 1500
    }

    with patch("services.acoustic_service.AcousticAnalysisService.analyze_audio") as mock_analyze:
        mock_analyze.return_value = mock_acoustics
        
        dummy_audio = io.BytesIO(b"dummy audio content")
        files = {"file": ("test.wav", dummy_audio, "audio/wav")}
        
        response = client.post("/stt/analyze-acoustics", files=files)
        
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ok"
        mock_analyze.assert_called_once()
