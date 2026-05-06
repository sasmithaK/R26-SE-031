from fastapi import FastAPI, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import joblib
import pandas as pd
import sqlite3
import requests

app = FastAPI(title="Monitoring Service", version="2.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Monitoring DB — stores full telemetry payload per student
DB_PATH = 'monitoring_history.db'

def init_monitoring_db():
    conn = sqlite3.connect(DB_PATH)
    conn.execute('''
        CREATE TABLE IF NOT EXISTS telemetry (
            id                  INTEGER PRIMARY KEY AUTOINCREMENT,
            student_id          TEXT,
            task_id             TEXT,
            hesitation_time_ms  REAL,
            swipe_velocity      REAL,
            correction_rate     REAL,
            cognitive_load      INTEGER,
            timestamp           DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    # Latest snapshot per student for fast lookup
    conn.execute('''
        CREATE TABLE IF NOT EXISTS latest_telemetry (
            student_id          TEXT PRIMARY KEY,
            cognitive_load      INTEGER,
            hesitation_time_ms  REAL,
            updated_at          DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ''')
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
    session_id: str = "default"
    task_id: str = "unknown"
    hesitation_time_ms: float = 0.0
    swipe_velocity: float = 0.0
    correction_rate: float = 0.0
    # Fields from Flutter Touch-to-Read
    response_time: float = 0.0
    error_count: int = 0
    hesitation_count: int = 0
    input_velocity: float = 0.0

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
    # Derive cognitive load — use ML model if loaded, else use heuristic fallback
    if model:
        input_data = pd.DataFrame([{
            'hesitation_time_ms': payload.hesitation_time_ms or payload.input_velocity,
            'swipe_velocity': payload.swipe_velocity,
            'correction_rate': payload.correction_rate
        }])
        cognitive_load = int(model.predict(input_data)[0])
    else:
        # Heuristic fallback so the system works without a trained model
        hesitation = payload.hesitation_time_ms or payload.input_velocity
        errors     = payload.error_count or int(payload.correction_rate * 10)
        if hesitation > 5000 or errors >= 4:
            cognitive_load = 2  # High
        elif hesitation > 2000 or errors >= 2 or payload.hesitation_count > 0:
            cognitive_load = 1  # Medium
        else:
            cognitive_load = 0  # Low

    # Persist full telemetry to history table
    conn = sqlite3.connect(DB_PATH)
    conn.execute(
        'INSERT INTO telemetry (student_id, task_id, hesitation_time_ms, swipe_velocity, correction_rate, cognitive_load) VALUES (?,?,?,?,?,?)',
        (payload.student_id, payload.task_id, payload.hesitation_time_ms or payload.input_velocity,
         payload.swipe_velocity, payload.correction_rate, cognitive_load)
    )
    # Update latest snapshot
    conn.execute('''
        INSERT INTO latest_telemetry (student_id, cognitive_load, hesitation_time_ms, updated_at)
        VALUES (?, ?, ?, CURRENT_TIMESTAMP)
        ON CONFLICT(student_id) DO UPDATE SET
            cognitive_load     = excluded.cognitive_load,
            hesitation_time_ms = excluded.hesitation_time_ms,
            updated_at         = CURRENT_TIMESTAMP
    ''', (payload.student_id, cognitive_load, payload.hesitation_time_ms or payload.input_velocity))
    conn.commit()
    conn.close()

    response = {
        "student_id": payload.student_id,
        "predicted_cognitive_load": cognitive_load,
        "status": "processed"
    }

    if cognitive_load >= 1:
        background_tasks.add_task(notify_intervention_service, payload.student_id, cognitive_load)
        response["intervention_triggered"] = True

    return response

# Fix 2 (Monitoring side): endpoint for Visual Service to fetch latest load
@app.get("/api/v1/telemetry/latest/{student_id}")
async def get_latest_telemetry(student_id: str):
    conn = sqlite3.connect(DB_PATH)
    row = conn.execute(
        'SELECT cognitive_load, hesitation_time_ms, updated_at FROM latest_telemetry WHERE student_id = ?',
        (student_id,)
    ).fetchone()
    conn.close()
    if row:
        return {"student_id": student_id, "cognitive_load": row[0], "hesitation_time_ms": row[1], "updated_at": row[2]}
    return {"student_id": student_id, "cognitive_load": 0, "hesitation_time_ms": 0.0}

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "monitoring-service"}
