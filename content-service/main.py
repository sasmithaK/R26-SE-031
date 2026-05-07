from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import joblib

from database import init_db, update_mastery, get_mastery, get_all_mastery, get_mastery_history

app = FastAPI(title="Content Service", version="2.0")

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

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "content-service"}
