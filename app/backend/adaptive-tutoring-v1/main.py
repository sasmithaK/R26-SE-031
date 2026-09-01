from fastapi import FastAPI, HTTPException
from schemas import InteractionRequest, TutoringResponse, NextAction
from database import connect_to_mongo, close_mongo_connection
import database
from services.bkt_engine import bkt_engine
from services.irt_engine import irt_engine
from services.policy_engine import policy_engine

import os
import random
from datetime import datetime

app = FastAPI(
    title="Adaptive Tutoring Service",
    version="1.0",
    root_path=os.getenv("ROOT_PATH", "")
)

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
    # Retrieve Learner DB State
    student_doc = await database.knowledge_states_collection.find_one({"student_id": request.student_id})
    db = database.get_db()
    
    if student_doc and "knowledge_state" in student_doc:
        knowledge_state = student_doc["knowledge_state"]
        theta = student_doc.get("theta_estimate", 0.0)
    else:
        knowledge_state = {
            # Initialise only the requested KC — avoids KeyError on hardcoded KC names
            request.knowledge_component_id: bkt_engine.priors.get(
                request.knowledge_component_id, bkt_engine.priors["default"]
            )[0]
        }
        theta = 0.0
        
    current_prob = knowledge_state.get(request.knowledge_component_id, bkt_engine.priors["default"][0])
    
    # Fetch Item parameters from Item Bank
    item_doc = await db.item_bank.find_one({"item_id": request.item_id})
    item_b = item_doc.get("difficulty_b", request.difficulty_b) if item_doc else request.difficulty_b
    
    previous_knowledge_state = dict(knowledge_state)

    # 1. Update BKT State
    new_prob = bkt_engine.update_knowledge_state(
        current_prob=current_prob,
        target_kc=request.knowledge_component_id,
        is_correct=request.is_correct
    )
    knowledge_state[request.knowledge_component_id] = new_prob
    
    # 2. Update IRT Theta
    theta_new = irt_engine.update_theta(
        theta_old=theta,
        is_correct=request.is_correct,
        b_i=item_b,
        learning_rate=0.5
    )
    
    # 3. Policy Engine Decision
    policy_output = policy_engine.get_next_action(
        kc_mastery=new_prob,
        fatigue_score=request.fatigue_score,
        current_activity=request.activity_id,
        learner_profile=request.learner_profile
    )
    
    # UPSERT the incoming item to the item bank (Option B)
    await db.item_bank.update_one(
        {"item_id": request.item_id},
        {"$set": {
            "knowledge_component_id": request.knowledge_component_id,
            "activity_id": request.activity_id,
            "difficulty_b": request.difficulty_b,
            "is_anchor": request.is_anchor,
            "last_seen_at": datetime.utcnow()
        }},
        upsert=True
    )
    
    # Update DB
    await database.knowledge_states_collection.update_one(
        {"student_id": request.student_id},
        {"$set": {
            "knowledge_state": knowledge_state,
            "theta_estimate": theta_new,
            "updated_at": datetime.utcnow()
        }},
        upsert=True
    )
    
    # 4. Fetch next item from Item Bank
    target_difficulty = policy_output["target_difficulty_b"]
    requires_anchor = random.random() < 0.25 # 25% chance of anchor item
    
    # Build query
    query = {
        "activity_id": policy_output["next_activity"],
        "difficulty_b": target_difficulty
    }
    if requires_anchor:
        query["is_anchor"] = True

    # Try to find a matching item
    next_item_doc = await db.item_bank.find_one(query)
    
    # Fallback if no exact match
    if not next_item_doc:
        query.pop("is_anchor", None)
        next_item_doc = await db.item_bank.find_one(query)
    
    # Ultimate fallback
    next_item_id = next_item_doc["item_id"] if next_item_doc else f"{policy_output['next_activity']}_R01"
    
    next_action = NextAction(
        next_activity=policy_output["next_activity"],
        next_item=next_item_id,
        difficulty=target_difficulty,
        scaffold_level=policy_output["scaffold_level"],
        decision=policy_output["decision"]
    )
    
    # 5. Log Adaptive Decision
    await database.adaptive_decisions_collection.insert_one({
        "student_id": request.student_id,
        "session_id": request.session_id,
        "activity_id": request.activity_id,
        "item_id": request.item_id,
        "knowledge_component_id": request.knowledge_component_id,
        "mastery_before": current_prob,
        "mastery_after": new_prob,
        "theta_before": theta,
        "theta_after": theta_new,
        "previous_difficulty": item_b,
        "selected_difficulty": target_difficulty,
        "next_activity": policy_output["next_activity"],
        "next_item": next_item_id,
        "scaffold_level": policy_output["scaffold_level"],
        "behavioral_fatigue_indicator": request.fatigue_score,
        "decision": policy_output["decision"],
        "decision_reason": f"Mastery {current_prob:.2f}→{new_prob:.2f}; θ {theta:.2f}→{theta_new:.2f}; selected difficulty {target_difficulty}",
        "created_at": datetime.utcnow()
    })

    
    return TutoringResponse(
        student_id=request.student_id,
        updated_knowledge_state=knowledge_state,
        previous_knowledge_state=previous_knowledge_state,
        next_action=next_action
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=9017, reload=False)
