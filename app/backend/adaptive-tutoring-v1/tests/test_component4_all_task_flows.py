import pytest
import pytest_asyncio

from item_bank_builder import build_items
from services.equivalent_task_policy import EquivalentTaskPolicy
from services.item_selector import item_selector
from tests.conftest import mock_db


SKILLS = {"skill_1", "skill_2", "skill_3", "skill_4"}


@pytest_asyncio.fixture(autouse=True)
async def seed_component4_bank():
    await mock_db["knowledge_states"].delete_many({})
    await mock_db["item_bank"].delete_many({})
    for item in build_items():
        await mock_db["item_bank"].update_one(
            {"item_id": item["item_id"]}, {"$set": item}, upsert=True
        )
    yield


def _decide(core, item_id, quality, state):
    return EquivalentTaskPolicy().get_next_action(
        activity_id=core["activity_id"],
        current_item_id=item_id,
        response_quality=quality,
        current_b=core["difficulty_b"],
        state=state,
        policy_reason=[f"RESPONSE_QUALITY: {quality}"],
        has_reduced_remediation=core["has_reduced_remediation"],
    )


def test_every_skill_one_to_four_task_has_a_bounded_age_appropriate_flow():
    items = [item for item in build_items() if item["skill_id"] in SKILLS]
    by_id = {item["item_id"]: item for item in items}
    cores = [item for item in items if item["is_core"]]

    assert len(cores) == 97
    for core in cores:
        state = {}
        clean = _decide(core, core["item_id"], "CLEAN_SUCCESS", state)
        assert clean["next_item"] == "", core["item_id"]
        assert clean["next_phase"] == "CORE", core["item_id"]

        state = {}
        assisted = _decide(core, core["item_id"], "ASSISTED_SUCCESS", state)
        if core["has_reduced_remediation"]:
            remediation_id = f'{core["item_id"]}V1'
            assert assisted["next_item"] == remediation_id, core["item_id"]
            assert assisted["next_phase"] == "REMEDIATION", core["item_id"]
            assert by_id[remediation_id]["difficulty_b"] < core["difficulty_b"]
            confirmation = _decide(
                core, remediation_id, "CLEAN_SUCCESS", state
            )
        else:
            assert assisted["next_item"] == f'{core["item_id"]}V2', core["item_id"]
            assert assisted["next_phase"] == "CONFIRMATION", core["item_id"]
            confirmation = assisted

        confirmation_id = f'{core["item_id"]}V2'
        assert confirmation["next_item"] == confirmation_id, core["item_id"]
        assert by_id[confirmation_id]["difficulty_b"] == core["difficulty_b"]

        finished = _decide(core, confirmation_id, "CLEAN_SUCCESS", state)
        assert finished["next_item"] == "", core["item_id"]
        assert finished["next_phase"] == "CORE", core["item_id"]


def test_clean_success_selects_the_next_core_not_an_equivalent_variant():
    items = [item for item in build_items() if item["skill_id"] in SKILLS]
    activities = sorted({item["activity_id"] for item in items})

    for activity_id in activities:
        candidates = [
            item for item in items
            if item["activity_id"] == activity_id and item["is_active"]
        ]
        cores = sorted(
            (item for item in candidates if item["is_core"]),
            key=lambda item: item["round"],
        )
        for index, core in enumerate(cores[:-1]):
            completed = [item["item_id"] for item in cores[:index + 1]]
            selected = item_selector.select_next_item(
                current_item_id=core["item_id"],
                current_activity=activity_id,
                target_difficulty=core["difficulty_b"],
                candidates=candidates,
                excluded_item_ids=completed,
            )
            assert selected["selected_item"] == cores[index + 1]["item_id"], (
                core["item_id"], selected
            )


@pytest.mark.asyncio
async def test_first_hidden_search_task_uses_two_image_remediation(client):
    response = client.post("/update_interaction", json={
        "student_id": "first-hidden-search-remediation",
        "session_id": "first-hidden-search-session",
        "skill_id": "skill_1",
        "activity_id": "1.1",
        "knowledge_component_id": "KC_VISUAL_IDENTIFICATION",
        "item_id": "S1A1R01",
        "is_correct": True,
        "phase": "COMPLETE",
        "current_session_duration_sec": 20,
        "telemetry": {
            "attempt_count": 2,
            "incorrect_attempt_count": 1,
            "first_attempt_correct": False,
            "scaffold_level_used": 1,
        },
    })
    assert response.status_code == 200
    body = response.json()
    assert body["response_quality"] == "ASSISTED_SUCCESS"
    assert body["next_action"]["next_item"] == "S1A1R01V1"
    assert body["next_action"]["next_phase"] == "REMEDIATION"
    assert body["next_action"]["difficulty_b"] == -1.5


@pytest.mark.asyncio
async def test_irreducible_first_task_uses_only_one_same_level_retry(client):
    response = client.post("/update_interaction", json={
        "student_id": "first-floor-task-retry",
        "session_id": "first-floor-task-session",
        "skill_id": "skill_3",
        "activity_id": "3.1",
        "knowledge_component_id": "KC_WORD_RECOGNITION",
        "item_id": "S3A1R01",
        "is_correct": True,
        "phase": "COMPLETE",
        "current_session_duration_sec": 20,
        "telemetry": {
            "attempt_count": 2,
            "incorrect_attempt_count": 1,
            "first_attempt_correct": False,
            "scaffold_level_used": 1,
        },
    })
    assert response.status_code == 200
    body = response.json()
    assert body["next_action"]["next_item"] == "S3A1R01V2"
    assert body["next_action"]["next_phase"] == "CONFIRMATION"
    assert body["next_action"]["difficulty_b"] == -1.0
    assert "NO_VALID_LOWER_LOAD_ITEM" in body["next_action"]["reason_codes"]


@pytest.mark.asyncio
async def test_every_skill_one_activity_persists_a_terminal_complete_state(client):
    kcs = {
        "1.1": "KC_VISUAL_IDENTIFICATION",
        "1.2": "KC_VISUAL_MATCHING",
        "1.3": "KC_VISUAL_CATEGORIZATION",
        "1.4": "KC_VISUAL_PATTERN",
        "1.5": "KC_VISUAL_MEMORY",
    }
    all_items = build_items()

    for activity_id, kc_id in kcs.items():
        student_id = f"skill1-terminal-{activity_id}"
        session_id = f"session-{activity_id}"
        cores = sorted(
            (
                item
                for item in all_items
                if item["activity_id"] == activity_id and item["is_core"]
            ),
            key=lambda item: item["round"],
        )

        last_body = None
        for core in cores:
            response = client.post("/update_interaction", json={
                "student_id": student_id,
                "session_id": session_id,
                "event_id": f'{session_id}:{core["item_id"]}:complete',
                "skill_id": "skill_1",
                "activity_id": activity_id,
                "knowledge_component_id": kc_id,
                "item_id": core["item_id"],
                "is_correct": True,
                "phase": "COMPLETE",
                "current_session_duration_sec": 20,
                "telemetry": {
                    "attempt_count": 1,
                    "incorrect_attempt_count": 0,
                    "first_attempt_correct": True,
                    "scaffold_level_used": 0,
                },
            })
            assert response.status_code == 200, (core["item_id"], response.text)
            last_body = response.json()

        assert last_body is not None
        assert last_body["next_action"]["decision"] == "ACTIVITY_COMPLETE"
        assert last_body["next_action"]["next_item"] == "COMPLETE"
        assert last_body["next_action"]["next_phase"] == "COMPLETE"

        state_doc = await mock_db["knowledge_states"].find_one({
            "student_id": student_id,
        })
        activity_state = state_doc["adaptive_states"][activity_id]
        assert activity_state["expected_item_id"] == "COMPLETE"
        assert activity_state["next_phase"] == "COMPLETE"
        assert activity_state["measurement_stop_reason"] == (
            "CORE_COVERAGE_AND_EQUIVALENT_FLOW_COMPLETE"
        )
