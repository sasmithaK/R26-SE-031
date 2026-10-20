"""Verify the tutoring API integrates state updates, models, and persistence."""

import pytest
import database
from main import _link_confirmation_policy_outcomes

MOCK_INTERACTION_PAYLOAD = {
    "student_id": "mock_student_123",
    "session_id": "mock_session_001",          # required field
    "activity_id": "Skill_2_Activity_1",        # required field
    "knowledge_component_id": "KC_mirror_consonants",
    "item_id": "S2A1R01",                       # required field
    "is_correct": True,
    "current_session_duration_sec": 300,
    "fatigue_score": 0.1,
    "learner_profile": {"Visual-Orthographic Learning Pattern": 0.3}
}

def test_health_check(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


@pytest.mark.asyncio
async def test_first_skill_uses_completed_starter_profile_prior(client):
    student_id = "starter_profile_student"
    await database.get_db().knowledge_states.insert_one({
        "student_id": student_id,
        "knowledge_state": {"KC_VISUAL_IDENTIFICATION": 0.52},
        "theta_by_kc": {"KC_VISUAL_IDENTIFICATION": 0.25},
        "theta_estimate": 0.1,
        "starter_baseline": {
            "baseline_version": "starter-profile-v1",
            "profile_status": "completed",
            "effective_latency_factor": 1.08,
            "skill_profiles": {
                "skill_1": {"mastery_prior": 0.52, "confidence": 0.42},
            },
        },
    })
    payload = {
        **MOCK_INTERACTION_PAYLOAD,
        "student_id": student_id,
        "session_id": "starter-first-session",
        "event_id": "starter-first-complete",
        "activity_id": "1.1",
        "knowledge_component_id": "KC_VISUAL_IDENTIFICATION",
        "item_id": "S1A1R01",
        "is_correct": True,
        "phase": "COMPLETE",
        "telemetry": {
            "total_round_latency_ms": 9000,
            "first_attempt_correct": True,
            "attempt_count": 1,
        },
    }
    response = client.post("/update_interaction", json=payload)
    assert response.status_code == 200
    stored = await database.get_db().adaptive_decisions.find_one({
        "event_id": payload["event_id"],
    })
    assert stored["mastery_before"] == pytest.approx(0.52)
    assert stored["theta_before"] == pytest.approx(0.25)
    assert stored["starter_baseline_context"]["available"] is True
    assert stored["starter_baseline_context"]["effective_latency_factor"] == 1.08

@pytest.mark.asyncio
async def test_update_interaction(client):
    response = client.post("/update_interaction", json=MOCK_INTERACTION_PAYLOAD)
    assert response.status_code == 200
    data = response.json()
    assert data["student_id"] == MOCK_INTERACTION_PAYLOAD["student_id"]
    assert "updated_knowledge_state" in data
    assert "next_action" in data
    # Match actual NextAction schema fields (not stale next_kc_id / terminate_session)
    assert "next_activity" in data["next_action"]
    assert "scaffold_level" in data["next_action"]
    assert "decision" in data["next_action"]
    assert data["next_action"]["decision"] in [
        "CONTINUE", "TERMINATE", "ACTIVITY_COMPLETE"
    ]
    assert "difficulty" in data["next_action"]
    assert 0.0 <= data["next_action"]["difficulty"] <= 1.0


@pytest.mark.asyncio
async def test_attempt_records_shadow_model_and_keeps_baseline_action(client):
    payload = {
        **MOCK_INTERACTION_PAYLOAD,
        "event_id": "session:S2A1R01:attempt:1",
        "activity_id": "2.1",
        "is_correct": False,
        "phase": "ATTEMPT",
        "policy_mode": "model",
        "data_origin": "observed",
        "dataset_id": "live:mock_student_123:mock_session_001",
        "validation_status": "operational_observation",
        "telemetry": {
            "total_round_latency_ms": 6000,
            "attempt_count": 1,
            "incorrect_attempt_count": 1,
            "original_options_count": 4,
            "visible_option_ids": ["O1", "O2", "O3", "O4"],
            "incorrect_option_ids": ["O2", "O3", "O4"],
            "correct_option_ids": ["O1"],
            "supported_actions": ["REMOVE_OPTION", "HIGHLIGHT_OPTION"],
        },
    }
    response = client.post("/update_interaction", json=payload)
    assert response.status_code == 200
    action = response.json()["next_action"]
    assert action["decision"] == "SCAFFOLD_REMOVE_DISTRACTOR"
    assert action["policy_mode"] == "model"
    assert action["model_version"] == "c4-action-outcome-synthetic-v2"
    assert action["fallback_reason"] == "SYNTHETIC_OR_UNVALIDATED_MODEL_SHADOW_ONLY"
    stored = await database.get_db().policy_decisions.find_one({
        "event_id": payload["event_id"]
    })
    assert stored["applied_action"] == "SCAFFOLD_REMOVE_DISTRACTOR"
    assert stored["assignment_probability"] == 1.0
    assert stored["calibration_eligible"] is False


@pytest.mark.asyncio
async def test_simulation_model_controls_an_authored_scaffold_command(client):
    payload = {
        **MOCK_INTERACTION_PAYLOAD,
        "student_id": "simulation_policy_student",
        "session_id": "simulation_policy_session",
        "event_id": "simulation:S2A1R01:attempt:1",
        "activity_id": "2.1",
        "is_correct": False,
        "phase": "ATTEMPT",
        "policy_mode": "simulation_model",
        "data_origin": "observed",
        "dataset_id": "live:simulation_policy_student:simulation_policy_session",
        "validation_status": "operational_observation",
        "telemetry": {
            "total_round_latency_ms": 12000,
            "attempt_count": 1,
            "incorrect_attempt_count": 1,
            "original_options_count": 4,
            "visible_option_ids": ["O1", "O2", "O3", "O4"],
            "incorrect_option_ids": ["O2", "O3", "O4"],
            "correct_option_ids": ["O1"],
            "supported_actions": [
                "HIGHLIGHT_OPTION",
                "REPLAY_INSTRUCTION",
                "SLOW_AUDIO",
            ],
        },
    }
    response = client.post("/update_interaction", json=payload)
    assert response.status_code == 200
    action = response.json()["next_action"]
    assert action["policy_mode"] == "simulation_model"
    assert action["controls_live_adaptation"] is True
    assert action["execution_source"] == "synthetic_model_simulation"
    assert action["decision"] == action["applied_action"]
    assert action["decision"] in {
        "RETRY_CURRENT",
        "SCAFFOLD_HIGHLIGHT_CORRECT",
        "SCAFFOLD_REPLAY_INSTRUCTION",
        "SCAFFOLD_SLOW_AUDIO",
    }
    stored = await database.get_db().policy_decisions.find_one({
        "event_id": payload["event_id"]
    })
    assert stored["assignment_mechanism"] == "configured_policy_mode"
    assert stored["controls_live_adaptation"] is True
    assert stored["data_origin"] == "observed"
    assert stored["simulation_disclosure"]


@pytest.mark.asyncio
async def test_every_scaffold_links_proximal_and_confirmation_outcomes(client):
    base = {
        **MOCK_INTERACTION_PAYLOAD,
        "student_id": "outcome_chain_student",
        "session_id": "outcome_chain_session",
        "activity_id": "2.1",
        "item_id": "S2A1R01",
        "is_correct": False,
        "phase": "ATTEMPT",
        "data_origin": "observed",
        "dataset_id": "live:mock_student_123:mock_session_001",
        "validation_status": "operational_observation",
        "telemetry": {
            "total_round_latency_ms": 3000,
            "attempt_count": 1,
            "incorrect_attempt_count": 1,
            "original_options_count": 4,
            "visible_option_ids": ["O1", "O2", "O3", "O4"],
            "incorrect_option_ids": ["O2", "O3", "O4"],
            "correct_option_ids": ["O1"],
            "supported_actions": ["REMOVE_OPTION", "HIGHLIGHT_OPTION"],
            "item_role": "CORE",
            "equivalent_group_id": "S2A1R01",
        },
    }
    await database.get_db().knowledge_states.delete_many({
        "student_id": base["student_id"],
    })
    await database.get_db().policy_decisions.delete_many({
        "student_id": base["student_id"],
    })
    first = {**base, "event_id": "chain:attempt:1"}
    second = {
        **base,
        "event_id": "chain:attempt:2",
        "telemetry": {
            **base["telemetry"],
            "attempt_count": 2,
            "incorrect_attempt_count": 2,
        },
    }
    assert client.post("/update_interaction", json=first).status_code == 200
    assert client.post("/update_interaction", json=second).status_code == 200

    complete = {
        **base,
        "event_id": "chain:complete",
        "is_correct": True,
        "phase": "COMPLETE",
        "telemetry": {
            **second["telemetry"],
            "attempt_count": 3,
            "first_attempt_correct": False,
        },
    }
    assert client.post("/update_interaction", json=complete).status_code == 200
    rows = await database.get_db().policy_decisions.find({
        "student_id": base["student_id"],
    }).sort("event_id", 1).to_list(length=10)
    assert len(rows) == 2
    assert rows[0]["proximal_next_response_correct"] is False
    assert rows[1]["proximal_next_response_correct"] is True
    assert all(row.get("outcome_observed") is not True for row in rows)

    await _link_confirmation_policy_outcomes(
        database.get_db(),
        student_id=base["student_id"],
        session_id=base["session_id"],
        equivalent_group_id="S2A1R01",
        confirmation_item_id="S2A1R01V2",
        response_event_id="chain:confirmation",
        first_independent_correct=True,
        final_correct=True,
        response_quality="CLEAN_SUCCESS",
    )
    linked = await database.get_db().policy_decisions.find({
        "student_id": base["student_id"],
    }).to_list(length=10)
    assert len(linked) == 2
    assert all(row["outcome_observed"] is True for row in linked)
    assert all(row["outcome_first_attempt_correct"] is True for row in linked)
    assert all(row["outcome_item_id"] == "S2A1R01V2" for row in linked)
