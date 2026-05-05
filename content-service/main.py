from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import joblib

from database import init_db, update_mastery, get_mastery, get_all_mastery

app = FastAPI(title="Content Service", version="1.0")

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

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "content-service"}
