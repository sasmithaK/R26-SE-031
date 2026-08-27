from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import logging
from datetime import datetime

from schemas import FusionRequest, FusionResponse
from services.xai_engine import get_xai_engine, XAIEngine
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
    lifespan=lifespan
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

@app.post("/diagnose", response_model=FusionResponse)
async def diagnose_patient(
    request: FusionRequest,
    engine: XAIEngine = Depends(get_xai_engine)
):
    """
    Ingests multimodal vectors (Acoustic + Kinematic) and returns a Dyslexia Subtype classification 
    along with SHAP explanations.
    """
    try:
        # Flatten the request into a single dictionary matching the feature columns
        flat_features = {}
        flat_features.update(request.c1_audio_vector.dict())
        flat_features.update(request.c2_kinematic_vector.dict())
        flat_features["student_age_months"] = request.student_age_months
        
        # Analyze
        analysis_result = engine.analyze_patient(flat_features)
        
        # Construct response
        response = FusionResponse(
            student_id=request.student_id,
            risk_score=analysis_result["clinical_assessment"]["final_predicted_risk"],
            clinical_subtype=analysis_result["clinical_assessment"]["predicted_subtype"],
            shap_explanations=analysis_result["shap_explanations"]
        )
        
        # Save to database
        db = get_db()
        diagnosis_doc = response.dict()
        diagnosis_doc["created_at"] = datetime.utcnow()
        await db.diagnoses.insert_one(diagnosis_doc)
        
        return response
        
    except Exception as e:
        logger.exception("Error during diagnosis")
        raise HTTPException(status_code=500, detail="Internal ML processing error.")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8016, reload=True)
