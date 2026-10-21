from __future__ import annotations
from database import get_db
from datetime import datetime


_KC_PRACTICE_LABELS = {
    "KC_VISUAL_IDENTIFICATION": "Visual identification",
    "KC_VISUAL_MATCHING": "Visual matching",
    "KC_VISUAL_CATEGORIZATION": "Visual categorisation",
    "KC_VISUAL_PATTERN": "Visual patterns",
    "KC_VISUAL_MEMORY": "Visual memory",
    "KC_LETTER_IDENTIFICATION": "Letter identification",
    "KC_LETTER_MATCHING": "Letter matching",
    "KC_LETTER_MEMORY": "Letter memory",
    "KC_LETTER_DECODING": "Letter decoding",
    "KC_PHONEME_LETTER_MAPPING": "Sound and letter matching",
    "KC_WORD_RECOGNITION": "Word recognition",
    "KC_ORAL_READING_FLUENCY": "Reading aloud",
    "KC_READING_COMPREHENSION": "Reading comprehension",
    "KC_SPELLING_SEQUENCE": "Spelling sequence",
    "KC_SENTENCE_LANGUAGE": "Sentence building",
}


def _recommendations_from_observed_evidence(state: dict) -> list[str]:
    """Return guidance only when the stored session measured a weakness."""
    knowledge_components = state.get("knowledge_components") or {}
    measured = []
    for kc, values in knowledge_components.items():
        accuracy = values.get("accuracy") if isinstance(values, dict) else None
        trials = values.get("trials", 0) if isinstance(values, dict) else 0
        if isinstance(accuracy, (int, float)) and trials:
            measured.append((float(accuracy), kc))

    if not measured:
        behavior = state.get("behavior") or {}
        independent_accuracy = behavior.get("independent_accuracy")
        if isinstance(independent_accuracy, (int, float)):
            if independent_accuracy < 0.80:
                return ["Repeat recently completed activities with light support, then try again independently."]
            return ["Continue practising the completed activities to build confidence."]
        return ["Complete a few more activities to receive personalised practice guidance."]

    accuracy, weakest_kc = min(measured)
    label = _KC_PRACTICE_LABELS.get(weakest_kc, "the least secure activity area")
    if accuracy >= 0.80:
        return ["Continue practising the completed activities to build confidence."]
    return [f"Practise {label.lower()} with a short, supported activity."]

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
            "accuracy": (state.get("behavior") or {}).get("accuracy"),
            "median_latency_ms": (state.get("behavior") or {}).get("median_latency_ms"),
            "fatigue_score": (state.get("fatigue") or {}).get("score"),
            "hesitation_rate": (state.get("behavior") or {}).get("hesitation_rate"),
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
            "accuracy": (state.get("behavior") or {}).get("accuracy"),
            "median_latency_ms": (state.get("behavior") or {}).get("median_latency_ms"),
            "hesitation_rate": (state.get("behavior") or {}).get("hesitation_rate"),
            "fatigue_score": (state.get("fatigue") or {}).get("score"),
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
    median_latency = behavior.get("median_latency_ms")
    response_speed = "NOT_MEASURED"
    if isinstance(median_latency, (int, float)) and median_latency > 0:
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
        acc_now, acc_prev = behavior.get("accuracy"), prev.get("accuracy")
        lat_now, lat_prev = behavior.get("median_latency_ms"), prev.get("median_latency_ms")
        if isinstance(acc_now, (int, float)) and isinstance(acc_prev, (int, float)) and acc_now > acc_prev:
            obs.append("The learner's accuracy improved since the last session.")
        if isinstance(lat_now, (int, float)) and isinstance(lat_prev, (int, float)) and lat_now > lat_prev + 1000:
            obs.append("Response time increased, which might indicate harder activities or lower focus.")
            
    if not obs:
        obs.append("The learner is practicing steadily.")
        
    # Recommendations must be grounded in this child's observed curriculum
    # evidence. Never show a generic activity as if it were personalised.
    recs = _recommendations_from_observed_evidence(latest)

    completion_rate = behavior.get("completion_rate")
    overall_progress = (
        int(float(completion_rate) * 100)
        if isinstance(completion_rate, (int, float))
        else None
    )
    
    return {
        "student_id": student_id,
        # Missing completion data is missing data, not 68% progress.
        "overall_progress": overall_progress,
        "accuracy": (int(behavior["accuracy"] * 100)
                     if isinstance(behavior.get("accuracy"), (int, float)) else None),
        "response_speed": response_speed,
        "attention": attention,
        "fatigue": fatigue_state,
        "learning_observations": obs,
        "recommended_practice": recs,
        "updated_at": latest.get("_id").generation_time if latest.get("_id") else datetime.utcnow()
    }
