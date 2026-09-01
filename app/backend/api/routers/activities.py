from fastapi import APIRouter, HTTPException, Depends, Query
from typing import Optional
from shared.database import get_db
from services.ml_engine import CognitiveLoadClassifier

router = APIRouter(
    prefix="/api/v1/auth/activities",
    tags=["Activities CMS"]
)

@router.get("/{skill_id}")
async def get_activities_for_skill(
    skill_id: str,
    student_id: Optional[str] = Query(None, description="Optional Student ID for ML dynamic adaptation")
):
    """
    Returns the dynamic JSON configuration for all activities within a skill.
    Fetches directly from the MongoDB CMS collection.
    If student_id is provided, intercepts and rewrites payload dynamically via ML.
    """
    db = get_db()
    skill_data = await db["curriculum"].find_one({"id": skill_id}, {"_id": 0})
    
    if not skill_data:
        # For now, return an empty structure so the app doesn't crash on unmocked skills
        return {
            "id": skill_id,
            "title": skill_id.replace("_", " ").title(),
            "activities": []
        }
        
    # --- ML Engine Interception ---
    if student_id:
        # Fetch the last 10 telemetry events for this student to determine load
        cursor = db.telemetry_events.find({"student_id": student_id, "schema_version": "2.0"}).sort("submitted_at", -1).limit(10)
        recent_telemetry = await cursor.to_list(length=10)
        
        classification = CognitiveLoadClassifier.classify(recent_telemetry)
        skill_data = CognitiveLoadClassifier.adapt_curriculum(skill_data, classification)
        
        # Inject classification into the metadata so frontend can trace it if needed
        skill_data["ml_classification"] = classification
    
    return skill_data
