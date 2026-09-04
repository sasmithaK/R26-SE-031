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
    
    assert "HIGH_FATIGUE" in evidence["policy_reason"]
    assert body["next_action"]["decision"] == "TERMINATE"

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
    
    res = client.post("/update_interaction", json=payload)
    
    # Check DB
    doc = await mock_db["adaptive_decisions"].find_one({"student_id": "s10"})
    
    assert doc is not None
    assert doc["activity_id"] == "2.1"
    assert doc["kc_id"] == "KC_LETTER_IDENTIFICATION"
    assert "mastery_after" in doc
    assert "theta_after" in doc
    assert "target_difficulty" in doc
    assert "selected_item" in doc
    assert "policy_reason" in doc
