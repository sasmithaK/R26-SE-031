from fastapi import FastAPI, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import joblib
import pandas as pd
import numpy as np
import motor.motor_asyncio
import requests
import datetime
from fastapi.staticfiles import StaticFiles
import os

app = FastAPI(title="Monitoring Service", version="4.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount the demo directory
demo_path = os.path.join(os.path.dirname(__file__), "demo")
if os.path.exists(demo_path):
    app.mount("/demo", StaticFiles(directory=demo_path), name="demo")

MONGO_URI = "mongodb+srv://kavindugunasena_db_user:2Vp8ipkprifuEH8t@cluster0.ypxuqen.mongodb.net/"
client = motor.motor_asyncio.AsyncIOMotorClient(MONGO_URI)
db = client.monitoring_db

async def init_monitoring_db():
    # Create indexes for performance
    await db.telemetry.create_index("student_id")
    await db.latest_telemetry.create_index("student_id", unique=True)
    await db.student_baseline.create_index("student_id", unique=True)
    print("MongoDB indexes initialized.")

@app.on_event("startup")
async def startup():
    await init_monitoring_db()

# ── Load ML model ─────────────────────────────────────────────────────────────
try:
    model = joblib.load('ml/lgbm_cognitive_load.pkl')
    print("LightGBM Cognitive Load model loaded successfully.")
except Exception as e:
    print(f"Error loading model: {e}")
    model = None

# ── Payload ───────────────────────────────────────────────────────────────────
class TelemetryPayload(BaseModel):
    student_id: str
    session_id: str = "default"
    task_id: str = "unknown"
    hesitation_time_ms: float = 0.0
    swipe_velocity: float = 0.0
    correction_rate: float = 0.0
    # Flutter Touch-to-Read fields
    response_time: float = 0.0
    error_count: int = 0
    hesitation_count: int = 0
    input_velocity: float = 0.0

# ── Baseline helpers ──────────────────────────────────────────────────────────
async def get_baseline(student_id: str) -> dict:
    doc = await db.student_baseline.find_one({"student_id": student_id})
    if doc:
        return {
            "mean_h": doc.get("mean_hesitation", 2000.0),
            "std_h": doc.get("std_hesitation", 800.0),
            "mean_c": doc.get("mean_correction", 0.15),
            "std_c": doc.get("std_correction", 0.08),
            "n": doc.get("session_count", 0)
        }
    return {"mean_h": 2000.0, "std_h": 800.0,
            "mean_c": 0.15, "std_c": 0.08, "n": 0}

async def update_baseline(student_id: str, hesitation_ms: float, correction_rate: float):
    """
    Incrementally updates the per-student rolling mean and std.
    Uses Welford's online algorithm for numerically stable variance update.
    Research basis: Yarkoni & Westfall (2017) — context-relative anomaly detection.
    """
    b = await get_baseline(student_id)
    n = b["n"] + 1

    # Welford online mean update
    new_mean_h = b["mean_h"] + (hesitation_ms - b["mean_h"]) / n
    new_std_h  = max(200.0, b["std_h"] * 0.9 + abs(hesitation_ms - new_mean_h) * 0.1)
    new_mean_c = b["mean_c"] + (correction_rate - b["mean_c"]) / n
    new_std_c  = max(0.02, b["std_c"] * 0.9 + abs(correction_rate - new_mean_c) * 0.1)

    await db.student_baseline.update_one(
        {"student_id": student_id},
        {"$set": {
            "mean_hesitation": new_mean_h,
            "std_hesitation": new_std_h,
            "mean_correction": new_mean_c,
            "std_correction": new_std_c,
            "session_count": n,
            "updated_at": datetime.datetime.now(datetime.UTC)
        }},
        upsert=True
    )

def compute_z_score(value: float, mean: float, std: float) -> float:
    """Clamp z-score to [-3, 3] to prevent extreme outliers from skewing features."""
    if std < 1e-6:
        return 0.0
    return max(-3.0, min(3.0, (value - mean) / std))

# ── Notification ──────────────────────────────────────────────────────────────
def notify_intervention_service(student_id: str, cognitive_load: int):
    try:
        url = "http://127.0.0.1:8003/api/v1/intervention/trigger"
        payload = {"student_id": student_id, "cognitive_load_level": cognitive_load}
        response = requests.post(url, json=payload, timeout=3)
        print(f"Notified intervention service: {response.json()}")
    except Exception as e:
        print(f"Failed to reach Intervention Service: {e}")

# ── Telemetry Endpoint ────────────────────────────────────────────────────────
@app.post("/api/v1/telemetry")
async def process_telemetry(payload: TelemetryPayload, background_tasks: BackgroundTasks):
    try:
        # Resolve raw signal (Flutter may send via either field name)
        hesitation_ms   = payload.hesitation_time_ms or payload.input_velocity or payload.response_time
        swipe_vel       = payload.swipe_velocity
        correction_rate = payload.correction_rate
        error_count     = payload.error_count
        hesitation_count= payload.hesitation_count

        # Derive correction_rate from error_count if not provided
        if correction_rate == 0.0 and error_count > 0:
            correction_rate = min(1.0, error_count / 10.0)

        # ── Personalised z-score features (Yarkoni & Westfall, 2017) ──────────────
        baseline = await get_baseline(payload.student_id)
        z_hesitation = compute_z_score(hesitation_ms,   baseline["mean_h"], baseline["std_h"])
        z_correction = compute_z_score(correction_rate, baseline["mean_c"], baseline["std_c"])

        # Update the student's personal baseline incrementally
        background_tasks.add_task(update_baseline, payload.student_id, hesitation_ms, correction_rate)

        # ── Predict cognitive load ─────────────────────────────────────────────────
        if model:
            try:
                # Pass as raw values to avoid feature name mismatch with LightGBM
                features = np.array([[
                    float(hesitation_ms),
                    float(swipe_vel),
                    float(correction_rate),
                    float(error_count),
                    float(hesitation_count)
                ]])
                cognitive_load = int(model.predict(features)[0])
            except Exception as e:
                print(f"Prediction error: {e}")
                cognitive_load = 2 if (hesitation_ms > 4000 or error_count >= 3) else 1
        else:
            # Heuristic fallback using both raw and z-score signals
            if hesitation_ms > 5000 or error_count >= 4 or z_hesitation > 1.5:
                cognitive_load = 2   # High
            elif hesitation_ms > 2000 or error_count >= 2 or hesitation_count > 0 or z_hesitation > 0.5:
                cognitive_load = 1   # Medium
            else:
                cognitive_load = 0   # Low

        erratic_clicks = float(error_count)

        # ── Persist ───────────────────────────────────────────────────────────────
        telemetry_doc = {
            "student_id": payload.student_id,
            "task_id": payload.task_id,
            "hesitation_time_ms": hesitation_ms,
            "swipe_velocity": swipe_vel,
            "correction_rate": correction_rate,
            "error_count": error_count,
            "hesitation_count": hesitation_count,
            "cognitive_load": cognitive_load,
            "timestamp": datetime.datetime.now(datetime.UTC)
        }
        await db.telemetry.insert_one(telemetry_doc)

        await db.latest_telemetry.update_one(
            {"student_id": payload.student_id},
            {"$set": {
                "cognitive_load": cognitive_load,
                "hesitation_time_ms": hesitation_ms,
                "erratic_clicks": erratic_clicks,
                "updated_at": datetime.datetime.now(datetime.UTC)
            }},
            upsert=True
        )

        response = {
            "student_id":             payload.student_id,
            "predicted_cognitive_load": cognitive_load,
            "personalised_z_score":   round(z_hesitation, 3),
            "baseline_sessions":      baseline["n"],
            "status":                 "processed"
        }

        if cognitive_load >= 1:
            background_tasks.add_task(notify_intervention_service, payload.student_id, cognitive_load)
            response["intervention_triggered"] = True

        return response
    except Exception as e:
        import traceback
        error_msg = f"Error: {str(e)}\n{traceback.format_exc()}"
        print(error_msg)
        return {"status": "error", "message": error_msg}

# ── Latest telemetry for Visual Service ───────────────────────────────────────
@app.get("/api/v1/telemetry/latest/{student_id}")
async def get_latest_telemetry(student_id: str):
    doc = await db.latest_telemetry.find_one({"student_id": student_id})
    if doc:
        return {
            "student_id":        student_id,
            "cognitive_load":    doc.get("cognitive_load", 0),
            "hesitation_time_ms": doc.get("hesitation_time_ms", 0.0),
            "erratic_clicks":    doc.get("erratic_clicks", 0.0),
            "updated_at":        doc.get("updated_at"),
        }
    return {"student_id": student_id, "cognitive_load": 0,
            "hesitation_time_ms": 0.0, "erratic_clicks": 0.0}

# ── Student baseline endpoint (educator view) ─────────────────────────────────
@app.get("/api/v1/baseline/{student_id}")
async def get_student_baseline(student_id: str):
    b = await get_baseline(student_id)
    return {
        "student_id":       student_id,
        "mean_hesitation_ms": round(b["mean_h"], 1),
        "std_hesitation_ms":  round(b["std_h"], 1),
        "mean_correction_rate": round(b["mean_c"], 3),
        "session_count":    b["n"],
        "note": "Personal baseline used for z-score cognitive load normalisation (Yarkoni & Westfall, 2017)"
    }

@app.get("/health")
def health_check():
    return {
        "status":       "healthy",
        "service":      "monitoring-service",
        "model_loaded": model is not None,
    }
