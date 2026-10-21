from datetime import datetime, timedelta, timezone

import pytest
from mongomock_motor import AsyncMongoMockClient

from services.dashboard_data import letter_practice_progress


@pytest.mark.asyncio
async def test_letter_progress_keeps_unclear_attempts_separate_from_matches():
    db = AsyncMongoMockClient()["letter_dashboard_test"]
    now = datetime.now(timezone.utc)
    await db.speech_features.insert_many([
        {
            "student_id": "student-a",
            "skill_id": "skill_sinhala_vowels",
            "item_id": "SVOWA1R01",
            "session_id": "session-1",
            "created_at": now,
            "recording_quality": "valid",
            "recognized_text": "අ",
            "exact_match": True,
            "measurement_status": "valid",
            "task_kind": "letter_pronunciation",
        },
        {
            "student_id": "student-a",
            "skill_id": "skill_sinhala_vowels",
            "item_id": "SVOWA1R01",
            "session_id": "session-1",
            "created_at": now - timedelta(seconds=3),
            "recording_quality": "retry_required",
            "recognized_text": "",
            "exact_match": None,
            "measurement_status": "retry_required",
            "task_kind": "letter_pronunciation",
        },
        {
            "student_id": "student-b",
            "skill_id": "skill_sinhala_vowels",
            "item_id": "SVOWA1R01",
            "session_id": "other-child-session",
            "created_at": now,
            "recording_quality": "valid",
            "recognized_text": "අ",
            "exact_match": True,
            "measurement_status": "valid",
        },
    ])

    progress = await letter_practice_progress(db, "student-a", days=30)
    vowels = next(group for group in progress if group["skill_id"] == "skill_sinhala_vowels")
    first_letter = vowels["letters"][0]

    assert len(vowels["letters"]) == 12
    assert first_letter["attempts"] == 2
    assert first_letter["clear_attempts"] == 1
    assert first_letter["matched_attempts"] == 1
    assert first_letter["sessions"] == 1
