"""
content-service-v2/main.py
============================
C3 — Personalized Learning Content Engine (PLCE)
FastAPI application — Port 8012

Endpoints:
    POST /api/v1/mastery/update            → BKT update for a skill
    GET  /api/v1/mastery/{student_id}      → Full mastery_vector
    GET  /api/v1/content/next/{student_id} → ZPD-targeted next content item
    POST /api/v1/content/learner_type      → Set VARK learner tag
    POST /api/v1/students/initialize       → Initialize BKT + SM2 for new student
    GET  /health
"""

import os
import sys
import time
from pathlib import Path
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

sys.path.insert(0, str(Path(__file__).parent.parent))
sys.path.insert(0, str(Path(__file__).parent))

from shared.schemas import (
    MasteryUpdatePayload, MasteryUpdateResponse, ContentItemResponse,
    ContentItem, LearnerTypePayload, BKTState, Modality
)
from core.bkt_engine import BKTEngine
from core.content_selector import ContentSelector
from shared.database import connect_to_mongo, close_mongo_connection, get_db

# ── Configuration ──────────────────────────────────────────────────────────
CONTENT_PATH = str(Path(__file__).parent / "data" / "content_repository.json")
PORT = int(os.getenv("C3_PORT", "8012"))
Path("./db").mkdir(parents=True, exist_ok=True)

# ── Engines ────────────────────────────────────────────────────────────────
bkt = BKTEngine()
selector = ContentSelector(content_path=CONTENT_PATH)

# ── Learner type store ─────────────────────────────────────────────────────

async def _get_learner_type(student_id: str) -> str:
    db = get_db()
    row = await db.learner_types.find_one({"student_id": student_id})
    return row.get("learner_type", "V") if row else "V"


# ── App ────────────────────────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    await connect_to_mongo()
    yield
    await close_mongo_connection()

app = FastAPI(
    title="C3 — Personalized Learning Content Engine (PLCE)",
    description="BKT mastery tracking + ZPD content selection for Sinhala dyslexia screening.",
    version="2.0.0",
    lifespan=lifespan
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_methods=["*"], allow_headers=["*"],
)


@app.get("/health")
def health():
    return {"status": "ok", "service": "C3-PLCE"}


@app.post("/api/v1/students/initialize")
async def initialize_student(student_id: str):
    """Called at onboarding: set all BKT skills to P_init = 0.3."""
    await bkt.initialize_student(student_id)
    return {
        "student_id": student_id,
        "message": "Student BKT initialized. All skills set to p_know=0.3.",
        "mastery_vector": await bkt.get_mastery_vector(student_id),
    }


@app.post("/api/v1/mastery/update", response_model=MasteryUpdateResponse)
async def update_mastery(payload: MasteryUpdatePayload):
    """
    Apply BKT update for a student's skill response.
    cognitive_load_index and session_fatigue_index are logged but
    their effect on content selection happens in /content/next.
    """
    before, after = await bkt.update(
        student_id=payload.student_id,
        skill_id=payload.skill_id,
        is_correct=payload.is_correct,
    )
    from core.bkt_engine import MASTERY_THRESHOLD, ZPD_LOWER, ZPD_UPPER
    return MasteryUpdateResponse(
        student_id=payload.student_id,
        skill_id=payload.skill_id,
        p_know_before=round(before, 4),
        p_know_after=round(after, 4),
        mastery_achieved=after > MASTERY_THRESHOLD,
        zpd_active=ZPD_LOWER <= after <= ZPD_UPPER,
    )


@app.get("/api/v1/mastery/{student_id}")
async def get_mastery(student_id: str):
    """Return full mastery_vector for a student. Used by C4 (IIGE) via API."""
    vector = await bkt.get_mastery_vector(student_id)
    if not any(v > 0 for v in vector.values()):
        # Student not initialized — initialize with defaults
        await bkt.initialize_student(student_id)
        vector = await bkt.get_mastery_vector(student_id)
    return {
        "student_id": student_id,
        "mastery_vector": {k: round(v, 4) for k, v in vector.items()},
        "next_recommended_skill": await bkt.get_next_skill(student_id),
    }


@app.get("/api/v1/content/next/{student_id}", response_model=ContentItemResponse)
async def get_next_content(
    student_id: str,
    cognitive_load_index: float = 0.5,
    session_fatigue_index: float = 0.0,
):
    """
    Return the next content item for a student using ZPD + IRT difficulty targeting.

    Query params:
        cognitive_load_index:   From C1 MBSV (consumed by C3 only).
        session_fatigue_index:  From C1 MBSV (consumed by C3 only).
    """
    mastery_vector = await bkt.get_mastery_vector(student_id)
    target_skill = await bkt.get_next_skill(student_id)
    learner_type = await _get_learner_type(student_id)
    from core.bkt_engine import MASTERY_THRESHOLD, ZPD_LOWER, ZPD_UPPER
    from core.content_selector import FATIGUE_THRESHOLD

    item_dict = selector.select(
        student_id=student_id,
        target_skill_id=target_skill,
        mastery_vector=mastery_vector,
        cognitive_load_index=cognitive_load_index,
        session_fatigue_index=session_fatigue_index,
        learner_type=learner_type,
    )

    if not item_dict:
        raise HTTPException(status_code=404, detail="No content items found for this skill.")

    content_item = ContentItem(
        item_id=item_dict["item_id"],
        skill_id=item_dict["skill_id"],
        sinhala_text=item_dict["sinhala_text"],
        english_gloss=item_dict.get("english_gloss"),
        irt_difficulty_b=item_dict.get("irt_difficulty_b", 0.0),
        audio_url=item_dict.get("audio_url"),
        image_url=item_dict.get("image_url"),
        modality=Modality(item_dict.get("modality", "VISUAL")),
    )

    p_know = mastery_vector.get(target_skill, 0.3)
    return ContentItemResponse(
        student_id=student_id,
        content_item=content_item,
        bkt_p_know=round(p_know, 4),
        zpd_active=ZPD_LOWER <= p_know <= ZPD_UPPER,
        fatigue_override=session_fatigue_index > FATIGUE_THRESHOLD,
        mastery_vector={k: round(v, 4) for k, v in mastery_vector.items()},
    )


@app.post("/api/v1/content/learner_type")
async def set_learner_type(payload: LearnerTypePayload):
    """Store VARK learner type from guardian onboarding questionnaire."""
    db = get_db()
    await db.learner_types.update_one(
        {"student_id": payload.student_id},
        {"$set": {
            "learner_type": payload.learner_type.value,
            "updated_ms": int(time.time() * 1000)
        }},
        upsert=True
    )
    return {
        "student_id": payload.student_id,
        "learner_type": payload.learner_type.value,
        "message": "Learner type stored.",
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=PORT, reload=True)
