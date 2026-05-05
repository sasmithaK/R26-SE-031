from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import joblib

app = FastAPI(title="Visual Service", version="1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

try:
    bandit = joblib.load('ml/ui_bandit.pkl')
    print("UI Bandit RL model loaded.")
except Exception as e:
    print(f"Error loading UI Bandit model: {e}")
    bandit = None

class LayoutRequest(BaseModel):
    student_id: str
    task_type: str # e.g., 'WordMatcher'

class RewardPayload(BaseModel):
    student_id: str
    action_taken: int
    reward: float

@app.post("/api/v1/ui/layout")
async def get_layout(payload: LayoutRequest):
    if not bandit:
        action = 0
    else:
        action = bandit.select_layout()
        
    layout_config = {
        "action_id": int(action),
        "character_spacing": 1.0,
        "highlight_pilla": False,
        "bionic_reading": False
    }
    
    # 0 = Default, 1 = Bionic Reading, 2 = High Spacing
    if action == 1:
        layout_config["bionic_reading"] = True
    elif action == 2:
        layout_config["character_spacing"] = 1.5
        layout_config["highlight_pilla"] = True
        
    return {
        "student_id": payload.student_id,
        "recommended_layout": layout_config
    }

@app.post("/api/v1/ui/reward")
async def provide_reward(payload: RewardPayload):
    # This endpoint receives feedback from Flutter if the layout was successful
    if bandit:
        bandit.update_reward(payload.action_taken, payload.reward)
        return {"status": "reward updated", "new_q_values": bandit.q_values}
    return {"error": "model not loaded"}

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "visual-service"}
