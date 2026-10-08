import copy

import pytest
from bson import ObjectId

# Re-use the payload shape that frontend sends
MOCK_TELEMETRY_PAYLOAD = {
    "student_id": str(ObjectId()),
    "session_id": "session_test_123",
    "started_at": "2026-08-30T09:58:00Z",
    "completed_at": "2026-08-30T10:00:00Z",
    "session_duration_seconds": 120,
    "device_metrics": {"os": "android", "model": "Pixel 6"},
    "events": [
        {
            "event_id": "test_evt_1",
            "activity_name": "Letter Matching",
            "round_number": 1,
            "is_correct": False,
            "score": 0,
            "timestamp": "2026-08-30T10:00:00Z",
            "first_touch_latency_ms": 1200,
            "total_round_latency_ms": 4500,
            "misclick_count": 0,
            "hesitation_count": 0,
            "audio_replay_count": 0,
            "correction_count": 0,
            "hint_count": 0,
            "is_abandoned": False,
            "touch_path": [],
            "attempt_count": 3,
            "incorrect_attempt_count": 2,
            "first_attempt_correct": False,
            "final_correct": True,
            "time_to_first_response_ms": 1200,
            "time_to_correct_ms": 4500,
            "skill_id": "skill_2",
            "activity_id": "skill2_act1_odd_one_out",
            "item_id": "S2A1R01",
            "item_version": 1,
            "knowledge_component_id": "KC_AKSHARA_IDENTITY",
            "prompt_modality": "visual",
            "response_modality": "tap",
            "research_role": "primary",
            "item_role": "REMEDIATION",
            "equivalent_group_id": "S2A1R01",
            "response_load_relation": "reduced",
            "difficulty_label": "easy",
            "difficulty_b": 0.2,
            "is_anchor": False,
            "targets": ["A", "A", "A", "B"],
            "selected_answers": ["A", "A", "B"],
            "error_type": "unknown_error",
            "phase": "COMPLETE",
            "scaffold_level_used": 2,
            "scaffold_applications": [
                {"scaffold_level": 2, "action": "disable_options"}
            ]
        }
    ]
}

@pytest.mark.asyncio
async def test_submit_telemetry(client, mock_db, mock_user):
    student_id = MOCK_TELEMETRY_PAYLOAD["student_id"]
    await mock_db.students.insert_one({"_id": ObjectId(student_id), "parent_id": mock_user["_id"]})
    
    response = client.post("/api/v1/auth/telemetry", json=MOCK_TELEMETRY_PAYLOAD)
    if response.status_code != 201:
        print("PAYLOAD ERROR:", response.json())
    assert response.status_code == 201
    data = response.json()
    assert "message" in data


@pytest.mark.asyncio
async def test_retried_session_is_idempotent(client, mock_db, mock_user):
    student_id = MOCK_TELEMETRY_PAYLOAD["student_id"]
    await mock_db.students.insert_one(
        {"_id": ObjectId(student_id), "parent_id": mock_user["_id"]}
    )

    first = client.post("/api/v1/auth/telemetry", json=MOCK_TELEMETRY_PAYLOAD)
    second = client.post("/api/v1/auth/telemetry", json=MOCK_TELEMETRY_PAYLOAD)

    assert first.status_code == 201
    assert second.status_code == 201
    assert await mock_db.telemetry_events.count_documents(
        {"event_id": "test_evt_1"}
    ) == 1
    stored = await mock_db.telemetry_events.find_one({"event_id": "test_evt_1"})
    assert stored["ingestion_key"] == f"{student_id}:test_evt_1"
    assert stored["item_role"] == "REMEDIATION"
    assert stored["equivalent_group_id"] == "S2A1R01"
    assert stored["response_load_relation"] == "reduced"
    assert stored["phase"] == "COMPLETE"
    assert stored["scaffold_level_used"] == 2
    assert stored["scaffold_applications"][0]["scaffold_level"] == 2
    session = await mock_db.telemetry_sessions.find_one(
        {"session_id": "session_test_123"}
    )
    assert session["skill_id"] == "skill_2"
    assert session["activity_id"] == "skill2_act1_odd_one_out"
    assert session["started_at"] == "2026-08-30T09:58:00Z"
    assert session["completed_at"] == "2026-08-30T10:00:00Z"
    assert session["session_number"] == 1
    summary = await mock_db.session_summaries.find_one(
        {"session_id": "session_test_123"}
    )
    assert summary["started_at"] == "2026-08-30T09:58:00+00:00"
    assert summary["completed_at"] == "2026-08-30T10:00:00+00:00"


@pytest.mark.asyncio
async def test_session_numbers_advance_and_retry_keeps_original_number(
    client, mock_db, mock_user
):
    student_id = MOCK_TELEMETRY_PAYLOAD["student_id"]
    await mock_db.students.insert_one(
        {"_id": ObjectId(student_id), "parent_id": mock_user["_id"]}
    )

    first = client.post("/api/v1/auth/telemetry", json=MOCK_TELEMETRY_PAYLOAD)
    retry = client.post("/api/v1/auth/telemetry", json=MOCK_TELEMETRY_PAYLOAD)
    second_payload = copy.deepcopy(MOCK_TELEMETRY_PAYLOAD)
    second_payload["session_id"] = "session_test_124"
    # Simulate the legacy mobile client that incorrectly labelled every run 1.
    second_payload["session_number"] = 1
    second_payload["events"][0]["event_id"] = "test_evt_2"
    second = client.post("/api/v1/auth/telemetry", json=second_payload)

    assert first.status_code == 201
    assert retry.status_code == 201
    assert second.status_code == 201
    stored_first = await mock_db.telemetry_sessions.find_one(
        {"session_id": "session_test_123"}
    )
    stored_second = await mock_db.telemetry_sessions.find_one(
        {"session_id": "session_test_124"}
    )
    assert stored_first["session_number"] == 1
    assert stored_second["session_number"] == 2


@pytest.mark.asyncio
async def test_canonical_abandoned_retry_is_persisted_and_summarized(
    client, mock_db, mock_user
):
    student_id = MOCK_TELEMETRY_PAYLOAD["student_id"]
    await mock_db.students.insert_one(
        {"_id": ObjectId(student_id), "parent_id": mock_user["_id"]}
    )
    payload = copy.deepcopy(MOCK_TELEMETRY_PAYLOAD)
    payload["session_id"] = "skill1-retry-abandoned"
    payload["skill_id"] = "skill_1"
    payload["activity_id"] = "act_1"
    event = payload["events"][0]
    event.update({
        "event_id": "skill1-retry-abandoned:S1A1R01:abandoned",
        "skill_id": "skill_1",
        "activity_id": "act_1",
        "item_id": "S1A1R01",
        "item_role": "CORE",
        "phase": "ABANDONED",
        "is_correct": False,
        "final_correct": False,
        "first_attempt_correct": None,
        "is_abandoned": True,
        "error_type": "abandoned_before_completion",
    })

    response = client.post("/api/v1/auth/telemetry", json=payload)

    assert response.status_code == 201
    stored = await mock_db.telemetry_events.find_one({"event_id": event["event_id"]})
    summary = await mock_db.session_summaries.find_one(
        {"session_id": "skill1-retry-abandoned"}
    )
    assert stored["skill_id"] == "skill_1"
    assert stored["activity_id"] == "act_1"
    assert stored["item_id"] == "S1A1R01"
    assert stored["phase"] == "ABANDONED"
    assert summary["overall"]["abandonment_rate"] == 1.0
    assert summary["overall"]["eventual_completion_rate"] == 0.0


@pytest.mark.asyncio
async def test_assisted_success_persists_both_accuracy_meanings(
    client, mock_db, mock_user
):
    student_id = MOCK_TELEMETRY_PAYLOAD["student_id"]
    await mock_db.students.insert_one(
        {"_id": ObjectId(student_id), "parent_id": mock_user["_id"]}
    )
    payload = copy.deepcopy(MOCK_TELEMETRY_PAYLOAD)
    payload["session_id"] = "skill1-assisted-success"
    payload["skill_id"] = "skill_1"
    payload["activity_id"] = "act_1"
    event = payload["events"][0]
    event.update({
        "event_id": "skill1-assisted-success:S1A1R01:complete",
        "skill_id": "skill_1",
        "activity_id": "act_1",
        "item_id": "S1A1R01",
        "is_correct": True,
        "final_correct": True,
        "first_attempt_correct": False,
    })

    response = client.post("/api/v1/auth/telemetry", json=payload)

    assert response.status_code == 201
    summary = await mock_db.session_summaries.find_one(
        {"session_id": "skill1-assisted-success"}
    )
    behavioral = await mock_db.behavioral_features.find_one(
        {"session_id": "skill1-assisted-success"}
    )
    assert summary["overall"]["accuracy"] == 0.0
    assert summary["overall"]["eventual_completion_rate"] == 1.0
    assert behavioral["behavior"]["independent_accuracy"] == 0.0
    assert behavioral["behavior"]["eventual_completion_accuracy"] == 1.0
    # Preserved for compatibility with the already trained C1 feature schema.
    assert behavioral["behavior"]["accuracy"] == 1.0

@pytest.mark.asyncio
async def test_get_comp2_analytics(client, mock_db, mock_user):
    student_id = MOCK_TELEMETRY_PAYLOAD["student_id"]
    await mock_db.students.insert_one({"_id": ObjectId(student_id), "parent_id": mock_user["_id"]})
    
    # First, insert data
    client.post("/api/v1/auth/telemetry", json=MOCK_TELEMETRY_PAYLOAD)
    
    student_id = MOCK_TELEMETRY_PAYLOAD["student_id"]
    response = client.get(f"/api/v1/auth/telemetry/{student_id}/comp2")
    
    assert response.status_code == 200
    data = response.json()
    assert data["student_id"] == student_id
    
    # Verify that the mathematical feature vector is present
    features = data["visual_feature_vector"]
    assert "dimensionless_jerk" in features
    assert "orthographic_confusion_index" in features
    assert "visual_dyslexia_risk_score" in features
    
@pytest.mark.asyncio
async def test_get_comp2_analytics_insufficient_data(client, mock_db, mock_user):
    student_id = MOCK_TELEMETRY_PAYLOAD["student_id"]
    await mock_db.students.insert_one({"_id": ObjectId(student_id), "parent_id": mock_user["_id"]})
    
    # We use a completely new student ID here that has no data
    response = client.get(f"/api/v1/auth/telemetry/{student_id}/comp2")
    
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "insufficient_data"

@pytest.mark.asyncio
async def test_generate_pdf_report(client, mock_db, mock_user):
    student_id = MOCK_TELEMETRY_PAYLOAD["student_id"]
    await mock_db.students.insert_one({"_id": ObjectId(student_id), "parent_id": mock_user["_id"]})
    
    # Ensure there's some data for the report
    client.post("/api/v1/auth/telemetry", json=MOCK_TELEMETRY_PAYLOAD)
    
    # Generate the cognitive profile by calling /analytics
    client.get(f"/api/v1/auth/telemetry/{student_id}/analytics")
    
    response = client.get(f"/api/v1/auth/telemetry/{student_id}/report/pdf")
    
    assert response.status_code == 200
    assert response.headers["content-type"] == "application/pdf"
    assert response.headers["content-disposition"].startswith("attachment")
    
    # Should return PDF binary
    assert response.content.startswith(b"%PDF")
