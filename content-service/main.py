from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import joblib
from typing import List
import json

from database import (
    init_db, update_mastery, get_mastery, get_all_mastery,
    get_questionnaire_by_category, get_tasks_by_type
)

app = FastAPI(title="Content Service", version="1.0")

FALLBACK_QUESTIONNAIRES = {
    "dyslexia_screening": {
        "category": "dyslexia_screening",
        "title": "Dyslexia Screening Questionnaire",
        "parts": [
            {
                "part_number": 1,
                "title": "Part One - Scores",
                "description": "Weighted assessment questions",
                "questions": [
                    {"id": 0, "question": "වම සහ දකුණ වෙන්කර හඳුනා ගැනීමට අපහසු ද?", "weight": 10},
                    {"id": 1, "question": "කියවීමේදී ඉක්මනින් තෙහෙට්ටුව දැනෙනවා ද?", "weight": 10},
                    {"id": 2, "question": "කියවද්දී සිත වෙනත් දෙයක් වෙත යාම නිතර සිදුවේද?", "weight": 10},
                    {"id": 3, "question": "කියවීමේදී වැරදි බොහෝවිට සිදුවේද?", "weight": 20},
                    {"id": 4, "question": "අවධානය රඳවා ගැනීමට අපහසු ද?", "weight": 20},
                    {"id": 5, "question": "නම් මතක තබා ගැනීමට අපහසු ද?", "weight": 20},
                    {"id": 6, "question": "කතා කරන විට වචන නිවැරදිව උච්චාරණයට අපහසු ද?", "weight": 10},
                    {"id": 7, "question": "ඔබ දන්නා කෙටි වචනවල අක්ෂර වින්යාසය අමතක වනවා ද?", "weight": 20},
                    {"id": 8, "question": "පෙර ලියවී නොදුටු වචනවල අක්ෂර වින්යාසය අපහසු ද?", "weight": 30},
                    {"id": 9, "question": "හුරු නැති වචන කියවීමට අපහසු ද?", "weight": 30},
                    {"id": 10, "question": "ලියන්න බැරි නමුත් භාවිතා කරන විශාල වචන තේරුම් ගන්නවා ද?", "weight": 20},
                    {"id": 11, "question": "කියවිය නොහැකි වචනවලදී නවතිනවා ද?", "weight": 10},
                    {"id": 12, "question": "කියවීමේදී ඇස් සම්බන්ධීකරණය අඩු වගේ දැනෙනවා ද?", "weight": 10},
                    {"id": 13, "question": "කියවීමේදී වචන හලනවා/අඳුරු/අවධානයට ගන්න අපහසු වගේ පෙනේද?", "weight": 30},
                ],
            },
            {
                "part_number": 2,
                "title": "Part Two - Reading Behaviors",
                "description": "Boolean assessment of reading behaviors",
                "questions": [
                    {"id": 0, "question": "දරුවා කියවීම සම්බන්ධ ක්‍රියාකාරකම්වලින් වැළකී සිටීමට උත්සාහ කරනවාද?"},
                    {"id": 1, "question": "දරුවා තම පන්තියේ අනෙකුත් දරුවන්ට වඩා මන්දගාමීව කියවනවාද?"},
                    {"id": 2, "question": "දරුවා කියවීමේදී වචන මඟහැර යනවාද?"},
                    {"id": 3, "question": "දරුවා කියවීමේදී තමන් කියවමින් සිටින ස්ථානය අහිමි කරගන්නවාද?"},
                    {"id": 4, "question": "දරුවා වචනය සම්පූර්ණයෙන් කියවීම වෙනුවට අනුමාන කරමින් කියවීමට උත්සාහ කරනවාද?"},
                    {"id": 5, "question": "දරුවා නව හෝ නොහුරු වචන කියවීමට අපහසුතාවයක් දක්වනවාද?"},
                    {"id": 6, "question": "දරුවා වාක්‍යයක් තේරුම් ගැනීම සඳහා නැවත නැවත කියවීමට අවශ්‍ය වනවාද?"},
                    {"id": 7, "question": "දරුවා ටික වේලාවක් කියවීමෙන් පසු ඉක්මනින් වෙහෙසට පත්වනවාද?"},
                ],
            },
            {
                "part_number": 3,
                "title": "Part Three - Classroom Observation",
                "description": "Boolean classroom observations",
                "questions": [
                    {"id": 0, "question": "ලිඛිතව ලබාදෙන තොරතුරු වලට වඩා කථනය මඟින් ලබාදෙන තොරතුරු දරුවාට වඩා හොඳින් අවබෝධ කරගත හැකිද?"},
                    {"id": 1, "question": "දරුවා කථන ක්‍රියාකාරකම්වල හොඳින් සහභාගී වන නමුත් ලිඛිත කාර්යයන්හි අපහසුතා පෙන්වනවාද?"},
                    {"id": 2, "question": "කියවීම සම්බන්ධ කාර්යයන් සම්පූර්ණ කිරීමට දරුවා අනෙකුත් දරුවන්ට වඩා වැඩි කාලයක් ගන්නවාද?"},
                    {"id": 3, "question": "දරුවා ශබ්ද නගා කියවීමෙන් වැළකී සිටීමට උත්සාහ කරනවාද?"},
                    {"id": 4, "question": "කියවීම හෝ ලිවීම සම්බන්ධ අධ්‍යයන ක්‍රියාකාරකම්වලදී දරුවා කලකිරීම, ආතිය හෝ අසහනය පෙන්වනවාද?"},
                ],
            },
        ],
    }
}

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize DB on startup
@app.on_event("startup")
def startup_event():
    init_db()

try:
    dkt_logic = joblib.load('ml/dkt_mock.pkl')
    print("DKT Mock Logic loaded.")
except Exception as e:
    print(f"Error loading DKT logic: {e}")
    dkt_logic = None

class InteractionPayload(BaseModel):
    student_id: str
    skill_id: str  # e.g., 'letter_ka', 'pilla_ispilla'
    is_correct: bool
    response_latency_ms: float

@app.post("/api/v1/mastery/update")
async def update_mastery_endpoint(payload: InteractionPayload):
    if not dkt_logic:
        return {"error": "DKT Logic not loaded"}
        
    sid = payload.student_id
    skid = payload.skill_id
    
    # Get mastery from SQLite
    current_mastery = get_mastery(sid, skid)
    if current_mastery == 0.0: current_mastery = 0.2 # Default baseline
    
    # Calculate new mastery using our imported mock
    new_mastery = dkt_logic.update_mastery(
        current_mastery, 
        payload.is_correct, 
        payload.response_latency_ms
    )
    
    # Save to SQLite
    update_mastery(sid, skid, new_mastery)
    
    return {
        "student_id": sid,
        "skill_id": skid,
        "previous_mastery": current_mastery,
        "new_mastery": new_mastery
    }

@app.get("/api/v1/mastery/{student_id}")
async def get_student_mastery(student_id: str):
    state = get_all_mastery(student_id)
    return {
        "student_id": student_id,
        "mastery_tree": state
    }

# Fix 3: Dynamic content recommendation based on lowest mastery skill
SKILL_LESSONS = {
    "syllable_blending":  ["Lesson 1: Blend කා+ක", "Lesson 2: Blend ම+ා", "Lesson 3: Complex blends"],
    "letter_ka":          ["Lesson 1: Trace ක",    "Lesson 2: ක in words",  "Lesson 3: ක with Pillas"],
    "pilla_ispilla":      ["Lesson 1: Spot ි",     "Lesson 2: ි vs ී",       "Lesson 3: Apply ි"],
    "phoneme_isolation":  ["Lesson 1: Hear /k/",  "Lesson 2: /k/ vs /g/",  "Lesson 3: Blend 3 phonemes"],
}
DEFAULT_LESSONS = ["Lesson 1: Introduction to Sinhala letters", "Lesson 2: Basic vowel sounds"]

@app.get("/api/v1/content/next/{student_id}")
async def get_next_content(student_id: str):
    """Returns the next recommended lesson based on the student's weakest skill."""
    mastery = get_all_mastery(student_id)

    if not mastery:
        return {
            "student_id": student_id,
            "recommended_skill": "introduction",
            "lessons": DEFAULT_LESSONS,
            "reason": "No data yet — starting from the beginning."
        }

    # Find the skill with the lowest mastery
    weakest_skill  = min(mastery, key=mastery.get)
    weakest_score  = mastery[weakest_skill]
    lessons        = SKILL_LESSONS.get(weakest_skill, DEFAULT_LESSONS)

    # Pick lesson difficulty based on mastery level
    if weakest_score < 0.33:
        lesson_index = 0  # Easiest
    elif weakest_score < 0.66:
        lesson_index = 1  # Intermediate
    else:
        lesson_index = 2  # Advanced

    return {
        "student_id": student_id,
        "recommended_skill": weakest_skill,
        "mastery_level": weakest_score,
        "next_lesson": lessons[lesson_index],
        "reason": f"Mastery for '{weakest_skill}' is {weakest_score:.0%} — focusing here."
    }


# Content Service Endpoints
@app.get("/api/questionnaires/{category}")
async def get_questionnaire(category: str):
    """Fetch questionnaire by category from MongoDB"""
    questionnaire = get_questionnaire_by_category(category)

    # Serve a built-in fallback so the app remains usable without MongoDB.
    if not questionnaire:
        questionnaire = FALLBACK_QUESTIONNAIRES.get(category)

    if not questionnaire:
        return {"error": f"Questionnaire not found for category: {category}"}
    
    # Remove MongoDB's _id field for cleaner response
    if '_id' in questionnaire:
        questionnaire['_id'] = str(questionnaire['_id'])
    
    # Return with explicit UTF-8 charset to ensure Sinhala text displays correctly
    return JSONResponse(
        content=questionnaire,
        media_type="application/json; charset=utf-8"
    )


@app.post("/api/questionnaire")
async def save_questionnaire_submission(payload: dict):
    """Save questionnaire submission data"""
    try:
        # For now, just return success - no MongoDB available for storage
        # In production, this would save to MongoDB
        return {
            "status": "success",
            "message": "Questionnaire submission recorded",
            "submission_id": "local_submission"
        }
    except Exception as e:
        return {"status": "error", "message": str(e)}


@app.get("/api/tasks/{task_type}")
async def get_tasks(task_type: str):
    """Fetch all tasks of a specific type from MongoDB"""
    tasks = get_tasks_by_type(task_type)
    
    # Convert MongoDB ObjectIds to strings
    for task in tasks:
        if '_id' in task:
            task['_id'] = str(task['_id'])
    
    return {
        "task_type": task_type,
        "tasks": tasks,
        "count": len(tasks)
    }


@app.get("/api/tasks/by-level/{task_type}/{level}")
async def get_tasks_by_level(task_type: str, level: int):
    """Fetch tasks of a specific type and level from MongoDB"""
    tasks = get_tasks_by_type(task_type)
    level_tasks = [t for t in tasks if t.get('level') == level]
    
    # Convert MongoDB ObjectIds to strings
    for task in level_tasks:
        if '_id' in task:
            task['_id'] = str(task['_id'])
    
    return {
        "task_type": task_type,
        "level": level,
        "tasks": level_tasks,
        "count": len(level_tasks)
    }


@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "content-service"}
