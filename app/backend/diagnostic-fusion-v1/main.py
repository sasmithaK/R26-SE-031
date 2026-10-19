from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
import logging
from datetime import datetime
import os
import math
from bson import ObjectId

from schemas import FusionRequest, FusionResponse, SessionFusionRequest
from services.xai_engine import get_xai_engine, XAIEngine
from services.llm_explainer import generate_diagnostic_summary
from database import connect_to_mongo, close_mongo_connection, get_db

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("Initializing XAI Engine and MongoDB...")
    try:
        await connect_to_mongo()
        get_xai_engine()
        logger.info("XAI Engine & DB initialized successfully.")
    except Exception as e:
        logger.error(f"Failed to initialize services: {e}")
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
    return {"status": "ok", "service": "diagnostic-fusion-v1"}


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
    if speech_status in {"valid", "available", "synthetic_features"} and word_accuracy is not None:
        statements.append(f"Recorded-word agreement was {round(word_accuracy * 100)}% in the latest usable reading sample.")
    elif speech:
        statements.append("The latest reading sample was saved, but it was not reliable enough to score.")
    if questionnaire_count:
        statements.append(f"The parent reported {questionnaire_count} learning observations in the questionnaires.")
    if not statements:
        statements.append("More completed activity observations are needed for a combined learning summary.")

    priorities = []
    if retry_rate is not None and retry_rate >= 0.35:
        priorities.append("Use short practice sets and observe whether support reduces repeated attempts.")
    if word_accuracy is not None and word_accuracy < 0.70 and speech_status in {"valid", "available"}:
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


@app.post("/diagnose/session")
async def diagnose_saved_session(
    request: SessionFusionRequest,
    engine: XAIEngine = Depends(get_xai_engine),
):
    """Idempotently combine saved C1, C2 and parent-observation evidence."""
    db = get_db()
    summary = await db.session_summaries.find_one(
        {"student_id": request.student_id, "session_id": request.session_id},
        sort=[("_id", -1)],
    ) or {}
    speech = await db.speech_features.find_one(
        {"student_id": request.student_id, "session_id": request.session_id},
        sort=[("created_at", -1), ("_id", -1)],
    ) or {}
    motion = await db.kinematic_features.find_one(
        {"student_id": request.student_id, "session_id": request.session_id},
        sort=[("_id", -1)],
    ) or {}
    try:
        student = await db.students.find_one({"_id": ObjectId(request.student_id)}) or {}
    except Exception:
        raise HTTPException(status_code=422, detail="Invalid student_id")

    narrative, recommendation, evidence = _build_observed_summary(summary, speech, student)
    completed = summary.get("completed_at") or summary.get("timestamp")
    try:
        hour = datetime.fromisoformat(str(completed).replace("Z", "+00:00")).hour
    except Exception:
        hour = None
    age_months = _number(student.get("age_months"))
    model_inputs = {
        "acoustic_latency_ms": _number(speech.get("acoustic_latency_ms")),
        "peak_count_delta": _number(speech.get("syllabic_event_mismatch", speech.get("peak_count_delta"))),
        "intra_word_silence_ratio": _number(speech.get("intra_word_silence_ratio")),
        "local_jitter": _number(speech.get("local_jitter")),
        "local_shimmer": _number(speech.get("local_shimmer")),
        "time_to_first_touch_ms": _number(motion.get("time_to_first_touch_ms")),
        "orthographic_confusion_index": _number(motion.get("orthographic_confusion_index")),
        "path_efficiency_ratio": _number(motion.get("path_efficiency_ratio")),
        "dimensionless_jerk": _number(motion.get("dimensionless_jerk")),
        "dwell_time_ms": _number(motion.get("dwell_time_ms")),
        "age": age_months // 12 if age_months is not None else None,
        "gender": _number(student.get("gender_code")),
        "time_of_day_hour": hour,
    }
    missing = [name for name, value in model_inputs.items() if value is None]
    requested_dataset = request.dataset_id or speech.get("dataset_id")
    if speech.get("dataset_id") != motion.get("dataset_id") or speech.get("dataset_id") != requested_dataset:
        missing.append("matched_dataset_id")
    if speech.get("measurement_status") not in {"valid", "available", "synthetic_features"}:
        missing.append("usable_speech_measurement")

    modalities = []
    if summary:
        modalities.append("learning activities")
    if speech:
        modalities.append("oral reading")
    if evidence["parent_observation_count"]:
        modalities.append("parent observations")
    learner_profile = {
        "class_probabilities": {}, "primary_pattern": "Unavailable",
        "confidence": None, "modalities_used": modalities,
        "final_predicted_risk": None,
    }
    shap_explanations = {"top_contributing_features": []}
    pipeline_status = "descriptive_ready" if summary or speech else "insufficient_evidence"
    model_applied = False
    if not missing and engine is not None and engine.model is not None:
        result = engine.analyze_patient(model_inputs)
        learner_profile = result["learner_profile"]
        shap_explanations = result["shap_explanations"]
        pipeline_status, model_applied = "model_and_summary_ready", True

    now = datetime.utcnow()
    document = {
        "student_id": request.student_id, "session_id": request.session_id,
        "data_origin": request.data_origin, "dataset_id": requested_dataset,
        "validation_status": "synthetic_only" if model_applied else "observational_summary",
        "pipeline_status": pipeline_status, "model_applied": model_applied,
        "missing_inputs": sorted(set(missing)), "learner_profile": learner_profile,
        "shap_explanations": shap_explanations, "llm_summary": narrative,
        "llm_recommendations": recommendation, "evidence_summary": evidence,
        "model_version": "C3-v1.1", "feature_version": "c3-session-evidence-v1",
        "updated_at": now,
    }
    await db.learner_profiles.update_one(
        {"student_id": request.student_id, "session_id": request.session_id},
        {"$set": document, "$setOnInsert": {"created_at": now}}, upsert=True,
    )
    await db.model_audit_log.update_one(
        {"student_id": request.student_id, "session_id": request.session_id, "model_name": "XGBoost"},
        {"$set": {"timestamp": now, "status": pipeline_status,
                  "missing_features": sorted(set(missing)), "model_applied": model_applied,
                  "validation_status": document["validation_status"]}}, upsert=True,
    )
    return {"student_id": request.student_id, "session_id": request.session_id,
            "pipeline_status": pipeline_status, "model_applied": model_applied,
            "missing_inputs": sorted(set(missing)), "summary": narrative,
            "recommendations": recommendation}

@app.post("/diagnose")
async def diagnose_patient(
    request: FusionRequest,
    engine: XAIEngine = Depends(get_xai_engine)
):
    """
    Ingests multimodal vectors and returns an experimental synthetic-trained learning-pattern classification
    along with SHAP explanations.
    """
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
