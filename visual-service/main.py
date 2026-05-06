from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import numpy as np
import joblib
import motor.motor_asyncio
from datetime import datetime
import requests
from pymongo import MongoClient
from pymongo.errors import ServerSelectionTimeoutError

# ── Multi-Armed Bandit Definition ───────────────────────────────────────────
class EGreedyBandit:
    """
    3-armed bandit over Sinhala UI spacing presets.
    Research basis: Zorzi et al. (2012) — Extra-large letter spacing improves 
    reading speed and accuracy in children with dyslexia.
    """
    def __init__(self, n_arms=3, epsilon=0.1):
        self.n_arms   = n_arms
        self.epsilon  = epsilon
        self.q        = [0.0] * n_arms
        self.counts   = [0]   * n_arms
        self.labels   = ["Default-1px", "Medium-4px", "HighSpace-8px"]

    def select(self):
        if np.random.rand() < self.epsilon:
            return np.random.randint(self.n_arms)
        return int(np.argmax(self.q))

    def update(self, arm, reward):
        self.counts[arm] += 1
        self.q[arm] += (reward - self.q[arm]) / self.counts[arm]

app = FastAPI(title="Visual Service", version="2.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# MONGO_URI = "mongodb+srv://kavindugunasena_db_user:2Vp8ipkprifuEH8t@cluster0.ypxuqen.mongodb.net/"
# client = motor.motor_asyncio.AsyncIOMotorClient(MONGO_URI)
# db = client.visual_db

# async def init_db():
#     await db.preferences.create_index("student_id", unique=True)
#     await db.pending_interventions.create_index("student_id", unique=True)
#     await db.last_bandit_arm.create_index("student_id", unique=True)
#     print("Visual Service: MongoDB indexes initialized.")
# ── MongoDB Setup ────────────────────────────────────────────────────────────
MONGODB_URL = "mongodb+srv://dyslexiaAdmin:yourpassword@cluster01.evjs7kv.mongodb.net/?appName=Cluster01"
client = MongoClient(MONGODB_URL)
db = client["visual_service"]
preferences_collection = db["preferences"]
pending_interventions_collection = db["pending_interventions"]
questions_collection = db["questions"]
student_responses_collection = db["student_responses"]
screen_events_collection = db["screen_events"]
touch_events_collection = db["touch_events"]
task_scores_collection = db["task_scores"]

def init_db():
    """Initialize MongoDB collections with indexes"""
    try:
        # Create indexes for better query performance
        preferences_collection.create_index("student_id", unique=True)
        pending_interventions_collection.create_index("student_id", unique=True)
        questions_collection.create_index("question_id", unique=True)
        student_responses_collection.create_index([("student_id", 1), ("question_id", 1)])
        task_scores_collection.create_index([("student_id", 1), ("task_id", 1)])
        task_scores_collection.create_index("created_at")
        # Telemetry indexes
        screen_events_collection.create_index([("student_id", 1), ("screen_name", 1)])
        screen_events_collection.create_index("event_time")
        touch_events_collection.create_index([("student_id", 1), ("screen_name", 1)])
        touch_events_collection.create_index("event_time")
        print("MongoDB collections initialized successfully")
    except ServerSelectionTimeoutError:
        print("WARNING: Could not connect to MongoDB. Check connection string and network.")
    except Exception as e:
        print(f"MongoDB initialization error: {e}")

@app.on_event("startup")
async def startup():
    await init_db()

# ── Load RL Bandit (optional) ─────────────────────────────────────────────────
try:
    bandit = joblib.load('ml/ui_bandit.pkl')
    print("UI Bandit RL model loaded.")
except Exception as e:
    print(f"UI Bandit not loaded: {e}")
    bandit = None

# ── Models ────────────────────────────────────────────────────────────────────
class LayoutRequest(BaseModel):
    student_id: str
    task_type: str

class RewardPayload(BaseModel):
    student_id: str
    error_rate_decreased: bool

class PreferencesPayload(BaseModel):
    student_id: str
    preferred_font_size: str   # "Small" | "Medium" | "Large"
    preferred_theme: str       # "Daylight" | "Calm Blue" | "High Contrast"

class InterventionStorePayload(BaseModel):
    student_id: str
    intervention_type: str
    ui_action: str

class QuestionPayload(BaseModel):
    question_id: str        # Unique identifier for question
    question_alias: str     # Friendly name/alias
    question_text: str      # The actual question
    question_type: str      # e.g., "multiple_choice", "short_answer", "essay"
    options: Optional[list] = None  # For multiple choice questions
    category: Optional[str] = None  # Topic/category of the question

class StudentResponsePayload(BaseModel):
    student_id: str
    question_id: str
    response_text: str      # Student's answer
    selected_option: Optional[str] = None  # For multiple choice
    time_taken: Optional[float] = None  # Time to answer in seconds
    confidence_level: Optional[int] = None  # 1-5 scale
    metadata: Optional[dict] = None  # Any additional data

class TaskScorePayload(BaseModel):
    student_id: str
    task_id: str
    task_name: str
    score: float
    max_score: Optional[float] = None
    duration_seconds: Optional[float] = None
    metadata: Optional[dict] = None


# ── Telemetry Models ───────────────────────────────────────────────────────
class ScreenEventPayload(BaseModel):
    student_id: str
    screen_name: str
    event_type: str  # 'enter' | 'exit' | 'duration'
    event_time: Optional[datetime] = None  # ISO timestamp when the event occurred
    duration: Optional[float] = None  # seconds (if provided by client)
    metadata: Optional[dict] = None

class TouchEventPayload(BaseModel):
    student_id: str
    screen_name: str
    x: float
    y: float
    element: Optional[str] = None  # optional UI element id/name
    event_time: Optional[datetime] = None
    metadata: Optional[dict] = None

# ── Fix 1: Preferences endpoint (was missing) ─────────────────────────────────
@app.post("/api/v1/preferences/update")
async def update_preferences(payload: PreferencesPayload):
    # await db.preferences.update_one(
    #     {"student_id": payload.student_id},
    #     {"$set": {
    #         "font_size": payload.preferred_font_size,
    #         "theme": payload.preferred_theme,
    #         "updated_at": datetime.datetime.now(datetime.UTC)
    #     }},
    preferences_collection.update_one(
        {"student_id": payload.student_id},
        {
            "$set": {
                "student_id": payload.student_id,
                "font_size": payload.preferred_font_size,
                "theme": payload.preferred_theme,
                "updated_at": datetime.utcnow()
            }
        },
        upsert=True
    )
    return {"status": "preferences saved", "student_id": payload.student_id}

@app.get("/api/v1/preferences/{student_id}")
async def get_preferences(student_id: str):
    # doc = await db.preferences.find_one({"student_id": student_id})
    doc = preferences_collection.find_one({"student_id": student_id})
    if doc:
        return {"student_id": student_id, "font_size": doc.get("font_size", "Medium"), "theme": doc.get("theme", "Daylight")}
    return {"student_id": student_id, "font_size": "Medium", "theme": "Daylight"}

# ── Fix 2: Layout reacts to real monitoring data ──────────────────────────────
@app.post("/api/v1/ui/layout")
async def get_layout(payload: LayoutRequest):
    # # Step 1 — Fetch student's saved preferences
    # doc = await db.preferences.find_one({"student_id": payload.student_id})
    # font_size = doc.get("font_size", "Medium") if doc else "Medium"
    # theme     = doc.get("theme", "Daylight") if doc else "Daylight"
    # Step 1 — Fetch student's saved preferences from MongoDB
    pref_doc = preferences_collection.find_one({"student_id": payload.student_id})
    font_size = pref_doc.get("font_size", "Medium") if pref_doc else "Medium"
    theme     = pref_doc.get("theme", "Daylight") if pref_doc else "Daylight"

    # Step 2 — Fetch latest cognitive load from Monitoring Service
    cognitive_load = 0
    try:
        resp = requests.get(
            f"http://127.0.0.1:8001/api/v1/telemetry/latest/{payload.student_id}",
            timeout=1
        )
        if resp.ok:
            cognitive_load = resp.json().get("cognitive_load", 0)
    except Exception:
        pass  # Monitoring service may not be running in test mode

    # Step 3 — Build layout config driven by real data
    layout_config = {
        "font_size": font_size,
        "theme": theme,
        "character_spacing": 1.0,
        "highlight_pilla": False,
        "bionic_reading": False,
        "font_family": "Noto Sans Sinhala" # Recommended for dyslexia
    }

    arm_selected = 0
    if cognitive_load == 2:
        # High load → max visual support
        layout_config["character_spacing"] = 1.8
        layout_config["highlight_pilla"]   = True
        layout_config["bionic_reading"]    = True
        arm_selected = 2
    elif cognitive_load == 1:
        # Medium load → add spacing
        layout_config["character_spacing"] = 1.4
        layout_config["highlight_pilla"]   = True
        arm_selected = 1
    # else: low load → keep defaults / preferences (arm_selected = 0)

    # Note the arm for bandit reward mapping
    await db.last_bandit_arm.update_one(
        {"student_id": payload.student_id},
        {"$set": {"arm": arm_selected}},
        upsert=True
    )

    return {
        "student_id": payload.student_id, 
        "recommended_layout": layout_config,
        "research_notes": "WCAG AAA contrast applied for selected theme. Wilkins (1994) colour tinting principles integrated. Font choice grounded in readability research."
    }

@app.post("/api/v1/ui/reward")
async def provide_reward(payload: RewardPayload):
    if bandit and hasattr(bandit, "update"):
        doc = await db.last_bandit_arm.find_one({"student_id": payload.student_id})
        arm = doc.get("arm", 0) if doc else 0
        reward = 1.0 if payload.error_rate_decreased else 0.0
        bandit.update(arm, reward)
        return {"status": "reward updated", "arm_updated": arm, "reward_given": reward}
    return {"status": "bandit not loaded, reward ignored"}

# ── Fix 4 (Visual side): Store incoming interventions for Flutter to poll ─────
@app.post("/api/v1/intervention/store")
async def store_intervention(payload: InterventionStorePayload):
    """Called by Intervention Service to push a decision to this student's queue."""
    # await db.pending_interventions.update_one(
    #     {"student_id": payload.student_id},
    #     {"$set": {
    #         "intervention_type": payload.intervention_type,
    #         "ui_action": payload.ui_action,
    #         "created_at": datetime.datetime.utcnow()
    #     }},
    pending_interventions_collection.update_one(
        {"student_id": payload.student_id},
        {
            "$set": {
                "student_id": payload.student_id,
                "intervention_type": payload.intervention_type,
                "ui_action": payload.ui_action,
                "created_at": datetime.utcnow()
            }
        },
        upsert=True
    )
    return {"status": "intervention queued"}

@app.get("/api/v1/intervention/status/{student_id}")
async def get_intervention_status(student_id: str):
    """Polled by Flutter every 10 seconds to check if an intervention is waiting."""
    # doc = await db.pending_interventions.find_one_and_delete({"student_id": student_id})
    # if doc:
    #     return {"pending": True, "intervention_type": doc["intervention_type"], "ui_action": doc["ui_action"]}
    doc = pending_interventions_collection.find_one({"student_id": student_id})
    if doc:
        # Clear it so it only fires once
        pending_interventions_collection.delete_one({"student_id": student_id})
        return {"pending": True, "intervention_type": doc.get("intervention_type"), "ui_action": doc.get("ui_action")}
    return {"pending": False}

# ── Questions Management ──────────────────────────────────────────────────────
@app.post("/api/v1/questions/save")
async def save_question(payload: QuestionPayload):
    """Save a question with ID and alias to MongoDB for reuse without manual entry"""
    questions_collection.update_one(
        {"question_id": payload.question_id},
        {
            "$set": {
                "question_id": payload.question_id,
                "question_alias": payload.question_alias,
                "question_text": payload.question_text,
                "question_type": payload.question_type,
                "options": payload.options,
                "category": payload.category,
                "created_at": datetime.utcnow()
            }
        },
        upsert=True
    )
    return {"status": "question saved", "question_id": payload.question_id}

@app.get("/api/v1/questions")
async def get_all_questions():
    """Retrieve all questions from MongoDB"""
    questions = list(questions_collection.find({}, {"_id": 0}))
    return {"total": len(questions), "questions": questions}

@app.get("/api/v1/questions/{question_id}")
async def get_question(question_id: str):
    """Retrieve a specific question by ID"""
    doc = questions_collection.find_one({"question_id": question_id}, {"_id": 0})
    if doc:
        return {"status": "found", "question": doc}
    return {"status": "not found", "question_id": question_id}

# ── Student Responses & Monitoring ────────────────────────────────────────────
@app.post("/api/v1/responses/save")
async def save_student_response(payload: StudentResponsePayload):
    """Save student's filled response to MongoDB for monitoring and analysis"""
    student_responses_collection.insert_one({
        "student_id": payload.student_id,
        "question_id": payload.question_id,
        "response_text": payload.response_text,
        "selected_option": payload.selected_option,
        "time_taken": payload.time_taken,
        "confidence_level": payload.confidence_level,
        "metadata": payload.metadata,
        "submitted_at": datetime.utcnow()
    })
    return {"status": "response saved", "student_id": payload.student_id, "question_id": payload.question_id}

# ── Task Score Tracking ───────────────────────────────────────────────────────
@app.post("/api/v1/scores/save")
async def save_task_score(payload: TaskScorePayload):
    """Save a completed task score for the logged-in student."""
    doc = {
        "student_id": payload.student_id,
        "task_id": payload.task_id,
        "task_name": payload.task_name,
        "score": payload.score,
        "max_score": payload.max_score,
        "duration_seconds": payload.duration_seconds,
        "metadata": payload.metadata,
        "created_at": datetime.utcnow()
    }
    task_scores_collection.insert_one(doc)
    return {"status": "score saved", "student_id": payload.student_id, "task_id": payload.task_id, "score": payload.score}

@app.get("/api/v1/scores/{student_id}")
async def get_student_scores(student_id: str):
    """Return score history for a student, newest first."""
    scores = list(task_scores_collection.find({"student_id": student_id}, {"_id": 0}).sort("created_at", -1))
    total_score = sum(item.get("score", 0) for item in scores)
    total_max_score = sum(item.get("max_score", 0) or 0 for item in scores)
    return {
        "student_id": student_id,
        "total_tasks": len(scores),
        "total_score": total_score,
        "total_max_score": total_max_score,
        "scores": scores
    }

@app.get("/api/v1/responses/{student_id}")
async def get_student_responses(student_id: str):
    """Retrieve all responses from a student for monitoring"""
    responses = list(student_responses_collection.find(
        {"student_id": student_id},
        {"_id": 0}
    ).sort("submitted_at", -1))
    return {"student_id": student_id, "total_responses": len(responses), "responses": responses}

@app.get("/api/v1/responses/{student_id}/{question_id}")
async def get_student_response_for_question(student_id: str, question_id: str):
    """Retrieve a specific student's response for a specific question"""
    doc = student_responses_collection.find_one(
        {"student_id": student_id, "question_id": question_id},
        {"_id": 0}
    )
    if doc:
        return {"status": "found", "response": doc}
    return {"status": "not found", "student_id": student_id, "question_id": question_id}

# ── Telemetry: Screen time & Touch events ───────────────────────────────────
@app.post("/api/v1/telemetry/screen_event")
async def save_screen_event(payload: ScreenEventPayload):
    """Save screen enter/exit or duration events. Prefer client to send duration when available."""
    event_time = payload.event_time or datetime.utcnow()
    doc = {
        "student_id": payload.student_id,
        "screen_name": payload.screen_name,
        "event_type": payload.event_type,
        "event_time": event_time,
        "duration": payload.duration,
        "metadata": payload.metadata,
        "submitted_at": datetime.utcnow()
    }
    screen_events_collection.insert_one(doc)
    return {"status": "screen event saved", "student_id": payload.student_id, "screen_name": payload.screen_name}


@app.post("/api/v1/telemetry/touch")
async def save_touch_event(payload: TouchEventPayload):
    """Save touch/click events with coordinates and optional element info."""
    event_time = payload.event_time or datetime.utcnow()
    doc = {
        "student_id": payload.student_id,
        "screen_name": payload.screen_name,
        "x": payload.x,
        "y": payload.y,
        "element": payload.element,
        "event_time": event_time,
        "metadata": payload.metadata,
        "submitted_at": datetime.utcnow()
    }
    touch_events_collection.insert_one(doc)
    return {"status": "touch event saved", "student_id": payload.student_id, "screen_name": payload.screen_name}


@app.get("/api/v1/telemetry/screen_time/{student_id}")
async def get_screen_time_by_student(student_id: str):
    """Return aggregated total time spent per screen for a student (sums `duration` field)."""
    pipeline = [
        {"$match": {"student_id": student_id, "duration": {"$exists": True, "$ne": None}}},
        {"$group": {"_id": "$screen_name", "total_seconds": {"$sum": "$duration"}, "count": {"$sum": 1}}},
        {"$project": {"screen_name": "$_id", "total_seconds": 1, "count": 1, "_id": 0}}
    ]
    results = list(screen_events_collection.aggregate(pipeline))
    return {"student_id": student_id, "screens": results}


@app.get("/api/v1/telemetry/touches/{student_id}")
async def get_touches_by_student(student_id: str, limit: int = 100):
    """Return recent touch events for a student (most recent first)."""
    docs = list(touch_events_collection.find({"student_id": student_id}, {"_id": 0}).sort("submitted_at", -1).limit(limit))
    return {"student_id": student_id, "total": len(docs), "touches": docs}


@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "visual-service"}
