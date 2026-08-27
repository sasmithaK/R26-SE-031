import pytest
from unittest.mock import patch, AsyncMock

def test_generate_speech_success(client):
    # Patch the TTS service to avoid actual gTTS network calls and GridFS writing
    with patch("routers.tts.TTSService.text_to_speech", new_callable=AsyncMock) as mock_tts:
        mock_tts.return_value = "mocked_hash_12345"
        
        response = client.post("/tts/generate", json={"text": "ආයුබෝවන්"})
        
        assert response.status_code == 200
        assert response.json() == {"file_path": "/tts/audio/mocked_hash_12345"}
        mock_tts.assert_called_once_with("ආයුබෝවන්")

def test_generate_speech_empty_text(client):
    response = client.post("/tts/generate", json={"text": "   "})
    assert response.status_code == 400
    assert response.json()["detail"] == "Text cannot be empty"

def test_get_audio_not_found(client):
    # Mock get_fs to return an empty cursor for GridFS
    class MockCursor:
        async def to_list(self, length):
            return []
            
    class MockFS:
        def find(self, query):
            return MockCursor()
            
    with patch("routers.tts.get_fs", return_value=MockFS()):
        response = client.get("/tts/audio/non_existent_hash")
        assert response.status_code == 404
        assert response.json()["detail"] == "Audio not found"

def test_get_audio_success(client):
    # Mock the GridFS download stream
    class MockGridOut:
        def __init__(self):
            self.chunks = [b"chunk1", b"chunk2", None]
            self.index = 0
            
        async def readchunk(self):
            res = self.chunks[self.index]
            self.index += 1
            return res

    class MockCursor:
        async def to_list(self, length):
            return [{"_id": "mock_file_id"}]
            
    class MockFS:
        def find(self, query):
            return MockCursor()
            
        async def open_download_stream(self, file_id):
            return MockGridOut()
            
    with patch("routers.tts.get_fs", return_value=MockFS()):
        response = client.get("/tts/audio/valid_hash")
        assert response.status_code == 200
        assert response.headers["content-type"] == "audio/mpeg"
        assert response.content == b"chunk1chunk2"
