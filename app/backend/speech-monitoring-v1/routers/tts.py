import os
from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel
from services.tts_service import TTSService

router = APIRouter(prefix="/tts", tags=["Text-to-Speech"])

from typing import Optional
class TTSRequest(BaseModel):
    text: str
    folder: Optional[str] = "general"

@router.post("/generate")
def generate_speech(request: TTSRequest):
    """
    Converts Sinhala text into speech using Google TTS.
    Returns the streaming URL for the generated MP3.
    """
    text = request.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="Text cannot be empty")
        
    try:
        file_path = TTSService.text_to_speech(text, request.folder)
        return {"file_path": f"/tts/audio/{file_path}"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.api_route("/audio/{folder}/{text_hash}.wav", methods=["GET", "HEAD"])
async def get_audio(folder: str, text_hash: str):
    """
    Streams the TTS audio file directly from local filesystem.
    """
    local_path = os.path.join(os.path.dirname(__file__), "..", "local_audio", folder, f"{text_hash}.wav")
    if not os.path.exists(local_path):
        raise HTTPException(status_code=404, detail="Audio not found")
        
    return FileResponse(local_path, media_type="audio/wav")
