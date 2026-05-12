"""
monitoring-service-v2/main.py
================================
C1 — Cognitive Behavioral Monitoring Engine (CBME)
FastAPI application — Port 8011

Endpoints:
    POST /api/v1/telemetry               → Compute MBSV from telemetry payload
    GET  /api/v1/mbsv/{student_id}       → Return latest stored MBSV
    GET  /api/v1/monitoring/baseline/{student_id} → Welford feature summary
    GET  /api/v1/monitoring/shap/{student_id}      → SHAP explanation (placeholder)
    GET  /health                         → Health check
"""

import os
import sys
import time
import json
import math
from pathlib import Path
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

# Allow importing from shared/ and local core/
sys.path.insert(0, str(Path(__file__).parent.parent))
sys.path.insert(0, str(Path(__file__).parent))

from shared.schemas import (
    TelemetryPayload, MBSVOutput, MBSV, ErrorPatternVector, WelfordState
)
from core.welford import get_baseline
from shared.database import connect_to_mongo, close_mongo_connection, get_db

# ── Configuration ─────────────────────────────────────────────────────────
PORT = int(os.getenv("C1_PORT", "8011"))

# ── Try to load LightGBM models ────────────────────────────────────────────
try:
    import pickle
    import joblib  # MultiOutputRegressor often requires joblib or pickle
    import numpy as np
    
    MODELS_DIR = Path(__file__).parent.parent / "models"
    MODEL_PATH = MODELS_DIR / "c1_lgbm_mbsv.pkl"
    
    LGBM_MODEL = None
    if MODEL_PATH.exists():
        with open(MODEL_PATH, "rb") as f:
            LGBM_MODEL = pickle.load(f)
    
    MODELS_LOADED = LGBM_MODEL is not None
    DIMENSION_NAMES = [
        "cognitive_load_index", "phonological_strain_index", "visual_strain_index",
        "session_fatigue_index", "engagement_index", "error_resilience_index"
    ]
except Exception as e:
    print(f"[C1] Model load error: {e}")
    LGBM_MODEL = None
    MODELS_LOADED = False

# ── Feature storage (latest MBSV per student) ──────────────────────────────
# Moved to MongoDB using motor collections

@asynccontextmanager
async def lifespan(app: FastAPI):
    await connect_to_mongo()
    yield
    await close_mongo_connection()

# ── App ────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="C1 — Cognitive Behavioral Monitoring Engine (CBME)",
    description="Produces the 6-dimension MBSV from Flutter behavioral telemetry.",
    version="2.0.0",
    lifespan=lifespan
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_methods=["*"], allow_headers=["*"],
)


# ── Helper: extract feature dict from telemetry payload ───────────────────
def _extract_features(payload: TelemetryPayload) -> dict:
    """Extract raw feature values from telemetry payload."""
    # Compute swipe velocity from touch_events if available
    swipe_velocity = 0.0
    if len(payload.touch_events) >= 2:
        first, last = payload.touch_events[0], payload.touch_events[-1]
        dt = max((last.timestamp_ms - first.timestamp_ms) / 1000.0, 0.001)
        dist = math.hypot(last.x - first.x, last.y - first.y)
        swipe_velocity = dist / dt

    # Inter-tap interval (std dev of timestamps)
    inter_tap_interval = 0.0
    if len(payload.touch_events) >= 3:
        intervals = [
            payload.touch_events[i + 1].timestamp_ms - payload.touch_events[i].timestamp_ms
            for i in range(len(payload.touch_events) - 1)
        ]
        mean_int = sum(intervals) / len(intervals)
        inter_tap_interval = math.sqrt(
            sum((x - mean_int) ** 2 for x in intervals) / len(intervals)
        )

    # Average touch pressure
    touch_pressure = (
        sum(e.pressure for e in payload.touch_events) / len(payload.touch_events)
        if payload.touch_events else 0.5
    )

    return {
        "hesitation_ms": float(payload.hesitation_ms),
        "correction_rate": float(payload.correction_rate),
        "response_latency": float(payload.session_latency_ms),
        "touch_pressure": touch_pressure,
        "swipe_velocity": swipe_velocity,
        "replay_count": float(payload.replay_count),
        "hint_request_count": float(payload.hint_request_count),
        "stylus_deviation": float(payload.stylus_deviation or 0.0),
        "inter_tap_interval": inter_tap_interval,
        "read_aloud_pause_ms": float(payload.read_aloud_pause_ms or 0.0),
        "syllable_rate": float(payload.syllable_rate or 0.0),
        "disfluency_count": float(payload.disfluency_count or 0.0),
        "kalman_innovation": 0.0,   # Milestone B: Kalman Filter
    }


def _compute_error_pattern(features: dict, z_scores: dict) -> ErrorPatternVector:
    """Rule-based error pattern vector from feature values and Z-scores."""
    # Reversal: high correction_rate + high hesitation
    reversal = 1 if (features["correction_rate"] > 0.3 and features["hesitation_ms"] > 2000) else 0
    # Omission: high disfluency + replay
    omission = 1 if (features["disfluency_count"] > 2 or features["replay_count"] >= 3) else 0
    # Substitution: high correction_rate alone
    substitution = 1 if (features["correction_rate"] > 0.5 and reversal == 0) else 0
    # Hesitation: just high hesitation
    hesitation = 1 if features["hesitation_ms"] > 2500 else 0
    return ErrorPatternVector(
        reversal=reversal, omission=omission,
        substitution=substitution, hesitation=hesitation
    )


def _rule_based_mbsv(features: dict, z_scores: dict) -> MBSV:
    """
    Fallback MBSV computation when LightGBM models are not loaded.
    Uses Z-score normalization + research-calibrated sigmoid mapping.
    """
    def sigmoid(x: float) -> float:
        return 1.0 / (1.0 + math.exp(-x))

    def clamp(v: float) -> float:
        return max(0.0, min(1.0, v))

    hesitation_z = z_scores.get("hesitation_ms", 0.0)
    replay_z = z_scores.get("replay_count", 0.0)
    correction_z = z_scores.get("correction_rate", 0.0)
    swipe_z = z_scores.get("swipe_velocity", 0.0)
    latency_z = z_scores.get("response_latency", 0.0)
    hint_z = z_scores.get("hint_request_count", 0.0)

    # Raw score: normalized Z-score combinations per dimension
    visual_raw     = 0.4 * (-swipe_z) + 0.3 * hesitation_z + 0.2 * z_scores.get("stylus_deviation", 0.0) + 0.1 * latency_z
    cogload_raw    = 0.35 * hesitation_z + 0.3 * latency_z + 0.2 * correction_z + 0.15 * z_scores.get("disfluency_count", 0.0)
    phonol_raw     = 0.35 * replay_z + 0.3 * z_scores.get("inter_tap_interval", 0.0) + 0.2 * z_scores.get("read_aloud_pause_ms", 0.0) + 0.15 * z_scores.get("syllable_rate", 0.0)
    engage_raw     = -(0.4 * hint_z + 0.3 * correction_z + 0.3 * swipe_z)  # inverted
    fatigue_raw    = 0.4 * latency_z + 0.35 * hesitation_z + 0.25 * z_scores.get("syllable_rate", 0.0)

    return MBSV(
        visual_strain_index=clamp(sigmoid(visual_raw)),
        cognitive_load_index=clamp(sigmoid(cogload_raw)),
        phonological_strain_index=clamp(sigmoid(phonol_raw)),
        engagement_index=clamp(sigmoid(engage_raw)),
        session_fatigue_index=clamp(sigmoid(fatigue_raw)),
        error_pattern_vector=_compute_error_pattern(features, z_scores),
    )


def _lgbm_mbsv(features: dict, z_scores: dict) -> MBSV:
    """Compute MBSV using trained LightGBM MultiOutput model."""
    import numpy as np
    feature_vector = np.array([[
        z_scores.get(k, 0.0) for k in [
            "hesitation_ms", "correction_rate", "response_latency", "touch_pressure",
            "swipe_velocity", "replay_count", "hint_request_count", "stylus_deviation",
            "inter_tap_interval", "read_aloud_pause_ms", "syllable_rate",
            "disfluency_count", "kalman_innovation",
        ]
    ]])
    
    # Predict all 6 dimensions
    preds = LGBM_MODEL.predict(feature_vector)[0]
    
    # Mapping based on train_c1_lgbm.py: 
    # TARGETS = ["label_CLI", "label_PSI", "label_VSI", "label_FI", "label_ES", "label_ERI"]
    def clamp(v: float) -> float:
        return float(max(0.0, min(1.0, v)))

    return MBSV(
        cognitive_load_index=clamp(preds[0]),
        phonological_strain_index=clamp(preds[1]),
        visual_strain_index=clamp(preds[2]),
        session_fatigue_index=clamp(preds[3]),
        engagement_index=clamp(preds[4]),
        error_resilience_index=clamp(preds[5]),
        error_pattern_vector=_compute_error_pattern(features, z_scores),
    )


# ── Endpoints ──────────────────────────────────────────────────────────────

@app.get("/health")
def health():
    return {"status": "ok", "service": "C1-CBME", "models_loaded": MODELS_LOADED}


@app.post("/api/v1/telemetry", response_model=MBSVOutput)
async def receive_telemetry(payload: TelemetryPayload):
    """
    Main telemetry ingestion endpoint.
    Runs Welford's Z-score → LightGBM (or rule-based fallback) → stores MBSV.
    """
    features = _extract_features(payload)
    baseline = await get_baseline(payload.student_id)
    await baseline.update(features)
    z_scores = baseline.z_score_all(features)

    mbsv = _lgbm_mbsv(features, z_scores) if MODELS_LOADED else _rule_based_mbsv(features, z_scores)

    timestamp_ms = int(time.time() * 1000)
    mbsv_json = mbsv.model_dump_json()

    db = get_db()
    await db.mbsv_events.update_one(
        {
            "student_id": payload.student_id,
            "session_id": payload.session_id,
            "timestamp_ms": timestamp_ms
        },
        {"$set": {"mbsv_json": mbsv_json}},
        upsert=True
    )

    return MBSVOutput(
        student_id=payload.student_id,
        session_id=payload.session_id,
        timestamp_ms=timestamp_ms,
        mbsv=mbsv,
        shap_available=False,
        session_outlier=False,
    )


@app.get("/api/v1/mbsv/{student_id}", response_model=MBSVOutput)
async def get_latest_mbsv(student_id: str):
    """Return the most recent MBSV for a student."""
    db = get_db()
    row = await db.mbsv_events.find_one(
        {"student_id": student_id},
        sort=[("timestamp_ms", -1)]
    )

    if not row:
        raise HTTPException(status_code=404, detail=f"No MBSV found for student {student_id}")

    session_id = row["session_id"]
    timestamp_ms = row["timestamp_ms"]
    mbsv_json = row["mbsv_json"]
    mbsv = MBSV.model_validate_json(mbsv_json)
    return MBSVOutput(
        student_id=student_id, session_id=session_id,
        timestamp_ms=timestamp_ms, mbsv=mbsv,
    )


@app.get("/api/v1/monitoring/baseline/{student_id}", response_model=WelfordState)
async def get_baseline_summary(student_id: str):
    """Return Welford feature summary (mean ± std) for a student."""
    baseline = await get_baseline(student_id)
    return WelfordState(
        student_id=student_id,
        feature_states=baseline.feature_summary(),
    )


@app.get("/api/v1/monitoring/shap/{student_id}")
def get_shap(student_id: str):
    """SHAP explanation placeholder — full implementation in Milestone B."""
    return {
        "student_id": student_id,
        "available": False,
        "message": "SHAP explanations available after Milestone B Kalman Filter integration.",
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=PORT, reload=True)
