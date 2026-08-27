from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from services.tts_service import TTSService
from database import get_fs

router = APIRouter(prefix="/tts", tags=["Text-to-Speech"])

class TTSRequest(BaseModel):
    text: str

@router.post("/generate")
async def generate_speech(request: TTSRequest):
    """
    Converts Sinhala text into speech using Google TTS.
    Returns the GridFS streaming URL for the generated MP3.
    """
    text = request.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="Text cannot be empty")
        
    try:
        text_hash = await TTSService.text_to_speech(text)
        return {"file_path": f"/tts/audio/{text_hash}"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/audio/{text_hash}")
async def get_audio(text_hash: str):
    """
    Streams the TTS audio file directly from MongoDB GridFS.
    """
    fs = get_fs()
    
    # Find the file in GridFS
    cursor = fs.find({"filename": text_hash})
    docs = await cursor.to_list(length=1)
    if not docs:
        raise HTTPException(status_code=404, detail="Audio not found")
    
    file_id = docs[0]["_id"]
    grid_out = await fs.open_download_stream(file_id)
    
    async def stream_audio():
        while True:
            chunk = await grid_out.readchunk()
            if not chunk:
                break
            yield chunk

    return StreamingResponse(stream_audio(), media_type="audio/mpeg")
