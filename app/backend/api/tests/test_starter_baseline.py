"""Starter Learning Profile unit and persistence tests (offline)."""

import sys
from pathlib import Path

import pytest
from fastapi import HTTPException
from mongomock_motor import AsyncMongoMockClient


TEST_FILE = Path(__file__).resolve()
sys.path.insert(0, str(TEST_FILE.parents[4]))
sys.path.insert(0, str(TEST_FILE.parents[1]))

from routers import starter_baseline as routes
from routers.starter_baseline import BaselineResponseRequest, BaselineStartRequest
from services.starter_baseline import (
    BASELINE_ITEMS,
    BASELINE_VERSION,
    build_starter_profile,
    score_answer,
)


def event_for(item, *, correct=True, latency=None):
    return {
        **item,
        "response_status": "answered",
        "is_correct": correct,
        "total_latency_ms": latency or item["expected_latency_ms"],
        "audio_replay_count": 0,
    }


def test_server_owned_answers_and_conservative_profile_bounds():
    item = BASELINE_ITEMS[0]
    assert score_answer(item, ["dog"]) is True
    assert score_answer(item, ["cat"]) is False

    profile = build_starter_profile([
        event_for(item, correct=True) for item in BASELINE_ITEMS
    ])
    assert profile["status"] == "completed"
    assert profile["valid_item_count"] == 8
    assert all(
        0.20 <= value <= 0.55
        for value in profile["mastery_by_kc"].values()
    )
    assert all(
        -0.75 <= value <= 0.75
        for value in profile["theta_by_kc"].values()
    )
    assert 0.95 <= profile["effective_latency_factor"] <= 1.10
    assert profile["diagnostic_claim"] is False


def test_missing_skill_is_honestly_insufficient():
    rows = [
        event_for(item, correct=True)
        for item in BASELINE_ITEMS
        if item["skill_id"] != "skill_4"
    ]
    profile = build_starter_profile(rows)
    assert profile["status"] == "insufficient"
    assert profile["data_quality"]["valid_items_by_skill"]["skill_4"] == 0


@pytest.mark.asyncio
async def test_end_to_end_resumable_submission_initializes_c4_without_overwrite(monkeypatch):
    db = AsyncMongoMockClient()["starter_baseline_test"]
    monkeypatch.setattr(routes, "get_db", lambda: db)
    student_id = "000000000000000000000031"
    student = {"starter_profile_required": True}
    session_id = "baseline-session-1"

    started = await routes.start_baseline(
        student_id,
        BaselineStartRequest(session_id=session_id),
        student=student,
    )
    assert started["status"] == "in_progress"
    assert started["next_item_index"] == 0

    # Existing evidence is never overwritten by a later baseline finalization.
    await db.knowledge_states.insert_one({
        "student_id": student_id,
        "knowledge_state": {"KC_VISUAL_IDENTIFICATION": 0.91},
        "theta_by_kc": {"KC_VISUAL_IDENTIFICATION": 1.2},
    })

    last = None
    last_request = None
    for index, item in enumerate(BASELINE_ITEMS):
        last_request = BaselineResponseRequest(
            event_id=f"baseline-event-{index}",
            session_id=session_id,
            item_id=item["item_id"],
            selected_answer_ids=item["correct_answer_ids"],
            presented_option_ids=item["option_ids"],
            total_latency_ms=item["expected_latency_ms"],
            first_touch_latency_ms=1000,
            touch_count=1,
        )
        last = await routes.submit_response(
            student_id,
            last_request,
            student=student,
        )

    assert last["status"] == "completed"
    assert last["completed_item_count"] == 8
    assert await db.baseline_item_events.count_documents({}) == 8
    stored_profile = await db.student_baseline_profiles.find_one({
        "student_id": student_id,
        "baseline_version": BASELINE_VERSION,
    })
    assert stored_profile["data_origin"] == "observed_baseline"
    state = await db.knowledge_states.find_one({"student_id": student_id})
    assert state["knowledge_state"]["KC_VISUAL_IDENTIFICATION"] == 0.91
    assert state["theta_by_kc"]["KC_VISUAL_IDENTIFICATION"] == 1.2
    assert state["starter_baseline"]["profile_status"] == "completed"
    assert state["starter_baseline"]["initialized_kcs"]

    # A response retry after the final completion is still idempotent.
    retried_final = await routes.submit_response(
        student_id, last_request, student=student
    )
    assert retried_final["status"] == "completed"
    assert await db.baseline_item_events.count_documents({}) == 8


@pytest.mark.asyncio
async def test_response_retry_is_idempotent(monkeypatch):
    db = AsyncMongoMockClient()["starter_baseline_retry_test"]
    monkeypatch.setattr(routes, "get_db", lambda: db)
    student_id = "000000000000000000000031"
    student = {"starter_profile_required": True}
    session_id = "baseline-session-2"
    await routes.start_baseline(
        student_id,
        BaselineStartRequest(session_id=session_id),
        student=student,
    )
    item = BASELINE_ITEMS[0]
    request = BaselineResponseRequest(
        event_id="same-event-id",
        session_id=session_id,
        item_id=item["item_id"],
        selected_answer_ids=item["correct_answer_ids"],
        presented_option_ids=item["option_ids"],
        total_latency_ms=item["expected_latency_ms"],
    )
    first = await routes.submit_response(student_id, request, student=student)
    retried = await routes.submit_response(student_id, request, student=student)
    assert first["next_item_index"] == 1
    assert retried["next_item_index"] == 1
    assert await db.baseline_item_events.count_documents({}) == 1


@pytest.mark.asyncio
async def test_previously_declined_profile_can_restart(monkeypatch):
    db = AsyncMongoMockClient()["starter_baseline_declined_test"]
    monkeypatch.setattr(routes, "get_db", lambda: db)
    student_id = "000000000000000000000031"
    await db.student_baseline_profiles.insert_one({
        "student_id": student_id,
        "baseline_version": BASELINE_VERSION,
        "status": "declined",
        "session_id": "baseline-session-resume",
        "next_item_index": 2,
        "completed_item_count": 2,
    })

    restarted = await routes.start_baseline(
        student_id,
        BaselineStartRequest(session_id="new-session-is-not-used"),
        student={"starter_profile_required": True},
    )

    assert restarted["status"] == "in_progress"
    assert restarted["session_id"] == "baseline-session-resume"
    assert restarted["next_item_index"] == 2


@pytest.mark.asyncio
async def test_tampered_option_pool_is_rejected_without_advancing(monkeypatch):
    db = AsyncMongoMockClient()["starter_baseline_option_test"]
    monkeypatch.setattr(routes, "get_db", lambda: db)
    student_id = "000000000000000000000031"
    student = {"starter_profile_required": True}
    session_id = "baseline-session-options"
    await routes.start_baseline(
        student_id,
        BaselineStartRequest(session_id=session_id),
        student=student,
    )
    item = BASELINE_ITEMS[0]
    with pytest.raises(HTTPException) as error:
        await routes.submit_response(
            student_id,
            BaselineResponseRequest(
                event_id="tampered-event-id",
                session_id=session_id,
                item_id=item["item_id"],
                selected_answer_ids=item["correct_answer_ids"],
                presented_option_ids=[item["correct_answer_ids"][0]],
                total_latency_ms=item["expected_latency_ms"],
            ),
            student=student,
        )
    assert error.value.status_code == 422
    profile = await db.student_baseline_profiles.find_one({
        "student_id": student_id,
        "baseline_version": BASELINE_VERSION,
    })
    assert int(profile.get("next_item_index", 0)) == 0
    assert await db.baseline_item_events.count_documents({}) == 0
