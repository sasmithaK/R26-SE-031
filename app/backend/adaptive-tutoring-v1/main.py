from fastapi import FastAPI, HTTPException
from datetime import datetime
from schemas import InteractionRequest, TutoringResponse, NextAction
from database import connect_to_mongo, close_mongo_connection
import database
from services.bkt_engine import bkt_engine
from services.irt_engine import irt_engine
from services.policy_engine import policy_engine
from typing import Dict, Any

def get_adaptive_state(student_doc: dict, activity_id: str) -> dict:
    if not student_doc:
        return _get_default_state(activity_id)
        
    adaptive_states = student_doc.get("adaptive_states", {})
    state = adaptive_states.get(activity_id)
    
    # Safe migration copy from old schema
    if not state and activity_id == "2.2":
        old_state = student_doc.get("s2a2_state")
        if old_state:
            state = dict(old_state) # Copy
            
    return state if state else _get_default_state(activity_id)

def _get_default_state(activity_id: str) -> dict:
    if activity_id == "2.2":
        return {"current_core_round": 1, "next_phase": "CORE", "adaptive_policy_version": "S2A2_CORE_V1"}
    elif activity_id == "2.1":
        return {"current_core_round": 1, "next_phase": "CORE", "adaptive_policy_version": "S2A1_CORE_V1"}
    elif activity_id == "2.3":
        return {"current_core_round": 1, "next_phase": "CORE", "adaptive_policy_version": "S2A3_CORE_V1"}
    elif activity_id == "2.4":
        return {"current_core_round": 1, "next_phase": "CORE", "adaptive_policy_version": "S2A4_CORE_V1"}
    return {}

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
    # Retrieve Learner DB State
    student_doc = await database.knowledge_states_collection.find_one({"student_id": request.student_id})
    db = database.get_db()
    
    from curriculum_mapping import resolve_knowledge_component, resolve_canonical_activity
    from services.item_selector import item_selector
    
    official_kc = resolve_knowledge_component(request.activity_id, request.item_id, request.knowledge_component_id)
    
    canonical_act = resolve_canonical_activity(request.activity_id, request.item_id, getattr(request, 'skill_id', None))
    if not canonical_act:
        canonical_act = request.activity_id
        
    # Map frontend item_id "act_X_roundY" to canonical "SXAXR0Y" if possible
    canonical_item = request.item_id
    if canonical_act == "2.2" and request.item_id.startswith("act_2_round"):
        round_str = request.item_id.replace("act_2_round", "")
        if round_str.isdigit():
            canonical_item = f"S2A2R{int(round_str):02d}"
    elif canonical_act == "2.1" and request.item_id.startswith("act_1_round"):
        round_str = request.item_id.replace("act_1_round", "")
        if round_str.isdigit():
            canonical_item = f"S2A1R{int(round_str):02d}"
    elif canonical_act == "2.3" and request.item_id.startswith("act_3_round"):
        round_str = request.item_id.replace("act_3_round", "")
        if round_str.isdigit():
            canonical_item = f"S2A3R{int(round_str):02d}"
    elif canonical_act == "2.4" and request.item_id.startswith("act_4_round"):
        round_str = request.item_id.replace("act_4_round", "")
        if round_str.isdigit():
            canonical_item = f"S2A4R{int(round_str):02d}"

    if student_doc and "knowledge_state" in student_doc:
        knowledge_state = student_doc["knowledge_state"]
        theta = student_doc.get("theta_estimate", 0.0)
    else:
        knowledge_state = {
            official_kc: bkt_engine.priors.get(official_kc, bkt_engine.priors["default"])[0]
        }
        theta = 0.0
        
    adaptive_state = get_adaptive_state(student_doc, canonical_act)
    current_prob = knowledge_state.get(official_kc, bkt_engine.priors["default"][0])
    mastery_before = current_prob
    
    # ---------------------------------------------------------
    # RESET LOGIC FOR TESTING OR REPLAY
    # ---------------------------------------------------------
    if canonical_item == "RESET" or canonical_item in ["S2A1R01", "S2A2R01", "S2A3R01", "S2A4R01"]:
        # Reset knowledge state and theta
        knowledge_state[official_kc] = bkt_engine.priors.get(official_kc, bkt_engine.priors["default"])[0]
        theta = 0.0
        adaptive_state = _get_default_state(canonical_act)
        if canonical_act == "2.2":
            adaptive_state["core_completed"] = {"1": False, "2": False, "3": False, "4": False, "5": False}

    # Fetch Item parameters from Item Bank
    item_doc = await db.item_bank.find_one({"item_id": canonical_item})
    if item_doc:
        diff_b = item_doc.get("difficulty_b", 0.0)
        disc_a = item_doc.get("discrimination_a", 1.0)
        guess_c = item_doc.get("guessing_c", 0.2)
    else:
        diff_b = 0.0
        disc_a = 1.0
        guess_c = 0.2

    response_quality, struggle_score, struggle_band, latency_ratio = policy_engine.classify_response(
        is_correct=request.is_correct,
        telemetry=request.telemetry,
        activity_id=canonical_act
    )

    if request.phase == "ATTEMPT":
        round_num = item_doc.get("round", 1) if item_doc else 1
        
        # Telemetry may provide precise pool sizes, else fallback
        options_count = getattr(request.telemetry, "original_options_count", None)
        if options_count is None:
            options_count = {1: 2, 2: 2, 3: 3, 4: 4, 5: 5}.get(round_num, 5)
            
        available_incorrect_ids = getattr(request.telemetry, "incorrect_option_ids", [])
        if available_incorrect_ids is None:
            available_incorrect_ids = []
        
        support = policy_engine.get_support_action(
            request.telemetry, 
            options_count, 
            struggle_score, 
            available_incorrect_ids, 
            adaptive_state,
            canonical_act,
            round_num
        )
        
        # Track scaffold usage
        if support.get("scaffold_level", 0) > adaptive_state.get("highest_scaffold_level_used", 0):
            adaptive_state["highest_scaffold_level_used"] = support.get("scaffold_level", 0)
            
        # Next item remains the current item! No state mutation occurs here.
        next_action = NextAction(
            next_activity=canonical_act,
            next_item=canonical_item,
            difficulty=diff_b,
            scaffold_level=support.get("scaffold_level", 0),
            decision=support.get("decision", "RETRY_CURRENT"),
            remove_option_ids=support.get("remove_option_ids", None),
            highlight_correct=support.get("highlight_correct", False),
            next_phase=adaptive_state.get("next_phase", "CORE"),
            progress_core=adaptive_state.get("current_core_round", 1),
            progress_total=7 if canonical_act == "2.1" else 5
        )
        
        # Save adaptive state
        adaptive_states = student_doc.get("adaptive_states", {}) if student_doc else {}
        adaptive_states[canonical_act] = adaptive_state
        
        update_set = {
            "knowledge_state": knowledge_state,
            "theta_estimate": theta,
            "adaptive_states": adaptive_states,
            "last_updated": datetime.utcnow().isoformat()
        }
        # Keep old state for rollback safety
        if student_doc and "s2a2_state" in student_doc:
            update_set["s2a2_state"] = student_doc["s2a2_state"]
            
        await database.knowledge_states_collection.update_one(
            {"student_id": request.student_id},
            {"$set": update_set},
            upsert=True
        )
        
        return TutoringResponse(
            student_id=request.student_id,
            updated_knowledge_state=knowledge_state,
            next_action=next_action
        )

    # COMPLETE Phase: check for duplicate/stale requests
    expected_item = adaptive_state.get("expected_item_id")
    # ---------------------------------------------------------
    # STALE COMPLETION CHECK (ONLY FOR S2A2 PILOT)
    # ---------------------------------------------------------
    if canonical_act == "2.2" and expected_item and expected_item != canonical_item and not expected_item.startswith(canonical_item):
        # Ignore stale completion and return the state as is
        print(f"S2A2_STALE_COMPLETION_IGNORED: Expected {expected_item}, got {canonical_item} (raw: {request.item_id})")
        next_action = NextAction(
            next_activity=canonical_act,
            next_item=expected_item,
            difficulty=diff_b,
            scaffold_level=0,
            decision="RETRY_CURRENT",
            next_phase=adaptive_state.get("next_phase", "CORE"),
            progress_core=adaptive_state.get("current_core_round", 1),
            progress_total=5
        )
        return TutoringResponse(
            student_id=request.student_id,
            updated_knowledge_state=knowledge_state,
            next_action=next_action
        )


    # COMPLETE Phase: update BKT/IRT
    
    # Override response quality if scaffolding was used during this item's attempts
    frontend_scaffold = getattr(request.telemetry, "scaffold_level_used", 0)
    if request.is_correct and (adaptive_state.get("highest_scaffold_level_used", 0) > 0 or frontend_scaffold > 0):
        # We cap response quality to ASSISTED_SUCCESS if any scaffolding was needed
        # (even if they solved it in 1 attempt from the frontend perspective).
        if response_quality in ["MASTERED", "INDEPENDENT_SUCCESS"]:
            response_quality = "ASSISTED_SUCCESS"
            
    print(f"BKT Before: {mastery_before:.3f}, Correct: {request.is_correct}, Quality: {response_quality}")

    new_prob = bkt_engine.update_knowledge_state(
        current_prob=current_prob,
        target_kc=official_kc,
        is_correct=request.is_correct
    )
    knowledge_state[official_kc] = new_prob
    
    theta_new = irt_engine.update_theta(
        theta_old=theta,
        is_correct=request.is_correct,
        b_i=diff_b,
        learning_rate=0.5
    )

    # Generate explicit Next Action using Policy Engine
    policy_output = policy_engine.get_next_action(
        kc_mastery=new_prob,
        theta=theta_new,
        fatigue_score=getattr(request, "fatigue_score", 0),
        current_activity=canonical_act,
        response_quality=response_quality,
        struggle_band=struggle_band,
        current_difficulty_b=diff_b,
        adaptive_state=adaptive_state,
        learner_profile=getattr(request, "learner_profile", {})
    )
    
    # 5. Check Candidate Availability for next_activity
    next_activity = policy_output["next_activity"]
    if next_activity != canonical_act and policy_output["decision"] not in ["TERMINATE", "CURRICULUM_COMPLETE"]:
        candidates_cursor = db.item_bank.find({"activity_id": next_activity})
        candidates = await candidates_cursor.to_list(length=100)
        
        if not candidates:
            # Revert progression
            next_activity = canonical_act
            policy_output["next_activity"] = canonical_act
            policy_output["policy_reason"].append("NEXT_ACTIVITY_UNAVAILABLE")
            candidates = []
    else:
        candidates = []

    if not candidates and policy_output["decision"] not in ["TERMINATE", "CURRICULUM_COMPLETE"]:
        # Query for the canonical/reverted activity
        candidates_cursor = db.item_bank.find({"activity_id": next_activity})
        candidates = await candidates_cursor.to_list(length=100)
    
    # Apply State Machine updates
    adaptive_state = policy_output.get("state_updates", adaptive_state)
    
    # Reset scaffold tracking for the next item
    adaptive_state["highest_scaffold_level_used"] = 0
    if "current_pair_state" in adaptive_state:
        adaptive_state["current_pair_state"] = {
            "pair_id": None,
            "wrong_count": 0,
            "p1_wrong": 0,
            "p2_wrong": 0,
            "p3_wrong": 0,
            "scaffold_step": 0
        }

    # Save final decision
    next_action = NextAction(
        next_activity=policy_output["next_activity"],
        next_item=policy_output["next_item"],
        difficulty=policy_output["difficulty"],
        scaffold_level=policy_output["scaffold_level"],
        decision=policy_output["decision"],
        next_phase=policy_output.get("next_phase", "CORE"),
        progress_core=policy_output.get("progress_core", 1),
        progress_total=policy_output.get("progress_total", 5)
    )
    next_reason = policy_output["policy_reason"]
    decision_doc = {
        "student_id": request.student_id,
        "timestamp": datetime.utcnow().isoformat(),
        "activity_id": canonical_act,
        "item_id": canonical_item,
        "is_correct": request.is_correct,
        "response_quality": response_quality,
        "mastery_before": mastery_before,
        "mastery_after": new_prob,
        "theta_before": theta,
        "theta_after": theta_new,
        "adaptive_state": adaptive_state,
        "next_item": next_action.next_item,
        "policy_reason": next_reason
    }
    await database.adaptive_decisions_collection.insert_one(decision_doc)

    adaptive_states = student_doc.get("adaptive_states", {}) if student_doc else {}
    adaptive_states[canonical_act] = adaptive_state
    
    update_set = {
        "knowledge_state": knowledge_state,
        "theta_estimate": theta_new,
        "adaptive_states": adaptive_states,
        "last_updated": datetime.utcnow().isoformat()
    }
    if student_doc and "s2a2_state" in student_doc:
        update_set["s2a2_state"] = student_doc["s2a2_state"]
        
    await database.knowledge_states_collection.update_one(
        {"student_id": request.student_id},
        {"$set": update_set},
        upsert=True
    )
    
    # BKT Decision Evidence
    evidence = {
        "official_kc": official_kc,
        "mastery_before": mastery_before,
        "mastery_after": new_prob,
        "correctness": request.is_correct
    }
    
    # IRT Decision Evidence
    irt_evidence = {
        "item_id": canonical_item,
        "difficulty_b": diff_b,
        "theta_before": theta,
        "predicted_probability": irt_engine.calculate_probability(theta, diff_b),
        "theta_after": theta_new
    }
    
    # Progression Evidence
    from curriculum_mapping import ACTIVITY_TO_KC
    progression_reasons = ["KC_MASTERY_THRESHOLD_REACHED", "CURRICULUM_COMPLETE", "UNKNOWN_ACTIVITY_PROGRESSION", "NEXT_ACTIVITY_UNAVAILABLE"]
    progression_reason_found = next((r for r in policy_output["policy_reason"] if r in progression_reasons), "NONE")
    
    progression_evidence = {
        "current_activity": canonical_act,
        "current_kc": official_kc,
        "mastery": new_prob,
        "threshold": 0.85,
        "mastery_status": "MASTERED" if new_prob > 0.85 else "IN_PROGRESS",
        "next_activity": next_activity,
        "next_kc": ACTIVITY_TO_KC.get(next_activity, "UNKNOWN_KC"),
        "progression_reason": progression_reason_found,
        "progression_status": "PROGRESSED" if next_activity != canonical_act else "REMAINED"
    }
    
    # 7. Select Next Item
    forced_id = policy_output.get("next_item", "")
    selection_evidence = item_selector.select_next_item(
        current_item_id=canonical_item,
        current_activity=next_activity,
        target_difficulty=policy_output["target_difficulty"],
        candidates=candidates,
        confirmation_required=policy_output.get("confirmation_required", False),
        forced_item_id=forced_id if forced_id else None
    )
    
    # Overwrite the policy's next_item placeholder if we are not terminating
    if policy_output["decision"] not in ["TERMINATE", "CURRICULUM_COMPLETE"]:
        policy_output["next_item"] = selection_evidence["selected_item"]
    
    next_action = NextAction(
        next_activity=next_activity,
        next_item=policy_output.get("next_item", ""),
        difficulty=selection_evidence["selected_difficulty"] if policy_output["decision"] not in ["TERMINATE", "CURRICULUM_COMPLETE"] else 0.0,
        scaffold_level=policy_output.get("scaffold_level", 0),
        decision=policy_output["decision"],
        next_phase=policy_output.get("next_phase", "CORE"),
        progress_core=policy_output.get("progress_core", 0),
        progress_total=policy_output.get("progress_total", 5)
    )
    
    # 8. Adaptive Decision Logging
    adaptive_decision_record = {
        "student_id": request.student_id,
        "session_id": request.session_id,
        "timestamp": datetime.utcnow().isoformat(),
        "activity_id": canonical_act,
        "kc_id": official_kc,
        "current_item": canonical_item,
        "is_correct": request.is_correct,
        "mastery_before": mastery_before,
        "mastery_after": new_prob,
        "theta_before": theta,
        "theta_after": theta_new,
        "fatigue_score": request.fatigue_score,
        "learner_profile": request.learner_profile,
        "struggle_score": struggle_score,
        "struggle_band": struggle_band,
        "response_quality": response_quality,
        "difficulty_direction": policy_output["difficulty_direction"],
        "target_difficulty": policy_output["target_difficulty"],
        "selected_item": policy_output["next_item"],
        "selected_difficulty": next_action.difficulty,
        "scaffold_level": next_action.scaffold_level,
        "decision": next_action.decision,
        "policy_reason": policy_output["policy_reason"],
        "progression_status": "PROGRESSED" if next_activity != canonical_act else "REMAINED",
        "previous_activity": canonical_act,
        "next_activity": next_activity,
        "previous_kc": official_kc,
        "next_kc": progression_evidence["next_kc"],
        "progression_reason": progression_evidence["progression_reason"]
    }
    
    await db.adaptive_decisions.insert_one(adaptive_decision_record)
    
    # Add policy_reason to selection_evidence for API response completeness
    selection_evidence["policy_reason"] = policy_output["policy_reason"]
    
    return TutoringResponse(
        student_id=request.student_id,
        updated_knowledge_state=knowledge_state,
        next_action=next_action,
        response_quality=response_quality,
        bkt_evidence=evidence,
        irt_evidence=irt_evidence,
        selection_evidence=selection_evidence,
        progression_evidence=progression_evidence
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=9017, reload=True)
