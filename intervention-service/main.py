from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import joblib
import numpy as np
import requests
import motor.motor_asyncio
import datetime

app = FastAPI(title="Intervention Service", version="2.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

MONGO_URI = "mongodb+srv://kavindugunasena_db_user:2Vp8ipkprifuEH8t@cluster0.ypxuqen.mongodb.net/"
client = motor.motor_asyncio.AsyncIOMotorClient(MONGO_URI)
db = client.intervention_db

async def init_db():
    await db.intervention_log.create_index("student_id")
    await db.failure_tracker.create_index("student_id", unique=True)
    await db.outcome_log.create_index("student_id")
    print("Intervention Service: MongoDB indexes initialized.")

@app.on_event("startup")
async def startup():
    await init_db()

# ── Load Random Forest Model ──────────────────────────────────────────────────
try:
    rf_model = joblib.load('ml/intervention_rf.pkl')
    print("Intervention RF model loaded successfully.")
except Exception as e:
    print(f"RF model not loaded: {e}")
    rf_model = None

# Try loading SHAP — graceful fallback if not installed
try:
    import shap
    _shap_available = True
    print("SHAP available — explainability enabled.")
except ImportError:
    _shap_available = False
    print("SHAP not installed — explanations will use feature importance fallback.")

FEATURE_NAMES = ["latency_ms", "erratic_clicks", "mastery_level", "prev_failures"]
INTERVENTION_LABELS = {0: "Audio_Hint", 1: "Visual_Split", 2: "Break"}

# ── Helpers ───────────────────────────────────────────────────────────────────
def get_mastery_data(student_id: str) -> dict:
    """Fetch full mastery tree from Content Service."""
    try:
        url = f"http://127.0.0.1:8002/api/v1/mastery/{student_id}"
        response = requests.get(url, timeout=2)
        return response.json().get("mastery_tree", {})
    except Exception as e:
        print(f"Could not reach Content Service: {e}")
        return {}

def get_latest_telemetry(student_id: str) -> dict:
    """Fetch latest raw telemetry from Monitoring Service."""
    try:
        url = f"http://127.0.0.1:8001/api/v1/telemetry/latest/{student_id}"
        response = requests.get(url, timeout=2)
        return response.json()
    except Exception:
        return {}

async def get_failure_count(student_id: str) -> int:
    doc = await db.failure_tracker.find_one({"student_id": student_id})
    return doc.get("failure_count", 0) if doc else 0

async def increment_failure(student_id: str):
    await db.failure_tracker.update_one(
        {"student_id": student_id},
        {
            "$inc": {"failure_count": 1},
            "$set": {"updated_at": datetime.datetime.now(datetime.UTC)}
        },
        upsert=True
    )

async def reset_failure(student_id: str):
    await db.failure_tracker.update_one(
        {"student_id": student_id},
        {"$set": {
            "failure_count": 0,
            "updated_at": datetime.datetime.now(datetime.UTC)
        }}
    )

def forward_to_visual_service(student_id: str, intervention_type: str, ui_action: str):
    try:
        requests.post(
            "http://127.0.0.1:8004/api/v1/intervention/store",
            json={"student_id": student_id,
                  "intervention_type": intervention_type,
                  "ui_action": ui_action},
            timeout=2
        )
    except Exception as e:
        print(f"Could not forward to Visual Service: {e}")

def compute_shap_explanation(X_input: np.ndarray) -> str:
    """
    Returns a human-readable explanation of the top contributing feature.
    Uses SHAP if available, falls back to RF feature_importances_.
    """
    if _shap_available and rf_model is not None:
        try:
            explainer = shap.TreeExplainer(rf_model)
            shap_values = explainer.shap_values(X_input)
            # shap_values is [n_classes, n_samples, n_features] for multi-class RF
            # Take absolute mean across classes for the single sample
            mean_abs = np.mean([np.abs(sv[0]) for sv in shap_values], axis=0)
            top_idx = int(np.argmax(mean_abs))
            top_feat = FEATURE_NAMES[top_idx]
            top_val  = float(mean_abs[top_idx])
            return f"{top_feat} (SHAP contribution: {top_val:.3f})"
        except Exception as ex:
            print(f"SHAP computation failed: {ex}")

    # Fallback: RF built-in feature importances
    if rf_model is not None:
        fi = rf_model.feature_importances_
        top_idx = int(np.argmax(fi))
        return f"{FEATURE_NAMES[top_idx]} (feature importance: {fi[top_idx]:.3f})"

    return "model not available"

# ── Payload Models ────────────────────────────────────────────────────────────
class TriggerPayload(BaseModel):
    student_id: str
    cognitive_load_level: int  # 1 = Medium, 2 = High

class OutcomePayload(BaseModel):
    student_id: str
    intervention_type: str
    post_correct: bool
    post_latency_ms: float

# ── Endpoints ─────────────────────────────────────────────────────────────────
@app.post("/api/v1/intervention/trigger")
async def trigger_intervention(payload: TriggerPayload):
    """
    Decides the intervention type using the trained Random Forest model.
    Features: latency_ms, erratic_clicks, mastery_level, prev_failures
    Returns intervention decision + SHAP explanation of top driver.
    """
    # 1. Gather feature inputs from dependent services
    mastery_tree  = get_mastery_data(payload.student_id)
    telemetry     = get_latest_telemetry(payload.student_id)
    prev_failures = await get_failure_count(payload.student_id)

    weakest_skill  = min(mastery_tree, key=mastery_tree.get) if mastery_tree else "unknown"
    mastery_level  = mastery_tree.get(weakest_skill, 0.3) if mastery_tree else 0.3
    latency_ms     = float(telemetry.get("hesitation_time_ms", 3000.0))
    erratic_clicks = float(telemetry.get("erratic_clicks", 1.0))

    # Infer erratic_clicks from cognitive load if not in telemetry
    if erratic_clicks == 1.0 and payload.cognitive_load_level == 2:
        erratic_clicks = 6.0  # proxy for high frustration
    elif erratic_clicks == 1.0 and payload.cognitive_load_level == 1:
        erratic_clicks = 2.5

    X_input = np.array([[latency_ms, erratic_clicks, mastery_level, prev_failures]])

    # 2. Predict with RF model (or rule-based fallback)
    if rf_model is not None:
        predicted_class = int(rf_model.predict(X_input)[0])
        intervention_type = INTERVENTION_LABELS[predicted_class]
        confidence = float(rf_model.predict_proba(X_input)[0][predicted_class])
        explanation = compute_shap_explanation(X_input)
    else:
        # Heuristic fallback when model is missing
        if payload.cognitive_load_level == 2 or prev_failures >= 3:
            intervention_type, predicted_class, confidence = "Break", 2, 0.0
        elif payload.cognitive_load_level == 1:
            intervention_type, predicted_class, confidence = "Visual_Split", 1, 0.0
        else:
            intervention_type, predicted_class, confidence = "Audio_Hint", 0, 0.0
        explanation = "rule-based fallback (model not loaded)"

    # 3. Build action message
    action_map = {
        "Audio_Hint":    f"Softly highlight correct answer and repeat audio cue for: {weakest_skill}",
        "Visual_Split":  f"Trigger syllable-by-syllable visual split for: {weakest_skill}. Pause game.",
        "Break":         f"Student overwhelmed. Show breathing exercise. Reset round for: {weakest_skill}.",
    }
    ui_action = action_map.get(intervention_type, "No action")

    # 4. Track failure count (increment on trigger, reset on outcome)
    await increment_failure(payload.student_id)

    # 5. Log to DB
    await db.intervention_log.insert_one({
        "student_id": payload.student_id,
        "intervention_type": intervention_type,
        "weak_skill": weakest_skill,
        "latency_ms": latency_ms,
        "erratic_clicks": erratic_clicks,
        "mastery_level": mastery_level,
        "prev_failures": prev_failures,
        "shap_top_feature": explanation,
        "timestamp": datetime.datetime.utcnow()
    })

    # 6. Push to Visual Service for Flutter to poll
    forward_to_visual_service(payload.student_id, intervention_type, ui_action)

    return {
        "student_id":               payload.student_id,
        "detected_weak_skill":      weakest_skill,
        "mastery_level":            round(mastery_level, 3),
        "recommended_intervention": intervention_type,
        "confidence":               round(confidence, 3),
        "ui_action":                ui_action,
        "model_used":               "RandomForest" if rf_model else "heuristic_fallback",
        "primary_driver":           explanation,
        "features_used": {
            "latency_ms":      latency_ms,
            "erratic_clicks":  erratic_clicks,
            "mastery_level":   round(mastery_level, 3),
            "prev_failures":   prev_failures,
        }
    }

@app.post("/api/v1/intervention/outcome")
async def record_outcome(payload: OutcomePayload):
    """
    Flutter calls this after the student's next attempt post-intervention.
    Records whether the intervention was effective.
    Research basis: Outcome tracking required for adaptive system validation
    (Fuchs & Fuchs, 2006 — Response to Intervention model).
    """
    effective = 1 if payload.post_correct and payload.post_latency_ms < 5000 else 0

    await db.outcome_log.insert_one({
        "student_id": payload.student_id,
        "intervention_type": payload.intervention_type,
        "post_correct": int(payload.post_correct),
        "post_latency_ms": payload.post_latency_ms,
        "effective": effective,
        "recorded_at": datetime.datetime.utcnow()
    })

    # If effective, reset failure counter
    if effective:
        await reset_failure(payload.student_id)

    return {
        "status": "outcome recorded",
        "effective": bool(effective),
        "note": "Failure counter reset." if effective else "Failure counter retained."
    }

@app.get("/api/v1/intervention/history/{student_id}")
async def get_intervention_history(student_id: str):
    """Returns the intervention history for a student — used by educator dashboard."""
    cursor = db.intervention_log.find({"student_id": student_id}).sort("timestamp", -1).limit(20)
    history = []
    async for doc in cursor:
        history.append({
            "intervention": doc["intervention_type"],
            "skill": doc["weak_skill"],
            "driver": doc["shap_top_feature"],
            "at": doc["timestamp"].isoformat()
        })
    return {
        "student_id": student_id,
        "history": history
    }

@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "service": "intervention-service",
        "rf_model_loaded": rf_model is not None,
        "shap_enabled": _shap_available,
    }
