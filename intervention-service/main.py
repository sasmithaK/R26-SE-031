from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import joblib
import numpy as np
import requests
import motor.motor_asyncio
import datetime
import hashlib
import os
import sys
from pathlib import Path
from typing import Optional, Any

from fastapi.staticfiles import StaticFiles

from database import init_local_db, upsert_passage, upsert_word, upsert_word_prediction, upsert_audio_asset

_ml_inf = Path(__file__).resolve().parent / "ml" / "inference"
if str(_ml_inf) not in sys.path:
    sys.path.insert(0, str(_ml_inf))
from model1_inference import Model1Predictor, infer_error_type_hint, tokenize_sinhala_text

_model1_predictor: Model1Predictor | None = None

BASE_DIR = Path(__file__).resolve().parent
AUDIO_CACHE_DIR = BASE_DIR / "audio_cache"

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
    init_local_db()

    # Load Model1 (Sinhala word difficulty) if artifacts exist
    global _model1_predictor
    try:
        model1_dir = BASE_DIR / "ml" / "model1"
        if (model1_dir / "model1.joblib").exists():
            _model1_predictor = Model1Predictor(model1_dir)
            print("Component4: Model1 predictor loaded (ml/model1).")
        else:
            _model1_predictor = None
            print("Component4: Model1 artifacts not found under ml/model1 (will use heuristic fallback).")
    except Exception as e:
        _model1_predictor = None
        print(f"Component4: Failed to load Model1 predictor: {e}")

# ── Component4: audio cache (gTTS) ────────────────────────────────────────────
AUDIO_CACHE_DIR.mkdir(parents=True, exist_ok=True)

# Serve cached mp3 files
app.mount("/api/v1/c4/audio", StaticFiles(directory=str(AUDIO_CACHE_DIR)), name="c4-audio")

def _hash_audio_id(lang: str, text: str, kind: str, slow: bool) -> str:
    h = hashlib.sha256()
    h.update(f"{lang}|{kind}|slow={int(slow)}|{text}".encode("utf-8"))
    return h.hexdigest()[:24]


def _is_short_syllable(text: str) -> bool:
    """Heuristic: treat 1-4 codepoint Sinhala/Tamil chunks as 'short syllable'.
    These need gTTS slow=True + duplication or they sound near-inaudible.
    """
    stripped = text.strip()
    if not stripped:
        return False
    return len(stripped) <= 4


def _prepare_tts_text(text: str, kind: str) -> tuple[str, bool]:
    """Return (text_to_send_to_gtts, slow_flag).

    For very short syllables we flip on gTTS slow mode, which stretches the
    pronunciation to roughly 2x duration. That alone is long enough to be
    clearly heard for a single letter/syllable, with no duplication.
    """
    text = text.strip()
    slow = kind in ("syllable", "first_sound") or _is_short_syllable(text)
    return text, slow


def _ensure_gtts_mp3(*, lang: str, text: str, kind: str) -> dict[str, Any]:
    """
    Generates and caches an mp3 file for (lang, text). Returns {audio_id, url}.
    Requires `gTTS` at runtime; if missing, raises a clear error for setup.
    """
    tts_text, slow = _prepare_tts_text(text, kind)
    audio_id = _hash_audio_id(lang, tts_text, kind, slow)
    filename = f"{audio_id}.mp3"
    rel_path = filename
    out_path = AUDIO_CACHE_DIR / filename

    if not out_path.exists():
        try:
            from gtts import gTTS
        except Exception as e:  # pragma: no cover
            raise HTTPException(
                status_code=500,
                detail="gTTS is not installed. Run: pip install gTTS",
            ) from e

        tts = gTTS(text=tts_text, lang=lang, slow=slow)
        tts.save(str(out_path))

    upsert_audio_asset(
        audio_id=audio_id, lang=lang, text=text, kind=kind, file_rel_path=rel_path
    )
    return {"audio_id": audio_id, "url": f"/api/v1/c4/audio/{filename}"}

@app.get("/api/v1/c4/tts")
def c4_tts(text: str, lang: str = "si", kind: str = "ui"):
    """
    Convenience endpoint for the Flutter UI: returns a cached gTTS mp3 URL
    for the given Sinhala/Tamil text. Cached on disk so repeats are instant.

    Example:
        GET /api/v1/c4/tts?text=සෞඛ්‍යයට&lang=si
        -> {"audio_id": "...", "url": "/api/v1/c4/audio/<sha>.mp3"}
    """
    text = (text or "").strip()
    if not text:
        raise HTTPException(status_code=400, detail="text is required")
    if lang not in ("si", "ta", "en", "hi"):
        raise HTTPException(status_code=400, detail="unsupported lang")
    return _ensure_gtts_mp3(lang=lang, text=text, kind=kind)


def _simple_tokenize(text: str) -> list[str]:
    # Basic whitespace tokenizer suitable for viva demo.
    return [w.strip() for w in text.replace("\n", " ").split(" ") if w.strip()]

def _model1_score(word: str) -> tuple[float, Optional[str]]:
    """
    Minimal Model1 placeholder (for viva):
    difficulty_score in [0,1] based on word length/complexity.
    error_type_hint is a coarse heuristic label.
    Replace later with your trained RF Model1.
    """
    n = len(word)
    score = min(1.0, max(0.0, (n - 2) / 10.0))
    hint: Optional[str] = None
    if n >= 8:
        hint = "long_word"
    return score, hint

class PassageStartPayload(BaseModel):
    student_id: str
    session_id: str
    passage_text: str
    language: Optional[str] = None  # "si" or "ta" for gTTS
    pre_generate_audio: bool = True

@app.post("/api/v1/c4/passage/start")
async def c4_passage_start(payload: PassageStartPayload):
    """
    Component4 entrypoint: store passage, tokenized words, difficulty (Model1 RF for Sinhala),
    and optional anticipatory error_type_hint (shape/rank heuristics — not observed learner errors).
    """
    import uuid

    passage_id = str(uuid.uuid4())
    upsert_passage(
        passage_id=passage_id,
        student_id=payload.student_id,
        session_id=payload.session_id,
        raw_text=payload.passage_text,
        language=payload.language,
    )

    if payload.language == "si":
        words = tokenize_sinhala_text(payload.passage_text)
        if not words:
            words = _simple_tokenize(payload.passage_text)
    else:
        words = _simple_tokenize(payload.passage_text)
    response_words: list[dict[str, Any]] = []
    model1_version = "heuristic_v0"
    model1_note = "length-based heuristic fallback"
    using_model1_rf = _model1_predictor is not None and payload.language == "si"
    if using_model1_rf and _model1_predictor is not None:
        mv = (
            _model1_predictor.meta.get("dataset_sha256_16", "model1")
            if isinstance(_model1_predictor.meta, dict)
            else "model1"
        )
        model1_version = str(mv)
        model1_note = "sklearn RF from ml/model1 (p_hard)"

    for idx, w in enumerate(words):
        word_id = str(uuid.uuid4())
        # Stage1 syllables: keep as whole word for now (replace with Unicode syllable splitter later)
        syllables = [w]
        upsert_word(word_id=word_id, passage_id=passage_id, word_index=idx, word_text=w, syllables=syllables)

        hint = None
        if using_model1_rf and _model1_predictor is not None:
            pred = _model1_predictor.predict_one(w)
            diff = float(pred.get("p_hard") or 0.0)
            hint = infer_error_type_hint(str(pred.get("error_type_pred") or ""))
        else:
            diff, hint = _model1_score(w)

        upsert_word_prediction(
            word_id=word_id,
            difficulty_score=diff,
            error_type_hint=hint,
            model1_version=str(model1_version),
        )

        audio = None
        if payload.pre_generate_audio and payload.language in ("si", "ta"):
            audio = _ensure_gtts_mp3(lang=payload.language, text=w, kind="word")

        response_words.append(
            {
                "word_id": word_id,
                "word_index": idx,
                "word_text": w,
                "syllables": syllables,
                "difficulty_score": diff,
                "error_type_hint": hint,
                "audio": audio,
            }
        )

    return {
        "student_id": payload.student_id,
        "session_id": payload.session_id,
        "passage_id": passage_id,
        "words": response_words,
        "model1": {"version": model1_version, "note": model1_note},
    }

# ── Load Random Forest Model ──────────────────────────────────────────────────
try:
    rf_model = joblib.load(BASE_DIR / "ml" / "intervention_rf.pkl")
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
