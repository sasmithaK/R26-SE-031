"""
routers/telemetry.py
====================
Telemetry ingestion and ML-powered cognitive analytics endpoints.

Endpoints:
  POST /api/v1/auth/telemetry          — Ingest an enriched telemetry session
  GET  /api/v1/auth/telemetry/{sid}    — Retrieve raw telemetry history
  GET  /api/v1/auth/telemetry/{sid}/analytics  — ML cognitive profile + risk report
"""

from fastapi import APIRouter, HTTPException, status, Depends, BackgroundTasks
from fastapi.responses import StreamingResponse
import io
import httpx
import asyncio
import os
import math
import re
from bson.objectid import ObjectId
from datetime import datetime, timezone

from database import get_db
from dependencies import get_current_user
from schemas.telemetry import TelemetrySessionSubmit
from services.ml_pipeline import generate_cognitive_profile, generate_comp2_profile
from services.ml_engine import CognitiveLoadClassifier
from services.report_generator import generate_pdf_report
from services.assessment_report_generator import generate_assessment_report
from services.behavioral_engine import extract_session_features
from services.comp2_kinematics import extract_comp2_features

router = APIRouter(prefix="/api/v1/auth", tags=["Telemetry"])


_CANONICAL_ITEM_RE = re.compile(
    r"^S(?P<skill>\d+)A(?P<activity>\d+)R(?P<round>\d{2})(?P<variant>V\d+)?$",
    re.IGNORECASE,
)


def _normalize_item_id(value: object) -> str:
    compact = re.sub(r"[_\-\s]", "", str(value or "")).upper()
    match = re.fullmatch(
        r"S(\d+)A(\d+)R(\d+)(V\d+)?",
        compact,
        re.IGNORECASE,
    )
    if not match:
        return compact
    return (
        f"S{int(match.group(1))}A{int(match.group(2))}"
        f"R{int(match.group(3)):02d}{(match.group(4) or '').upper()}"
    )


async def _validate_component_four_research_event(db, event: dict) -> None:
    """Validate immutable Skill 1-4 lineage against the canonical item bank.

    Observation fields are never rewritten. Static item metadata is copied
    from the bank, while any client mismatch is retained as an explicit audit
    error and makes the row ineligible for model calibration.
    """
    raw_item_id = str(event.get("item_id") or "")
    normalized_item_id = _normalize_item_id(raw_item_id)
    item_match = _CANONICAL_ITEM_RE.fullmatch(normalized_item_id)
    submitted_skill = str(event.get("skill_id") or "")
    item_skill_number = item_match.group("skill") if item_match else ""
    skill_number = (
        item_skill_number
        or (submitted_skill.removeprefix("skill_") if submitted_skill else "")
    )
    if skill_number not in {"1", "2", "3", "4"}:
        return
    canonical_skill_id = f"skill_{skill_number}"

    errors = []
    if raw_item_id != normalized_item_id:
        errors.append("NON_CANONICAL_ITEM_ID")
    bank_item = await db.item_bank.find_one({
        "item_id": normalized_item_id,
        "skill_id": canonical_skill_id,
        "is_active": {"$ne": False},
    })
    if bank_item is None:
        event["research_eligible"] = False
        event["research_validation_errors"] = [
            *errors,
            "ITEM_NOT_FOUND_IN_CANONICAL_BANK",
        ]
        return

    expected = {
        "skill_id": bank_item["skill_id"],
        "knowledge_component_id": bank_item["knowledge_component_id"],
        "prompt_modality": bank_item["prompt_modality"],
        "response_modality": bank_item["response_modality"],
        "item_role": bank_item["item_role"],
        "equivalent_group_id": bank_item["equivalent_group_id"],
        "response_load_relation": bank_item["response_load_relation"],
        "difficulty_label": bank_item["difficulty_label"],
        "difficulty_b": float(bank_item["difficulty_b"]),
        "is_anchor": bool(bank_item["is_anchor"]),
        "item_version": int(bank_item["item_version"]),
    }
    for field, expected_value in expected.items():
        submitted_value = event.get(field)
        if field == "difficulty_b":
            try:
                matches = abs(float(submitted_value) - expected_value) < 1e-9
            except (TypeError, ValueError):
                matches = False
        else:
            matches = submitted_value == expected_value
        if not matches:
            errors.append(f"{field.upper()}_MISMATCH")
            event[f"submitted_{field}"] = submitted_value
        event[field] = expected_value

    canonical_activity = str(bank_item["activity_id"])
    activity_number = canonical_activity.split(".")[-1]
    accepted_activity_ids = {
        canonical_activity,
        f"act_{activity_number}",
        f"{canonical_skill_id}_act_{activity_number}",
    }
    if event.get("activity_id") not in accepted_activity_ids:
        errors.append("ACTIVITY_ID_MISMATCH")
        event["submitted_activity_id"] = event.get("activity_id")
    event["canonical_activity_id"] = canonical_activity

    event["item_id"] = normalized_item_id
    event["research_eligible"] = not errors
    event["research_validation_errors"] = errors

async def _trigger_c3_background(student_id: str, session_summary: dict):
    """Fuse only explicitly linked, complete inputs. C1 accuracy is not path efficiency."""
    db = get_db()
    session_id = session_summary.get("session_id")
    audit = {"student_id": student_id, "session_id": session_id, "timestamp": datetime.now(timezone.utc),
             "model_name": "XGBoost", "validation_status": "synthetic_only"}
    try:
        speech = await db.speech_features.find_one({"student_id": student_id, "session_id": session_id}, sort=[("created_at", -1)]) or {}
        motion = await db.kinematic_features.find_one({"student_id": student_id, "session_id": session_id}, sort=[("timestamp", -1)]) or {}
        student = await db.students.find_one({"_id": ObjectId(student_id)}) or {}
        audio_names = {"acoustic_latency_ms": "acoustic_latency_ms", "peak_count_delta": "syllabic_event_mismatch",
                       "intra_word_silence_ratio": "intra_word_silence_ratio", "local_jitter": "local_jitter", "local_shimmer": "local_shimmer"}
        motion_names = ("time_to_first_touch_ms", "orthographic_confusion_index", "path_efficiency_ratio", "dimensionless_jerk", "dwell_time_ms")
        audio = {k: speech.get(v) for k,v in audio_names.items()}
        kinematics = {k: motion.get(k) for k in motion_names}
        demographics = {"student_age_months": student.get("age_months"), "gender": student.get("gender_code"),
                        "time_of_day_hour": session_summary.get("time_of_day_hour")}
        missing = [k for k,v in {**audio, **kinematics, **demographics}.items()
                   if not isinstance(v, (int,float)) or isinstance(v,bool) or not math.isfinite(v)]
        origins = {speech.get("data_origin"), motion.get("data_origin")}
        if origins not in ({"observed"}, {"synthetic"}):
            missing.append("consistent_explicit_modality_provenance")
        if speech.get("measurement_status") not in ("available", "valid", "synthetic_features"):
            missing.append("valid_speech_measurement")
        if speech.get("dataset_id") != motion.get("dataset_id"):
            missing.append("matched_dataset_id")
        if missing:
            await db.model_audit_log.insert_one({**audit, "status": "skipped_missing_inputs", "missing_features": missing})
            return
        payload = {"student_id": student_id, "session_id": session_id, "c1_audio_vector": audio,
                   "c2_kinematic_vector": kinematics, **demographics,
                   "data_origin": speech["data_origin"], "dataset_id": speech.get("dataset_id")}
        async with httpx.AsyncClient() as client:
            response = await client.post(os.getenv("FUSION_API_URL", "http://localhost:9016").rstrip("/") + "/diagnose", json=payload, timeout=15)
            response.raise_for_status()
        await db.model_audit_log.insert_one({**audit,"status":"fusion_requested","data_origin":speech["data_origin"]})
    except Exception:
        await db.model_audit_log.insert_one({**audit,"status":"fusion_failed"})


def _kinematic_events(events: list[dict]) -> list[dict]:
    """Normalize Flutter ratio/timestamp touch points for the C2 extractor."""
    normalized = []
    for event in events:
        source = event.get("touch_stream") or event.get("touch_path") or []
        points = []
        for point in source:
            if not isinstance(point, dict):
                continue
            points.append({
                "x": point.get("x_ratio", point.get("x", 0.0)),
                "y": point.get("y_ratio", point.get("y", 0.0)),
                "t": point.get("timestamp_ms", point.get("t", 0)),
                "type": str(point.get("type") or "").upper(),
            })
        if len(points) < 2:
            continue
        targets = event.get("targets") or event.get("target_ids") or []
        selected = event.get("selected_answers") or []
        normalized.append({
            **event,
            "touch_stream": points,
            "target_stimulus": targets[0] if targets else None,
            "selected_stimulus": selected[0] if selected else None,
        })
    return normalized

# ---------------------------------------------------------------------------
# POST /telemetry  — Ingest enriched telemetry session
# ---------------------------------------------------------------------------

@router.post("/telemetry", status_code=status.HTTP_201_CREATED)
async def submit_telemetry(
    req: TelemetrySessionSubmit,
    background_tasks: BackgroundTasks,
    current_user: dict = Depends(get_current_user),
):
    """
    Ingest a telemetry session payload after activity completion.

    The parent JWT is used to verify ownership of the student_id before
    storing any data — full data isolation is maintained.
    """
    db = get_db()

    try:
        student_oid = ObjectId(req.student_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid student ID format.",
        )

    # Ownership check — parent can only submit for their own students
    student = await db.students.find_one({"_id": student_oid})
    if not student or str(student.get("parent_id")) != str(current_user["_id"]):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student not found or does not belong to your account.",
        )

    # Persist to dedicated telemetry_sessions collection
    session_doc = req.model_dump()
    session_doc["student_id"] = str(student_oid)
    session_doc["submitted_at"] = datetime.now(timezone.utc).isoformat()
    session_doc["schema_version"] = "2.0"
    session_doc["data_origin"] = req.data_origin
    session_doc["dataset_id"] = req.dataset_id or f"live:{req.student_id}:{req.session_id}"
    session_doc["validation_status"] = "synthetic_pipeline_test" if req.data_origin == "synthetic" else "operational_observation"
    session_doc["calibration_eligible"] = False

    session_key = {"student_id": req.student_id, "session_id": req.session_id}
    existing_session = await db.telemetry_sessions.find_one(
        session_key, {"session_number": 1}
    )
    if existing_session and existing_session.get("session_number"):
        # An offline retry must retain its original longitudinal position.
        session_doc["session_number"] = existing_session["session_number"]
    else:
        # MongoDB is authoritative for longitudinal order. Older clients sent
        # `session_number: 1` for every standalone activity, so accepting the
        # client value would silently corrupt the research sequence.
        session_doc["session_number"] = (
            await db.telemetry_sessions.count_documents(
                {"student_id": req.student_id}
            )
        ) + 1

    # Defensively derive session lineage for older clients. Standalone level
    # activities resolve to one exact skill/activity; a multi-activity daily
    # session is explicitly labelled `mixed` rather than silently `unknown`.
    events_list = session_doc.get("events", [])
    for field in ("skill_id", "activity_id"):
        if session_doc.get(field) in (None, "", "unknown"):
            values = {
                str(event.get(field)).strip()
                for event in events_list
                if event.get(field) not in (None, "", "unknown")
            }
            if values:
                session_doc[field] = next(iter(values)) if len(values) == 1 else "mixed"

    # Validate and enrich immutable research lineage before either the session
    # or individual event copy is stored.
    for event in events_list:
        event["schema_version"] = "2.0"
        event["session_id"] = req.session_id
        event["student_id"] = req.student_id
        event["data_origin"] = session_doc["data_origin"]
        event["dataset_id"] = session_doc["dataset_id"]
        event["validation_status"] = session_doc["validation_status"]
        event["calibration_eligible"] = False
        await _validate_component_four_research_event(db, event)

    # Retried submissions update the same complete session and summary.
    await db.telemetry_sessions.update_one(session_key, {"$set": session_doc}, upsert=True)

    # Store individual events idempotently. Legacy databases may contain
    # repeated event_id values, so reconcile one old record and then use a
    # unique v2 ingestion key for all later retries.
    if events_list:
        for event in events_list:
            event_id = event.get("event_id")
            if not event_id:
                continue
            ingestion_key = f"{req.student_id}:{event_id}"
            event["ingestion_key"] = ingestion_key
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
                {"$set": event},
                upsert=existing is None,
            )

    validated_req = TelemetrySessionSubmit.model_validate(session_doc)
    summary = extract_session_features(validated_req).model_dump()
    summary.update({
        "data_origin": session_doc["data_origin"],
        "dataset_id": session_doc["dataset_id"],
        "validation_status": session_doc["validation_status"],
        "calibration_eligible": False,
    })
    await db.session_summaries.update_one(
        {"student_id": req.student_id, "session_id": req.session_id},
        {"$set": summary}, upsert=True,
    )

    normalized_motion = _kinematic_events(events_list)
    if normalized_motion:
        motion = extract_comp2_features(normalized_motion)
        motion_doc = {
            "student_id": req.student_id,
            "session_id": req.session_id,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "feature_version": "kinematics-v2",
            "measurement_status": "available",
            "data_origin": session_doc["data_origin"],
            "dataset_id": session_doc["dataset_id"],
            "validation_status": session_doc["validation_status"],
            **motion,
            "dwell_time_ms": motion.get("mean_dwell_time_ms", 0.0),
        }
        await db.kinematic_features.update_one(
            {"student_id": req.student_id, "session_id": req.session_id},
            {"$set": motion_doc},
            upsert=True,
        )

    # Assess real-time cognitive load
    events_list = session_doc.get("events", [])
    cognitive_load = CognitiveLoadClassifier.classify(events_list)

    # Process & Save C1 State for Therapist/Parent dashboards
    from services.c1.processor import process_session
    from services.ml.inference import predict_c1_pattern
    from repositories import c1_repository
    
    try:
        events_data = [
            e.model_dump() if hasattr(e, "model_dump") else dict(e)
            for e in validated_req.events
        ]
        for e in events_data:
            e["session_id"] = req.session_id
            e["student_id"] = req.student_id
            
        c1_partial = process_session(req.session_id, req.student_id, events_data)
        model_metadata = predict_c1_pattern(c1_partial["behavior"])
        c1_partial["model"] = model_metadata
        await c1_repository.save_c1_state(c1_partial)
    except Exception as err:
        print(f"C1 processing error in telemetry router: {err}")

    # Trigger C3 Background Fusion
    background_tasks.add_task(_trigger_c3_background, str(student_oid), summary)

    return {
        "message": "Telemetry session logged successfully.",
        "cognitive_load": cognitive_load
    }


# ---------------------------------------------------------------------------
# GET /telemetry/{student_id}  — Raw telemetry history
# ---------------------------------------------------------------------------

@router.get("/telemetry/{student_id}")
async def get_telemetry(
    student_id: str,
    current_user: dict = Depends(get_current_user),
):
    """
    Retrieve raw telemetry session history for a student.

    Access is granted to: (a) the owning parent, or (b) a connected specialist.
    """
    db = get_db()

    try:
        student_oid = ObjectId(student_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid student ID format.",
        )

    if current_user.get("role") == "specialist":
        connection = await db.connections.find_one({
            "student_id": student_id,
            "specialist_id": str(current_user["_id"]),
        })
        if not connection:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Not connected to this student.",
            )
    else:
        student = await db.students.find_one(
            {"_id": student_oid, "parent_id": current_user["_id"]}
        )
        if not student:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Student not found.",
            )

    cursor = db.telemetry_sessions.find(
        {"student_id": student_id, "schema_version": "2.0"}
    ).sort("submitted_at", -1).limit(200)

    sessions = await cursor.to_list(length=200)
    for s in sessions:
        s["id"] = str(s["_id"])
        del s["_id"]

    return sessions


@router.get("/telemetry/{student_id}/c3-ready")
async def get_c3_ready_features(
    student_id: str,
    current_user: dict = Depends(get_current_user),
):
    """
    Retrieve feature bundle formatted for Component 3 fusion models.
    Aggregates KC-level performance and phonological metrics.
    """
    db = get_db()
    cursor = db.telemetry_events.find({"student_id": student_id})
    events = await cursor.to_list(length=1000)
    if not events:
        raise HTTPException(status_code=404, detail="No telemetry events found")

    akshara_events = [e for e in events if e.get("knowledge_component_id") == "KC_AKSHARA_IDENTITY"]
    word_events = [e for e in events if e.get("knowledge_component_id") == "KC_WORD_RECOGNITION"]

    akshara_acc = sum(1 for e in akshara_events if e.get("is_correct")) / len(akshara_events) if akshara_events else 0.0
    akshara_lat = float(akshara_events[0].get("first_touch_latency_ms", 0)) if akshara_events else 0.0

    word_acc = sum(1 for e in word_events if e.get("is_correct")) / len(word_events) if word_events else 0.0
    word_lat = float(word_events[0].get("total_round_latency_ms", 0)) if word_events else 0.0

    overall_acc = sum(1 for e in events if e.get("is_correct")) / len(events) if events else 0.0
    phono_rate = sum(1 for e in events if e.get("error_type") == "phonological_confusion") / len(events) if events else 0.0

    return {
        "student_id": student_id,
        "akshara_accuracy": akshara_acc,
        "akshara_median_latency_ms": akshara_lat,
        "word_recognition_accuracy": word_acc,
        "word_recognition_median_latency_ms": word_lat,
        "overall_accuracy": overall_acc,
        "phonological_confusion_rate": phono_rate,
    }


# ---------------------------------------------------------------------------
# GET /telemetry/{student_id}/analytics  — ML Cognitive Profile
# ---------------------------------------------------------------------------

@router.get("/telemetry/{student_id}/analytics")
async def get_cognitive_analytics(
    student_id: str,
    current_user: dict = Depends(get_current_user),
):
    """
    Run the ML Analytics Pipeline over all telemetry sessions for a student
    and return a structured cognitive profile including:
      - 4 cognitive index scores (0-100)
      - Dyslexia subtype risk classification
      - Personalized intervention recommendations

    Access is granted to: (a) the owning parent, or (b) a connected specialist.
    """
    db = get_db()

    try:
        student_oid = ObjectId(student_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid student ID format.",
        )

    # Permission check
    if current_user.get("role") == "specialist":
        connection = await db.connections.find_one({
            "student_id": student_id,
            "specialist_id": str(current_user["_id"]),
        })
        if not connection:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Not connected to this student.",
            )
    else:
        student = await db.students.find_one(
            {"_id": student_oid, "parent_id": current_user["_id"]}
        )
        if not student:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Student not found.",
            )

    # Retrieve up to 500 most recent sessions for the pipeline
    cursor = db.telemetry_events.find(
        {"student_id": student_id}
    ).sort("submitted_at", -1).limit(500)
    sessions = await cursor.to_list(length=500)

    if not sessions:
        return {
            "student_id": student_id,
            "status": "insufficient_data",
            "message": "Complete at least one activity to generate a cognitive profile.",
            "data_points": 0,
        }

    # Fetch assessment_risk_score
    comp_results = student.get("comprehensive_assessment_results", {})
    total_yes = sum(sum(1 for a in ans if a is True) for ans in comp_results.values() if isinstance(ans, list))
    total_q = sum(len(ans) for ans in comp_results.values() if isinstance(ans, list))
    assessment_risk_score = total_yes / max(total_q, 1)

    # Run ML pipeline
    profile = generate_cognitive_profile(sessions, assessment_risk_score=assessment_risk_score)

    # Persist / upsert the latest cognitive profile for this student
    await db.cognitive_profiles.update_one(
        {"student_id": student_id},
        {
            "$set": {
                **profile,
                "student_id": student_id,
                "last_updated": datetime.now(timezone.utc).isoformat(),
            }
        },
        upsert=True,
    )

    return {
        "student_id": student_id,
        "status": "ok",
        **profile,
    }

# ---------------------------------------------------------------------------
# GET /telemetry/{student_id}/comp2  — Component 2 Feature Vector (Integration)
# ---------------------------------------------------------------------------

@router.get("/telemetry/{student_id}/comp2")
async def get_comp2_analytics(
    student_id: str,
    current_user: dict = Depends(get_current_user),
):
    """
    Returns the Component 2 specific visual-orthographic kinematic feature vector.
    Used for integration with Component 3 (Fusion Engine).
    """
    db = get_db()
    
    try:
        student_oid = ObjectId(student_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid student ID format.",
        )
        
    cursor = db.telemetry_events.find(
        {"student_id": student_id}
    ).sort("submitted_at", -1).limit(500)
    sessions = await cursor.to_list(length=500)
    
    if not sessions:
        return {
            "student_id": student_id,
            "status": "insufficient_data",
            "message": "Complete at least one visual orthographic activity."
        }
        
    comp2_profile = generate_comp2_profile(sessions)
    
    return comp2_profile

# ---------------------------------------------------------------------------
# GET /telemetry/{student_id}/report/pdf  — Clinical PDF Report
# ---------------------------------------------------------------------------

@router.get("/telemetry/{student_id}/report/pdf")
async def get_clinical_report_pdf(
    student_id: str,
    current_user: dict = Depends(get_current_user),
):
    """
    Generate a formatted clinical PDF report of the student's telemetry and cognitive profile.
    """
    db = get_db()
    
    try:
        student_oid = ObjectId(student_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid student ID format.",
        )

    # Permission check
    if current_user.get("role") == "specialist":
        connection = await db.connections.find_one({
            "student_id": student_id,
            "specialist_id": str(current_user["_id"]),
        })
        if not connection:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Not connected to this student.",
            )
    else:
        student = await db.students.find_one(
            {"_id": student_oid, "parent_id": current_user["_id"]}
        )
        if not student:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Student not found.",
            )
            
    # Need student name
    student_name = student.get("first_name", "Unknown") if 'student' in locals() else "Student"
    if 'student' not in locals():
        student = await db.students.find_one({"_id": student_oid})
        student_name = student.get("first_name", "Unknown") if student else "Unknown"
        
    # Get profile
    profile = await db.cognitive_profiles.find_one({"student_id": student_id})
    if not profile:
        raise HTTPException(status_code=404, detail="No cognitive profile found for this student. Complete an activity first.")
        
    # Get sessions
    cursor = db.telemetry_events.find({"student_id": student_id}).sort("submitted_at", -1)
    sessions = await cursor.to_list(length=500)
    
    pdf_bytes = generate_pdf_report(student_name, profile, sessions)
    
    return StreamingResponse(
        io.BytesIO(pdf_bytes),
        media_type="application/pdf",
        headers={"Content-Disposition": f"attachment; filename=Clinical_Report_{student_id}.pdf"}
    )

# ---------------------------------------------------------------------------
# GET /telemetry/export/csv  — Data Lake ML Export
# ---------------------------------------------------------------------------
import csv

@router.get("/telemetry/export/csv")
async def export_telemetry_csv(
    current_user: dict = Depends(get_current_user),
):
    """
    Export all raw telemetry flattened for Data Lake / ML training.
    In production, restrict this to Admin/Data Scientists only.
    """
    # Simple permission check
    if current_user.get("role") not in ("admin", "specialist"):
        raise HTTPException(status_code=403, detail="Not authorized to export data lake.")
        
    db = get_db()
    cursor = db.telemetry_events.find({}).sort("submitted_at", -1)
    
    # We will flatten the session and events
    output = io.StringIO()
    writer = csv.writer(output)
    
    # Headers
    headers = [
        "session_id", "student_id", "submitted_at", "session_duration",
        "activity_name", "round_number", "is_correct", "score",
        "first_touch_latency_ms", "total_round_latency_ms", "misclick_count",
        "hesitation_count", "audio_replay_count",
        "is_abandoned", "device_os", "device_model"
    ]
    writer.writerow(headers)
    
    async for session in cursor:
        s_id = str(session["_id"])
        st_id = session.get("student_id", "")
        sub_at = session.get("submitted_at", "")
        dur = session.get("session_duration_seconds", 0)
        
        dev = session.get("device_metrics", {})
        d_os = dev.get("os", "unknown")
        d_mod = dev.get("model", "unknown")
        
        for e in session.get("events", []):
            row = [
                s_id, st_id, sub_at, dur,
                e.get("activity_name", ""),
                e.get("round_number", 0),
                e.get("is_correct", False),
                e.get("score", 0),
                e.get("first_touch_latency_ms", 0),
                e.get("total_round_latency_ms", 0),
                e.get("misclick_count", 0),
                e.get("hesitation_count", 0),
                e.get("audio_replay_count", 0),
                e.get("is_abandoned", False),
                d_os, d_mod
            ]
            writer.writerow(row)

    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=sipsara_telemetry_datalake.csv"}
    )


# ---------------------------------------------------------------------------
# GET /students/{student_id}/assessment/report/pdf
# ---------------------------------------------------------------------------
@router.get("/students/{student_id}/assessment/report/pdf")
async def get_assessment_report_pdf(student_id: str, current_user: dict = Depends(get_current_user)):
    """Generate and return a PDF report of the student's comprehensive assessment answers."""
    try:
        obj_id = ObjectId(student_id)
    except Exception:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid student ID")

    db = get_db()
    
    # Allow either the parent or the assigned therapist to access this
    student = await db.students.find_one({"_id": obj_id})
    if not student:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")
        
    is_parent = student.get("parent_id") == current_user["_id"]
    is_therapist = current_user.get("role") == "therapist" and student.get("therapist_id") == current_user["_id"]
    
    if not (is_parent or is_therapist):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized to view this student's assessment")
        
    pdf_bytes = generate_assessment_report(student)
    
    return StreamingResponse(
        io.BytesIO(pdf_bytes), 
        media_type="application/pdf", 
        headers={"Content-Disposition": f"attachment; filename=Assessment_Report_{student_id}.pdf"}
    )
