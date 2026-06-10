"""
visual-service-v1/main.py
===========================
C2 — Adaptive Visual Learning Interface (AVLI)
FastAPI application — Port 8014

Endpoints:
    POST /api/v1/ui/typography               → LinUCB arm select → typography config
    POST /api/v1/ui/reward                   → LinUCB update after reading attempt
    GET  /api/v1/ui/gamification/status/{student_id} → Gamification trigger check
    POST /api/v1/ui/preferences              → Store student onboarding preferences
    GET  /api/v1/ui/linucb/stats             → Bandit performance stats
    GET  /health
"""

import os
import sys
import time
from pathlib import Path
from typing import Optional
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

sys.path.insert(0, str(Path(__file__).parent.parent))
sys.path.insert(0, str(Path(__file__).parent))

import numpy as np

from shared.schemas import (
    TypographyRequest, TypographyResponse, TypographyConfig,
    RewardPayload, StudentPreferences
)
from core.linucb import LinUCBAgent, build_context_vector, compute_reward
from core.sovcm import task_complexity as sovcm_task_complexity, crowding_load as sovcm_crowding_load
from shared.database import connect_to_mongo, close_mongo_connection, get_db

# ── Configuration ──────────────────────────────────────────────────────────
MODELS_DIR = Path(__file__).parent.parent / "models"
DATA_DIR   = Path(__file__).parent / "data"
STATE_PATH   = str(MODELS_DIR / "c2_linucb_agent_warmstart.pkl")
PRESETS_PATH = str(DATA_DIR / "arm_presets.json")
PORT = int(os.getenv("C2_PORT", "8014"))

ENGAGEMENT_LOW_THRESHOLD = float(os.getenv("ENGAGEMENT_LOW_THRESHOLD", "0.30"))
VISUAL_STRAIN_TRIGGER    = float(os.getenv("VISUAL_STRAIN_TRIGGER", "0.60"))

MODELS_DIR.mkdir(parents=True, exist_ok=True)
Path("./db").mkdir(parents=True, exist_ok=True)

# ── LinUCB Agent ───────────────────────────────────────────────────────────
agent = LinUCBAgent.load_or_create(STATE_PATH, PRESETS_PATH)

# ── Gamification tracker (in-memory: {student_id: [timestamps of low engagement]}) ─
_low_engagement_events: dict = {}

# ── Context cache: stores the context vector used during arm selection so the
#    reward update can use the exact same context (not reconstructed defaults).
#    Keyed by (student_id, session_id) → (arm_id, context_ndarray)
_arm_context_cache: dict = {}

# ── DB helpers ─────────────────────────────────────────────────────────────

async def _get_preferences(student_id: str) -> dict:
    db = get_db()
    row = await db.student_preferences.find_one({"student_id": student_id})
    if row:
        return {"font": row.get("preferred_font", "NotoSansSinhala"),
                "theme": row.get("preferred_theme", "Calm Blue"),
                "language": row.get("language", "si"),
                "learner_type": row.get("learner_type", "V")}
    return {"font": "NotoSansSinhala", "theme": "Calm Blue", "language": "si", "learner_type": "V"}


def _check_gamification_trigger(student_id: str, engagement_index: float) -> bool:
    """
    Gamification trigger: engagement_index < 0.3 for 2 consecutive 30s windows.
    """
    now = time.time()
    events = _low_engagement_events.setdefault(student_id, [])
    if engagement_index < ENGAGEMENT_LOW_THRESHOLD:
        events.append(now)
    # Keep only events from last 90s (3 windows)
    _low_engagement_events[student_id] = [t for t in events if now - t < 90]
    # Count events in two consecutive 30s windows
    recent = [t for t in _low_engagement_events[student_id] if now - t < 60]
    return len(recent) >= 2  # ≥2 low-engagement events in 60s window


# ── App ────────────────────────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    await connect_to_mongo()
    yield
    await close_mongo_connection()

app = FastAPI(
    title="C2 — Adaptive Visual Learning Interface (AVLI)",
    description="LinUCB contextual bandit for Sinhala-specific typography adaptation + gamification controller.",
    version="2.0.0",
    lifespan=lifespan
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_methods=["*"], allow_headers=["*"],
)


@app.get("/health")
def health():
    return {"status": "ok", "service": "C2-AVLI", "linucb_steps": agent.total_steps}


@app.post("/api/v1/ui/typography", response_model=TypographyResponse)
async def get_typography(request: TypographyRequest):
    """
    Select typography configuration via LinUCB.
    Uses visual_strain_index + engagement_index from MBSV (C2's dimensions only).
    Context includes SOVCM complexity score (novel abugida-specific feature).
    """
    prefs = await _get_preferences(request.student_id)
    content_text = request.current_content_text or ""

    # Real SOVCM — mean composite score across all Sinhala chars in current content
    task_complexity = sovcm_task_complexity(content_text)

    # Real crowding load — uses the arm-0 baseline letter_spacing (2.0px) as prior;
    # we compute before arm selection because the context informs the selection
    baseline_spacing = 2.0
    crowding = sovcm_crowding_load(content_text, baseline_spacing)

    context = build_context_vector(
        visual_strain_index=request.visual_strain_index,
        engagement_index=request.engagement_index,
        session_number=request.session_number,
        child_age_years=request.child_age_years,
        task_complexity_sovcm=task_complexity,
        crowding_load=crowding,
        phonological_strain_index=request.phonological_strain_index,
    )

    arm_id = agent.select_arm(context)
    preset = agent.get_typography_config(arm_id)

    # Cache context so the reward endpoint can use the exact same vector
    _arm_context_cache[(request.student_id, request.session_id)] = (arm_id, context)

    # Override font from student preferences
    config = TypographyConfig(
        font_size=preset.get("font_size", 20.0),
        font_family=prefs["font"],
        letter_spacing=preset.get("letter_spacing", 2.0),
        word_spacing=preset.get("word_spacing", 8.0),
        line_height=preset.get("line_height", 1.6),
        background_contrast=preset.get("background_contrast", "WCAG_AA"),
        diacritic_offset=preset.get("diacritic_offset", 0.0),
        glyph_padding=preset.get("glyph_padding", 0.0),
    )

    game_trigger = _check_gamification_trigger(request.student_id, request.engagement_index)

    # Dynamic game difficulty: easier game when very disengaged, harder when moderately engaged
    if request.engagement_index < 0.2:
        game_difficulty = 1
    elif request.engagement_index > 0.6:
        game_difficulty = 3
    else:
        game_difficulty = 2

    return TypographyResponse(
        student_id=request.student_id,
        linucb_arm_selected=arm_id,
        typography_config=config,
        game_mode_trigger=game_trigger,
        game_difficulty=game_difficulty,
    )


@app.post("/api/v1/ui/reward")
async def update_reward(payload: RewardPayload):
    """Update LinUCB with reward signal after a reading attempt."""
    reward = compute_reward(
        payload.visual_strain_before,
        payload.visual_strain_after,
        payload.reading_accuracy_delta,
    )

    # Retrieve the exact context used when this arm was selected; fall back to a
    # visual-strain-only reconstruction if the session key has expired from cache
    cached = _arm_context_cache.get((payload.student_id, payload.session_id))
    if cached is not None:
        _, context = cached
    else:
        context = build_context_vector(
            visual_strain_index=payload.visual_strain_before,
            engagement_index=0.5,
            session_number=1,
            child_age_years=None,
            task_complexity_sovcm=0.5,
            crowding_load=0.4,
            phonological_strain_index=0.0,
        )

    agent.update(payload.arm_id, context, reward)
    agent.save(STATE_PATH)

    db = get_db()
    await db.linucb_history.insert_one({
        "student_id": payload.student_id,
        "session_id": payload.session_id,
        "arm_id": payload.arm_id,
        "reward": float(reward),
        "timestamp_ms": int(time.time() * 1000)
    })

    return {
        "student_id": payload.student_id,
        "arm_id": payload.arm_id,
        "reward": round(reward, 4),
        "cumulative_reward": round(agent.cumulative_reward, 4),
    }


@app.get("/api/v1/ui/gamification/status/{student_id}")
def get_gamification_status(student_id: str, engagement_index: float = 0.5):
    """Check if gamification mode should be triggered for a student."""
    triggered = _check_gamification_trigger(student_id, engagement_index)
    if triggered:
        # Reset events after trigger to avoid repeated triggering
        _low_engagement_events[student_id] = []
    return {
        "student_id": student_id,
        "game_mode_trigger": triggered,
        "game_difficulty": 2,
    }


@app.post("/api/v1/ui/preferences")
async def store_preferences(prefs: StudentPreferences):
    """Store student UI preferences from guardian onboarding."""
    db = get_db()
    await db.student_preferences.update_one(
        {"student_id": prefs.student_id},
        {"$set": {
            "preferred_font": prefs.preferred_font,
            "preferred_theme": prefs.preferred_theme,
            "language": prefs.language,
            "learner_type": prefs.learner_type.value,
            "updated_ms": int(time.time() * 1000)
        }},
        upsert=True
    )
    return {"student_id": prefs.student_id, "message": "Preferences stored."}


@app.get("/api/v1/ui/linucb/stats")
def get_linucb_stats():
    """Return LinUCB performance statistics for research evaluation."""
    return agent.get_stats()


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=PORT, reload=True)
