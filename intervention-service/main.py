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
        url = f"http://127.0.0.1:8002/api/v1/mastery/{student_id}"
        response = requests.get(url)
        mastery_tree = response.json().get("mastery_tree", {})
        if not mastery_tree:
            return "unknown"
        weakest_skill = min(mastery_tree, key=mastery_tree.get)
        return weakest_skill
    except Exception as e:
        print(f"Could not reach Content Service: {e}")
        return "unknown"

# Fix 4: Forward intervention decision to Visual Service for Flutter to poll
def forward_to_visual_service(student_id: str, intervention_type: str, ui_action: str):
    try:
        requests.post(
            "http://127.0.0.1:8004/api/v1/intervention/store",
            json={"student_id": student_id, "intervention_type": intervention_type, "ui_action": ui_action},
            timeout=2
        )
    except Exception as e:
        print(f"Could not forward to Visual Service: {e}")

@app.post("/api/v1/intervention/trigger")
async def trigger_intervention(payload: TriggerPayload):
    weakest_skill = get_weakest_skill(payload.student_id)

    intervention_type = "None"
    action = ""

    if payload.cognitive_load_level == 2:
        intervention_type = "Syllable_Splitter"
        action = f"Trigger visual-audio synchronized split for skill: {weakest_skill}. Pause game."
    elif payload.cognitive_load_level == 1:
        intervention_type = "Audio_Hint"
        action = f"Softly highlight correct answer and repeat audio cue for: {weakest_skill}"

    # Fix 4: Push the decision to the Visual Service so Flutter can poll it
    if intervention_type != "None":
        forward_to_visual_service(payload.student_id, intervention_type, action)

    return {
        "student_id": payload.student_id,
        "detected_weak_skill": weakest_skill,
        "recommended_intervention": intervention_type,
        "ui_action": action
    }

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "intervention-service"}
