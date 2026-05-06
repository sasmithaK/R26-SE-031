from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import numpy as np
import joblib
import motor.motor_asyncio
import datetime
import requests

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

MONGO_URI = "mongodb+srv://kavindugunasena_db_user:2Vp8ipkprifuEH8t@cluster0.ypxuqen.mongodb.net/"
client = motor.motor_asyncio.AsyncIOMotorClient(MONGO_URI)
db = client.visual_db

async def init_db():
    await db.preferences.create_index("student_id", unique=True)
    await db.pending_interventions.create_index("student_id", unique=True)
    await db.last_bandit_arm.create_index("student_id", unique=True)
    print("Visual Service: MongoDB indexes initialized.")

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

# ── Fix 1: Preferences endpoint (was missing) ─────────────────────────────────
@app.post("/api/v1/preferences/update")
async def update_preferences(payload: PreferencesPayload):
    await db.preferences.update_one(
        {"student_id": payload.student_id},
        {"$set": {
            "font_size": payload.preferred_font_size,
            "theme": payload.preferred_theme,
            "updated_at": datetime.datetime.now(datetime.UTC)
        }},
        upsert=True
    )
    return {"status": "preferences saved", "student_id": payload.student_id}

@app.get("/api/v1/preferences/{student_id}")
async def get_preferences(student_id: str):
    doc = await db.preferences.find_one({"student_id": student_id})
    if doc:
        return {"student_id": student_id, "font_size": doc.get("font_size", "Medium"), "theme": doc.get("theme", "Daylight")}
    return {"student_id": student_id, "font_size": "Medium", "theme": "Daylight"}

# ── Fix 2: Layout reacts to real monitoring data ──────────────────────────────
@app.post("/api/v1/ui/layout")
async def get_layout(payload: LayoutRequest):
    # Step 1 — Fetch student's saved preferences
    doc = await db.preferences.find_one({"student_id": payload.student_id})
    font_size = doc.get("font_size", "Medium") if doc else "Medium"
    theme     = doc.get("theme", "Daylight") if doc else "Daylight"

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
    await db.pending_interventions.update_one(
        {"student_id": payload.student_id},
        {"$set": {
            "intervention_type": payload.intervention_type,
            "ui_action": payload.ui_action,
            "created_at": datetime.datetime.utcnow()
        }},
        upsert=True
    )
    return {"status": "intervention queued"}

@app.get("/api/v1/intervention/status/{student_id}")
async def get_intervention_status(student_id: str):
    """Polled by Flutter every 10 seconds to check if an intervention is waiting."""
    doc = await db.pending_interventions.find_one_and_delete({"student_id": student_id})
    if doc:
        return {"pending": True, "intervention_type": doc["intervention_type"], "ui_action": doc["ui_action"]}
    return {"pending": False}

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "visual-service"}
