from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
import logging
from datetime import datetime, timedelta, timezone
import os
import math
from bson import ObjectId

from schemas import FusionRequest, FusionResponse, SessionFusionRequest, EvidenceChatRequest
from services.xai_engine import get_xai_engine, XAIEngine
from services.llm_explainer import generate_diagnostic_summary, answer_evidence_question
from database import connect_to_mongo, close_mongo_connection, get_db
from auth import get_current_user, require_student_access

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("Initializing XAI Engine and MongoDB...")
    await connect_to_mongo()
    await get_db().command("ping")
    engine = get_xai_engine()
    if engine is None or engine.model is None or engine.explainer is None:
        raise RuntimeError("C3 model artifacts did not load")
    logger.info("C3 XGBoost, SHAP, and MongoDB initialized successfully.")
    yield
    # Shutdown
    await close_mongo_connection()

app = FastAPI(
    title="C3 — Diagnostic Fusion & XAI Engine",
    description="Multi-Modal Late Fusion XGBoost API with SHAP Explainability",
    version="1.0.0",
    lifespan=lifespan,
    root_path=os.getenv("ROOT_PATH", ""),
)

# CORS config
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
def health_check():
    engine = get_xai_engine()
    healthy = bool(engine and engine.model is not None and engine.explainer is not None)
    return JSONResponse(
        status_code=200 if healthy else 503,
        content={"status": "ok" if healthy else "degraded", "service": "diagnostic-fusion-v1",
                 "model": "ready" if healthy else "unavailable"},
    )


@app.get("/ready")
async def readiness_check():
    engine = get_xai_engine()
    model_ready = bool(engine and engine.model is not None and engine.explainer is not None)
    database_ready = False
    error_type = None
    try:
        await get_db().command("ping")
        database_ready = True
    except Exception as exc:
        error_type = type(exc).__name__
    auth_ready = bool(os.getenv("JWT_SECRET_KEY") or os.getenv("JWT_SECRET"))
    ready = model_ready and database_ready and auth_ready
    return JSONResponse(
        status_code=200 if ready else 503,
        content={"ready": ready, "service": "diagnostic-fusion-v1",
                 "model": "ready" if model_ready else "unavailable",
                 "database": "ready" if database_ready else "unavailable",
                 "authentication": "configured" if auth_ready else "missing",
                 "error_type": error_type},
    )


def _number(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    value = float(value)
    return value if math.isfinite(value) else None


def _chat_observation_rows(student: dict) -> list:
    """Return a small, text-only view of the current parent questionnaire answers."""
    groups = student.get("comprehensive_assessment_results") or {}
    rows = []
    if isinstance(groups, dict):
        for category, answers in groups.items():
            if not isinstance(answers, list):
                continue
            for item in answers:
                if isinstance(item, dict):
                    question = (item.get("question_en") or item.get("question") or
                                item.get("question_text") or item.get("text"))
                    answer = item.get("answer", item.get("value"))
                else:
                    question, answer = None, item
                rows.append({
                    "category": str(category)[:40],
                    "question": str(question)[:240] if question is not None else None,
                    "answer": answer if isinstance(answer, (bool, int, float, str)) else str(answer)[:120],
                })
    if not rows and isinstance(student.get("assessment_results"), list):
        for item in student["assessment_results"]:
            if isinstance(item, dict):
                rows.append({
                    "category": "basic",
                    "question": str(item.get("question_en") or item.get("question") or
                                     item.get("question_text") or "")[:240],
                    "answer": item.get("answer", item.get("value")),
                })
            else:
                rows.append({"category": "basic", "question": None, "answer": item})
    return rows[:80]


def _chat_context_from_records(sessions: list, speech_rows: list, student: dict) -> dict:
    """Whitelist observed fields; never pass identifiers, profiles, or raw audio to the LLM."""
    c1_fields = ("accuracy", "retry_rate", "correction_rate", "median_response_latency_ms",
                 "mean_attempts_per_round", "median_time_to_correct_ms", "error_rate", "trials")
    activity_fields = ("skill_id", "activity_id", "activity_name", "trials", "accuracy",
                       "retry_rate", "abandoned_trials", "median_response_latency_ms")
    c1 = []
    for row in sessions:
        overall = row.get("overall") or {}
        activities = row.get("activity_breakdown_by_skill") or row.get("activity_breakdown") or {}
        compact_activities = []
        if isinstance(activities, dict):
            for metrics in list(activities.values())[:12]:
                if isinstance(metrics, dict):
                    compact_activities.append({key: metrics[key] for key in activity_fields if key in metrics})
        c1.append({
            "session_date": str(row.get("completed_at") or row.get("timestamp") or "")[:40],
            "skill_id": row.get("skill_id"),
            "overall": {key: overall[key] for key in c1_fields if key in overall},
            "activities": compact_activities,
        })

    c2_fields = ("skill_id", "activity_id", "expected_text", "recognized_text", "exact_match",
                 "word_accuracy", "word_error_rate", "grapheme_accuracy", "grapheme_error_rate",
                 "acoustic_latency_ms", "syllabic_event_mismatch", "intra_word_silence_ratio",
                 "pause_ratio", "reading_rate_wpm", "recording_quality", "measurement_status")
    c2 = []
    for row in speech_rows:
        compact = {key: row[key] for key in c2_fields if key in row}
        compact["recorded_at"] = str(row.get("created_at") or row.get("timestamp") or "")[:40]
        # Keep transcript strings bounded; never transfer the uploaded recording itself.
        for key in ("expected_text", "recognized_text"):
            if isinstance(compact.get(key), str):
                compact[key] = compact[key][:240]
        c2.append(compact)

    return {
        "activity_observations_c1": c1,
        "reading_observations_c2": c2,
        "parent_reported_observations": _chat_observation_rows(student),
    }


@app.post("/chat/students/{student_id}")
async def chat_about_student_evidence(
    student_id: str,
    request: EvidenceChatRequest,
    current_user: dict = Depends(get_current_user),
):
    """Therapist-only, read-only chat grounded in this student's C1/C2/questionnaire records."""
    if current_user.get("role") not in {"therapist", "specialist"}:
        raise HTTPException(status_code=403, detail="This assistant is available to connected therapists only")
    await require_student_access(student_id, current_user)
    if not 1 <= len(request.messages) <= 8 or request.messages[-1].role != "user":
        raise HTTPException(status_code=422, detail="Provide 1–8 recent messages ending with a question")

    db = get_db()
    try:
        student = await db.students.find_one({"_id": ObjectId(student_id)}) or {}
    except Exception:
        raise HTTPException(status_code=422, detail="Invalid student_id")

    session_cursor = db.session_summaries.find({"student_id": student_id}).sort(
        [("completed_at", -1), ("timestamp", -1), ("_id", -1)]
    ).limit(12)
    speech_cursor = db.speech_features.find({"student_id": student_id}).sort(
        [("created_at", -1), ("timestamp", -1), ("_id", -1)]
    ).limit(12)
    sessions, speech_rows = await session_cursor.to_list(length=12), await speech_cursor.to_list(length=12)
    evidence = _chat_context_from_records(sessions, speech_rows, student)
    try:
        answer = await answer_evidence_question(
            evidence,
            [{"role": item.role, "content": item.content} for item in request.messages],
        )
    except RuntimeError as exc:
        status_code = 503 if "not configured" in str(exc).lower() else 502
        raise HTTPException(status_code=status_code, detail=str(exc))
    return {
        "answer": answer,
        "evidence_counts": {
            "activity_sessions": len(sessions),
            "reading_samples": len(speech_rows),
            "parent_observations": len(evidence["parent_reported_observations"]),
        },
        "stored": False,
    }


def _questionnaire_yes_count(student: dict) -> int:
    """Count unique current parent observations without double-counting basic."""
    comprehensive = student.get("comprehensive_assessment_results") or {}
    groups = list(comprehensive.values())
    if not comprehensive.get("basic"):
        groups.append(student.get("assessment_results") or [])
    seen, total = set(), 0
    for rows in groups:
        if not isinstance(rows, list):
            continue
        for index, item in enumerate(rows):
            if isinstance(item, dict):
                identity = item.get("id") or item.get("question") or (id(rows), index)
                answer = item.get("answer") is True
            else:
                identity, answer = (id(rows), index), item is True
            if answer and identity not in seen:
                seen.add(identity)
                total += 1
    return total


def _build_observed_summary(summary: dict, speech: dict, student: dict):
    overall = summary.get("overall") or {}
    accuracy = _number(overall.get("accuracy"))
    retry_rate = _number(overall.get("retry_rate"))
    word_accuracy = _number(speech.get("word_accuracy"))
    grapheme_accuracy = _number(speech.get("grapheme_accuracy"))
    speech_status = speech.get("measurement_status") or "unavailable"
    questionnaire_count = _questionnaire_yes_count(student)

    statements = []
    if accuracy is not None:
        statements.append(f"First-attempt activity accuracy was {round(accuracy * 100)}%.")
    if retry_rate is not None:
        statements.append(f"Extra attempts were used in {round(retry_rate * 100)}% of completed rounds.")
    if word_accuracy is not None:
        statements.append(f"Recorded-word agreement was {round(word_accuracy * 100)}% in the latest reading practice sample.")
    elif speech:
        statements.append("The latest oral reading practice audio was recorded.")
    if questionnaire_count:
        statements.append(f"The parent reported {questionnaire_count} learning observations in the questionnaires.")
    if not statements:
        statements.append("More completed activity observations are needed for a combined learning summary.")

    priorities = []
    if retry_rate is not None and retry_rate >= float(os.getenv("C3_SUMMARY_RETRY_RATE", "0.35")):
        priorities.append("Use short practice sets and observe whether support reduces repeated attempts.")
    if (word_accuracy is not None and word_accuracy < float(os.getenv("C3_SUMMARY_WORD_ACCURACY", "0.70"))
            and speech_status in {"valid", "available"}):
        priorities.append("Repeat familiar oral-reading items and compare several clear recordings over time.")
    if questionnaire_count:
        priorities.append("Compare parent observations with patterns repeated across several activities.")
    if not priorities:
        priorities.append("Continue regular practice and review the trend after more sessions.")

    evidence = {
        "c1": {
            "first_attempt_accuracy": accuracy,
            "retry_rate": retry_rate,
            "correction_rate": _number(overall.get("correction_rate")),
            "median_response_latency_ms": _number(overall.get("median_response_latency_ms")),
        },
        "c2": {
            "measurement_status": speech_status,
            "word_accuracy": word_accuracy,
            "grapheme_accuracy": grapheme_accuracy,
            "recording_quality": speech.get("recording_quality"),
        },
        "parent_observation_count": questionnaire_count,
    }
    return " ".join(statements), " ".join(priorities), evidence


# --- Learner-window fusion ---------------------------------------------------
# C3 fuses a learner's recent evidence over a time window instead of one
# session: touch activities (Skills 1-4) and reading (Skills 5-6) are recorded
# in different sessions, so a per-session join almost never has both. Missing
# measurements are never replaced with default values; the model is skipped
# and the missing evidence is reported instead.
C3_WINDOW_DAYS = int(os.getenv("C3_WINDOW_DAYS", "14"))
C3_MIN_USABLE_RECORDINGS = int(os.getenv("C3_MIN_USABLE_RECORDINGS", "2"))
C3_MIN_MOVEMENT_SESSIONS = int(os.getenv("C3_MIN_MOVEMENT_SESSIONS", "2"))
C3_MODEL_VERSION = "C3-v1.2"
C3_FEATURE_VERSION = "c3-learner-window-v1"

SPEECH_FEATURE_SOURCES = {
    "acoustic_latency_ms": ("acoustic_latency_ms",),
    "peak_count_delta": ("syllabic_event_mismatch", "peak_count_delta"),
    "intra_word_silence_ratio": ("intra_word_silence_ratio",),
    "local_jitter": ("local_jitter",),
    "local_shimmer": ("local_shimmer",),
}
MOTION_FEATURE_SOURCES = {
    "time_to_first_touch_ms": ("time_to_first_touch_ms",),
    "orthographic_confusion_index": ("orthographic_confusion_index",),
    "path_efficiency_ratio": ("path_efficiency_ratio",),
    "dimensionless_jerk": ("dimensionless_jerk",),
    "dwell_time_ms": ("dwell_time_ms", "mean_dwell_time_ms"),
}
USABLE_SPEECH_STATUSES = {"valid", "available"}


def _row_time(row: dict):
    for key in ("completed_at", "created_at", "timestamp", "updated_at"):
        value = row.get(key)
        if isinstance(value, datetime):
            return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
        if isinstance(value, str) and value:
            try:
                parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
                return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)
            except ValueError:
                continue
    oid = row.get("_id")
    return oid.generation_time if isinstance(oid, ObjectId) else None


async def _recent(db, collection: str, student_id: str, since: datetime, limit: int = 300):
    rows = await db[collection].find({"student_id": student_id}).sort("_id", -1).to_list(length=limit)
    return [row for row in rows if (_row_time(row) or since) >= since]


def _median_feature(rows: list, sources: tuple):
    values = []
    for row in rows:
        for key in sources:
            value = _number(row.get(key))
            if value is not None:
                values.append(value)
                break
    if not values:
        return None, 0
    values.sort()
    mid = len(values) // 2
    median = values[mid] if len(values) % 2 else (values[mid - 1] + values[mid]) / 2
    return median, len(values)


def _student_age_years(student: dict):
    months = _number(student.get("age_months"))
    if months is None and student.get("birth_year") and student.get("birth_month"):
        try:
            today = datetime.now(timezone.utc)
            months = (today.year - int(student["birth_year"])) * 12 + (today.month - int(student["birth_month"]))
        except (TypeError, ValueError):
            months = None
    if months is not None:
        return months // 12
    return _number(student.get("age"))


def _student_gender_code(student: dict):
    code = student.get("gender_code")
    if code in (0, 1):
        return code
    return {"female": 0, "girl": 0, "male": 1, "boy": 1}.get(str(student.get("gender", "")).strip().lower())


@app.post("/diagnose/session")
async def diagnose_saved_session(
    request: SessionFusionRequest,
    engine: XAIEngine = Depends(get_xai_engine),
    current_user: dict = Depends(get_current_user),
):
    """Idempotently fuse the learner's recent C1 + C2 evidence (window-based)."""
    await require_student_access(request.student_id, current_user)
    if engine is None or engine.model is None or engine.explainer is None:
        raise HTTPException(status_code=503, detail="C3 pattern model is unavailable")
    db = get_db()
    try:
        student = await db.students.find_one({"_id": ObjectId(request.student_id)}) or {}
    except Exception:
        raise HTTPException(status_code=422, detail="Invalid student_id")

    now = datetime.now(timezone.utc)
    since = now - timedelta(days=C3_WINDOW_DAYS)
    summaries = await _recent(db, "session_summaries", request.student_id, since)
    speech_rows = await _recent(db, "speech_features", request.student_id, since)
    motion_rows = await _recent(db, "kinematic_features", request.student_id, since)
    usable_speech = [row for row in speech_rows if row.get("measurement_status") in USABLE_SPEECH_STATUSES]

    # Narrative uses the most recent observed records (descriptive only).
    narrative, recommendation, evidence = _build_observed_summary(
        summaries[0] if summaries else {}, usable_speech[0] if usable_speech else (speech_rows[0] if speech_rows else {}), student,
    )

    model_inputs, feature_counts, missing = {}, {}, []
    if len(usable_speech) < C3_MIN_USABLE_RECORDINGS:
        missing.append(f"usable_reading_recordings ({len(usable_speech)} of {C3_MIN_USABLE_RECORDINGS})")
    if len(motion_rows) < C3_MIN_MOVEMENT_SESSIONS:
        missing.append(f"touch_movement_sessions ({len(motion_rows)} of {C3_MIN_MOVEMENT_SESSIONS})")
    for name, sources in SPEECH_FEATURE_SOURCES.items():
        value, count = _median_feature(usable_speech, sources)
        feature_counts[name] = count
        if value is None:
            missing.append(name)
        else:
            model_inputs[name] = value
    for name, sources in MOTION_FEATURE_SOURCES.items():
        value, count = _median_feature(motion_rows, sources)
        feature_counts[name] = count
        if value is None:
            missing.append(name)
        else:
            model_inputs[name] = value

    age_years = _student_age_years(student)
    if age_years is None:
        missing.append("age")
    else:
        model_inputs["age"] = float(age_years)
    gender = _student_gender_code(student)
    marginalize = {}
    if gender is None:
        marginalize["gender"] = [0.0, 1.0]  # averaged out, not invented
    else:
        model_inputs["gender"] = float(gender)
    latest_time = max((t for t in (_row_time(r) for r in usable_speech + motion_rows) if t), default=now)
    model_inputs["time_of_day_hour"] = float(latest_time.hour)

    measurement_notes = []
    if any((row.get("orthographic_confusion_coverage") == 0) for row in motion_rows):
        measurement_notes.append("Letter-confusion index covers only the letter pairs in the confusion map.")
    if marginalize:
        measurement_notes.append("Gender not recorded: estimate averaged over both values.")

    modalities = []
    if summaries or motion_rows:
        modalities.append("learning activities & touch")
    if speech_rows:
        modalities.append("oral reading speech")
    if evidence["parent_observation_count"]:
        modalities.append("parent observations")

    learner_profile = {
        "class_probabilities": {}, "primary_pattern": "Unavailable",
        "confidence": None, "modalities_used": modalities,
        "final_predicted_risk": None,
    }
    shap_explanations = {"top_contributing_features": []}
    model_applied = False
    if not missing:
        result = engine.analyze_patient(model_inputs, marginalize=marginalize)
        learner_profile = {**result["learner_profile"], "modalities_used": modalities}
        shap_explanations = result["shap_explanations"]
        model_applied = True
        pipeline_status = "model_and_summary_ready"
    else:
        pipeline_status = "insufficient_evidence" if (summaries or speech_rows or motion_rows) else "no_evidence"

    origins = {row.get("data_origin", "observed") for row in summaries + speech_rows + motion_rows}
    data_origin = origins.pop() if len(origins) == 1 else ("mixed" if origins else request.data_origin)
    document = {
        "student_id": request.student_id, "session_id": request.session_id,
        "data_origin": data_origin, "dataset_id": f"window:{request.student_id}:{C3_WINDOW_DAYS}d",
        "validation_status": "synthetic_trained_model",
        "model_provenance": "multimodal_pattern_model_trained_on_synthetic_data",
        "pipeline_status": pipeline_status, "model_applied": model_applied,
        "missing_inputs": missing, "learner_profile": learner_profile,
        "shap_explanations": shap_explanations, "llm_summary": narrative,
        "llm_recommendations": recommendation, "evidence_summary": evidence,
        "evidence_window": {
            "days": C3_WINDOW_DAYS, "start": since.isoformat(), "end": now.isoformat(),
            "activity_sessions": len(summaries), "movement_sessions": len(motion_rows),
            "recordings": len(speech_rows), "usable_recordings": len(usable_speech),
            "min_usable_recordings": C3_MIN_USABLE_RECORDINGS,
            "min_movement_sessions": C3_MIN_MOVEMENT_SESSIONS,
            "feature_counts": feature_counts,
        },
        "model_inputs": model_inputs if model_applied else {},
        "measurement_notes": measurement_notes,
        "model_version": C3_MODEL_VERSION, "feature_version": C3_FEATURE_VERSION,
        "updated_at": now,
    }
    # One current profile per learner window (latest wins); history is kept
    # in the audit log.
    await db.learner_profiles.update_one(
        {"student_id": request.student_id, "feature_version": C3_FEATURE_VERSION},
        {"$set": document, "$setOnInsert": {"created_at": now}}, upsert=True,
    )
    await db.model_audit_log.insert_one({
        "student_id": request.student_id, "session_id": request.session_id,
        "model_name": "XGBoost", "model_version": C3_MODEL_VERSION,
        "timestamp": now, "status": pipeline_status, "missing_features": missing,
        "model_applied": model_applied, "validation_status": document["validation_status"],
        "input_features": model_inputs if model_applied else {},
        "output_probabilities": learner_profile.get("class_probabilities"),
    })
    return {"student_id": request.student_id, "session_id": request.session_id,
            "pipeline_status": pipeline_status, "model_applied": model_applied,
            "missing_inputs": missing, "summary": narrative,
            "recommendations": recommendation}

@app.post("/diagnose")
async def diagnose_patient(
    request: FusionRequest,
    engine: XAIEngine = Depends(get_xai_engine),
    current_user: dict = Depends(get_current_user),
):
    """
    Ingests multimodal vectors and returns an experimental synthetic-trained learning-pattern classification
    along with SHAP explanations.
    """
    await require_student_access(request.student_id, current_user)
    if engine is None or engine.model is None:
        return JSONResponse(
            status_code=503, 
            content={"status": "model_unavailable", "student_id": request.student_id}
        )
        
    try:
        # Flatten the request into a single dictionary matching the feature columns
        flat_features = {}
        flat_features.update(request.c1_audio_vector.dict())
        flat_features.update(request.c2_kinematic_vector.dict())
        # Convert age from months to years to match training data scale (range 5-7 years)
        flat_features["age"] = request.student_age_months // 12
        flat_features["gender"] = request.gender
        flat_features["time_of_day_hour"] = request.time_of_day_hour
        
        # Analyze
        analysis_result = engine.analyze_patient(flat_features)
        
        # Extract simple SHAP dictionary for the LLM
        # Note: the key is "shap_impact" (formatted string), not "shap_value"
        simple_shap = {item["feature_name"]: item["shap_impact"] 
                       for item in analysis_result["shap_explanations"]["top_contributing_features"]}
        
        # Call LLM Explainer asynchronously
        llm_summary, llm_recommendations = await generate_diagnostic_summary(
            request.student_id, 
            analysis_result["learner_profile"], 
            simple_shap
        )
        
        # Construct response
        response = FusionResponse(
            student_id=request.student_id,
            data_origin=request.data_origin, dataset_id=request.dataset_id,
            learner_profile=analysis_result["learner_profile"],
            shap_explanations=analysis_result["shap_explanations"],
            llm_summary=llm_summary,
            llm_recommendations=llm_recommendations
        )
        
        # Save to database
        db = get_db()
        diagnosis_doc = response.dict()
        diagnosis_doc["created_at"] = datetime.utcnow()
        diagnosis_doc["session_id"] = request.session_id
        diagnosis_doc["item_id"] = request.item_id
        diagnosis_doc["feature_source"] = {
            "kinematics_source": "C1 legacy telemetry (request.c2_kinematic_vector)",
            "acoustic_source": "C2 speech (request.c1_audio_vector)"
        }
        await db.learner_profiles.insert_one(diagnosis_doc)
        
        # Audit Log
        audit_doc = {
            "student_id": request.student_id,
            "timestamp": datetime.utcnow(),
            "model_name": "XGBoost",
            "model_version": "C3-v1.0",
            "validation_status": "synthetic_only",
            "input_features": flat_features,
            "output_probabilities": analysis_result["learner_profile"]["class_probabilities"],
            "predicted_pattern": analysis_result["learner_profile"]["primary_pattern"],
            "feature_source": diagnosis_doc["feature_source"]
        }
        await db.model_audit_log.insert_one(audit_doc)
        
        return response
        
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    except Exception as e:
        logger.exception("Error during diagnosis")
        raise HTTPException(status_code=500, detail="Internal ML processing error.")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=9016, reload=False)
