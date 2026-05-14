"""
intervention-service-v2/main.py
=================================
C4 — Intelligent Intervention & Guidance Engine (IIGE)
FastAPI application — Port 8013

Endpoints:
    POST /api/v1/intervention/check         → Stage check + payload
    GET  /api/v1/intervention/sm2/schedule/{student_id}  → Today's review skills
    POST /api/v1/intervention/sm2/update    → Update SM-2 after activity
    POST /api/v1/intervention/rti_alert     → Log/retrieve Tier 3 alerts
    POST /api/v1/students/initialize        → Initialize SM-2 for new student
    GET  /health
"""

import os
import sys
import time
import httpx
from pathlib import Path
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

sys.path.insert(0, str(Path(__file__).parent.parent))
sys.path.insert(0, str(Path(__file__).parent))

from shared.database import connect_to_mongo, close_mongo_connection
from shared.schemas import (
    InterventionCheckPayload, InterventionStageResponse, InterventionStage,
    SM2UpdatePayload, SM2ScheduleResponse, ActivityType, ActivityContent, RTIAlert
)
from core.intervention_engine import InterventionEngine
from core.sm2_scheduler import SM2Scheduler
from core.stroke_scorer import score_stroke, accuracy_to_sm2_quality

# ── Configuration ──────────────────────────────────────────────────────────
C3_BASE_URL = os.getenv("C3_BASE_URL", "http://localhost:8012")
PORT = int(os.getenv("C4_PORT", "8013"))
RTI_FAILURE_COUNT = int(os.getenv("RTI_TIER3_FAILURE_COUNT", "3"))

# ── Engines ────────────────────────────────────────────────────────────────
engine = InterventionEngine()
scheduler = SM2Scheduler()

@asynccontextmanager
async def lifespan(app: FastAPI):
    await connect_to_mongo()
    yield
    await close_mongo_connection()

# ── App ────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="C4 — Intelligent Intervention & Guidance Engine (IIGE)",
    description="Phonological intervention pipeline: syllable splitting, SM-2 scheduling, RTI escalation.",
    version="2.0.0",
    lifespan=lifespan,
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_methods=["*"], allow_headers=["*"],
)


async def _fetch_mastery_from_c3(student_id: str) -> dict:
    """Fetch mastery_vector from C3 API. C4 never computes BKT directly."""
    try:
        async with httpx.AsyncClient(timeout=3.0) as client:
            resp = await client.get(f"{C3_BASE_URL}/api/v1/mastery/{student_id}")
            if resp.status_code == 200:
                return resp.json().get("mastery_vector", {})
    except Exception:
        pass
    return {}


@app.get("/health")
def health():
    return {"status": "ok", "service": "C4-IIGE"}


@app.post("/api/v1/students/initialize")
async def initialize_student(student_id: str):
    """Called at onboarding: set all SM-2 skill states to 'due today'."""
    await scheduler.initialize_student(student_id)
    return {"student_id": student_id, "message": "SM-2 initialized for all skill nodes."}


@app.post("/api/v1/intervention/check")
async def check_intervention(payload: InterventionCheckPayload):
    """
    Main intervention trigger endpoint.
    Fetches mastery_vector from C3 if not provided in payload.
    Returns stage (0–3) + appropriate payload for Flutter to render.
    """
    # Resolve mastery_vector: use payload value or fetch from C3
    mastery_vector = payload.mastery_vector
    if not mastery_vector:
        mastery_vector = await _fetch_mastery_from_c3(payload.student_id)

    # Determine active skill (lowest mastery in ZPD if any)
    active_skill_id = None
    if mastery_vector:
        zpd = {k: v for k, v in mastery_vector.items() if 0.45 <= v <= 0.80}
        if zpd:
            active_skill_id = min(zpd, key=zpd.get)

    result = await engine.check(
        student_id=payload.student_id,
        current_word=payload.current_word,
        phonological_strain_index=payload.phonological_strain_index,
        error_pattern_vector=payload.error_pattern_vector,
        strain_duration_ms=payload.strain_duration_ms,
        mastery_vector=mastery_vector,
        active_skill_id=active_skill_id,
        context_sentence=payload.context_sentence,
    )

    stage = result.get("stage", 0)

    if stage == 0:
        return {"stage": 0, "student_id": payload.student_id}

    if stage == 1:
        return {
            "stage": 1,
            "student_id": payload.student_id,
            "syllable_segments": result.get("syllable_segments", []),
            "sm2_quality_required": False,
        }

    if stage == 2:
        return {
            "stage": 2,
            "student_id": payload.student_id,
            "syllable_segments": result.get("syllable_segments", []),
            "error_type": result.get("error_type"),
            "activity_type": result.get("activity_type"),
            "activity_difficulty": result.get("activity_difficulty"),
            "sm2_quality_required": True,
            "active_skill_id": active_skill_id,
            "classifier_model": result.get("classifier_model"),
            "confidence": result.get("confidence"),
        }

    # Stage 3 — RTI Tier 3
    return {
        "stage": 3,
        "student_id": payload.student_id,
        "syllable_segments": result.get("syllable_segments", []),
        "error_type": result.get("error_type"),
        "activity_type": result.get("activity_type"),
        "activity_difficulty": result.get("activity_difficulty"),
        "sm2_quality_required": True,
        "classifier_model": result.get("classifier_model"),
        "confidence": result.get("confidence"),
        "rti_alert": {
            "student_id": payload.student_id,
            "skill_id": active_skill_id or "unknown",
            "word": payload.current_word,
            "failure_count": result.get("failure_count", RTI_FAILURE_COUNT),
            "suggested_activity": _suggest_home_activity(result.get("error_type", "")),
            "alert_timestamp_ms": int(time.time() * 1000),
        },
    }


@app.get("/api/v1/intervention/sm2/schedule/{student_id}", response_model=SM2ScheduleResponse)
async def get_sm2_schedule(student_id: str):
    """Return skill_ids due for SM-2 review today (used at session warm-up)."""
    due = await scheduler.get_due_skills(student_id)
    return SM2ScheduleResponse(
        student_id=student_id,
        review_skills=due,
        total_due=len(due),
    )


@app.post("/api/v1/intervention/sm2/update")
async def update_sm2(payload: SM2UpdatePayload):
    """Update SM-2 scheduler after an activity completes."""
    next_date = await scheduler.update(
        student_id=payload.student_id,
        skill_id=payload.skill_id,
        accuracy_pct=payload.activity_accuracy_pct,
    )
    return {
        "student_id": payload.student_id,
        "skill_id": payload.skill_id,
        "next_review_date": next_date,
        "message": f"SM-2 updated. Next review: {next_date}",
    }


@app.get("/api/v1/intervention/sm2/full_schedule/{student_id}")
async def get_full_schedule(student_id: str):
    """Return all skill SM-2 dates for guardian dashboard."""
    return {
        "student_id": student_id,
        "schedule": await scheduler.get_schedule_summary(student_id),
    }


def _suggest_home_activity(error_type: str) -> str:
    suggestions = {
        "LONG_WORD": "Practice clapping syllables of 4+ syllable words at home.",
        "VOWEL_CONFUSION": "Read 'pilla' (vowel sign) flashcards with your child for 5 minutes.",
        "CONSONANT_CONFUSION": "Play picture-sound matching games for confused consonant pairs.",
        "UNFAMILIAR": "Read the word aloud 3 times together; then use it in a sentence.",
    }
    return suggestions.get(error_type, "Practice reading together for 10 minutes daily.")


@app.post("/api/v1/intervention/stroke_score")
async def score_stroke_endpoint(payload: dict):
    """
    Score a student stroke image against a template letter.
    Input: { student_img_base64: str, template_img_base64: str }
    Output: { accuracy_pct, sm2_quality, method, detail }
    Reference: De Silva et al. (2025) UCSC — CNN stroke accuracy scorer.
    """
    student_img = payload.get("student_img_base64", "")
    template_img = payload.get("template_img_base64", "")
    if not student_img or not template_img:
        raise HTTPException(status_code=422, detail="Both student_img_base64 and template_img_base64 required")
    return score_stroke(student_img, template_img)


@app.get("/api/v1/intervention/error_classifier/status")
def get_classifier_status():
    """
    Return which error classifier is active: SinBERT or rule_based.
    Used by demo UI to show classifier badge (Part 10.4).
    """
    from core.intervention_engine import _SINBERT_AVAILABLE, SINBERT_MODEL_PATH
    return {
        "model": "sinbert" if _SINBERT_AVAILABLE else "rule_based",
        "model_loaded": bool(_SINBERT_AVAILABLE),
        "model_path": str(SINBERT_MODEL_PATH),
        "training_accuracy": 0.70 if _SINBERT_AVAILABLE else None,
        "fallback": "rule_based",
        "reference": "Perera & Sumanathilaka (2025) arXiv:2510.04750",
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=PORT, reload=True)
