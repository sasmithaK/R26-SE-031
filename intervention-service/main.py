from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import requests

app = FastAPI(title="Intervention Service", version="1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class TriggerPayload(BaseModel):
    student_id: str
    cognitive_load_level: int # 1 = Medium, 2 = High

def get_weakest_skill(student_id: str):
    try:
        # Ask Content-Service for the mastery tree
        url = f"http://127.0.0.1:8002/api/v1/mastery/{student_id}"
        response = requests.get(url)
        mastery_tree = response.json().get("mastery_tree", {})
        
        if not mastery_tree:
            return "unknown"
            
        # Find the skill with the lowest mastery score
        weakest_skill = min(mastery_tree, key=mastery_tree.get)
        return weakest_skill
    except Exception as e:
        print(f"Could not reach Content Service: {e}")
        return "unknown"

@app.post("/api/v1/intervention/trigger")
async def trigger_intervention(payload: TriggerPayload):
    # 1. Figure out what the student is struggling with
    weakest_skill = get_weakest_skill(payload.student_id)
    
    # 2. Decide the intervention based on load and weak skill
    intervention_type = "None"
    action = ""
    
    if payload.cognitive_load_level == 2:
        intervention_type = "Syllable_Splitter"
        action = f"Trigger visual-audio synchronized split for skill: {weakest_skill}. Pause game."
    elif payload.cognitive_load_level == 1:
        intervention_type = "Audio_Hint"
        action = f"Softly highlight correct answer and repeat audio cue for: {weakest_skill}"
        
    # In a full system, this would push a WebSocket message back to the Flutter UI
    return {
        "student_id": payload.student_id,
        "detected_weak_skill": weakest_skill,
        "recommended_intervention": intervention_type,
        "ui_action": action
    }

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "intervention-service"}
