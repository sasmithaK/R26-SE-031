from fastapi import APIRouter, File, UploadFile, Form, HTTPException
from services.stt_service import get_stt_engine
import math
import unicodedata
from datetime import datetime
from database import get_db

router = APIRouter(prefix="/stt", tags=["Speech-to-Text"])

def normalize_sinhala(text: str) -> str:
    """Normalize Sinhala text for comparison."""
    if not text:
        return ""
    # NFC normalization
    text = unicodedata.normalize('NFC', text)
    # Trim and collapse whitespace
    text = " ".join(text.split())
    # Keep only Sinhala unicode range and spaces
    # Sinhala Unicode range: \u0D80 - \u0DFF
    filtered = []
    for c in text:
        if ('\u0D80' <= c <= '\u0DFF') or c.isspace():
            filtered.append(c)
    return "".join(filtered).strip()


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
            wer = None
        else:
            distance = levenshtein_distance(expected_text, transcription)
            wer = float(distance) / num_expected_words
            
        # Ensure WER is capped at 1.0 (100% error) for sanity, though technically it can exceed 1.0 if many insertions
        # WER is uncapped: insertion errors can exceed 1.
            
        return {
            "transcription": transcription,
            "expected_text": expected_text,
            "word_error_rate": wer
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/analyze-acoustics")
async def analyze_acoustics(
    student_id: str = Form(None),
    session_id: str = Form(None),
    activity_id: str = Form(None),
    item_id: str = Form(None),
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
        
        # Calculate ASR metrics
        recognized_text = results.get("transcription", "")
        norm_expected = normalize_sinhala(expected_text)
        norm_recognized = normalize_sinhala(recognized_text)
        
        exact_match = (norm_expected == norm_recognized) if norm_expected else None
        
        # Char Error Rate
        char_dist = levenshtein_distance(" ".join(norm_expected), " ".join(norm_recognized)) if norm_expected else 0
        cer = float(char_dist) / len(norm_expected) if norm_expected else None
        
        # Word Error Rate
        word_dist = levenshtein_distance(norm_expected, norm_recognized)
        wer = float(word_dist) / len(norm_expected.split()) if norm_expected.split() else None
        
        # Normalized similarity
        max_len = max(len(norm_expected), len(norm_recognized), 1)
        normalized_similarity = max(0.0, 1.0 - (float(char_dist) / max_len))
        
        doc = {
            "student_id": student_id,
            "session_id": session_id,
            "activity_id": activity_id,
            "item_id": item_id,
            "expected_text": expected_text,
            "recognized_text": recognized_text,
            "asr_engine": "whisper",
            "asr_confidence": None, # Whisper local doesn't expose confidence easily without tokens
            "exact_match": exact_match,
            "character_error_rate": cer,
            "word_error_rate": wer,
            "normalized_similarity": normalized_similarity,
            "acoustic_latency_ms": results.get("Acoustic_Latency_ms"),
            "voice_onset_ms": results.get("Voice_Onset_ms"),
            "detected_peaks": results.get("Detected_Peaks"),
            "expected_syllables": results.get("Expected_Syllables"),
            "syllabic_event_mismatch": results.get("Peak_Count_Delta"),
            "intra_word_silence_ratio": results.get("Intra_Word_Silence_Ratio"),
            "speech_duration_ms": results.get("Speech_Duration_ms"),
            "pause_count": results.get("Pause_Count"),
            "mean_pause_duration_ms": results.get("Mean_Pause_Duration_ms"),
            "pause_ratio": results.get("Pause_Ratio"),
            "local_jitter": results.get("Local_Jitter"),
            "local_shimmer": results.get("Local_Shimmer"),
            "recording_quality": results.get("recording_quality", "unknown"),
            "created_at": datetime.utcnow(),
            "feature_version": "c2-v2",
            "data_origin": "observed",
            "validation_status": "not_clinically_validated",
            "measurement_status": "available" if recognized_text and norm_expected else "incomplete_transcription",
            "persistence_status": "not_requested"
        }
        
        # Save to DB
        if student_id:
            try:
                db = get_db()
                if not all((session_id, activity_id, item_id)):
                    raise HTTPException(422, "student/session/activity/item identifiers are required for stored speech")
                await db.speech_features.insert_one(dict(doc))
                doc["persistence_status"] = "saved"
            except Exception as e:
                doc["persistence_status"] = "failed"
                doc["measurement_status"] = "persistence_failed"
                
        # Return merged results so the caller gets everything
        return {**results, **doc}

        
    except Exception as e:
        print(f"Acoustic analysis error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
