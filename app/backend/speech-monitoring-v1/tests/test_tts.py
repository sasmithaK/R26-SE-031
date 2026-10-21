"""TTS endpoints: Gemini audio cached as local WAV files (routers/tts.py)."""
import os
from unittest.mock import patch

import routers.tts as tts_router


def test_generate_speech_success(client):
    # TTSService.text_to_speech is synchronous and returns "<folder>/<hash>.wav".
    with patch("routers.tts.TTSService.text_to_speech", return_value="general/abc123.wav") as mock_tts:
        response = client.post("/tts/generate", json={"text": "ආයුබෝවන්"})
    assert response.status_code == 200
    assert response.json() == {"file_path": "/tts/audio/general/abc123.wav"}
    mock_tts.assert_called_once_with("ආයුබෝවන්", "general")


def test_generate_speech_empty_text(client):
    response = client.post("/tts/generate", json={"text": "   "})
    assert response.status_code == 400
    assert response.json()["detail"] == "Text cannot be empty"


def test_get_audio_not_found(client):
    response = client.get("/tts/audio/general/does_not_exist_hash.wav")
    assert response.status_code == 404
    assert response.json()["detail"] == "Audio not found"


def test_get_audio_success(client, tmp_path):
    folder = tmp_path / "local_audio" / "general"
    folder.mkdir(parents=True)
    (folder / "known_hash.wav").write_bytes(b"RIFFfakewav")
    real_join = os.path.join

    def join(*parts):
        if "local_audio" in parts:
            return real_join(str(tmp_path), *parts[parts.index("local_audio"):])
        return real_join(*parts)

    with patch.object(tts_router.os.path, "join", side_effect=join):
        response = client.get("/tts/audio/general/known_hash.wav")
    assert response.status_code == 200
    assert response.headers["content-type"] == "audio/wav"
    assert response.content == b"RIFFfakewav"
