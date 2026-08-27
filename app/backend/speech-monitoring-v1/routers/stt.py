from fastapi import APIRouter, File, UploadFile, Form, HTTPException
from services.stt_service import get_stt_engine
import math

router = APIRouter(prefix="/stt", tags=["Speech-to-Text"])

def levenshtein_distance(s1: str, s2: str) -> int:
    """Calculate the Levenshtein distance between two strings (measured in words)."""
    words1 = s1.split()
    words2 = s2.split()
    
    if len(words1) < len(words2):
        return levenshtein_distance(s2, s1)
        
    if len(words2) == 0:
        return len(words1)
        
    previous_row = range(len(words2) + 1)
    for i, c1 in enumerate(words1):
        current_row = [i + 1]
        for j, c2 in enumerate(words2):
            insertions = previous_row[j + 1] + 1
            deletions = current_row[j] + 1
            substitutions = previous_row[j] + (c1 != c2)
            current_row.append(min(insertions, deletions, substitutions))
        previous_row = current_row
        
    return previous_row[-1]

@router.post("/transcribe")
async def transcribe_audio(file: UploadFile = File(...)):
    """
    Accepts an audio file and transcribes it into Sinhala text using Whisper.
    """
    if not file:
        raise HTTPException(status_code=400, detail="No file uploaded")
        
    try:
        audio_bytes = await file.read()
        if len(audio_bytes) == 0:
            raise HTTPException(status_code=400, detail="Empty file uploaded")
            
        stt_engine = get_stt_engine()
        transcription = stt_engine.transcribe_audio_bytes(audio_bytes)
        
        return {"transcription": transcription}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/analyze-reading")
async def analyze_reading(
    expected_text: str = Form(...),
    file: UploadFile = File(...)
):
    """
    Accepts an audio file and the expected Sinhala text.
    Transcribes the audio and calculates the Word Error Rate (WER) using Levenshtein Distance.
    """
    if not file:
        raise HTTPException(status_code=400, detail="No file uploaded")
        
    try:
        audio_bytes = await file.read()
        if len(audio_bytes) == 0:
            raise HTTPException(status_code=400, detail="Empty file uploaded")
            
        stt_engine = get_stt_engine()
        transcription = stt_engine.transcribe_audio_bytes(audio_bytes)
        
        # Calculate Word Error Rate (WER)
        # WER = (Substitutions + Deletions + Insertions) / Number of words in expected text
        expected_words = expected_text.split()
        num_expected_words = len(expected_words)
        
        if num_expected_words == 0:
            wer = 0.0
        else:
            distance = levenshtein_distance(expected_text, transcription)
            wer = float(distance) / num_expected_words
            
        # Ensure WER is capped at 1.0 (100% error) for sanity, though technically it can exceed 1.0 if many insertions
        wer = min(1.0, wer)
            
        return {
            "transcription": transcription,
            "expected_text": expected_text,
            "word_error_rate": wer
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/analyze-acoustics")
async def analyze_acoustics(
    expected_text: str = Form(""),
    expected_syllables: int = Form(0),
    t_stimulus: int = Form(0),
    t_record_start: int = Form(0),
    file: UploadFile = File(...)
):
    """
    Accepts a raw WAV audio file and analyzes it for acoustic hesitation,
    latency, syllable peak deltas, and prosodic instability (jitter/shimmer).
    """
    if not file:
        raise HTTPException(status_code=400, detail="No file uploaded")
        
    try:
        audio_bytes = await file.read()
        if len(audio_bytes) == 0:
            raise HTTPException(status_code=400, detail="Empty file uploaded")
            
        from services.acoustic_service import AcousticAnalysisService
        acoustic_engine = AcousticAnalysisService()
        
        results = acoustic_engine.analyze_audio(
            wav_bytes=audio_bytes,
            expected_text=expected_text,
            expected_syllables=expected_syllables,
            t_stimulus=t_stimulus,
            t_record_start=t_record_start
        )
        
        return results
        
    except Exception as e:
        print(f"Acoustic analysis error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
