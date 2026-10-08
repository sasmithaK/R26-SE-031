import pytest
import pytest_asyncio
from tests.conftest import mock_db
from seed_item_bank import build_items
from services.item_selector import item_selector
from services.policy_engine import policy_engine

MOCK_PAYLOAD = {
    "student_id": "step7_student",
    "session_id": "session_007",
    "activity_id": "act_1",
    "knowledge_component_id": "UNKNOWN",
    "item_id": "S2A1R01",
    "is_correct": True,
    "current_session_duration_sec": 30,
    "fatigue_score": 0.0,
    "learner_profile": {}
}

@pytest_asyncio.fixture(autouse=True)
async def seed_mock_db():
    await mock_db["knowledge_states"].delete_many({})
    await mock_db["item_bank"].delete_many({})
    await mock_db["adaptive_decisions"].delete_many({})
    
    items = build_items()
    for doc in items:
        await mock_db["item_bank"].update_one(
            {"item_id": doc["item_id"]},
            {"$set": doc},
            upsert=True
        )
    yield

async def force_state(student_id: str, theta: float, mastery: float, kc: str):
    await mock_db["knowledge_states"].update_one(
        {"student_id": student_id},
        {"$set": {
            "knowledge_state": {kc: mastery},
            "theta_estimate": theta
        }},
        upsert=True
    )

def test_0_repeat_avoidance_correction():
    # Target difficulty 0.0, current item is S3A2R03 (b=0.0). 
    # Alternatives exist: S3A2R02 (-0.5), S3A2R04 (0.5)
    candidates = [
        {"item_id": "S3A2R02", "activity_id": "act_3", "difficulty_b": -0.5, "round": 2},
        {"item_id": "S3A2R03", "activity_id": "act_3", "difficulty_b": 0.0, "round": 3},
        {"item_id": "S3A2R04", "activity_id": "act_3", "difficulty_b": 0.5, "round": 4}
    ]
    
    res = item_selector.select_next_item(
        current_item_id="S3A2R03",
        current_activity="act_3",
        target_difficulty=0.0,
        candidates=candidates
    )
    # Must NOT select S3A2R03 even though it is perfectly 0.0
    assert res["selected_item"] != "S3A2R03"
    assert res["selected_item"] == "S3A2R02" # Based on sorting tie-breaker

def test_0b_repeat_when_only_one_candidate():
    candidates = [
        {"item_id": "S3A2R03", "activity_id": "act_3", "difficulty_b": 0.0, "round": 3}
    ]
    res = item_selector.select_next_item(
        current_item_id="S3A2R03",
        current_activity="act_3",
        target_difficulty=0.0,
        candidates=candidates
    )
    # Must repeat because no alternatives exist
    assert res["selected_item"] == "S3A2R03"


def test_0c_completed_items_are_not_selected_again():
    candidates = [
        {"item_id": "S3A2R01", "activity_id": "act_3", "difficulty_b": -1.0, "round": 1},
        {"item_id": "S3A2R02", "activity_id": "act_3", "difficulty_b": 0.0, "round": 2},
    ]
    result = item_selector.select_next_item(
        current_item_id="S3A2R01",
        current_activity="act_3",
        target_difficulty=-1.0,
        candidates=candidates,
        excluded_item_ids=["S3A2R01"],
    )
    assert result["selected_item"] == "S3A2R02"


def test_0d_activity_completes_when_all_active_items_were_administered():
    candidates = [
        {"item_id": "S3A2R01", "activity_id": "act_3", "difficulty_b": -1.0, "round": 1},
    ]
    result = item_selector.select_next_item(
        current_item_id="S3A2R01",
        current_activity="act_3",
        target_difficulty=-1.0,
        candidates=candidates,
        excluded_item_ids=["S3A2R01"],
    )
    assert result["selected_item"] == "COMPLETE"
    assert result["selection_reason"] == "ALL_ACTIVE_ITEMS_ADMINISTERED"


def test_0e_skill1_slow_but_independent_success_does_not_trigger_remediation():
    result = policy_engine.get_next_action(
        kc_mastery=0.6,
        theta=0.2,
        fatigue_score=0.0,
        current_activity="1.1",
        response_quality="STRUGGLED_SUCCESS",
        struggle_band="MODERATE",
        current_difficulty_b=1.0,
        adaptive_state={
            "expected_item_id": "S1A1R03",
            "next_phase": "CORE",
            "administered_item_ids": ["S1A1R01", "S1A1R02"],
        },
        learner_profile={},
    )

    assert result["decision"] == "NEXT_CORE"
    assert result["next_phase"] == "CORE"
    assert result["next_item"] == "S1A1R04"
    assert "S1A1_STRUGGLED_BUT_INDEPENDENT_MAINTAINS_DIFFICULTY" in (
        result["policy_reason"]
    )


@pytest.mark.asyncio
async def test_1_low_mastery(client):
    await force_state("s1", theta=0.0, mastery=0.20, kc="KC_LETTER_IDENTIFICATION")
    
    payload = dict(MOCK_PAYLOAD)
    payload["student_id"] = "s1"
    payload["is_correct"] = False
    
    res = client.post("/update_interaction", json=payload)
    evidence = res.json().get("selection_evidence")
    
    assert "MASTERY_LOW" in evidence["policy_reason"]

@pytest.mark.asyncio
async def test_2_moderate_mastery(client):
    await force_state("s2", theta=0.0, mastery=0.45, kc="KC_LETTER_IDENTIFICATION")
    
    payload = dict(MOCK_PAYLOAD)
    payload["student_id"] = "s2"
    payload["is_correct"] = True
    
    res = client.post("/update_interaction", json=payload)
    evidence = res.json().get("selection_evidence")
    
    assert "MASTERY_MODERATE" in evidence["policy_reason"]

@pytest.mark.asyncio
async def test_3_high_mastery(client):
    # Mastery close to 0.70. With True it might jump into MASTERED, so we use False to keep it HIGH
    await force_state("s3", theta=0.0, mastery=0.84, kc="KC_LETTER_IDENTIFICATION")
    
    payload = dict(MOCK_PAYLOAD)
    payload["student_id"] = "s3"
    payload["is_correct"] = False
    
    res = client.post("/update_interaction", json=payload)
    evidence = res.json().get("selection_evidence")
    
    assert "MASTERY_HIGH" in evidence["policy_reason"]

@pytest.mark.asyncio
async def test_4_mastered_threshold(client):
    await force_state("s4", theta=0.0, mastery=0.90, kc="KC_LETTER_IDENTIFICATION")
    
    payload = dict(MOCK_PAYLOAD)
    payload["student_id"] = "s4"
    payload["is_correct"] = True
    
    res = client.post("/update_interaction", json=payload)
    evidence = res.json().get("selection_evidence")
    
    assert "MASTERY_MASTERED" in evidence["policy_reason"]

@pytest.mark.asyncio
async def test_5_high_fatigue(client):
    await force_state("s5", theta=0.0, mastery=0.90, kc="KC_LETTER_IDENTIFICATION")
    
    payload = dict(MOCK_PAYLOAD)
    payload["student_id"] = "s5"
    payload["fatigue_score"] = 0.95
    
    res = client.post("/update_interaction", json=payload)
    body = res.json()
    evidence = body.get("selection_evidence")
    
    assert "HIGH_FATIGUE_OBSERVED" in evidence["policy_reason"]
    assert "BREAK_RECOMMENDED_AFTER_ACTIVITY" in evidence["policy_reason"]
    assert body["next_action"]["decision"] != "TERMINATE"

@pytest.mark.asyncio
async def test_6_visual_orthographic_profile(client):
    await force_state("s6", theta=0.0, mastery=0.40, kc="KC_LETTER_IDENTIFICATION")
    
    payload = dict(MOCK_PAYLOAD)
    payload["student_id"] = "s6"
    payload["is_correct"] = False
    payload["learner_profile"] = {"Visual-Orthographic Learning Pattern": 0.8}
    
    res = client.post("/update_interaction", json=payload)
    body = res.json()
    evidence = body.get("selection_evidence")
    
    assert "VISUAL_ORTHOGRAPHIC_SUPPORT" in evidence["policy_reason"]
    assert body["next_action"]["scaffold_level"] == 1

@pytest.mark.asyncio
async def test_7_missing_learner_profile(client):
    await force_state("s7", theta=0.0, mastery=0.40, kc="KC_LETTER_IDENTIFICATION")
    
    payload = dict(MOCK_PAYLOAD)
    payload["student_id"] = "s7"
    del payload["learner_profile"] # Completely missing
    
    res = client.post("/update_interaction", json=payload)
    evidence = res.json().get("selection_evidence")
    
    assert "NO_LEARNER_PROFILE_AVAILABLE" in evidence["policy_reason"]
    assert res.status_code == 200

@pytest.mark.asyncio
async def test_8_typical_low_risk_profile(client):
    await force_state("s8", theta=0.0, mastery=0.40, kc="KC_LETTER_IDENTIFICATION")
    
    payload = dict(MOCK_PAYLOAD)
    payload["student_id"] = "s8"
    payload["is_correct"] = False
    payload["learner_profile"] = {"Visual-Orthographic Learning Pattern": 0.2}
    
    res = client.post("/update_interaction", json=payload)
    body = res.json()
    
    # Neither HIGH FATIGUE nor VO SUPPORT
    evidence = body.get("selection_evidence")
    assert "VISUAL_ORTHOGRAPHIC_SUPPORT" not in evidence["policy_reason"]
    assert body["next_action"]["scaffold_level"] == 0

@pytest.mark.asyncio
async def test_9_c3_does_not_directly_control_difficulty(client):
    await force_state("s9a", theta=0.0, mastery=0.40, kc="KC_LETTER_IDENTIFICATION")
    await force_state("s9b", theta=0.0, mastery=0.40, kc="KC_LETTER_IDENTIFICATION")
    
    payload_a = dict(MOCK_PAYLOAD)
    payload_a["student_id"] = "s9a"
    payload_a["is_correct"] = False
    payload_a["learner_profile"] = {"Visual-Orthographic Learning Pattern": 0.2}
    
    payload_b = dict(MOCK_PAYLOAD)
    payload_b["student_id"] = "s9b"
    payload_b["is_correct"] = False
    payload_b["learner_profile"] = {"Visual-Orthographic Learning Pattern": 0.9}
    
    res_a = client.post("/update_interaction", json=payload_a).json()
    res_b = client.post("/update_interaction", json=payload_b).json()
    
    # Both should have exactly the same target difficulty and selected difficulty
    assert res_a["selection_evidence"]["target_difficulty"] == res_b["selection_evidence"]["target_difficulty"]
    # Only scaffold should differ
    assert res_a["next_action"]["scaffold_level"] == 0
    assert res_b["next_action"]["scaffold_level"] == 1

@pytest.mark.asyncio
async def test_10_adaptive_decision_persistence(client):
    await force_state("s10", theta=0.0, mastery=0.50, kc="KC_LETTER_IDENTIFICATION")
    
    payload = dict(MOCK_PAYLOAD)
    payload["student_id"] = "s10"
    payload["event_id"] = "session_007:S2A1R01:complete"
    payload["telemetry"] = {
        "first_attempt_correct": True,
        "item_role": "CORE",
        "equivalent_group_id": "S2A1R01",
        "response_load_relation": "core",
        "target_ids": ["S2A1R01_O1"],
        "selected_answers": ["S2A1R01_O1"],
        "scaffold_applications": [],
    }
    
    res = client.post("/update_interaction", json=payload)
    
    # Check DB
    doc = await mock_db["adaptive_decisions"].find_one({"student_id": "s10"})
    
    assert doc is not None
    assert doc["activity_id"] == "2.1"
    assert doc["event_id"] == "session_007:S2A1R01:complete"
    assert doc["kc_id"] == "KC_LETTER_IDENTIFICATION"
    assert doc["submitted_kc_id"] == "UNKNOWN"
    assert doc["item_role"] == "CORE"
    assert doc["equivalent_group_id"] == "S2A1R01"
    assert doc["response_load_relation"] == "core"
    assert doc["item_version"] == 2
    assert doc["difficulty_label"] == "easy"
    assert doc["difficulty_b"] == -1.0
    assert doc["difficulty_source"] == "expert_provisional"
    assert doc["calibration_status"] == "not_empirically_calibrated"
    assert doc["is_anchor"] is False
    assert doc["target_ids"] == ["S2A1R01_O1"]
    assert doc["selected_answers"] == ["S2A1R01_O1"]
    assert "mastery_after" in doc
    assert doc["bkt_model_version"] == "bkt_theory_provisional_v1"
    assert doc["bkt_calibration_status"] == "provisional"
    assert doc["bkt_parameters"]["p_initial"] == 0.3
    assert "theta_after" in doc
    assert 0.0 < doc["predicted_probability"] < 1.0
    assert doc["test_information_after"] > 0.0
    assert "target_difficulty" in doc
    assert "selected_item" in doc
    assert doc["next_phase"] == res.json()["next_action"]["next_phase"]
    assert doc["policy_version"] == res.json()["next_action"]["policy_version"]
    assert "policy_reason" in doc


@pytest.mark.asyncio
async def test_11_assisted_final_success_uses_first_attempt_for_mastery(client):
    payload = dict(MOCK_PAYLOAD)
    payload["student_id"] = "assisted_student"
    payload["is_correct"] = True
    payload["telemetry"] = {
        "first_attempt_correct": False,
        "attempt_count": 2,
        "incorrect_attempt_count": 1,
        "scaffold_level_used": 1,
    }

    response = client.post("/update_interaction", json=payload)
    assert response.status_code == 200
    body = response.json()

    assert body["bkt_evidence"]["first_attempt_correct"] is False
    assert body["bkt_evidence"]["final_correct"] is True
    assert body["bkt_evidence"]["mastery_after"] < body["bkt_evidence"]["mastery_before"]
    assert body["next_action"]["decision"] == "REMEDIATION"
    assert body["next_action"]["next_item"] == "S2A1R01V1"
    decision = await mock_db["adaptive_decisions"].find_one(
        {"student_id": "assisted_student"}
    )
    assert decision["scaffold_level"] == 1
    assert decision["scaffold_level_used"] == 1
    assert decision["next_scaffold_level"] == body["next_action"]["scaffold_level"]


@pytest.mark.asyncio
async def test_12_skill1_activity1_serves_all_five_core_items_before_completion(client):
    student_id = "skill1_all_five"
    next_item = "S1A1R01"
    served = []

    for round_index in range(5):
        served.append(next_item)
        payload = {
            "student_id": student_id,
            "session_id": "skill1-session",
            "skill_id": "skill_1",
            "activity_id": "1.1",
            "knowledge_component_id": "KC_VISUAL_IDENTIFICATION",
            "item_id": next_item,
            "is_correct": True,
            "phase": "COMPLETE",
            "current_session_duration_sec": 10,
            "fatigue_score": 0.0,
            "learner_profile": {},
            "telemetry": {
                "first_attempt_correct": True,
                "attempt_count": 1,
                "incorrect_attempt_count": 0,
                "scaffold_level_used": 0,
            },
        }
        response = client.post("/update_interaction", json=payload)
        assert response.status_code == 200
        body = response.json()
        assert body["next_action"]["progress_total"] == 5

        if round_index < 4:
            assert body["next_action"]["next_activity"] == "1.1"
            assert body["next_action"]["decision"] != "ACTIVITY_COMPLETE"
            next_item = body["next_action"]["next_item"]
            assert next_item.startswith("S1A1R")
            assert next_item not in served
        else:
            assert body["next_action"]["decision"] == "ACTIVITY_COMPLETE"
            assert body["next_action"]["next_item"] == "COMPLETE"

    assert served == [
        "S1A1R01", "S1A1R02", "S1A1R03", "S1A1R04", "S1A1R05"
    ]
    state = await mock_db["knowledge_states"].find_one({"student_id": student_id})
    assert state["adaptive_states"]["1.1"]["expected_item_id"] == "COMPLETE"
    assert state["adaptive_states"]["1.1"]["next_phase"] == "COMPLETE"
    terminal = await mock_db["adaptive_decisions"].find_one({
        "student_id": student_id,
        "decision": "ACTIVITY_COMPLETE",
    })
    assert terminal["next_phase"] == "COMPLETE"
    assert terminal["timestamp"].endswith("+00:00")


@pytest.mark.asyncio
async def test_13_skill1_assisted_core_runs_remediation_then_confirmation(client):
    student_id = "skill1_remediation_flow"

    await mock_db["knowledge_states"].update_one(
        {"student_id": student_id},
        {"$set": {
            "knowledge_state": {"KC_VISUAL_IDENTIFICATION": 0.65},
            "theta_estimate": 0.5,
            "adaptive_states": {
                "1.1": {
                    "expected_item_id": "S1A1R03",
                    "next_phase": "CORE",
                    "administered_item_ids": ["S1A1R01", "S1A1R02"],
                },
            },
        }},
        upsert=True,
    )

    async def complete(item_id, first_attempt_correct, scaffold_level=0):
        response = client.post("/update_interaction", json={
            "student_id": student_id,
            "session_id": "skill1-remediation-session",
            "skill_id": "skill_1",
            "activity_id": "1.1",
            "knowledge_component_id": "KC_VISUAL_IDENTIFICATION",
            "item_id": item_id,
            "is_correct": True,
            "phase": "COMPLETE",
            "current_session_duration_sec": 10,
            "fatigue_score": 0.0,
            "learner_profile": {},
            "telemetry": {
                "first_attempt_correct": first_attempt_correct,
                "attempt_count": 1 if first_attempt_correct else 4,
                "incorrect_attempt_count": 0 if first_attempt_correct else 3,
                "scaffold_level_used": scaffold_level,
            },
        })
        assert response.status_code == 200
        return response.json()

    assisted = await complete("S1A1R03", False, scaffold_level=3)
    assert assisted["response_quality"] == "ASSISTED_SUCCESS"
    assert assisted["next_action"]["decision"] == "REMEDIATION"
    assert assisted["next_action"]["next_phase"] == "REMEDIATION"
    assert assisted["next_action"]["next_item"] == "S1A1R03V1"
    assert assisted["next_action"]["progress_total"] == 5

    remediation = await complete("S1A1R03V1", True)
    assert remediation["next_action"]["decision"] == "CONFIRMATION"
    assert remediation["next_action"]["next_phase"] == "CONFIRMATION"
    assert remediation["next_action"]["next_item"] == "S1A1R03V2"

    confirmation = await complete("S1A1R03V2", True)
    assert confirmation["next_action"]["next_phase"] == "CORE"
    assert confirmation["next_action"]["next_item"] == "S1A1R04"
    assert "UNASSISTED_EQUIVALENT_CONFIRMATION_PASSED" in (
        confirmation["selection_evidence"]["policy_reason"]
    )


@pytest.mark.asyncio
async def test_14_irt_ability_is_scoped_to_the_current_knowledge_component(client):
    await mock_db["knowledge_states"].update_one(
        {"student_id": "domain_theta_student"},
        {"$set": {
            "knowledge_state": {"KC_LETTER_IDENTIFICATION": 0.5},
            "theta_estimate": 2.0,
            "theta_by_kc": {
                "KC_VISUAL_IDENTIFICATION": 1.5,
                "KC_LETTER_IDENTIFICATION": -1.0,
            },
            "adaptive_states": {
                "2.1": {
                    "expected_item_id": "S2A1R01",
                    "next_phase": "CORE",
                },
            },
        }},
        upsert=True,
    )
    payload = dict(MOCK_PAYLOAD)
    payload["student_id"] = "domain_theta_student"

    response = client.post("/update_interaction", json=payload)
    assert response.status_code == 200
    evidence = response.json()["irt_evidence"]
    assert evidence["theta_before"] == -1.0
    assert evidence["ability_scope"] == "KC_LETTER_IDENTIFICATION"
    assert evidence["observation_count"] == 1
    assert evidence["standard_error_after"] > 0
    assert evidence["test_information_after"] > 0


@pytest.mark.asyncio
async def test_15_stale_core_completion_cannot_bypass_equivalent_remediation(client):
    student_id = "stale_completion_student"
    await mock_db["knowledge_states"].update_one(
        {"student_id": student_id},
        {"$set": {
            "knowledge_state": {"KC_VISUAL_IDENTIFICATION": 0.5},
            "adaptive_states": {
                "1.1": {
                    "expected_item_id": "S1A1R03V1",
                    "next_phase": "REMEDIATION",
                    "administered_item_ids": ["S1A1R01", "S1A1R02", "S1A1R03"],
                },
            },
        }},
        upsert=True,
    )
    payload = {
        "student_id": student_id,
        "session_id": "stale-session",
        "skill_id": "skill_1",
        "activity_id": "1.1",
        "knowledge_component_id": "KC_VISUAL_IDENTIFICATION",
        "item_id": "S1A1R03",
        "is_correct": True,
        "phase": "COMPLETE",
        "current_session_duration_sec": 10,
        "telemetry": {"first_attempt_correct": True},
    }

    response = client.post("/update_interaction", json=payload)
    assert response.status_code == 200
    action = response.json()["next_action"]
    assert action["decision"] == "RETRY_CURRENT"
    assert action["next_item"] == "S1A1R03V1"
    assert action["next_phase"] == "REMEDIATION"
    assert "STALE_OR_DUPLICATE_COMPLETION_IGNORED" in action["reason_codes"]
    assert await mock_db["adaptive_decisions"].count_documents({
        "student_id": student_id,
    }) == 0
