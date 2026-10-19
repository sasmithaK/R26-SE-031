"""Verify historical scaffold decisions link to their observable outcomes."""

from datetime import datetime, timezone

from research.backfill_policy_outcomes import build_backfill_updates


def test_backfill_uses_next_response_and_independent_confirmation_only():
    policy_time = datetime(2026, 10, 13, 10, 0, 1, tzinfo=timezone.utc)
    policies = [{
        "_id": "p1", "student_id": "s", "session_id": "session",
        "event_id": "attempt-1", "timestamp": policy_time,
        "item_id": "S1A1R02",
    }]
    telemetry = [
        {
            "student_id": "s", "session_id": "session", "item_id": "S1A1R02",
            "event_id": "attempt-1", "phase": "ATTEMPT", "is_correct": False,
            "timestamp": "2026-10-13T10:00:01.100000Z",
        },
        {
            "student_id": "s", "session_id": "session", "item_id": "S1A1R02",
            "event_id": "attempt-2", "phase": "ATTEMPT", "is_correct": False,
            "timestamp": "2026-10-13T10:00:02Z",
        },
    ]
    decisions = [{
        "student_id": "s", "session_id": "session", "event_id": "confirm",
        "timestamp": "2026-10-13T10:00:05Z", "current_item": "S1A1R02V2",
        "item_role": "CONFIRMATION", "equivalent_group_id": "S1A1R02",
        "learning_observation_correct": True, "is_correct": True,
        "response_quality": "CLEAN_SUCCESS",
    }]

    updates = build_backfill_updates(policies, telemetry, decisions)

    assert len(updates) == 1
    fields = updates[0]["set"]
    assert fields["proximal_response_event_id"] == "attempt-2"
    assert fields["proximal_next_response_correct"] is False
    assert fields["outcome_item_id"] == "S1A1R02V2"
    assert fields["outcome_first_attempt_correct"] is True
    assert fields["equivalent_group_id"] == "S1A1R02"
