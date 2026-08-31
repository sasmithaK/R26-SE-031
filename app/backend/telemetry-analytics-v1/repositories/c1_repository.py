from __future__ import annotations
from database import get_db
from datetime import datetime

async def save_c1_state(state_data: dict) -> None:
    """Upsert the processed C1 result for a specific session."""
    db = get_db()
    
    # We upsert based on session_id to ensure idempotency.
    await db.behavioral_features.update_one(
        {"session_id": state_data.get("session_id")},
        {"$set": state_data},
        upsert=True
    )

async def get_recent_states(student_id: str, limit: int = 5) -> list[dict]:
    """Retrieve the most recent C1 states for a student to calculate rolling metrics."""
    db = get_db()
    cursor = db.behavioral_features.find({"student_id": student_id}).sort("_id", -1).limit(limit)
    return await cursor.to_list(length=limit)

async def get_c1_state_by_session(session_id: str) -> dict | None:
    """Retrieve the exact C1 processing result for a specific session."""
    db = get_db()
    return await db.behavioral_features.find_one({"session_id": session_id})

async def get_c1_trend(student_id: str, limit: int = 10) -> list[dict]:
    """Retrieve a list of C1TrendPoints for historical charts."""
    db = get_db()
    cursor = db.behavioral_features.find({"student_id": student_id}).sort("_id", -1).limit(limit)
    states = await cursor.to_list(length=limit)
    states.reverse() # chronological order
    
    trend = []
    for i, state in enumerate(states):
        trend.append({
            "session_id": state.get("session_id", ""),
            "session_index": i + 1,
            "accuracy": state.get("behavior", {}).get("accuracy", 0.0),
            "median_latency_ms": state.get("behavior", {}).get("median_latency_ms", 0.0),
            "fatigue_score": state.get("fatigue", {}).get("score", 0.0),
            "hesitation_rate": state.get("behavior", {}).get("hesitation_rate", 0.0),
            "timestamp": state.get("_id").generation_time if state.get("_id") else datetime.utcnow()
        })
    return trend

async def get_c1_sessions(student_id: str, limit: int = 10) -> list[dict]:
    """Retrieve a list of C1SessionSummary."""
    db = get_db()
    cursor = db.behavioral_features.find({"student_id": student_id}).sort("_id", -1).limit(limit)
    states = await cursor.to_list(length=limit)
    
    sessions = []
    for i, state in enumerate(states):
        sessions.append({
            "session_id": state.get("session_id", ""),
            "session_index": len(states) - i, # reverse index for display
            "accuracy": state.get("behavior", {}).get("accuracy", 0.0),
            "median_latency_ms": state.get("behavior", {}).get("median_latency_ms", 0.0),
            "hesitation_rate": state.get("behavior", {}).get("hesitation_rate", 0.0),
            "fatigue_score": state.get("fatigue", {}).get("score", 0.0),
            "timestamp": state.get("_id").generation_time if state.get("_id") else datetime.utcnow()
        })
    return sessions

async def get_parent_summary(student_id: str) -> dict | None:
    """Calculate and return a parent-safe C1 summary."""
    states = await get_recent_states(student_id, limit=5)
    if not states:
        return None
    
    latest = states[0]
    behavior = latest.get("behavior", {})
    fatigue = latest.get("fatigue", {})
    interaction = latest.get("interaction_state", {})
    
    # Calculate simple statuses
    median_latency = behavior.get("median_latency_ms", 0.0)
    response_speed = "DEVELOPING"
    if median_latency < 2000:
        response_speed = "EXCELLENT"
    elif median_latency < 4000:
        response_speed = "GOOD"
        
    attention = interaction.get("state", "UNKNOWN")
    if attention == "ENGAGED": attention = "GOOD"
    elif attention == "MODERATE_LOAD": attention = "FAIR"
    else: attention = "NEEDS_SUPPORT"
    
    fatigue_state = fatigue.get("state", "UNKNOWN")
    
    # Observations
    obs = []
    if len(states) >= 2:
        prev = states[1].get("behavior", {})
        if behavior.get("accuracy", 0) > prev.get("accuracy", 0):
            obs.append("The learner's accuracy improved since the last session.")
        if behavior.get("median_latency_ms", 0) > prev.get("median_latency_ms", 0) + 1000:
            obs.append("Response time increased, which might indicate harder activities or lower focus.")
            
    if not obs:
        obs.append("The learner is practicing steadily.")
        
    # Recommendations
    recs = ["Visual letter matching", "Letter recognition"]
    
    return {
        "student_id": student_id,
        "overall_progress": int(behavior.get("completion_rate", 0.0) * 100) if behavior.get("completion_rate") else 68,
        "accuracy": int(behavior.get("accuracy", 0.0) * 100),
        "response_speed": response_speed,
        "attention": attention,
        "fatigue": fatigue_state,
        "learning_observations": obs,
        "recommended_practice": recs,
        "updated_at": latest.get("_id").generation_time if latest.get("_id") else datetime.utcnow()
    }
