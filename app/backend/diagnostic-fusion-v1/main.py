from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
import logging
from datetime import datetime, timedelta, timezone
import os
import math
import json
from bson import ObjectId

from schemas import FusionRequest, FusionResponse, SessionFusionRequest
from services.xai_engine import get_xai_engine, XAIEngine
from services.llm_explainer import generate_diagnostic_summary
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


def _completed_rounds(row: dict):
    if row.get("valid_trials") is not None:
        return int(row.get("valid_trials") or 0)
    total = int(row.get("total_trials") or 0)
    abandoned = _number((row.get("overall") or {}).get("abandonment_rate")) or 0.0
    return max(0, total - round(abandoned * total))


def _pooled_overall(summaries: list) -> dict:
    """Pool session rates over completed rounds (abandoned-only sessions skipped)."""
    pooled, rounds = {}, sum(_completed_rounds(r) for r in summaries)
    for field in ("accuracy", "retry_rate", "correction_rate"):
        total = weight = 0.0
        for row in summaries:
            value, n = _number((row.get("overall") or {}).get(field)), _completed_rounds(row)
            if value is not None and n > 0:
                total += value * n
                weight += n
        pooled[field] = (total / weight) if weight else None
    latencies = sorted(v for v in (_number((r.get("overall") or {}).get("median_response_latency_ms"))
                                   for r in summaries if _completed_rounds(r) > 0) if v is not None)
    pooled["median_response_latency_ms"] = latencies[len(latencies) // 2] if latencies else None
    pooled["completed_rounds"] = rounds
    return pooled


def _build_observed_summary(summaries, speech: dict, student: dict, recordings: int = 0):
    """Descriptive summary over the C3 window. ``speech`` is the latest
    recording that was clear enough to measure (or {} when there is none)."""
    if isinstance(summaries, dict):  # backward compatible single-session call
        summaries = [summaries] if summaries else []
    overall = _pooled_overall(summaries)
    accuracy = overall.get("accuracy")
    retry_rate = overall.get("retry_rate")
    rounds = overall.get("completed_rounds") or 0
    word_accuracy = _number(speech.get("word_accuracy"))
    grapheme_accuracy = _number(speech.get("grapheme_accuracy"))
    speech_status = speech.get("measurement_status") or "unavailable"
    questionnaire_count = _questionnaire_yes_count(student)

    statements = []
    if accuracy is not None:
        statements.append(f"Across {rounds} completed activity rounds in the last {C3_WINDOW_DAYS} days, "
                          f"{round(accuracy * 100)}% were correct on the first try.")
    if retry_rate is not None:
        statements.append(f"Extra attempts were used in {round(retry_rate * 100)}% of completed rounds.")
    if word_accuracy is not None and speech_status in USABLE_SPEECH_STATUSES:
        statements.append(f"Recorded-word agreement was {round(word_accuracy * 100)}% in the latest clear reading recording.")
    elif recordings:
        statements.append("Reading recordings were made, but none was clear enough to measure yet.")
    if questionnaire_count:
        statements.append(f"In the parent questionnaire, {questionnaire_count} items were marked as observed at home.")
    if not statements:
        statements.append("More completed activity observations are needed for a combined learning summary.")

    priorities = []
    if retry_rate is not None and retry_rate >= float(os.getenv("C3_SUMMARY_RETRY_RATE", "0.35")):
        priorities.append("Use short practice sets and observe whether support reduces repeated attempts.")
    if (word_accuracy is not None and word_accuracy < float(os.getenv("C3_SUMMARY_WORD_ACCURACY", "0.70"))
            and speech_status in USABLE_SPEECH_STATUSES):
        priorities.append("Repeat familiar oral-reading items and compare several clear recordings over time.")
    if questionnaire_count:
        priorities.append("Compare parent observations with patterns repeated across several activities.")
    if not priorities:
        priorities.append("Continue regular practice and review the trend after more sessions.")

    evidence = {
        "c1": {
            "first_attempt_accuracy": accuracy,
            "retry_rate": retry_rate,
            "correction_rate": overall.get("correction_rate"),
            "median_response_latency_ms": overall.get("median_response_latency_ms"),
            "completed_rounds": rounds,
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
C3_MODEL_VERSION = "C3-v2.0"
# Inputs, aggregation and the evidence rule live in services/c3_features.py and
# are shared with scripts/train_c3_model.py (training uses the same code).
from services.c3_features import (FEATURE_VERSION as C3_FEATURE_VERSION, FEATURE_LABELS,
                                  USABLE_SPEECH_STATUSES, age_years as _c3_age_years,
                                  build_c3_inputs, evidence_gaps as _c3_evidence_gaps,
                                  outside_training_range as _c3_outside_range,
                                  median_feature as _median_feature)


def _c3_ranges() -> dict:
    path = os.path.join(os.path.dirname(__file__), "models", "c3_feature_ranges.json")
    try:
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
        return data.get("ranges", {}) if data.get("feature_version") == C3_FEATURE_VERSION else {}
    except (OSError, ValueError):
        return {}


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
        summaries, usable_speech[0] if usable_speech else {}, student, recordings=len(speech_rows),
    )

    # Activity-behaviour inputs come from the learner-level C1 estimate, used
    # only when C1 itself had enough evidence.
    c1_doc = await db.c1_learner_estimates.find_one({"student_id": request.student_id}) or {}
    c1_features = c1_doc.get("features") if c1_doc.get("status") in {"estimated", "outside_training_range"} else None
    age = _c3_age_years(student, now)
    values, feature_counts = build_c3_inputs(usable_speech, motion_rows, c1_features, age)
    missing = _c3_evidence_gaps(len(usable_speech), len(motion_rows), age,
                                C3_MIN_USABLE_RECORDINGS, C3_MIN_MOVEMENT_SESSIONS)
    model_inputs = {k: v for k, v in values.items() if v is not None}
    not_measured = [k for k, v in values.items() if v is None]
    outside = _c3_outside_range(values, _c3_ranges()) if not missing else []
    marginalize = {}

    measurement_notes = []
    if any((row.get("orthographic_confusion_coverage") == 0) for row in motion_rows):
        measurement_notes.append("Letter-confusion index covers only the letter pairs in the confusion map.")
    if not_measured and not missing:
        measurement_notes.append("Not measured yet (the model handles these as missing, nothing is filled in): "
                                 + ", ".join(FEATURE_LABELS.get(k, k) for k in not_measured) + ".")
    if outside:
        measurement_notes.append("Some measurements are outside the range the model was trained on, so no estimate is shown.")

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
    if not missing and not outside:
        result = engine.analyze_patient(model_inputs, marginalize=marginalize)
        learner_profile = {**result["learner_profile"], "modalities_used": modalities}
        shap_explanations = result["shap_explanations"]
        model_applied = True
        pipeline_status = "model_and_summary_ready"
    elif outside:
        pipeline_status = "outside_training_range"
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
        "missing_inputs": missing, "not_measured_inputs": not_measured, "outside_range": outside,
        "learner_profile": learner_profile,
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
        "c1_evidence_used": c1_features is not None,
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
            "missing_inputs": missing, "outside_range": outside, "summary": narrative,
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
        # v2 model: age in decimal years; gender/time of day are no longer
        # inputs; C1 activity inputs are not part of this legacy request (NaN).
        flat_features["age_years"] = round(request.student_age_months / 12, 2)
        
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
            "model_version": C3_MODEL_VERSION,
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
