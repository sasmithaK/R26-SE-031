from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import pandas as pd
import uvicorn
from contextlib import asynccontextmanager

from db.database import latest_telemetry_collection, student_baseline_collection, prediction_collection, add_prediction
from ml.data_generator import generate_synthetic_data
from ml.feature_engineering import FeatureEngineer
from ml.models import LearnerClassifierModels

ml_models = LearnerClassifierModels()
feature_engineer = FeatureEngineer()

@asynccontextmanager
async def lifespan(app: FastAPI):
    yield

app = FastAPI(title="Learner Classification System - Simplified", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class PredictRequest(BaseModel):
    mean_hesitation: float
    std_hesitation: float
    mean_correction: float
    std_correction: float
    session_count: int
    cognitive_load: int
    hesitation_time_ms: float
    erratic_clicks: int

@app.post("/train-model")
async def train_model():
    # 1. Fetch both collections
    cursor_tel = latest_telemetry_collection.find({}, {'_id': 0, 'updated_at': 0})
    telemetry_docs = await cursor_tel.to_list(length=None)
    
    cursor_base = student_baseline_collection.find({}, {'_id': 0, 'updated_at': 0})
    baseline_docs = await cursor_base.to_list(length=None)
    
    if not telemetry_docs or not baseline_docs:
        raise HTTPException(status_code=400, detail="Training failed. Database is empty.")
        
    df_tel = pd.DataFrame(telemetry_docs)
    df_base = pd.DataFrame(baseline_docs)
    
    # 2. Join the two dataframes on student_id
    df_merged = pd.merge(df_tel, df_base, on="student_id", how="inner")
    
    # Ensure there's a learner_type label (the synthetic generator adds it to telemetry)
    if 'learner_type' not in df_merged.columns:
        raise HTTPException(status_code=400, detail="No learner_type labels found. Synthesize data first.")
        
    # Target column
    Y_series = df_merged['learner_type']
    X_raw = df_merged.drop(columns=['learner_type', 'student_id'])
    
    # Ensure columns match expected input order and names
    # (some real data from monitoring developer might miss 'audio_replay_count')
    for col in feature_engineer.num_cols:
        if col not in X_raw.columns:
            X_raw[col] = 0
            
    # Feature Engineering (Scaling)
    X_scaled = feature_engineer.fit_transform(X_raw, is_training=True)
    
    # Train
    metrics = ml_models.train(X_scaled[feature_engineer.num_cols], Y_series)
    
    return {"message": "Model trained successfully", "metrics": metrics}

@app.post("/predict")
async def predict(req: PredictRequest, background_tasks: BackgroundTasks):
    if not ml_models.is_trained:
        raise HTTPException(status_code=400, detail="Ensure models are trained before predicting.")
        
    # Convert input to DataFrame
    input_dict = req.model_dump()
    df_input = pd.DataFrame([input_dict])
    
    # Feature Engineering (Scale)
    X_scaled = feature_engineer.fit_transform(df_input, is_training=False)
    
    # Predict
    results = ml_models.predict(X_scaled[feature_engineer.num_cols], df_input)
    prediction_result = results[0]
    
    # Combine everything for persistence
    full_record = {
        "learner_id": "simulated",
        "behavioral_metrics": input_dict,
        "prediction": prediction_result
    }
    
    # Save to MongoDB asynchronously
    background_tasks.add_task(add_prediction, full_record)
    
    return full_record

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
