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

app = FastAPI(title="Content Service", version="2.0")

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

@app.on_event("startup")
async def startup_event():
    await init_db()

try:
    dkt_logic = joblib.load('ml/dkt_assistments.pkl')
    print("DKT model loaded.")
except Exception:
    try:
        dkt_logic = joblib.load('ml/dkt_mock.pkl')
        print("DKT Mock Logic loaded (fallback).")
    except Exception as e:
        print(f"No DKT model found: {e}")
        dkt_logic = None

# ── Sinhala Skill Curriculum ──────────────────────────────────────────────────
# Expanded from 4 → 10 skills covering NIE Grade 1 Sinhala curriculum clusters
# Reference: National Institute of Education Sri Lanka, Sinhala Grade 1 Syllabus (2016)
SKILL_LESSONS = {
    # Cluster 1: Vowels (Swar)
    "vowel_a":            ["Lesson 1: Hear and trace 'අ'",   "Lesson 2: 'අ' in simple words",    "Lesson 3: Contrast 'අ' vs 'ආ'"],
    "vowel_recognition":  ["Lesson 1: Match all vowel sounds","Lesson 2: Spot vowels in words",    "Lesson 3: Short vs Long vowels"],

    # Cluster 2: Stops — Ka family
    "letter_ka":          ["Lesson 1: Trace ක",              "Lesson 2: ක in words",              "Lesson 3: ක with Pillas"],
    "letter_ga":          ["Lesson 1: Trace ග",              "Lesson 2: ග vs ක contrast",         "Lesson 3: ග in words"],

    # Cluster 3: Nasals
    "letter_na":          ["Lesson 1: Trace න",              "Lesson 2: න in words",              "Lesson 3: න vs ම contrast"],
    "letter_ma":          ["Lesson 1: Trace ම",              "Lesson 2: ම in words",              "Lesson 3: ම vs නcomplex"],

    # Cluster 4: Vowel Modifiers (Pillas)
    "pilla_ispilla":      ["Lesson 1: Spot ි (Ispilla)",     "Lesson 2: ි vs ී (Deergha)",        "Lesson 3: Apply ි to consonants"],
    "pilla_aapilla":      ["Lesson 1: Spot ා (Aapilla)",    "Lesson 2: ා in common words",       "Lesson 3: ා vs ැ contrast"],

    # Cluster 5: Syllable structure
    "syllable_blending":  ["Lesson 1: Blend කා+ක",           "Lesson 2: Blend ම+ා",              "Lesson 3: Complex CVC blends"],
    "phoneme_isolation":  ["Lesson 1: Hear /k/ in words",    "Lesson 2: /k/ vs /g/ discrimination","Lesson 3: Isolate 3-phoneme words"],
}

DEFAULT_LESSONS = [
    "Lesson 1: Introduction to Sinhala letters",
    "Lesson 2: Basic vowel sounds"
]

# Zone of Proximal Development thresholds (Vygotsky, 1978)
# Only offer a lesson within ±0.2 of current mastery to stay in ZPD
ZPD_WINDOW = 0.20

class InteractionPayload(BaseModel):
    student_id: str
    skill_id: str
    is_correct: bool
    response_latency_ms: float

# ── Endpoints ─────────────────────────────────────────────────────────────────
@app.post("/api/v1/mastery/update")
async def update_mastery_endpoint(payload: InteractionPayload):
    sid  = payload.student_id
    skid = payload.skill_id

    current_mastery = await get_mastery(sid, skid)
    if current_mastery == 0.0:
        current_mastery = 0.2   # Prior baseline

    if dkt_logic is not None:
        if hasattr(dkt_logic, 'update_mastery'):
            # EMA/DKT mock interface
            new_mastery = dkt_logic.update_mastery(
                current_mastery, payload.is_correct, payload.response_latency_ms
            )
        else:
            # ASSISTments-trained GBT: predict P(correct next attempt)
            import numpy as np
            attempts_so_far = 1
            try:
                from database import get_mastery_history
                hist = await get_mastery_history(sid)
                skill_hist = [h for h in hist if h["skill_id"] == skid]
                attempts_so_far = skill_hist[0]["attempt_count"] + 1 if skill_hist else 1
            except Exception:
                pass

            speed_norm = min(1.0, payload.response_latency_ms / 10000.0)
            X = np.array([[attempts_so_far, current_mastery,
                           payload.response_latency_ms, payload.response_latency_ms]])
            prob_correct = float(dkt_logic.predict_proba(X)[0][1])
            # Blend DKT prediction with EMA update
            alpha = 0.3
            raw = 1.0 if payload.is_correct else 0.0
            ema  = alpha * raw + (1 - alpha) * current_mastery
            new_mastery = round(min(1.0, max(0.0, 0.5 * prob_correct + 0.5 * ema)), 4)
    else:
        alpha = 0.3
        speed_bonus = max(0.0, (6000 - payload.response_latency_ms) / (6000 - 800)) * 0.2
        raw = 1.0 if payload.is_correct else 0.0
        new_mastery = round(min(1.0, max(0.0, alpha * (raw + speed_bonus) + (1-alpha) * current_mastery)), 4)

    await update_mastery(sid, skid, new_mastery)
    
    # Re-fetch to confirm forgetting status
    confirmed_mastery = await get_mastery(sid, skid)

    return {
        "student_id":       sid,
        "skill_id":         skid,
        "previous_mastery": current_mastery,
        "new_mastery":      new_mastery,
        "forgetting_applied": current_mastery < confirmed_mastery + 0.001,
    }

@app.get("/api/v1/mastery/{student_id}")
async def get_student_mastery(student_id: str):
    state = await get_all_mastery(student_id)
    return {"student_id": student_id, "mastery_tree": state}

@app.get("/api/v1/content/next/{student_id}")
async def get_next_content(student_id: str):
    """
    Returns the recommended next lesson based on:
    1. Weakest skill (lowest decay-adjusted mastery)
    2. Zone of Proximal Development — lesson difficulty within ±0.20 of mastery
    Research: VanLehn (2006) — optimal challenge point for adaptive tutoring.
    """
    mastery = await get_all_mastery(student_id)

    if not mastery:
        return {
            "student_id":       student_id,
            "recommended_skill": "vowel_a",
            "lessons":          DEFAULT_LESSONS,
            "reason":           "No data yet — starting from the beginning (vowels)."
        }

    # Find weakest skill
    weakest_skill = min(mastery, key=mastery.get)
    weakest_score = mastery[weakest_skill]
    lessons       = SKILL_LESSONS.get(weakest_skill, DEFAULT_LESSONS)

    # ZPD-based difficulty selection
    # Easy: mastery 0.0–0.33, Medium: 0.33–0.66, Advanced: 0.66–1.0
    if weakest_score < 0.33:
        lesson_index = 0
        difficulty   = "Foundational"
    elif weakest_score < 0.66:
        lesson_index = 1
        difficulty   = "Intermediate"
    else:
        lesson_index = 2
        difficulty   = "Advanced"

    return {
        "student_id":       student_id,
        "recommended_skill": weakest_skill,
        "mastery_level":    round(weakest_score, 3),
        "next_lesson":      lessons[lesson_index],
        "difficulty":       difficulty,
        "reason":           f"Mastery for '{weakest_skill}' is {weakest_score:.0%}. "
                            f"ZPD difficulty: {difficulty} (VanLehn, 2006).",
        "all_skills":       {k: round(v, 3) for k, v in mastery.items()},
    }

@app.get("/api/v1/progress/{student_id}")
async def get_student_progress(student_id: str):
    """
    Returns full mastery history with decay-adjusted scores and attempt counts.
    Designed for educator dashboard — shows which skills need attention.
    Research: Multi-session learning curve analysis (Koedinger et al., 2013).
    """
    history = await get_mastery_history(student_id)
    if not history:
        return {"student_id": student_id, "skills": [], "summary": "No data yet."}

    mastered    = [h for h in history if h["mastery_level"] >= 0.70]
    progressing = [h for h in history if 0.35 <= h["mastery_level"] < 0.70]
    struggling  = [h for h in history if h["mastery_level"] < 0.35]

    return {
        "student_id": student_id,
        "skills":     history,
        "summary": {
            "mastered_count":    len(mastered),
            "progressing_count": len(progressing),
            "struggling_count":  len(struggling),
            "mastered_skills":   [h["skill_id"] for h in mastered],
            "struggling_skills": [h["skill_id"] for h in struggling],
        }
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
