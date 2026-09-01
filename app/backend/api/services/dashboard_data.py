"""Dashboard projections: preserve missingness, provenance and current storage contracts."""
from datetime import datetime, timezone
import math

KC_NAMES = {
    "KC_VISUAL_SUPPORT": "Visual support", "KC_AKSHARA_IDENTITY": "Sinhala letter identity",
    "KC_PHONEME_GRAPHEME": "Sound-letter matching", "KC_ORTHOGRAPHIC_MEMORY": "Letter sequence memory",
    "KC_WORD_RECOGNITION": "Word recognition", "KC_SPELLING_SEQUENCE": "Spelling sequence",
    "KC_SENTENCE_LANGUAGE": "Sentence language", "KC_READING_COMPREHENSION": "Reading comprehension",
    "KC_ORAL_READING_FLUENCY": "Oral reading",
}
PATTERNS = {name: name.removesuffix(" Learning Pattern") for name in (
    "Typical Learning Pattern", "Phonological Learning Pattern",
    "Visual-Orthographic Learning Pattern", "Combined Learning Pattern")}

def number(value):
    if isinstance(value, bool):
        return None
    try:
        result = float(value)
        return result if math.isfinite(result) else None
    except (ValueError, TypeError):
        return None

def stamp(value):
    if isinstance(value, datetime):
        if value.tzinfo is None:
            value = value.replace(tzinfo=timezone.utc)
        return value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")
    if isinstance(value, str) and value:
        try:
            return stamp(datetime.fromisoformat(value.replace("Z", "+00:00")))
        except ValueError:
            return None
    return None

def timestamp(doc):
    return stamp(doc.get("completed_at") or doc.get("created_at") or doc.get("timestamp") or doc.get("updated_at"))

async def records(db, collection, student_id, limit=200):
    # Bounded projection: newest ingested records, then chronological presentation.
    docs = await db[collection].find({"student_id": student_id}).sort("_id", -1).limit(limit).to_list(length=limit)
    return sorted(docs, key=lambda d: timestamp(d) or "", reverse=True)

def provenance(doc):
    doc = doc or {}
    return dict(available=bool(doc), data_origin=doc.get("data_origin", "unspecified"),
                dataset_id=doc.get("dataset_id"), validation_status=doc.get("validation_status", "not_clinically_validated"),
                limitations=["Prototype observations and model estimates are not a diagnosis.",
                             "Synthetic results demonstrate software behavior, not performance on Sri Lankan Grade 1 children.",
                             "Missing measurements are unavailable, not zero."])

def base(student_id, doc=None, period="Latest available record"):
    return dict(student_id=student_id, updated_at=stamp(datetime.now(timezone.utc)), reporting_period=period, **provenance(doc))

def mlbase(student_id, doc=None, model="unavailable", feature="unavailable"):
    doc = doc or {}
    return dict(**base(student_id, doc), model_version=doc.get("model_version", model),
                feature_version=doc.get("feature_version", feature), last_data_at=timestamp(doc))

def speech(doc):
    doc = doc or {}
    raw = doc.get("speech_data") or {}
    def field(*names):
        for source in (doc, raw):
            for name in names:
                if source.get(name) is not None:
                    return source[name]
        return None
    # A historical 1-WER value is not a recognition confidence estimate.
    confidence = field("stt_confidence") if field("stt_confidence_method") not in (None, "one_minus_wer") else None
    return dict(pause_count=number(field("pause_count", "Pause_Count")),
                mean_pause_duration_ms=number(field("mean_pause_duration_ms", "Mean_Pause_Duration_ms")),
                pause_ratio=number(field("pause_ratio", "Pause_Ratio")), speech_duration_ms=number(field("speech_duration_ms", "Speech_Duration_ms")),
                expected_text=field("expected_text") or "", transcription=field("recognized_text", "transcription") or "",
                wer=number(field("word_error_rate", "wer")), stt_confidence=number(confidence),
                stt_confidence_method=field("stt_confidence_method"),
                acoustic_latency_ms=number(field("acoustic_latency_ms", "reading_initiation_latency_ms", "Acoustic_Latency_ms")),
                voice_onset_ms=number(field("voice_onset_ms", "Voice_Onset_ms")),
                peak_delta=number(field("syllabic_event_mismatch", "peak_count_delta", "Peak_Count_Delta")),
                silence_ratio=number(field("intra_word_silence_ratio", "internal_silence_ratio", "Intra_Word_Silence_Ratio")),
                jitter=number(field("local_jitter", "jitter", "Local_Jitter")),
                shimmer=number(field("local_shimmer", "shimmer", "Local_Shimmer")),
                recording_quality=field("recording_quality") or "Unknown",
                measurement_status=field("measurement_status") or ("unverified" if doc else "unavailable"))

def pattern_profile(doc):
    profile = (doc or {}).get("learner_profile") or {}
    probs = {PATTERNS.get(k, k): number(v) for k, v in (profile.get("class_probabilities") or {}).items()}
    probs = {k:v for k,v in probs.items() if v is not None and 0 <= v <= 1}
    pattern = PATTERNS.get(profile.get("primary_pattern"), profile.get("primary_pattern", "Unavailable"))
    return profile, probs, pattern

def mastery_status(value):
    if value is None:
        return "Unavailable"
    return "Higher model estimate" if value >= .8 else "Developing estimate" if value >= .5 else "Lower model estimate"

async def research_evidence(db, student_id):
    docs = await records(db, "research_evaluations", student_id)
    if docs:
        doc = {k:v for k,v in docs[0].items() if k != "_id"}
        return {**base(student_id, doc, "Synthetic held-out evaluation"), **doc}
    return {**base(student_id, None), "components": [], "message": "No reproducible evaluation has been imported for this student. No baseline scores are invented."}
