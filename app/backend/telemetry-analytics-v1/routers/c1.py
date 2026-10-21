from fastapi import APIRouter, HTTPException, status, Depends
from typing import List

from dependencies import get_current_user, require_owned_student
from schemas.telemetry import TelemetrySessionSubmit
from schemas.c1 import (
    C1Result, ParentC1Summary, TherapistC1State, 
    C1TrendPoint, C1SessionSummary
)
from services.c1.processor import process_session
from repositories import telemetry_repository, c1_repository

router = APIRouter(prefix="/api/v1/c1", tags=["C1 Analytics"])

@router.post("/session", response_model=C1Result, status_code=status.HTTP_201_CREATED)
async def process_c1_session(
    payload: TelemetrySessionSubmit,
    current_user: dict = Depends(get_current_user)
):
    """
    Component 1 Canonical Pipeline:
    1. Ingest telemetry session
    2. Save raw telemetry
    3. Extract behavioral features
    4. Calculate Learner-State & Fatigue
    5. Predict Pattern (ML)
    6. Store C1 State
    """
    await require_owned_student(payload.student_id, current_user)
    session_data = payload.model_dump()
    events_data = session_data.pop("events", [])
    
    for e in events_data:
        e["session_id"] = payload.session_id
        e["student_id"] = payload.student_id
        
    await telemetry_repository.save_session(session_data)
    await telemetry_repository.save_events(events_data)
    
    c1_partial = process_session(payload.session_id, payload.student_id, events_data)
    # Per-session model retired: the estimate is per learner (c1_learner_estimates).
    c1_partial["model"] = {
        "model_name": "c1_learner_model",
        "model_version": "learner-level",
        "feature_schema_version": "c1-learner-v2",
        "predicted_pattern": None,
        "probabilities": {},
        "confidence": None,
        "model_used": "learner_level_only",
        "unavailable_reason": "The C1 pattern estimate is made per learner over 14 days (c1_learner_estimates), not per session.",
    }
    
    await c1_repository.save_c1_state(c1_partial)
    return c1_partial

@router.get("/student/{student_id}/history", response_model=List[C1Result])
async def get_c1_history(
    student_id: str,
    limit: int = 5,
    current_user: dict = Depends(get_current_user)
):
    """Retrieve the recent C1 learner states for a student."""
    await require_owned_student(student_id, current_user)
    states = await c1_repository.get_recent_states(student_id, limit=limit)
    return states

@router.get("/students/{student_id}/summary", response_model=ParentC1Summary)
async def get_student_summary(student_id: str, current_user: dict = Depends(get_current_user)):
    """Parent dashboard endpoint."""
    await require_owned_student(student_id, current_user)
    summary = await c1_repository.get_parent_summary(student_id)
    if not summary:
        raise HTTPException(status_code=404, detail="No analytics found for this student")
    return summary

@router.get("/students/{student_id}/state", response_model=TherapistC1State)
async def get_student_state(student_id: str, current_user: dict = Depends(get_current_user)):
    """Therapist dashboard endpoint (latest full state)."""
    await require_owned_student(student_id, current_user)
    states = await c1_repository.get_recent_states(student_id, limit=1)
    if not states:
        raise HTTPException(status_code=404, detail="No analytics found for this student")
    state = states[0]
    state['updated_at'] = state.get('_id').generation_time if state.get('_id') else None
    return state

@router.get("/students/{student_id}/trend", response_model=List[C1TrendPoint])
async def get_student_trend(student_id: str, current_user: dict = Depends(get_current_user)):
    """Trend charts endpoint."""
    await require_owned_student(student_id, current_user)
    return await c1_repository.get_c1_trend(student_id)

@router.get("/students/{student_id}/sessions", response_model=List[C1SessionSummary])
async def get_student_sessions(student_id: str, current_user: dict = Depends(get_current_user)):
    """Session history list endpoint."""
    await require_owned_student(student_id, current_user)
    return await c1_repository.get_c1_sessions(student_id)

@router.get("/sessions/{session_id}", response_model=C1Result)
async def get_session_detail(session_id: str, current_user: dict = Depends(get_current_user)):
    """Specific session detailed view endpoint."""
    session = await c1_repository.get_c1_state_by_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    await require_owned_student(session["student_id"], current_user)
    return session

@router.get("/students/{student_id}/skills-breakdown")
async def get_skills_breakdown(student_id: str, current_user: dict = Depends(get_current_user)):
    """Aggregate per-skill and per-activity performance metrics directly from telemetry events."""
    await require_owned_student(student_id, current_user)
    from database import get_db
    db = get_db()
    cursor = db.telemetry_events.find({"student_id": student_id})
    events = await cursor.to_list(length=2000)
    
    skills: dict = {}
    for e in events:
        s_id = e.get("skill_id", "unknown_skill")
        act_id = e.get("activity_id", "unknown_activity")
        is_corr = 1 if e.get("is_correct") or e.get("final_correct") else 0
        lat = e.get("total_round_latency_ms", 0) or e.get("first_touch_latency_ms", 0)
        
        if s_id not in skills:
            skills[s_id] = {"total_trials": 0, "correct_trials": 0, "latencies": [], "activities": {}}
            
        skills[s_id]["total_trials"] += 1
        skills[s_id]["correct_trials"] += is_corr
        if lat > 0:
            skills[s_id]["latencies"].append(lat)
            
        if act_id not in skills[s_id]["activities"]:
            skills[s_id]["activities"][act_id] = {"trials": 0, "correct": 0}
        skills[s_id]["activities"][act_id]["trials"] += 1
        skills[s_id]["activities"][act_id]["correct"] += is_corr

    breakdown = []
    for s_id, s_data in skills.items():
        avg_lat = sum(s_data["latencies"]) / len(s_data["latencies"]) if s_data["latencies"] else 0.0
        acc = s_data["correct_trials"] / s_data["total_trials"] if s_data["total_trials"] else 0.0
        breakdown.append({
            "skill_id": s_id,
            "accuracy": round(acc, 4),
            "mean_latency_ms": round(avg_lat, 2),
            "total_trials": s_data["total_trials"],
            "activities": [
                {
                    "activity_id": a_id,
                    "accuracy": round(a_data["correct"] / a_data["trials"], 4) if a_data["trials"] else 0.0,
                    "total_trials": a_data["trials"]
                }
                for a_id, a_data in s_data["activities"].items()
            ]
        })
    return {"student_id": student_id, "skills": breakdown}

@router.get("/students/{student_id}/performance-tree")
async def get_performance_tree(student_id: str, current_user: dict = Depends(get_current_user)):
    return await get_skills_breakdown(student_id, current_user)
