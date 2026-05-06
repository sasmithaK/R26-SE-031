from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import joblib
import sqlite3
import requests

app = FastAPI(title="Visual Service", version="2.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Database Setup ────────────────────────────────────────────────────────────
DB_PATH = "visual_state.db"

def init_db():
    conn = sqlite3.connect(DB_PATH)
    conn.execute('''
        CREATE TABLE IF NOT EXISTS preferences (
            student_id   TEXT PRIMARY KEY,
            font_size    TEXT DEFAULT "Medium",
            theme        TEXT DEFAULT "Daylight",
            updated_at   DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    conn.execute('''
        CREATE TABLE IF NOT EXISTS pending_interventions (
            student_id        TEXT PRIMARY KEY,
            intervention_type TEXT,
            ui_action         TEXT,
            created_at        DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    conn.commit()
    conn.close()

@app.on_event("startup")
def startup():
    init_db()

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
    action_taken: int
    reward: float

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
    conn = sqlite3.connect(DB_PATH)
    conn.execute('''
        INSERT INTO preferences (student_id, font_size, theme, updated_at)
        VALUES (?, ?, ?, CURRENT_TIMESTAMP)
        ON CONFLICT(student_id) DO UPDATE SET
            font_size  = excluded.font_size,
            theme      = excluded.theme,
            updated_at = CURRENT_TIMESTAMP
    ''', (payload.student_id, payload.preferred_font_size, payload.preferred_theme))
    conn.commit()
    conn.close()
    return {"status": "preferences saved", "student_id": payload.student_id}

@app.get("/api/v1/preferences/{student_id}")
async def get_preferences(student_id: str):
    conn = sqlite3.connect(DB_PATH)
    row = conn.execute(
        'SELECT font_size, theme FROM preferences WHERE student_id = ?', (student_id,)
    ).fetchone()
    conn.close()
    if row:
        return {"student_id": student_id, "font_size": row[0], "theme": row[1]}
    return {"student_id": student_id, "font_size": "Medium", "theme": "Daylight"}

# ── Fix 2: Layout reacts to real monitoring data ──────────────────────────────
@app.post("/api/v1/ui/layout")
async def get_layout(payload: LayoutRequest):
    # Step 1 — Fetch student's saved preferences
    conn = sqlite3.connect(DB_PATH)
    pref_row = conn.execute(
        'SELECT font_size, theme FROM preferences WHERE student_id = ?',
        (payload.student_id,)
    ).fetchone()
    conn.close()
    font_size = pref_row[0] if pref_row else "Medium"
    theme     = pref_row[1] if pref_row else "Daylight"

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
    }

    if cognitive_load == 2:
        # High load → max visual support
        layout_config["character_spacing"] = 1.8
        layout_config["highlight_pilla"]   = True
        layout_config["bionic_reading"]    = True
    elif cognitive_load == 1:
        # Medium load → add spacing
        layout_config["character_spacing"] = 1.4
        layout_config["highlight_pilla"]   = True
    # else: low load → keep defaults / preferences

    return {"student_id": payload.student_id, "recommended_layout": layout_config}

@app.post("/api/v1/ui/reward")
async def provide_reward(payload: RewardPayload):
    if bandit:
        bandit.update_reward(payload.action_taken, payload.reward)
        return {"status": "reward updated", "new_q_values": bandit.q_values}
    return {"status": "bandit not loaded, reward ignored"}

# ── Fix 4 (Visual side): Store incoming interventions for Flutter to poll ─────
@app.post("/api/v1/intervention/store")
async def store_intervention(payload: InterventionStorePayload):
    """Called by Intervention Service to push a decision to this student's queue."""
    conn = sqlite3.connect(DB_PATH)
    conn.execute('''
        INSERT INTO pending_interventions (student_id, intervention_type, ui_action, created_at)
        VALUES (?, ?, ?, CURRENT_TIMESTAMP)
        ON CONFLICT(student_id) DO UPDATE SET
            intervention_type = excluded.intervention_type,
            ui_action         = excluded.ui_action,
            created_at        = CURRENT_TIMESTAMP
    ''', (payload.student_id, payload.intervention_type, payload.ui_action))
    conn.commit()
    conn.close()
    return {"status": "intervention queued"}

@app.get("/api/v1/intervention/status/{student_id}")
async def get_intervention_status(student_id: str):
    """Polled by Flutter every 10 seconds to check if an intervention is waiting."""
    conn = sqlite3.connect(DB_PATH)
    row = conn.execute(
        'SELECT intervention_type, ui_action FROM pending_interventions WHERE student_id = ?',
        (student_id,)
    ).fetchone()
    if row:
        # Clear it so it only fires once
        conn.execute('DELETE FROM pending_interventions WHERE student_id = ?', (student_id,))
        conn.commit()
    conn.close()
    if row:
        return {"pending": True, "intervention_type": row[0], "ui_action": row[1]}
    return {"pending": False}

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "visual-service"}
