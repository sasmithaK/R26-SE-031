from fastapi import APIRouter, HTTPException, Depends, BackgroundTasks
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any, List
import httpx
import uuid
import asyncio
import os
from datetime import datetime, timezone
import re
import sys
from pathlib import Path as PathLib
sys.path.insert(0, str(PathLib(__file__).parent.parent.parent.parent))
from shared.database import get_db

router = APIRouter(prefix="/api/v1/learning", tags=["Unified Learning"])

class InteractionResponseModel(BaseModel):
    selected_character: str
    is_correct: bool

class TelemetryModel(BaseModel):
    first_touch_latency_ms: int
    total_round_latency_ms: int
    hesitation_count: int
    misclick_count: int
    audio_replay_count: Optional[int] = 0
    scaffold_level_used: Optional[int] = 0
    original_options_count: Optional[int] = None
    current_pair_id: Optional[str] = None
    incorrect_option_ids: Optional[List[str]] = None
    visible_option_ids: Optional[List[str]] = None
    selected_option_ids: Optional[List[str]] = None
    correct_option_ids: Optional[List[str]] = None
    supported_actions: Optional[List[str]] = None
    minimum_visible_options: Optional[int] = 2
    scaffold_applications: Optional[List[Dict[str, Any]]] = None
    attempt_count: Optional[int] = 0
    incorrect_attempt_count: Optional[int] = 0
    first_attempt_correct: Optional[bool] = None
    correction_count: Optional[int] = 0
    hint_count: Optional[int] = 0
    item_role: Optional[str] = None
    equivalent_group_id: Optional[str] = None
    response_load_relation: Optional[str] = None
    target_ids: Optional[List[str]] = None
    selected_answers: Optional[List[str]] = None
    touch_stream: List[Any] = Field(default_factory=list)
    item_version: int = 1
    prompt_modality: str = "visual"
    response_modality: str = "tap"
    research_role: str = "primary"
    difficulty_label: str = "medium"
    error_type: str = "unknown_error"
    final_correct: Optional[bool] = None
    time_to_first_response_ms: int = 0
    time_to_correct_ms: int = 0
    score: int = 0
    is_abandoned: bool = False

class InteractionPayload(BaseModel):
    event_id: Optional[str] = None
    student_id: str
    session_id: str
    skill_id: Optional[str] = None
    activity_id: str
    round_number: Optional[int] = None
    item_id: str
    knowledge_component_id: str = "KC_LETTER_IDENTITY"
    response: InteractionResponseModel
    telemetry: TelemetryModel
    speech: Optional[Any] = None
    phase: str = "COMPLETE"
    difficulty_b: float = 0.0
    is_anchor: bool = False


def build_adaptive_submit(
    payload: InteractionPayload,
    *,
    event_id: str,
    canonical_activity_id: str,
    canonical_item_id: str,
    fatigue_score: float,
    learner_profile: Dict[str, float],
) -> Dict[str, Any]:
    """Build the lossless C4 request shared by runtime code and contract tests."""
    return {
        "student_id": payload.student_id,
        "session_id": payload.session_id,
        "event_id": event_id,
        "activity_id": canonical_activity_id,
        "knowledge_component_id": payload.knowledge_component_id,
        "item_id": canonical_item_id,
        "is_correct": payload.response.is_correct,
        "difficulty_b": payload.difficulty_b,
        "is_anchor": payload.is_anchor,
        "current_session_duration_sec": (
            payload.telemetry.total_round_latency_ms // 1000
        ),
        "fatigue_score": fatigue_score,
        "learner_profile": learner_profile,
        "phase": payload.phase,
        "telemetry": payload.telemetry.model_dump(),
    }


async def run_background_pipeline(payload: InteractionPayload, c4_result: dict, event_id: str):
    db = get_db()
    ingestion_key = f"{payload.student_id}:{event_id}"
    
    # 1. Save Telemetry
    telemetry_doc = {
        "schema_version": "2.0",
        "event_id": event_id,
        "ingestion_key": ingestion_key,
        "student_id": payload.student_id,
        "session_id": payload.session_id,
        "skill_id": payload.skill_id,
        "activity_id": payload.activity_id,
        "item_id": payload.item_id,
        "knowledge_component_id": payload.knowledge_component_id,
        "difficulty_b": payload.difficulty_b,
        "is_anchor": payload.is_anchor,
        "phase": payload.phase,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "is_correct": payload.response.is_correct,
        "final_correct": (
            payload.telemetry.final_correct
            if payload.telemetry.final_correct is not None
            else payload.response.is_correct
        ),
        "score": payload.telemetry.score,
        "is_abandoned": payload.telemetry.is_abandoned,
        "first_touch_latency_ms": payload.telemetry.first_touch_latency_ms,
        "total_round_latency_ms": payload.telemetry.total_round_latency_ms,
        "time_to_first_response_ms": payload.telemetry.time_to_first_response_ms,
        "time_to_correct_ms": payload.telemetry.time_to_correct_ms,
        "hesitation_count": payload.telemetry.hesitation_count,
        "misclick_count": payload.telemetry.misclick_count,
        "audio_replay_count": getattr(payload.telemetry, "audio_replay_count", 0),
        "scaffold_level_used": getattr(payload.telemetry, "scaffold_level_used", 0),
        "scaffold_applications": getattr(payload.telemetry, "scaffold_applications", None) or [],
        "attempt_count": getattr(payload.telemetry, "attempt_count", 0),
        "incorrect_attempt_count": getattr(payload.telemetry, "incorrect_attempt_count", 0),
        "first_attempt_correct": getattr(payload.telemetry, "first_attempt_correct", None),
        "correction_count": getattr(payload.telemetry, "correction_count", 0),
        "hint_count": getattr(payload.telemetry, "hint_count", 0),
        "item_role": getattr(payload.telemetry, "item_role", None),
        "item_version": payload.telemetry.item_version,
        "prompt_modality": payload.telemetry.prompt_modality,
        "response_modality": payload.telemetry.response_modality,
        "research_role": payload.telemetry.research_role,
        "difficulty_label": payload.telemetry.difficulty_label,
        "error_type": payload.telemetry.error_type,
        "equivalent_group_id": getattr(
            payload.telemetry, "equivalent_group_id", None
        ),
        "response_load_relation": getattr(
            payload.telemetry, "response_load_relation", None
        ),
        "targets": getattr(payload.telemetry, "target_ids", None) or [],
        "target_ids": getattr(payload.telemetry, "target_ids", None) or [],
        "selected_answers": (
            getattr(payload.telemetry, "selected_answers", None) or []
        ),
        # Keep both names because the real-time gateway and the batch
        # telemetry service historically used different field names.
        "touch_stream": payload.telemetry.touch_stream,
        "touch_path": payload.telemetry.touch_stream,
        "event_source": "learning_interaction",
    }
    # Prefer the v2 key, while reconciling one pre-v2 record in place when it
    # exists. This keeps retries idempotent without deleting legacy records.
    existing = await db.telemetry_events.find_one(
        {"ingestion_key": ingestion_key}, {"_id": 1}
    )
    if not existing:
        existing = await db.telemetry_events.find_one(
            {"event_id": event_id}, {"_id": 1}
        )
    event_filter = {"_id": existing["_id"]} if existing else {
        "ingestion_key": ingestion_key
    }
    await db.telemetry_events.update_one(
        event_filter,
        {"$set": telemetry_doc},
        upsert=existing is None,
    )

    # C1 descriptive processing is performed by authenticated end-of-session ingestion.
    # No duplicate call to the incompatible legacy /api/v1/c1/session route is made.

    # C4 owns adaptive-decision persistence.  The gateway stores the raw
    # telemetry event only; writing the decision here as well previously
    # produced two research rows for one child interaction.
    
    # Save Speech Features and Transcriptions separately as requested
    if payload.speech:
        speech_trans_doc = {
            "speech_event_id": event_id,
            "student_id": payload.student_id,
            "session_id": payload.session_id,
            "activity_id": payload.activity_id,
            "item_id": payload.item_id,
            "expected_text": payload.speech.get("expected_text", ""),
            "transcription": payload.speech.get("transcription", ""),
            "wer": payload.speech.get("word_error_rate", 0.0),
            "stt_confidence": 1.0 - (payload.speech.get("word_error_rate") or 0.0),
            "model_version": "whisper-si-v1",
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
        await db.speech_transcriptions.insert_one(speech_trans_doc)
        
        speech_feat_doc = {
            "speech_event_id": event_id,
            "student_id": payload.student_id,
            "session_id": payload.session_id,
            "activity_id": payload.activity_id,
            "item_id": payload.item_id,
            "acoustic_latency_ms": payload.speech.get("Acoustic_Latency_ms", 0),
            "voice_onset_ms": payload.speech.get("Voice_Onset_ms", 0),
            "detected_peaks": payload.speech.get("Detected_Peaks", 0),
            "expected_syllables": payload.speech.get("Expected_Syllables", 0),
            "peak_count_delta": payload.speech.get("Peak_Count_Delta", 0),
            "intra_word_silence_ratio": payload.speech.get("Intra_Word_Silence_Ratio", 0.0),
            "jitter": payload.speech.get("Local_Jitter", 0.0),
            "shimmer": payload.speech.get("Local_Shimmer", 0.0),
            "recording_quality": payload.speech.get("recording_quality", "good"),
            "analysis_confidence": 0.88 if payload.speech.get("recording_quality", "good") == "good" else 0.5,
            "feature_version": "speech-v1",
            "speech_data": payload.speech, # Kept for backward compatibility in other endpoints
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
        await db.speech_features.insert_one(speech_feat_doc)


@router.post("/interaction")
async def process_interaction(payload: InteractionPayload, background_tasks: BackgroundTasks):
    db = get_db()
    event_id = payload.event_id or str(uuid.uuid4())
    
    # --- CANONICALIZATION ---
    canonical_activity_id = payload.activity_id
    canonical_item_id = payload.item_id
    
    if payload.skill_id and payload.activity_id and payload.round_number is not None:
        s_match = re.search(r"skill_(\d+)", str(payload.skill_id))
        a_match = re.search(r"act_(\d+)", str(payload.activity_id))
        if s_match and a_match:
            s_num = s_match.group(1)
            a_num = a_match.group(1)
            canonical_activity_id = f"{s_num}.{a_num}"
            if payload.item_id and payload.item_id.startswith(f"S{s_num}A{a_num}"):
                canonical_item_id = payload.item_id
            else:
                canonical_item_id = f"S{s_num}A{a_num}R{payload.round_number:02d}"

    print(f"\n[LEARNING INTERACTION]")
    print(f"student={payload.student_id}")
    print(f"frontend skill={payload.skill_id}")
    print(f"frontend activity={payload.activity_id}")
    print(f"round={payload.round_number}")
    print(f"canonical activity={canonical_activity_id}")
    print(f"canonical item={canonical_item_id}")

    # Fetch latest fatigue from C1 and learner profile from C3 to inform C4
    c1 = await db.session_summaries.find_one({"student_id": payload.student_id}, sort=[("_id", -1)])
    c3 = await db.learner_profiles.find_one({"student_id": payload.student_id}, sort=[("_id", -1)])
    
    fatigue_score = (c1.get("behavioral_fatigue_proxy") or 0.0) if c1 else 0.0
    learner_profile_dict = c3.get("learner_profile", {}).get("class_probabilities", {}) if c3 else {}
    
    c4_result = {}
    async with httpx.AsyncClient() as client:
        # Call Adaptive Tutoring (C4) synchronously
        try:
            adaptive_submit = build_adaptive_submit(
                payload,
                event_id=event_id,
                canonical_activity_id=canonical_activity_id,
                canonical_item_id=canonical_item_id,
                fatigue_score=fatigue_score,
                learner_profile=learner_profile_dict,
            )
            
            adaptive_api_url = os.getenv("ADAPTIVE_API_URL", "http://localhost:9017")
            
            c4_resp = await client.post(
                f"{adaptive_api_url}/update_interaction",
                json=adaptive_submit,
                timeout=5.0
            )
            if c4_resp.status_code == 200:
                c4_result = c4_resp.json()
        except Exception as e:
            print(f"C4 pipeline error: {e}")
            c4_result = {}

    # Dispatch background tasks for ML processing and persistence
    background_tasks.add_task(run_background_pipeline, payload, c4_result, event_id)
    
    # Return immediately to unblock learner
    return {
        "result": {
            "is_correct": payload.response.is_correct
        },
        "next_action": c4_result.get("next_action", {}),
        "response_quality": c4_result.get("response_quality")
    }
