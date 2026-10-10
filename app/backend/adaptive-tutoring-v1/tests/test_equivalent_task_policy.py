from services.equivalent_task_policy import EquivalentTaskPolicy
from services.policy_engine import policy_engine
from schemas import TelemetryData


def decide(item_id: str, quality: str, state=None):
    return EquivalentTaskPolicy().get_next_action(
        activity_id="3.1",
        current_item_id=item_id,
        response_quality=quality,
        current_b=0.5,
        state={} if state is None else state,
        policy_reason=[f"RESPONSE_QUALITY: {quality}"],
    )


def test_assisted_core_uses_unseen_reduced_load_remediation():
    action = decide("S3A1R03", "ASSISTED_SUCCESS")
    assert action["next_item"] == "S3A1R03V1"
    assert action["next_phase"] == "REMEDIATION"
    assert action["target_difficulty"] == 0.0
    assert action["difficulty_direction"] == "EASIER"


def test_floor_task_skips_invalid_easy_step_and_uses_one_equivalent_retry():
    action = EquivalentTaskPolicy().get_next_action(
        activity_id="3.1",
        current_item_id="S3A1R01",
        response_quality="ASSISTED_SUCCESS",
        current_b=-1.0,
        state={},
        policy_reason=["RESPONSE_QUALITY: ASSISTED_SUCCESS"],
        has_reduced_remediation=False,
    )
    assert action["next_item"] == "S3A1R01V2"
    assert action["next_phase"] == "CONFIRMATION"
    assert "NO_VALID_LOWER_LOAD_ITEM" in action["policy_reason"]


def test_authored_floor_remediation_precedes_independent_confirmation():
    action = EquivalentTaskPolicy().get_next_action(
        activity_id="2.4",
        current_item_id="S2A4R01",
        response_quality="ASSISTED_SUCCESS",
        current_b=-1.0,
        state={},
        policy_reason=["RESPONSE_QUALITY: ASSISTED_SUCCESS"],
        has_reduced_remediation=False,
        has_floor_remediation=True,
    )
    assert action["next_item"] == "S2A4R01V1"
    assert action["next_phase"] == "REMEDIATION"
    assert action["target_difficulty"] == -1.0
    assert action["difficulty_direction"] == "MAINTAIN"
    assert "UNSEEN_FLOOR_REMEDIATION_REQUIRED" in action["policy_reason"]


def test_remediation_always_moves_to_distinct_confirmation():
    state = {"next_phase": "REMEDIATION"}
    action = decide("S3A1R03V1", "ASSISTED_SUCCESS", state)
    assert action["next_item"] == "S3A1R03V2"
    assert action["next_phase"] == "CONFIRMATION"
    assert action["confirmation_required"] is True


def test_clean_confirmation_returns_to_normal_core_selection():
    state = {"next_phase": "CONFIRMATION"}
    action = decide("S3A1R03V2", "CLEAN_SUCCESS", state)
    assert action["decision"] == "CONTINUE"
    assert action["next_item"] == ""
    assert state["next_phase"] == "CORE"
    assert "remediation_origin_item_id" not in state


def test_assisted_confirmation_is_bounded_and_flags_review():
    state = {"next_phase": "CONFIRMATION"}
    action = decide("S3A1R03V2", "ASSISTED_SUCCESS", state)
    assert action["decision"] == "CONTINUE"
    assert state["teacher_review_required"] is True
    assert state["teacher_review_item_id"] == "S3A1R03"


def test_struggled_but_independent_core_skips_remediation():
    action = decide("S3A1R03", "STRUGGLED_SUCCESS")
    assert action["next_item"] == "S3A1R03V2"
    assert action["next_phase"] == "CONFIRMATION"


def test_grade_one_normal_thinking_time_remains_clean_success():
    telemetry = TelemetryData(
        first_touch_latency_ms=4905,
        total_round_latency_ms=8871,
        hesitation_count=1,
        misclick_count=0,
        audio_replay_count=0,
        attempt_count=1,
        incorrect_attempt_count=0,
        first_attempt_correct=True,
    )
    quality, _, _, _ = policy_engine.classify_response(True, telemetry, "1.2")
    assert quality == "CLEAN_SUCCESS"


def test_wrong_first_attempt_is_assisted_even_when_final_answer_is_correct():
    telemetry = TelemetryData(
        total_round_latency_ms=6000,
        attempt_count=2,
        incorrect_attempt_count=1,
        first_attempt_correct=False,
    )
    quality, _, _, _ = policy_engine.classify_response(True, telemetry, "1.1")
    assert quality == "ASSISTED_SUCCESS"
