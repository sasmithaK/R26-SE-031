from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
import logging
from datetime import datetime
import os

from schemas import FusionRequest, FusionResponse
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
