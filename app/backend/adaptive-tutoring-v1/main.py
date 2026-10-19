"""Serve the real-time Component 4 adaptive-tutoring workflow.

The main interaction endpoint combines observed telemetry, starter-baseline
context, BKT mastery, Rasch ability, scaffold ranking, and bounded targeted
practice.  Every response also persists an auditable decision trace.
"""

from fastapi import FastAPI
from datetime import datetime, timezone
from schemas import InteractionRequest, TutoringResponse, NextAction
from database import connect_to_mongo, close_mongo_connection
import database
from services.bkt_engine import bkt_engine
from services.irt_engine import irt_engine
from services.policy_engine import policy_engine
from services.action_policy_model import action_policy_model, context_features
from services.dynamic_practice_policy import dynamic_practice_policy
from services.error_profile_service import error_profile_service
from services.practice_selector_model import (
    APPROVED_ACTIVE_STATUSES as PRACTICE_APPROVED_STATUSES,
    practice_selector_model,
)
from typing import Dict, Any, Optional
import copy
import os
import re


def _practice_policy_mode(requested_mode: Optional[str]) -> Dict[str, Any]:
    """Resolve whether the targeted-practice model may control this run."""
    mode = str(requested_mode or os.getenv("C4_POLICY_MODE", "shadow")).lower()
    if mode == "simulation":
        mode = "simulation_model"
    status = str(
        practice_selector_model.artifact.get("validation_status")
        or "model_unavailable"
    )
    activation_allowed = bool(
        practice_selector_model.artifact.get("activation_allowed", False)
    )
    controls = mode == "simulation_model" or (
        mode == "model"
        and status in PRACTICE_APPROVED_STATUSES
        and activation_allowed
    )
    return {
        "mode": mode,
        "controls": controls,
        "model_version": practice_selector_model.artifact.get("model_version"),
        "validation_status": status,
        "activation_allowed": activation_allowed,
    }


def difficulty_unit_interval(difficulty_b: float) -> float:
    """Expose a backwards-compatible 0..1 value while retaining the IRT logit."""
    return round(max(0.0, min(1.0, (float(difficulty_b) + 3.0) / 6.0)), 4)


def mastery_evidence_role(item_role: Optional[str], practice_phase: Optional[str]) -> str:
    """Resolve how this completed item may contribute to latent mastery.

    Remediation is an intervention response, not an independent mastery check.
    A CORE item temporarily reused as a confirmation inherits the active
    confirmation phase so that the fresh independent check remains evidence.
    """
    role = str(item_role or "").upper()
    phase = str(practice_phase or "").upper()
    if role.startswith("REMEDIATION"):
        return "REMEDIATION"
    if role.startswith("CONFIRMATION"):
        return "CONFIRMATION"
    if phase.startswith("REMEDIATION"):
        return "REMEDIATION"
    if phase.startswith("CONFIRMATION"):
        return "CONFIRMATION"
    return "CORE" if role in {"", "CORE"} else "OTHER"


async def _link_proximal_policy_outcome(
    db: Any,
    *,
    student_id: str,
    session_id: str,
    item_id: str,
    response_event_id: Optional[str],
    is_correct: bool,
    phase: str,
    response_quality: Optional[str] = None,
) -> None:
    """Link the latest scaffold to the response immediately following it.

    A child may receive several scaffolds before completing one item. Linking
    only the final scaffold loses the observed failures after earlier actions.
    The proximal fields retain every action -> next response relationship.
    """
    query: Dict[str, Any] = {
        "student_id": student_id,
        "session_id": session_id,
        "item_id": item_id,
        "proximal_outcome_observed": {"$ne": True},
    }
    if response_event_id:
        query["event_id"] = {"$ne": response_event_id}
    latest = await db.policy_decisions.find_one(query, sort=[("_id", -1)])
    if not latest:
        return
    await db.policy_decisions.update_one(
        {"_id": latest["_id"]},
        {"$set": {
            "proximal_outcome_observed": True,
            "proximal_next_response_correct": bool(is_correct),
            "proximal_response_phase": phase,
            "proximal_response_event_id": response_event_id,
            "proximal_response_quality": response_quality,
            "proximal_outcome_recorded_at": datetime.now(timezone.utc).isoformat(),
        }},
    )


async def _link_confirmation_policy_outcomes(
    db: Any,
    *,
    student_id: str,
    session_id: str,
    equivalent_group_id: str,
    confirmation_item_id: str,
    response_event_id: Optional[str],
    first_independent_correct: bool,
    final_correct: bool,
    response_quality: str,
) -> None:
    """Attach the independent equivalent-task result to the whole support chain."""
    now = datetime.now(timezone.utc).isoformat()
    await db.policy_decisions.update_many(
        {
            "student_id": student_id,
            "session_id": session_id,
            "outcome_observed": {"$ne": True},
            "$or": [
                {"equivalent_group_id": equivalent_group_id},
                {"item_id": equivalent_group_id},
            ],
        },
        {"$set": {
            "outcome_observed": True,
            "outcome_definition": "equivalent_confirmation_first_attempt_success",
            "outcome_first_attempt_correct": bool(first_independent_correct),
            "outcome_final_correct": bool(final_correct),
            "outcome_response_quality": response_quality,
            "outcome_item_id": confirmation_item_id,
            "outcome_event_id": response_event_id,
            "outcome_phase": "CONFIRMATION",
            "outcome_recorded_at": now,
        }},
    )

def get_adaptive_state(student_doc: dict, activity_id: str) -> dict:
    """Return the persisted per-activity state, including legacy migration."""
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
    """Create the initial deterministic curriculum state for an activity."""
    if activity_id in {"2.1", "2.2", "2.3", "2.4", "2.5"}:
        activity_number = activity_id.split(".")[1]
        return {
            "current_core_round": 1,
            "next_phase": "CORE",
            "expected_item_id": f"S2A{activity_number}R01",
            "adaptive_policy_version": "C4_EQUIVALENT_TASK_V2",
        }
    return {}

app = FastAPI(
    title="Adaptive Tutoring Service",
    version="1.0",
    root_path=os.getenv("ROOT_PATH", "")
)

@app.on_event("startup")
async def startup_db_client():
    """Connect MongoDB and load approved observed-data BKT parameters."""
    await connect_to_mongo()
    db = database.get_db()
    models = await db.model_registry.find({
        "model_type": "BKT",
        "status": "active",
        "data_origin": "observed",
        "validation_status": {"$in": ["pilot_approved", "validated_observed"]},
    }).to_list(length=100)
    loaded = 0
    for model in models:
        if bkt_engine.apply_calibrated_parameters(
            model.get("knowledge_component_id", ""),
            model.get("parameters", {}),
            model_version=model.get(
                "model_version", "bkt_calibrated_unknown_version"
            ),
            calibrated_at=model.get("calibrated_at"),
        ):
            loaded += 1
    if loaded:
        print(f"Loaded {loaded} calibrated BKT knowledge-component models")

@app.on_event("shutdown")
async def shutdown_db_client():
    """Close the shared MongoDB client during application shutdown."""
    await close_mongo_connection()

@app.get("/health")
def health_check():
    """Report service health, model versions, and activation safeguards."""
    return {
        "status": "ok",
        "service": "adaptive-tutoring-v1",
        "default_policy_mode": os.getenv("C4_POLICY_MODE", "shadow"),
        "action_model_version": action_policy_model.artifact.get("model_version"),
        "action_model_validation_status": action_policy_model.artifact.get(
            "validation_status", "unavailable"
        ),
        "action_model_activation_allowed": bool(
            action_policy_model.artifact.get("activation_allowed", False)
        ),
        "practice_model_version": practice_selector_model.artifact.get(
            "model_version"
        ),
        "practice_model_validation_status": practice_selector_model.artifact.get(
            "validation_status", "unavailable"
        ),
        "practice_model_activation_allowed": bool(
            practice_selector_model.artifact.get("activation_allowed", False)
        ),
        "dynamic_targeted_practice": (
            "active_simulation"
            if _practice_policy_mode(None)["controls"]
            else "shadow_or_baseline"
        ),
        "skill_1_2_practice_flow": "local_exact_target_remediation_confirmation",
        "supported_policy_modes": [
            "baseline", "shadow", "simulation_model",
            "simulation_experiment", "model",
        ],
    }

@app.post("/update_interaction", response_model=TutoringResponse)
async def update_interaction(request: InteractionRequest):
    """Process one learner response through the complete Component 4 loop.

    The endpoint canonicalizes activity/item identifiers, reconstructs learner
    state, updates BKT and IRT evidence, asks the action model for a scaffold,
    applies capability and safety constraints, selects targeted practice when
    needed, persists the decision/outcome evidence, and returns executable
    commands to Flutter.
    """
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
    compact_match = re.match(
        r"^S(\d+)A(\d+)R(\d+)(V\d+)?$",
        canonical_item.replace("_", "").replace("-", ""),
        re.IGNORECASE,
    )
    if compact_match:
        canonical_item = (
            f"S{compact_match.group(1)}A{compact_match.group(2)}"
            f"R{int(compact_match.group(3)):02d}{compact_match.group(4) or ''}"
        ).upper()
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
    elif canonical_act == "2.5" and request.item_id.startswith("act_5_round"):
        round_str = request.item_id.replace("act_5_round", "")
        if round_str.isdigit():
            canonical_item = f"S2A5R{int(round_str):02d}"

    if student_doc and "knowledge_state" in student_doc:
        knowledge_state = student_doc["knowledge_state"]
        theta_by_kc = dict(student_doc.get("theta_by_kc", {}))
        # Existing learners migrate safely from the historical global theta.
        theta = theta_by_kc.get(
            official_kc, student_doc.get("theta_estimate", 0.0)
        )
    else:
        knowledge_state = {
            official_kc: bkt_engine.priors.get(official_kc, bkt_engine.priors["default"])[0]
        }
        theta_by_kc = {}
        theta = 0.0
        
    adaptive_state = get_adaptive_state(student_doc, canonical_act)
    starter_baseline = (
        dict(student_doc.get("starter_baseline") or {}) if student_doc else {}
    )
    personal_latency_factor = float(
        starter_baseline.get("effective_latency_factor", 1.0) or 1.0
    )
    current_prob = knowledge_state.get(official_kc, bkt_engine.priors["default"][0])
    mastery_before = current_prob
    
    # ---------------------------------------------------------
    # RESET LOGIC FOR TESTING OR REPLAY
    # ---------------------------------------------------------
    is_fresh_start = False
    if canonical_item == "RESET":
        is_fresh_start = True
    elif re.fullmatch(r"S\d+A\d+R01", canonical_item):
        # A new level-map run has a new session ID.  A delayed/retried R01
        # completion from the *same* session must never reset a state that has
        # already advanced to R01V1/R01V2; the stale-item guard below will
        # return the currently expected item instead.  This was the source of
        # the Skill 2 first-task remediation loop.
        expected = adaptive_state.get("expected_item_id")
        if canonical_act.startswith("2."):
            active_session_id = adaptive_state.get("active_session_id")
            if (
                expected != canonical_item
                and active_session_id != request.session_id
            ):
                is_fresh_start = True
        elif expected != canonical_item:
            # Preserve the established behavior for already-validated skills.
            is_fresh_start = True

    if is_fresh_start:
        # An explicit RESET remains a true test reset. A normal first round for
        # a learner with a valid Starter Learning Profile preserves the soft
        # cold-start prior (and any later evidence) instead of erasing it back
        # to the global 0.30/0.00 defaults.
        has_starter_profile = starter_baseline.get("profile_status") == "completed"
        if canonical_item == "RESET" or not has_starter_profile:
            knowledge_state[official_kc] = bkt_engine.priors.get(
                official_kc, bkt_engine.priors["default"]
            )[0]
            theta = 0.0
            theta_by_kc[official_kc] = 0.0
        else:
            knowledge_state.setdefault(
                official_kc,
                bkt_engine.priors.get(
                    official_kc, bkt_engine.priors["default"]
                )[0],
            )
            theta = theta_by_kc.get(official_kc, theta)
        adaptive_state = _get_default_state(canonical_act)
        adaptive_state["expected_item_id"] = canonical_item
        if canonical_act == "2.2":
            adaptive_state["core_completed"] = {"1": False, "2": False, "3": False, "4": False, "5": False}
        
        if canonical_item == "RESET":
            # Save and return immediately if this was just a reset ping
            pass

    # Persist session ownership on attempts as well as completions so retries
    # can be distinguished from an intentional new activity/retake session.
    if canonical_act.startswith("2."):
        adaptive_state["active_session_id"] = request.session_id

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

    item_role = (
        item_doc.get("item_role") if item_doc else
        getattr(request.telemetry, "item_role", None)
    ) or "CORE"
    equivalent_group_id = (
        item_doc.get("equivalent_group_id") if item_doc else
        getattr(request.telemetry, "equivalent_group_id", None)
    ) or re.sub(r"V\d+$", "", canonical_item, flags=re.IGNORECASE)

    activity_total = await db.item_bank.count_documents({
        "activity_id": canonical_act,
        "is_core": True,
        "is_active": {"$ne": False},
    })
    if activity_total <= 0:
        activity_total = 7 if canonical_act == "2.1" else 5

    response_quality, struggle_score, struggle_band, latency_ratio = policy_engine.classify_response(
        is_correct=request.is_correct,
        telemetry=request.telemetry,
        activity_id=canonical_act,
        personal_latency_factor=personal_latency_factor,
    )

    if request.phase == "ATTEMPT":
        round_num = item_doc.get("round", 1) if item_doc else 1

        struggled_target_units = [
            str(value)
            for value in (
                getattr(
                    request.telemetry, "struggled_target_units", None
                ) or []
            )
            if str(value).strip()
        ]
        if struggled_target_units:
            # Retain the exact visual/letter/word unit until this item is
            # completed. COMPLETE telemetry describes the whole reviewed task,
            # while this attempt-level evidence identifies what the child
            # actually struggled with. If a multi-object task produces more
            # than one error, retain up to three ranked units. Remediation is
            # later bounded to the strongest two while confirmation checks up
            # to three. Frequency wins first and recency breaks a tie.
            existing_struggle = adaptive_state.get(
                "latest_struggled_target"
            ) or {}
            if str(existing_struggle.get("item_id") or "") != canonical_item:
                existing_struggle = {}
            target_counts = {
                str(key): int(value or 0)
                for key, value in (
                    existing_struggle.get("target_counts") or {}
                ).items()
                if str(key).strip()
            }
            target_order = [
                str(value)
                for value in (existing_struggle.get("observed_units") or [])
                if str(value).strip()
            ]
            first_observed_units = [
                str(value)
                for value in (
                    existing_struggle.get("first_observed_units")
                    or target_order
                )
                if str(value).strip()
            ]
            for unit in struggled_target_units:
                target_counts[unit] = target_counts.get(unit, 0) + 1
                if unit not in first_observed_units:
                    first_observed_units.append(unit)
                if unit in target_order:
                    target_order.remove(unit)
                target_order.append(unit)
            order_index = {
                unit: index for index, unit in enumerate(target_order)
            }
            ranked_units = sorted(
                target_counts,
                key=lambda unit: (
                    -target_counts[unit], -order_index.get(unit, -1)
                ),
            )[:3]
            adaptive_state["latest_struggled_target"] = {
                "item_id": canonical_item,
                "units": ranked_units,
                "observed_units": target_order,
                "first_observed_units": first_observed_units,
                "target_counts": target_counts,
            }
        
        # Telemetry may provide precise pool sizes, else fallback
        options_count = getattr(request.telemetry, "original_options_count", None)
        if options_count is None:
            options_count = {1: 2, 2: 2, 3: 3, 4: 4, 5: 5}.get(round_num, 5)
            
        available_incorrect_ids = getattr(request.telemetry, "incorrect_option_ids", [])
        if available_incorrect_ids is None:
            available_incorrect_ids = []
        
        # The baseline and ML policies must be compared from the same state.
        # Evaluate the baseline on a copy so a simulation-model recommendation
        # does not accidentally retain a distractor removed by the baseline.
        baseline_state = copy.deepcopy(adaptive_state)
        support = policy_engine.get_support_action(
            request.telemetry, 
            options_count, 
            struggle_score, 
            available_incorrect_ids, 
            baseline_state,
            canonical_act,
            round_num
        )
        model_features = context_features(
            telemetry=request.telemetry,
            struggle_score=struggle_score,
            mastery=current_prob,
            difficulty_b=diff_b,
            fatigue=request.fatigue_score,
            behavioral_context=request.behavioral_context,
            learner_profile=request.learner_profile,
            personal_latency_factor=personal_latency_factor,
        )
        model_evidence = action_policy_model.evaluate(
            baseline_action=support.get("decision", "RETRY_CURRENT"),
            telemetry=request.telemetry,
            features=model_features,
            requested_mode=request.policy_mode,
            data_origin=request.data_origin,
            assignment_key=f"{request.student_id}:{request.session_id}",
        )
        applied_action = model_evidence["applied_action"]
        if applied_action == support.get("decision", "RETRY_CURRENT"):
            adaptive_state = baseline_state
        else:
            support = policy_engine.translate_model_support_action(
                action=applied_action,
                telemetry=request.telemetry,
                available_incorrect_ids=available_incorrect_ids,
                adaptive_state=adaptive_state,
            )
            if support.get("decision") != applied_action:
                applied_action = support.get("decision", "RETRY_CURRENT")
                model_evidence["applied_action"] = applied_action
                model_evidence["fallback_reason"] = (
                    "COMMAND_TRANSLATION_SAFETY_FALLBACK"
                )
        support_commands = []
        for command_index, command in enumerate(support.get("commands", [])):
            command_copy = dict(command)
            local_action_id = command_copy.get("action_id", f"command-{command_index}")
            command_copy["action_id"] = f"{canonical_item}-{local_action_id}"
            support_commands.append(command_copy)
        
        # Track scaffold usage
        if support.get("scaffold_level", 0) > adaptive_state.get("highest_scaffold_level_used", 0):
            adaptive_state["highest_scaffold_level_used"] = support.get("scaffold_level", 0)
            
        # Next item remains the current item! No state mutation occurs here.
        next_action = NextAction(
            next_activity=canonical_act,
            next_item=canonical_item,
            difficulty=difficulty_unit_interval(diff_b),
            difficulty_b=diff_b,
            scaffold_level=support.get("scaffold_level", 0),
            decision=applied_action,
            remove_option_ids=support.get("remove_option_ids", None),
            highlight_correct=support.get("highlight_correct", False),
            next_phase=adaptive_state.get("next_phase", "CORE"),
            progress_core=adaptive_state.get("current_core_round", 1),
            progress_total=activity_total,
            action_id=f"{canonical_item}-{support.get('action_id', 'support')}",
            commands=support_commands,
            reason_codes=support.get("reason_codes", []),
            policy_version=support.get("policy_version", "C4_POLICY_V2"),
            policy_mode=model_evidence["policy_mode"],
            model_recommendation=model_evidence["model_recommendation"],
            model_confidence=model_evidence["model_confidence"],
            model_version=model_evidence["model_version"],
            fallback_reason=model_evidence["fallback_reason"],
            applied_action=applied_action,
            controls_live_adaptation=model_evidence["controls_live_adaptation"],
            execution_source=model_evidence["execution_source"],
            experiment_arm=model_evidence["experiment_arm"],
            assignment_mechanism=model_evidence["assignment_mechanism"],
        )
        
        # Save adaptive state
        adaptive_states = student_doc.get("adaptive_states", {}) if student_doc else {}
        adaptive_states[canonical_act] = adaptive_state
        
        update_set = {
            "knowledge_state": knowledge_state,
            "theta_estimate": theta,
            "theta_by_kc": theta_by_kc,
            "adaptive_states": adaptive_states,
            "last_updated": datetime.now(timezone.utc).isoformat()
        }
        # Keep old state for rollback safety
        if student_doc and "s2a2_state" in student_doc:
            update_set["s2a2_state"] = student_doc["s2a2_state"]
            
        await database.knowledge_states_collection.update_one(
            {"student_id": request.student_id},
            {"$set": update_set},
            upsert=True
        )

        existing_policy = None
        if request.event_id:
            existing_policy = await db.policy_decisions.find_one({
                "student_id": request.student_id,
                "event_id": request.event_id,
            })
        if not existing_policy:
            await _link_proximal_policy_outcome(
                db,
                student_id=request.student_id,
                session_id=request.session_id,
                item_id=canonical_item,
                response_event_id=request.event_id,
                is_correct=request.is_correct,
                phase="ATTEMPT",
                response_quality="INCORRECT_ATTEMPT",
            )

        policy_record = {
            "schema_version": "3.0",
            "student_id": request.student_id,
            "session_id": request.session_id,
            "event_id": request.event_id,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "activity_id": canonical_act,
            "item_id": canonical_item,
            "item_role": item_role,
            "equivalent_group_id": adaptive_state.get(
                "practice_origin_group_id", equivalent_group_id
            ),
            "item_equivalent_group_id": equivalent_group_id,
            "practice_phase": adaptive_state.get("next_phase", item_role),
            "phase": "ATTEMPT",
            "knowledge_component_id": official_kc,
            "features": model_features,
            "behavioral_context": request.behavioral_context or {},
            "context_evidence": request.context_evidence or {},
            "starter_baseline_context": {
                "available": starter_baseline.get("profile_status") == "completed",
                "baseline_version": starter_baseline.get("baseline_version"),
                "effective_latency_factor": round(personal_latency_factor, 4),
                "skill_profile": (
                    starter_baseline.get("skill_profiles") or {}
                ).get(f"skill_{str(canonical_act).split('.')[0]}", {}),
            },
            "data_origin": request.data_origin,
            "dataset_id": request.dataset_id,
            "validation_status": request.validation_status,
            "calibration_eligible": False,
            **model_evidence,
        }
        if existing_policy:
            pass
        elif request.event_id:
            await db.policy_decisions.update_one(
                {"student_id": request.student_id, "event_id": request.event_id},
                {"$setOnInsert": policy_record},
                upsert=True,
            )
        else:
            await db.policy_decisions.insert_one(policy_record)
        
        return TutoringResponse(
            student_id=request.student_id,
            updated_knowledge_state=knowledge_state,
            next_action=next_action
        )

    # COMPLETE Phase: check for duplicate/stale requests
    expected_item = adaptive_state.get("expected_item_id")
    # ---------------------------------------------------------
    # STALE COMPLETION CHECK
    # ---------------------------------------------------------
    if expected_item and expected_item != canonical_item:
        # Ignore duplicate/out-of-order completions for every activity. This is
        # essential when a mobile retry arrives after V1/V2 has already begun.
        print(
            "C4_STALE_COMPLETION_IGNORED: "
            f"Expected {expected_item}, got {canonical_item} "
            f"(raw: {request.item_id})"
        )
        is_complete = expected_item == "COMPLETE"
        next_action = NextAction(
            next_activity=canonical_act,
            next_item=expected_item,
            difficulty=difficulty_unit_interval(diff_b),
            difficulty_b=diff_b,
            scaffold_level=0,
            decision="ACTIVITY_COMPLETE" if is_complete else "RETRY_CURRENT",
            next_phase="COMPLETE" if is_complete else adaptive_state.get("next_phase", "CORE"),
            progress_core=adaptive_state.get("current_core_round", 1),
            progress_total=activity_total,
            reason_codes=["STALE_OR_DUPLICATE_COMPLETION_IGNORED"],
            policy_version=adaptive_state.get(
                "adaptive_policy_version", "C4_POLICY_V2"
            ),
        )
        return TutoringResponse(
            student_id=request.student_id,
            updated_knowledge_state=knowledge_state,
            next_action=next_action
        )


    # COMPLETE Phase: update BKT/IRT
    
    # Override response quality if scaffolding was used during this item's attempts
    frontend_scaffold = getattr(request.telemetry, "scaffold_level_used", 0)
    application_levels = [
        int(application.get("scaffold_level", 0) or 0)
        for application in (
            getattr(request.telemetry, "scaffold_applications", None) or []
        )
        if isinstance(application, dict)
    ]
    scaffold_level_used = max(
        int(adaptive_state.get("highest_scaffold_level_used", 0) or 0),
        int(frontend_scaffold or 0),
        *application_levels,
    )
    if request.is_correct and scaffold_level_used > 0:
        # We cap response quality to ASSISTED_SUCCESS if any scaffolding was needed
        # (even if they solved it in 1 attempt from the frontend perspective).
        if response_quality in ["MASTERED", "INDEPENDENT_SUCCESS", "CLEAN_SUCCESS"]:
            response_quality = "ASSISTED_SUCCESS"
            
    # Mastery/ability must be updated from the first independent response,
    # never from an answer obtained after a scaffold. This prevents assisted
    # success from being misrepresented as independent mastery.
    first_attempt_correct = getattr(request.telemetry, "first_attempt_correct", None)
    if first_attempt_correct is None:
        scaffold_was_used = scaffold_level_used > 0
        learning_observation_correct = bool(request.is_correct and not scaffold_was_used)
    else:
        learning_observation_correct = bool(first_attempt_correct)

    error_profile = error_profile_service.build(
        item=item_doc or {
            "item_id": canonical_item,
            "knowledge_component_id": official_kc,
            "template_type": "unknown",
            "content": {},
        },
        telemetry=request.telemetry,
        response_quality=response_quality,
        learning_observation_correct=learning_observation_correct,
        knowledge_component_id=official_kc,
        adaptive_state=adaptive_state,
    )
    adaptive_state.pop("latest_struggled_target", None)
    error_profile["equivalent_group_id"] = equivalent_group_id
    practice_origin_group_before = adaptive_state.get(
        "practice_origin_group_id", equivalent_group_id
    )
    practice_origin_item_before = adaptive_state.get(
        "practice_origin_item_id", canonical_item
    )
    practice_phase_before = str(
        adaptive_state.get("next_phase") or item_role or "CORE"
    ).upper()
    evidence_role = mastery_evidence_role(item_role, practice_phase_before)
    mastery_update_applied = evidence_role in {"CORE", "CONFIRMATION"}
    mastery_update_reason = (
        "INDEPENDENT_CORE_RESPONSE"
        if evidence_role == "CORE"
        else "FRESH_CONFIRMATION_RESPONSE"
        if evidence_role == "CONFIRMATION"
        else "REMEDIATION_RECORDED_AS_INTERVENTION_RESPONSE"
    )

    print(
        f"BKT Before: {mastery_before:.3f}, "
        f"First Independent Correct: {learning_observation_correct}, "
        f"Final Correct: {request.is_correct}, Quality: {response_quality}, "
        f"Evidence Role: {evidence_role}, "
        f"Mastery Update: {mastery_update_applied}"
    )

    new_prob = (
        bkt_engine.update_knowledge_state(
            current_prob=current_prob,
            target_kc=official_kc,
            is_correct=learning_observation_correct,
        )
        if mastery_update_applied
        else float(current_prob)
    )
    knowledge_state[official_kc] = new_prob

    theta_new = (
        irt_engine.update_theta(
            theta_old=theta,
            is_correct=learning_observation_correct,
            b_i=diff_b,
            learning_rate=0.5,
        )
        if mastery_update_applied
        else float(theta)
    )
    theta_by_kc[official_kc] = theta_new

    # Generate the next instructional phase. Synthetic-trained targeted
    # selection controls only an explicitly labelled simulation run. Shadow,
    # baseline, and unapproved observed-child modes retain the validated fixed
    # V1/V2 policy while still collecting the metadata needed for comparison.
    practice_mode = _practice_policy_mode(request.policy_mode)
    practice_controls = bool(practice_mode["controls"])
    if practice_controls:
        policy_output = dynamic_practice_policy.get_next_action(
            activity_id=canonical_act,
            current_item_id=canonical_item,
            item_role=item_role,
            response_quality=response_quality,
            current_b=diff_b,
            state=adaptive_state,
            error_profile=error_profile,
            policy_reason=[f"RESPONSE_QUALITY: {response_quality}"],
            has_reduced_remediation=bool(
                item_doc.get("has_reduced_remediation", False)
                if item_doc else False
            ),
            has_floor_remediation=bool(
                item_doc.get("has_floor_remediation", False)
                if item_doc else False
            ),
        )
        policy_output["policy_reason"].append(
            "DYNAMIC_TARGETED_PRACTICE_ACTIVE"
        )
    else:
        policy_output = policy_engine.get_next_action(
            kc_mastery=new_prob,
            theta=theta_new,
            fatigue_score=getattr(request, "fatigue_score", 0),
            current_activity=canonical_act,
            response_quality=response_quality,
            struggle_band=struggle_band,
            current_difficulty_b=diff_b,
            adaptive_state=adaptive_state,
            learner_profile=getattr(request, "learner_profile", {}),
            current_item_id=canonical_item,
            has_reduced_remediation=bool(
                item_doc.get("has_reduced_remediation", False)
                if item_doc else False
            ),
            has_floor_remediation=bool(
                item_doc.get("has_floor_remediation", False)
                if item_doc else False
            ),
        )
        policy_output["policy_reason"].append(
            "DYNAMIC_TARGETED_PRACTICE_SHADOW_ONLY"
        )

    # Keep the original Component 2/3 evidence signals in the unified C4
    # decision record. Learner profile may increase support intensity, but it
    # never changes the IRT difficulty target.
    if mastery_before < 0.40:
        mastery_reason = "MASTERY_LOW"
    elif mastery_before < 0.70:
        mastery_reason = "MASTERY_MODERATE"
    elif mastery_before < 0.85:
        mastery_reason = "MASTERY_HIGH"
    else:
        mastery_reason = "MASTERY_MASTERED"
    policy_output["policy_reason"].append(mastery_reason)

    learner_profile = getattr(request, "learner_profile", None)
    if not learner_profile:
        policy_output["policy_reason"].append("NO_LEARNER_PROFILE_AVAILABLE")
    else:
        visual_support = float(
            learner_profile.get("Visual-Orthographic Learning Pattern", 0.0)
        )
        if visual_support >= 0.70:
            policy_output["policy_reason"].append("VISUAL_ORTHOGRAPHIC_SUPPORT")
            policy_output["scaffold_level"] = max(
                1, int(policy_output.get("scaffold_level", 0))
            )
    
    # Apply State Machine updates
    adaptive_state = policy_output.get("state_updates", adaptive_state)

    administered_item_ids = list(adaptive_state.get("administered_item_ids", []))
    administered_difficulties = dict(
        adaptive_state.get("administered_item_difficulties", {})
    )
    difficulty_history_before = list(administered_difficulties.values())
    if canonical_item not in administered_item_ids:
        administered_item_ids.append(canonical_item)
    if mastery_update_applied and canonical_item not in administered_difficulties:
        administered_difficulties[canonical_item] = float(diff_b)
    adaptive_state["administered_item_ids"] = administered_item_ids[-100:]
    adaptive_state["administered_item_difficulties"] = {
        item_id: administered_difficulties[item_id]
        for item_id in adaptive_state["administered_item_ids"]
        if item_id in administered_difficulties
    }
    difficulty_history_after = list(
        adaptive_state["administered_item_difficulties"].values()
    )
    standard_error_before = (
        irt_engine.calculate_standard_error(theta, difficulty_history_before)
        if difficulty_history_before else None
    )
    standard_error_after = irt_engine.calculate_standard_error(
        theta_new, difficulty_history_after
    )
    adaptive_state["measurement_standard_error"] = round(
        standard_error_after, 6
    )
    adaptive_state["measurement_observation_count"] = len(
        difficulty_history_after
    )

    # A high BKT score may change the difficulty/order of the next task, but it
    # must not skip curriculum evidence. Keep selection inside the current
    # activity until every active core item has been administered at least once.
    candidate_query: Dict[str, Any] = {
        "activity_id": canonical_act,
        "is_active": {"$ne": False},
    }
    candidates_cursor = db.item_bank.find(candidate_query)
    candidates = await candidates_cursor.to_list(length=100)
    core_candidate_ids = {
        item.get("item_id") for item in candidates if item.get("is_core", True)
    }
    unseen_core_ids = core_candidate_ids.difference(administered_item_ids)
    completed_core_count = len(
        core_candidate_ids.intersection(administered_item_ids)
    )

    next_activity = canonical_act
    policy_output["next_activity"] = canonical_act

    # Validate an explicit state-machine item before it is allowed to bypass
    # normal IRT selection. Missing historical variants fall back to their core
    # item for one unassisted confirmation.
    forced_id = policy_output.get("next_item", "")

    if forced_id and forced_id != "COMPLETE":
        forced_document = await db.item_bank.find_one({
            "item_id": forced_id,
            "activity_id": canonical_act,
            "is_active": {"$ne": False},
        })
        if forced_document is None:
            policy_output["policy_reason"].append(
                "FORCED_VARIANT_INACTIVE_OR_MISSING"
            )
            core_fallback_id = re.sub(r"V\d+$", "", forced_id)
            core_fallback = await db.item_bank.find_one({
                "item_id": core_fallback_id,
                "activity_id": canonical_act,
                "is_core": True,
                "is_active": {"$ne": False},
            })
            if core_fallback is not None and core_fallback_id != forced_id:
                forced_id = core_fallback_id
                adaptive_state["next_phase"] = "CONFIRMATION"
                policy_output["next_phase"] = "CONFIRMATION"
                policy_output["decision"] = "CONFIRMATION_FALLBACK"
                policy_output["policy_reason"].append(
                    "ACTIVE_CORE_USED_FOR_UNASSISTED_CONFIRMATION"
                )
            else:
                forced_id = ""
        else:
            # Forced V1/V2 selection must report its authored difficulty, not
            # the difficulty of the item that was just completed.
            forced_b = float(forced_document.get("difficulty_b", 0.0))
            policy_output["difficulty"] = forced_b
            policy_output["target_difficulty"] = forced_b

    if policy_output["decision"] != "TERMINATE":
        if unseen_core_ids:
            if policy_output["decision"] in {
                "CURRICULUM_COMPLETE", "ACTIVITY_COMPLETE"
            }:
                policy_output["decision"] = "CONTINUE"
                if forced_id == "COMPLETE":
                    forced_id = ""
            policy_output["policy_reason"].append(
                "CORE_ITEM_COVERAGE_REQUIRED"
            )
        elif not forced_id and not policy_output.get("selection_intent"):
            policy_output["decision"] = "ACTIVITY_COMPLETE"
            policy_output["next_item"] = "COMPLETE"
            policy_output["next_phase"] = "COMPLETE"
            policy_output["policy_reason"].append(
                "ALL_CORE_ITEMS_ADMINISTERED"
            )
    
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
    adaptive_state.pop("generic_scaffold_state", None)

    # BKT Decision Evidence
    evidence = {
        "official_kc": official_kc,
        "mastery_before": mastery_before,
        "mastery_after": new_prob,
        "evidence_role": evidence_role,
        "mastery_update_applied": mastery_update_applied,
        "mastery_update_reason": mastery_update_reason,
        "correctness": learning_observation_correct,
        "first_attempt_correct": first_attempt_correct,
        "final_correct": request.is_correct,
    }
    
    # IRT Decision Evidence
    irt_evidence = {
        "item_id": canonical_item,
        "difficulty_b": diff_b,
        "theta_before": theta,
        "predicted_probability": irt_engine.calculate_probability(theta, diff_b),
        "theta_after": theta_new,
        "observation_correct": learning_observation_correct,
        "evidence_role": evidence_role,
        "ability_update_applied": mastery_update_applied,
        "ability_update_reason": mastery_update_reason,
        "standard_error_before": (
            round(standard_error_before, 6)
            if standard_error_before is not None else None
        ),
        "standard_error_after": round(standard_error_after, 6),
        "test_information_after": round(
            1.0 / (standard_error_after ** 2), 6
        ),
        "observation_count": len(difficulty_history_after),
        "ability_scope": official_kc,
    }
    bkt_model_evidence = bkt_engine.get_model_evidence(official_kc)
    
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
    
    # 7. Select Next Item. Dynamic practice ranks only reviewed, unseen
    # alternatives. Ordinary core progression and non-simulation modes retain
    # the established constrained IRT/fixed-equivalent selector.
    selection_intent = policy_output.get("selection_intent")
    exposure_counts = {
        item_id: 1
        for item_id in adaptive_state.get("administered_item_ids", [])
    }
    if practice_controls and selection_intent:
        selection_evidence = item_selector.select_targeted_practice_item(
            current_item_id=canonical_item,
            current_activity=next_activity,
            knowledge_component_id=official_kc,
            target_difficulty=policy_output["target_difficulty"],
            candidates=candidates,
            selection_intent=selection_intent,
            excluded_item_ids=adaptive_state.get("administered_item_ids", []),
            exposure_counts=exposure_counts,
            micro_skill_evidence=adaptive_state.get("micro_skill_evidence", {}),
            fatigue=request.fatigue_score,
            requested_mode=request.policy_mode,
            data_origin=request.data_origin,
        )
        if not selection_evidence.get("selected_item"):
            # Preserve availability even after a small candidate pool is
            # exhausted. First try the reviewed authored equivalent for the
            # original core; if it was already seen, leave the bounded cycle
            # and continue to an unseen core item without trapping the child.
            origin_id = str(selection_intent.get("origin_item_id") or "")
            suffix = "V1" if selection_intent.get("role") == "REMEDIATION" else "V2"
            fallback_id = f"{origin_id}{suffix}" if origin_id else ""
            fallback = next(
                (
                    candidate for candidate in candidates
                    if candidate.get("item_id") == fallback_id
                    and candidate.get("is_active", True) is not False
                    and fallback_id not in set(adaptive_state.get("administered_item_ids", []))
                ),
                None,
            )
            if fallback:
                selection_evidence = item_selector.select_next_item(
                    current_item_id=canonical_item,
                    current_activity=next_activity,
                    target_difficulty=policy_output["target_difficulty"],
                    candidates=candidates,
                    forced_item_id=fallback_id,
                    excluded_item_ids=adaptive_state.get("administered_item_ids", []),
                    knowledge_component_id=official_kc,
                    equivalent_group_id=equivalent_group_id,
                    exposure_counts=exposure_counts,
                )
                selection_evidence["selection_reason"] = (
                    "DYNAMIC_POOL_EXHAUSTED_AUTHORED_FALLBACK"
                )
                selection_evidence["selection_intent"] = selection_intent
                policy_output["policy_reason"].append(
                    "DYNAMIC_POOL_EXHAUSTED_AUTHORED_FALLBACK"
                )
            else:
                adaptive_state["teacher_review_required"] = True
                adaptive_state["teacher_review_item_id"] = origin_id or canonical_item
                policy_output["policy_reason"].append(
                    "DYNAMIC_POOL_EXHAUSTED_BOUNDED_EXIT"
                )
                policy_output["decision"] = "CONTINUE"
                policy_output["next_phase"] = "CORE"
                policy_output["selection_intent"] = None
                adaptive_state["next_phase"] = "CORE"
                selection_evidence = item_selector.select_next_item(
                    current_item_id=canonical_item,
                    current_activity=next_activity,
                    target_difficulty=policy_output["target_difficulty"],
                    candidates=candidates,
                    excluded_item_ids=adaptive_state.get("administered_item_ids", []),
                    knowledge_component_id=official_kc,
                    equivalent_group_id=equivalent_group_id,
                    exposure_counts=exposure_counts,
                )
    else:
        selection_evidence = item_selector.select_next_item(
            current_item_id=canonical_item,
            current_activity=next_activity,
            target_difficulty=policy_output["target_difficulty"],
            candidates=candidates,
            confirmation_required=policy_output.get("confirmation_required", False),
            forced_item_id=forced_id if forced_id else None,
            excluded_item_ids=adaptive_state.get("administered_item_ids", []),
            knowledge_component_id=official_kc,
            equivalent_group_id=equivalent_group_id,
            exposure_counts=exposure_counts,
        )

    terminal_decisions = {"TERMINATE", "CURRICULUM_COMPLETE", "ACTIVITY_COMPLETE"}
    if (
        selection_evidence.get("selection_reason") == "ALL_ACTIVE_ITEMS_ADMINISTERED"
        and policy_output["decision"] not in terminal_decisions
    ):
        policy_output["decision"] = "ACTIVITY_COMPLETE"
        policy_output["next_item"] = "COMPLETE"
        policy_output["policy_reason"].append("ALL_ACTIVE_ITEMS_ADMINISTERED")
    
    # Overwrite the policy's next_item placeholder if we are not terminating
    if policy_output["decision"] not in terminal_decisions:
        policy_output["next_item"] = selection_evidence["selected_item"]

    if selection_intent:
        print(
            "C4_TARGETED_PRACTICE: "
            f"origin={selection_intent.get('origin_item_id')} "
            f"target={selection_intent.get('target_units', [])} "
            f"phase={selection_intent.get('role')} "
            f"selected={policy_output.get('next_item')} "
            f"scope={selection_evidence.get('candidate_scope')}"
        )

    selected_practice_item = policy_output.get("next_item", "")
    if (
        selection_intent
        and selected_practice_item
        and selected_practice_item != "COMPLETE"
    ):
        route = list(adaptive_state.get("practice_route", []))
        route.append({
            "phase": policy_output.get("next_phase"),
            "item_id": selected_practice_item,
            "selection_reason": selection_evidence.get("selection_reason"),
            "target_difficulty": policy_output.get("target_difficulty"),
            "selected_difficulty": selection_evidence.get(
                "selected_difficulty"
            ),
            "model_version": selection_evidence.get("model_version"),
        })
        adaptive_state["practice_route"] = route[-8:]
        adaptive_state["active_practice_selection"] = route[-1]
    elif policy_output.get("next_phase") == "CORE":
        adaptive_state.pop("active_practice_selection", None)

    # Keep every activity's replay/confirmation state explicit. This lets an
    # intentional repeat proceed while a new R01 after completion resets the
    # activity cleanly, including activities outside the original Skill 2 pilot.
    adaptive_state["expected_item_id"] = policy_output.get("next_item", "")
    adaptive_state["next_phase"] = policy_output.get("next_phase", "CORE")

    if policy_output["decision"] == "TERMINATE":
        stop_reason = "SAFETY_FATIGUE_STOP"
    elif policy_output["decision"] in {"ACTIVITY_COMPLETE", "CURRICULUM_COMPLETE"}:
        stop_reason = "CORE_COVERAGE_AND_EQUIVALENT_FLOW_COMPLETE"
    else:
        stop_reason = "CONTINUE_COLLECTING_EVIDENCE"
    adaptive_state["measurement_stop_reason"] = stop_reason
    irt_evidence["stop_reason"] = stop_reason
    
    next_action = NextAction(
        next_activity=next_activity,
        next_item=policy_output.get("next_item", ""),
        difficulty=difficulty_unit_interval(selection_evidence["selected_difficulty"])
        if policy_output["decision"] not in terminal_decisions
        else 0.0,
        difficulty_b=selection_evidence["selected_difficulty"]
        if policy_output["decision"] not in terminal_decisions
        else 0.0,
        scaffold_level=policy_output.get("scaffold_level", 0),
        decision=policy_output["decision"],
        next_phase=policy_output.get("next_phase", "CORE"),
        progress_core=completed_core_count,
        progress_total=activity_total,
        reason_codes=policy_output.get("policy_reason", []),
        policy_version=adaptive_state.get("adaptive_policy_version", "C4_POLICY_V2"),
    )
    
    # 8. Adaptive Decision Logging
    adaptive_decision_record = {
        "schema_version": "2.0",
        "research_eligible": item_doc is not None,
        "data_origin": request.data_origin,
        "dataset_id": request.dataset_id,
        "validation_status": request.validation_status,
        "calibration_eligible": bool(request.calibration_eligible),
        "behavioral_context": request.behavioral_context or {},
        "context_evidence": request.context_evidence or {},
        "starter_baseline_context": {
            "available": starter_baseline.get("profile_status") == "completed",
            "baseline_version": starter_baseline.get("baseline_version"),
            "effective_latency_factor": round(personal_latency_factor, 4),
            "skill_profile": (starter_baseline.get("skill_profiles") or {}).get(
                f"skill_{str(canonical_act).split('.')[0]}", {}
            ),
        },
        "research_validation_errors": (
            [] if item_doc is not None else ["ITEM_NOT_FOUND_IN_CANONICAL_BANK"]
        ),
        "student_id": request.student_id,
        "session_id": request.session_id,
        "event_id": request.event_id,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "activity_id": canonical_act,
        "kc_id": official_kc,
        "current_item": canonical_item,
        "item_role": item_role,
        "equivalent_group_id": equivalent_group_id,
        "response_load_relation": (
            item_doc.get("response_load_relation") if item_doc else
            getattr(request.telemetry, "response_load_relation", None)
        ),
        "item_version": item_doc.get("item_version", 1) if item_doc else 1,
        "difficulty_label": (
            item_doc.get("difficulty_label", "medium") if item_doc else "medium"
        ),
        "difficulty_b": diff_b,
        "difficulty_source": (
            item_doc.get("difficulty_source", "authored")
            if item_doc else "fallback"
        ),
        "calibration_status": (
            item_doc.get("calibration_status", "uncalibrated")
            if item_doc else "item_not_found"
        ),
        "is_anchor": item_doc.get("is_anchor", False) if item_doc else False,
        "submitted_kc_id": request.knowledge_component_id,
        "target_ids": getattr(request.telemetry, "target_ids", None) or [],
        "struggled_target_units": getattr(
            request.telemetry, "struggled_target_units", None
        ) or [],
        "selected_answers": (
            getattr(request.telemetry, "selected_answers", None) or []
        ),
        "attempt_history": (
            getattr(request.telemetry, "attempt_history", None) or []
        ),
        "attempt_count": int(
            getattr(request.telemetry, "attempt_count", 0) or 0
        ),
        "incorrect_attempt_count": int(
            getattr(request.telemetry, "incorrect_attempt_count", 0) or 0
        ),
        "correction_count": int(
            getattr(request.telemetry, "correction_count", 0) or 0
        ),
        "hint_count": int(getattr(request.telemetry, "hint_count", 0) or 0),
        "first_touch_latency_ms": int(
            getattr(request.telemetry, "first_touch_latency_ms", 0) or 0
        ),
        "total_round_latency_ms": int(
            getattr(request.telemetry, "total_round_latency_ms", 0) or 0
        ),
        "error_profile": error_profile,
        "micro_skill_evidence": adaptive_state.get(
            "micro_skill_evidence", {}
        ),
        "practice_origin_item_id": practice_origin_item_before,
        "practice_origin_equivalent_group_id": practice_origin_group_before,
        "scaffold_applications": (
            getattr(request.telemetry, "scaffold_applications", None) or []
        ),
        "is_correct": request.is_correct,
        "first_attempt_correct": first_attempt_correct,
        "learning_observation_correct": learning_observation_correct,
        "mastery_evidence_role": evidence_role,
        "mastery_update_applied": mastery_update_applied,
        "mastery_update_reason": mastery_update_reason,
        "mastery_before": mastery_before,
        "mastery_after": new_prob,
        "bkt_model_version": bkt_model_evidence["model_version"],
        "bkt_calibration_status": bkt_model_evidence["calibration_status"],
        "bkt_calibrated_at": bkt_model_evidence["calibrated_at"],
        "bkt_parameters": bkt_model_evidence["parameters"],
        "theta_before": theta,
        "theta_after": theta_new,
        "ability_update_applied": mastery_update_applied,
        "theta_scope": official_kc,
        "predicted_probability": irt_evidence["predicted_probability"],
        "measurement_standard_error": standard_error_after,
        "test_information_after": irt_evidence["test_information_after"],
        "measurement_observation_count": len(difficulty_history_after),
        "measurement_stop_reason": stop_reason,
        "fatigue_score": request.fatigue_score,
        "learner_profile": request.learner_profile,
        "struggle_score": struggle_score,
        "struggle_band": struggle_band,
        "response_quality": response_quality,
        "difficulty_direction": policy_output["difficulty_direction"],
        "target_difficulty": policy_output["target_difficulty"],
        "selected_item": policy_output["next_item"],
        "selected_difficulty": next_action.difficulty_b,
        "practice_selection_strategy": selection_evidence.get(
            "selection_strategy"
        ),
        "practice_selection_reason": selection_evidence.get(
            "selection_reason"
        ),
        "practice_candidate_scope": selection_evidence.get(
            "candidate_scope"
        ),
        "practice_selection_intent": selection_evidence.get(
            "selection_intent"
        ),
        "practice_model_version": selection_evidence.get(
            "model_version", practice_mode.get("model_version")
        ),
        "practice_model_validation_status": selection_evidence.get(
            "model_validation_status", practice_mode.get("validation_status")
        ),
        "practice_model_controls_live_adaptation": bool(
            selection_evidence.get("controls_live_adaptation", False)
        ),
        "practice_top_candidate_scores": selection_evidence.get(
            "top_candidate_scores", []
        ),
        # `scaffold_level` remains the dashboard-compatible treatment-fidelity
        # value. The recommendation for the next item is stored separately.
        "scaffold_level": scaffold_level_used,
        "scaffold_level_used": scaffold_level_used,
        "next_scaffold_level": next_action.scaffold_level,
        "decision": next_action.decision,
        "next_phase": next_action.next_phase,
        "policy_version": next_action.policy_version,
        "policy_reason": policy_output["policy_reason"],
        "progression_status": "PROGRESSED" if next_activity != canonical_act else "REMAINED",
        "previous_activity": canonical_act,
        "next_activity": next_activity,
        "previous_kc": official_kc,
        "next_kc": progression_evidence["next_kc"],
        "progression_reason": progression_evidence["progression_reason"]
    }
    
    if request.event_id:
        # A retried mobile completion keeps one auditable decision record.
        # Sequential retries are already rejected by the expected-item guard;
        # this upsert also protects the research dataset from duplicate rows.
        await db.adaptive_decisions.update_one(
            {"student_id": request.student_id, "event_id": request.event_id},
            {"$setOnInsert": adaptive_decision_record},
            upsert=True,
        )
    else:
        await db.adaptive_decisions.insert_one(adaptive_decision_record)

    # Close the final action -> immediate-response link for this item. Earlier
    # scaffold actions were closed by the later ATTEMPT events above.
    await _link_proximal_policy_outcome(
        db,
        student_id=request.student_id,
        session_id=request.session_id,
        item_id=canonical_item,
        response_event_id=request.event_id,
        is_correct=request.is_correct,
        phase="COMPLETE",
        response_quality=response_quality,
    )

    # The research target is an *independent equivalent-task check*, not the
    # supported click that merely completes the original item. When V2 is
    # completed, attach its first-attempt result to every scaffold in the same
    # support chain. Unfinished/abandoned chains remain honestly censored.
    normalized_role = str(item_role or "").upper()
    is_confirmation = (
        practice_phase_before == "CONFIRMATION"
        if practice_controls
        else (
            normalized_role == "CONFIRMATION"
            or bool(re.search(r"V2$", canonical_item, re.IGNORECASE))
        )
    )
    if is_confirmation:
        await _link_confirmation_policy_outcomes(
            db,
            student_id=request.student_id,
            session_id=request.session_id,
            equivalent_group_id=str(practice_origin_group_before),
            confirmation_item_id=canonical_item,
            response_event_id=request.event_id,
            first_independent_correct=learning_observation_correct,
            final_correct=request.is_correct,
            response_quality=response_quality,
        )

    adaptive_states = student_doc.get("adaptive_states", {}) if student_doc else {}
    adaptive_states[canonical_act] = adaptive_state
    update_set = {
        "knowledge_state": knowledge_state,
        "theta_estimate": theta_new,
        "theta_by_kc": theta_by_kc,
        "adaptive_states": adaptive_states,
        "last_updated": datetime.now(timezone.utc).isoformat(),
    }
    if student_doc and "s2a2_state" in student_doc:
        update_set["s2a2_state"] = student_doc["s2a2_state"]
    await database.knowledge_states_collection.update_one(
        {"student_id": request.student_id},
        {"$set": update_set},
        upsert=True,
    )
    
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
