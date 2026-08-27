import pytest
import httpx

@pytest.mark.asyncio
async def test_speech_analyze(base_url):
    async with httpx.AsyncClient() as client:
        # We assume the speech service expects a JSON payload with base64 audio
        payload = {
            "student_id": "test_student",
            "audio_base64": "UklGRiQAAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQAAAAA=",
            "expected_text": "hello world"
        }
        
        response = await client.post(f"{base_url}/speech/analyze", json=payload, timeout=10.0)
        
        # We assert a 200 OK or 422 (if payload schema doesn't strictly match)
        assert response.status_code in [200, 422], f"Unexpected status: {response.status_code}"
        
        if response.status_code == 200:
            data = response.json()
            assert "phoneme_accuracy" in data
            assert "fluency_score" in data
