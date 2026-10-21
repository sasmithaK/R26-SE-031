"""Authenticated Starter Learning Profile endpoints."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import List, Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from services.dashboard_access import require_dashboard_access
from services.starter_baseline import (
    BASELINE_ITEMS,
    BASELINE_VERSION,
    ITEMS_BY_ID,
    build_starter_profile,
    response_is_valid,
    score_answer,
)
from shared.database import get_db


router = APIRouter(
    prefix="/api/v1/learning/starter-baseline",
    tags=["Starter Learning Profile"],
)


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


class BaselineStartRequest(BaseModel):
    session_id: str = Field(min_length=8, max_length=120)


class BaselineResponseRequest(BaseModel):
    event_id: str = Field(min_length=8, max_length=180)
    session_id: str = Field(min_length=8, max_length=120)
    item_id: str
    selected_answer_ids: List[str] = Field(default_factory=list, max_length=8)
    presented_option_ids: List[str] = Field(max_length=8)
    response_status: Literal["answered", "skipped"] = "answered"
    first_touch_latency_ms: int = Field(default=0, ge=0, le=300000)
    total_latency_ms: int = Field(ge=0, le=300000)
    audio_replay_count: int = Field(default=0, ge=0, le=20)
    misclick_count: int = Field(default=0, ge=0, le=100)
    hesitation_count: int = Field(default=0, ge=0, le=20)
    touch_count: int = Field(default=0, ge=0, le=10000)


def public_status(profile, *, required: bool) -> dict:
    if not profile:
        return {
            "baseline_version": BASELINE_VERSION,
            "status": "not_started" if required else "not_required",
            "required": required,
            "session_id": None,
            "next_item_index": 0,
            "completed_item_count": 0,
            "total_item_count": len(BASELINE_ITEMS),
            "data_quality": None,
        }
    return {
        "baseline_version": profile.get("baseline_version", BASELINE_VERSION),
        "status": profile.get("status", "not_started"),
        "required": required,
        "session_id": profile.get("session_id"),
        "next_item_index": int(profile.get("next_item_index", 0)),
        "completed_item_count": int(profile.get("completed_item_count", 0)),
        "total_item_count": len(BASELINE_ITEMS),
        "data_quality": profile.get("data_quality"),
    }


async def _profile(db, student_id: str):
    return await db.student_baseline_profiles.find_one({
        "student_id": student_id,
        "baseline_version": BASELINE_VERSION,
    })


async def _finalize(db, student_id: str, session_id: str) -> dict:
    events = await db.baseline_item_events.find({
        "student_id": student_id,
        "baseline_version": BASELINE_VERSION,
        "session_id": session_id,
    }).sort("item_index", 1).to_list(length=len(BASELINE_ITEMS))
    derived = build_starter_profile(events)
    completed_at = utc_now()
    derived.update({
        "student_id": student_id,
        "session_id": session_id,
        "completed_at": completed_at,
        "completed_item_count": len(events),
        "next_item_index": len(BASELINE_ITEMS),
    })
    await db.student_baseline_profiles.update_one(
        {"student_id": student_id, "baseline_version": BASELINE_VERSION},
        {"$set": derived},
        upsert=True,
    )

    # A low-quality run is retained honestly, but it must not initialize C4.
    if derived["status"] == "completed":
        state = await db.knowledge_states.find_one({"student_id": student_id}) or {}
        knowledge = dict(state.get("knowledge_state") or {})
        theta_by_kc = dict(state.get("theta_by_kc") or {})
        initialized = []
        for kc, value in derived["mastery_by_kc"].items():
            if kc not in knowledge:
                knowledge[kc] = value
                initialized.append(kc)
        for kc, value in derived["theta_by_kc"].items():
            if kc not in theta_by_kc:
                theta_by_kc[kc] = value
        theta_values = list(derived["theta_by_kc"].values())
        overall_theta = (
            round(sum(theta_values) / len(theta_values), 4)
            if theta_values else 0.0
        )
        starter_state = {
            "baseline_version": BASELINE_VERSION,
            "profile_status": derived["status"],
            "initialized_kcs": initialized,
            "effective_latency_factor": derived["effective_latency_factor"],
            "speed_factor": derived["speed_factor"],
            "audio_replay_tendency": derived["audio_replay_tendency"],
            "sequence_accuracy": derived["sequence_accuracy"],
            "skill_profiles": derived["skill_profiles"],
            "data_origin": "observed_baseline",
            "initialized_at": completed_at,
        }
        update = {
            "knowledge_state": knowledge,
            "theta_by_kc": theta_by_kc,
            "starter_baseline": starter_state,
            "last_updated": completed_at,
        }
        if "theta_estimate" not in state:
            update["theta_estimate"] = overall_theta
        await db.knowledge_states.update_one(
            {"student_id": student_id}, {"$set": update}, upsert=True
        )
    return derived


@router.get("/{student_id}")
async def get_status(
    student_id: str,
    student=Depends(require_dashboard_access),
):
    db = get_db()
    profile = await _profile(db, student_id)
    required = bool(student.get("starter_profile_required", False))
    return public_status(profile, required=required)


@router.post("/{student_id}/start")
async def start_baseline(
    student_id: str,
    request: BaselineStartRequest,
    student=Depends(require_dashboard_access),
):
    db = get_db()
    profile = await _profile(db, student_id)
    if profile and profile.get("status") in {"completed", "insufficient"}:
        return public_status(
            profile, required=bool(student.get("starter_profile_required", False))
        )
    now = utc_now()
    await db.student_baseline_profiles.update_one(
        {"student_id": student_id, "baseline_version": BASELINE_VERSION},
        {
            "$setOnInsert": {
                "student_id": student_id,
                "baseline_version": BASELINE_VERSION,
                "created_at": now,
                "data_origin": "observed_baseline",
                "research_role": "baseline_probe",
            },
            "$set": {
                "status": "in_progress",
                "session_id": (profile or {}).get("session_id") or request.session_id,
                "updated_at": now,
            },
        },
        upsert=True,
    )
    profile = await _profile(db, student_id)
    return public_status(profile, required=True)


@router.post("/{student_id}/response")
async def submit_response(
    student_id: str,
    request: BaselineResponseRequest,
    student=Depends(require_dashboard_access),
):
    del student
    db = get_db()
    profile = await _profile(db, student_id)
    if not profile:
        raise HTTPException(409, "Starter profile is not in progress")
    if request.session_id != profile.get("session_id"):
        raise HTTPException(409, "Starter profile session does not match")

    duplicate = await db.baseline_item_events.find_one({
        "student_id": student_id,
        "baseline_version": BASELINE_VERSION,
        "event_id": request.event_id,
    })
    if duplicate:
        latest = await _profile(db, student_id)
        return public_status(latest, required=True)
    if profile.get("status") != "in_progress":
        raise HTTPException(409, "Starter profile is not in progress")

    next_index = int(profile.get("next_item_index", 0))
    if next_index >= len(BASELINE_ITEMS):
        latest = await _finalize(db, student_id, request.session_id)
        return public_status(latest, required=True)
    expected = BASELINE_ITEMS[next_index]
    if request.item_id != expected["item_id"]:
        raise HTTPException(
            409,
            f"Expected baseline item {expected['item_id']}, got {request.item_id}",
        )

    allowed_options = list(expected["option_ids"])
    if (
        len(request.presented_option_ids) != len(allowed_options)
        or set(request.presented_option_ids) != set(allowed_options)
    ):
        raise HTTPException(422, "Presented baseline options do not match the item")
    if (
        len(set(request.selected_answer_ids)) != len(request.selected_answer_ids)
        or not set(request.selected_answer_ids).issubset(set(allowed_options))
    ):
        raise HTTPException(422, "Selected baseline answers are invalid")

    is_correct = (
        request.response_status == "answered"
        and score_answer(expected, request.selected_answer_ids)
    )
    now = utc_now()
    event = {
        "schema_version": "1.0",
        "event_id": request.event_id,
        "student_id": student_id,
        "session_id": request.session_id,
        "baseline_version": BASELINE_VERSION,
        "item_index": next_index,
        "item_id": expected["item_id"],
        "skill_id": expected["skill_id"],
        "knowledge_component_id": expected["knowledge_component_id"],
        "difficulty_b": expected["difficulty_b"],
        "expected_latency_ms": expected["expected_latency_ms"],
        "prompt_modality": expected["prompt_modality"],
        "response_modality": expected["response_modality"],
        "selected_answer_ids": request.selected_answer_ids,
        "presented_option_ids": request.presented_option_ids,
        "target_ids": expected["correct_answer_ids"],
        "is_correct": is_correct,
        "response_status": request.response_status,
        "first_touch_latency_ms": request.first_touch_latency_ms,
        "total_latency_ms": request.total_latency_ms,
        "audio_replay_count": request.audio_replay_count,
        "misclick_count": request.misclick_count,
        "hesitation_count": request.hesitation_count,
        "touch_count": request.touch_count,
        "scaffold_level_used": 0,
        "scaffold_applications": [],
        "remediation_used": False,
        "confirmation_used": False,
        "data_origin": "observed_baseline",
        "dataset_id": f"baseline:{student_id}:{request.session_id}",
        "research_role": "baseline_probe",
        "validation_status": "operational_observation",
        "calibration_eligible": False,
        "recorded_at": now,
    }
    event["is_valid"] = response_is_valid(event)
    await db.baseline_item_events.insert_one(event)
    next_index += 1
    await db.student_baseline_profiles.update_one(
        {"student_id": student_id, "baseline_version": BASELINE_VERSION},
        {"$set": {
            "completed_item_count": next_index,
            "next_item_index": next_index,
            "updated_at": now,
        }},
    )
    if next_index == len(BASELINE_ITEMS):
        profile = await _finalize(db, student_id, request.session_id)
    else:
        profile = await _profile(db, student_id)
    return public_status(profile, required=True)
