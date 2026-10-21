from fastapi import APIRouter, Query
from typing import Optional
from shared.database import get_db

router = APIRouter(
    prefix="/api/v1/auth/activities",
    tags=["Activities CMS"]
)


@router.get("/{skill_id}")
async def get_activities_for_skill(
    skill_id: str,
    student_id: Optional[str] = Query(
        None,
        description="Accepted for backward compatibility; content is not rewritten per learner.",
    ),
):
    """Return the stored JSON configuration for all activities within a skill.

    Adaptation is handled only by Component 4 (adaptive tutoring). The former
    heuristic "cognitive load" rewrite of the curriculum was removed so that a
    second, undocumented policy can never change what a child sees.
    """
    db = get_db()
    skill_data = await db["curriculum"].find_one({"id": skill_id}, {"_id": 0})
    if not skill_data:
        return {
            "id": skill_id,
            "title": skill_id.replace("_", " ").title(),
            "activities": [],
        }
    return skill_data
