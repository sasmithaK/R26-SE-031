"""Lossless Component 4 gateway contract tests (no network or database)."""

import sys
from pathlib import Path

import pytest
from mongomock_motor import AsyncMongoMockClient

sys.path.insert(0, str(Path(__file__).resolve().parents[4]))

from routers import learning
from routers.learning import (
    InteractionPayload,
    build_adaptive_submit,
    run_background_pipeline,
)


def research_payload() -> InteractionPayload:
    return InteractionPayload(
        event_id="session:S1A5R02V1:complete",
        student_id="student-1",
        session_id="session",
        skill_id="skill_1",
        activity_id="skill1_act5_visual_memory",
        round_number=2,
        item_id="S1A5R02V1",
        knowledge_component_id="KC_VISUAL_MEMORY",
        response={"selected_character": "item", "is_correct": True},
        telemetry={
            "first_touch_latency_ms": 2000,
            "total_round_latency_ms": 5000,
            "hesitation_count": 0,
            "misclick_count": 1,
            "scaffold_level_used": 2,
            "item_role": "REMEDIATION",
            "equivalent_group_id": "S1A5R02",
            "response_load_relation": "reduced",
            "item_version": 2,
            "prompt_modality": "visual",
            "response_modality": "tap",
            "research_role": "primary",
            "difficulty_label": "easy",
            "error_type": "visual_confusion",
            "final_correct": True,
            "time_to_first_response_ms": 2000,
            "time_to_correct_ms": 5000,
            "score": 90,
            "touch_stream": [
                {
                    "x_ratio": 0.2,
                    "y_ratio": 0.3,
                    "timestamp_ms": 2000,
                    "type": "down",
                }
            ],
            "target_ids": ["animals/cat.png"],
            "selected_answers": ["animals/cat.png"],
            "scaffold_applications": [
                {"scaffold_level": 2, "action": "disable_options"}
            ],
        },
        phase="COMPLETE",
        difficulty_b=-0.6,
    )


def test_learning_gateway_preserves_research_lineage_for_c4():
    payload = research_payload()

    forwarded = build_adaptive_submit(
        payload,
        event_id=payload.event_id,
        canonical_activity_id="1.5",
        canonical_item_id="S1A5R02V1",
        fatigue_score=0.1,
        learner_profile={},
    )

    assert forwarded["event_id"] == "session:S1A5R02V1:complete"
    assert forwarded["activity_id"] == "1.5"
    assert forwarded["item_id"] == "S1A5R02V1"
    assert forwarded["phase"] == "COMPLETE"
    telemetry = forwarded["telemetry"]
    assert telemetry["item_role"] == "REMEDIATION"
    assert telemetry["equivalent_group_id"] == "S1A5R02"
    assert telemetry["response_load_relation"] == "reduced"
    assert telemetry["target_ids"] == ["animals/cat.png"]
    assert telemetry["selected_answers"] == ["animals/cat.png"]
    assert telemetry["scaffold_level_used"] == 2
    assert telemetry["scaffold_applications"][0]["scaffold_level"] == 2


@pytest.mark.asyncio
async def test_realtime_persistence_keeps_the_same_complete_evidence(monkeypatch):
    db = AsyncMongoMockClient()["research_contract"]
    monkeypatch.setattr(learning, "get_db", lambda: db)
    payload = research_payload()

    await run_background_pipeline(payload, {}, payload.event_id)
    await run_background_pipeline(payload, {}, payload.event_id)

    assert await db.telemetry_events.count_documents({}) == 1
    stored = await db.telemetry_events.find_one({"event_id": payload.event_id})
    assert stored["ingestion_key"] == "student-1:session:S1A5R02V1:complete"
    assert stored["phase"] == "COMPLETE"
    assert stored["item_role"] == "REMEDIATION"
    assert stored["equivalent_group_id"] == "S1A5R02"
    assert stored["response_load_relation"] == "reduced"
    assert stored["item_version"] == 2
    assert stored["prompt_modality"] == "visual"
    assert stored["response_modality"] == "tap"
    assert stored["research_role"] == "primary"
    assert stored["difficulty_label"] == "easy"
    assert stored["error_type"] == "visual_confusion"
    assert stored["final_correct"] is True
    assert stored["time_to_first_response_ms"] == 2000
    assert stored["time_to_correct_ms"] == 5000
    assert stored["score"] == 90
    assert stored["touch_stream"] == stored["touch_path"]
    assert len(stored["touch_stream"]) == 1
    assert stored["targets"] == ["animals/cat.png"]
    assert stored["target_ids"] == ["animals/cat.png"]
    assert stored["selected_answers"] == ["animals/cat.png"]
    assert stored["scaffold_level_used"] == 2
    assert stored["scaffold_applications"][0]["scaffold_level"] == 2
    assert stored["timestamp"].endswith("+00:00")


@pytest.mark.asyncio
async def test_realtime_attempt_persistence_keeps_canonical_item_evidence(monkeypatch):
    db = AsyncMongoMockClient()["attempt_research_contract"]
    monkeypatch.setattr(learning, "get_db", lambda: db)
    payload = research_payload()
    payload.phase = "ATTEMPT"
    payload.response.is_correct = False
    payload.telemetry.final_correct = False
    payload.telemetry.item_version = 2
    payload.telemetry.item_role = "REMEDIATION"
    payload.telemetry.difficulty_label = "easy"
    payload.telemetry.selected_answers = ["animals/cow.png"]
    payload.telemetry.target_ids = ["animals/cat.png"]
    event_id = "session:S1A5R02V1:attempt:1"

    await run_background_pipeline(payload, {}, event_id)

    stored = await db.telemetry_events.find_one({"event_id": event_id})
    assert stored["phase"] == "ATTEMPT"
    assert stored["item_id"] == "S1A5R02V1"
    assert stored["item_version"] == 2
    assert stored["difficulty_b"] == -0.6
    assert stored["difficulty_label"] == "easy"
    assert stored["item_role"] == "REMEDIATION"
    assert stored["equivalent_group_id"] == "S1A5R02"
    assert stored["target_ids"] == ["animals/cat.png"]
    assert stored["selected_answers"] == ["animals/cow.png"]
    assert stored["final_correct"] is False
