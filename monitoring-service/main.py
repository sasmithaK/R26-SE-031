from fastapi import FastAPI, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import joblib
import pandas as pd
import requests

app = FastAPI(title="Monitoring Service", version="1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Simple Monitoring DB
def init_monitoring_db():
    import sqlite3
    conn = sqlite3.connect('monitoring_history.db')
    conn.execute('CREATE TABLE IF NOT EXISTS telemetry (student_id TEXT, task_id TEXT, cognitive_load INTEGER, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP)')
    conn.commit()
    conn.close()

@app.on_event("startup")
def startup():
    init_monitoring_db()

# Load the ML model
try:
    model = joblib.load('ml/lgbm_cognitive_load.pkl')
    print("Model loaded successfully.")
except Exception as e:
    print(f"Error loading model: {e}")
    model = None

class TelemetryPayload(BaseModel):
    student_id: str
    session_id: str
    hesitation_time_ms: float
    swipe_velocity: float
    correction_rate: float

def notify_intervention_service(student_id: str, cognitive_load: int):
    # Sends a request to the intervention service if load is high
    try:
        url = "http://127.0.0.1:8003/api/v1/intervention/trigger"
        payload = {"student_id": student_id, "cognitive_load_level": cognitive_load}
        response = requests.post(url, json=payload)
        print(f"Notified intervention service: {response.json()}")
    except Exception as e:
        print(f"Failed to reach Intervention Service: {e}")

@app.post("/api/v1/telemetry")
async def process_telemetry(payload: TelemetryPayload, background_tasks: BackgroundTasks):
    if not model:
        return {"error": "ML Model not loaded."}
    
    # Format data for LightGBM
    input_data = pd.DataFrame([{
        'hesitation_time_ms': payload.hesitation_time_ms,
        'swipe_velocity': payload.swipe_velocity,
        'correction_rate': payload.correction_rate
    }])
    
    # Predict Cognitive Load (0: Low, 1: Medium, 2: High)
    pred = model.predict(input_data)[0]
    cognitive_load = int(pred)
    
    response = {
        "student_id": payload.student_id,
        "predicted_cognitive_load": cognitive_load,
        "status": "processed"
    }
    
    # If student is struggling, asynchronously trigger intervention
    if cognitive_load >= 1:
        background_tasks.add_task(notify_intervention_service, payload.student_id, cognitive_load)
        response["intervention_triggered"] = True
        
    return response

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "monitoring-service"}
