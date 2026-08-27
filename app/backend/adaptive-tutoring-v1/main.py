from fastapi import FastAPI, HTTPException
from schemas import InteractionRequest, TutoringResponse, NextAction
from database import connect_to_mongo, close_mongo_connection
import database
from services.bkt_engine import bkt_engine
from services.irt_engine import irt_engine
from services.policy_engine import policy_engine

app = FastAPI(title="Adaptive Tutoring Service", version="1.0")

@app.on_event("startup")
async def startup_db_client():
    await connect_to_mongo()

@app.on_event("shutdown")
async def shutdown_db_client():
    await close_mongo_connection()

@app.get("/health")
def health_check():
    return {"status": "ok", "service": "adaptive-tutoring-v1"}

@app.post("/update_interaction", response_model=TutoringResponse)
async def update_interaction(request: InteractionRequest):
    # Retrieve student's current knowledge state from DB
    student_doc = await database.bkt_states_collection.find_one({"student_id": request.student_id})
    
    if student_doc and "knowledge_state" in student_doc:
        knowledge_state = student_doc["knowledge_state"]
        # Retrieve item history for IRT, defaulting to empty if not present
        item_difficulties = student_doc.get("item_difficulties_history", [])
        theta = student_doc.get("theta_estimate", 0.0) # Assume 0.0 as baseline theta
    else:
        # Initialize default state
        knowledge_state = {
            "KC_mirror_consonants": bkt_engine.priors["KC_mirror_consonants"][0],
            "KC_vowel_diacritics": bkt_engine.priors["KC_vowel_diacritics"][0],
            "KC_conjunct_consonants": bkt_engine.priors["KC_conjunct_consonants"][0]
        }
        item_difficulties = []
        theta = 0.0
        
    current_prob = knowledge_state.get(request.knowledge_component_id, bkt_engine.priors["default"][0])
    
    # 1. Update BKT State
    new_prob = bkt_engine.update_knowledge_state(
        current_prob=current_prob,
        target_kc=request.knowledge_component_id,
        is_correct=request.is_correct
    )
    knowledge_state[request.knowledge_component_id] = new_prob
    
    # Mock item difficulty based on target KC (normally this would be fetched from an item bank)
    mock_item_b = 0.5 if request.knowledge_component_id == "KC_conjunct_consonants" else (0.2 if request.knowledge_component_id == "KC_vowel_diacritics" else 0.0)
    item_difficulties.append(mock_item_b)
    
    # Simple theta update (mock adjustment for demonstration)
    if request.is_correct:
        theta += 0.1
    else:
        theta -= 0.1
    
    # 2. Check Fatigue via IRT SE or Time
    terminate_session = irt_engine.should_terminate_session(theta, item_difficulties) or request.current_session_duration_sec > 900
    
    # 3. Determine ZPD Scaffolding
    scaffold_level = 0
    if new_prob < 0.4:
        scaffold_level = 2
    elif new_prob < 0.8:
        scaffold_level = 1
        
    next_kc_id = "KC_vowel_diacritics" if request.knowledge_component_id == "KC_mirror_consonants" else "KC_mirror_consonants"
    
    # Update DB
    await database.bkt_states_collection.update_one(
        {"student_id": request.student_id},
        {"$set": {
            "knowledge_state": knowledge_state,
            "item_difficulties_history": item_difficulties,
            "theta_estimate": theta
        }},
        upsert=True
    )
    
    next_action = NextAction(
        next_kc_id=next_kc_id,
        scaffold_level=scaffold_level,
        terminate_session=terminate_session
    )
    
    return TutoringResponse(
        student_id=request.student_id,
        updated_knowledge_state=knowledge_state,
        next_action=next_action
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8017, reload=True)
