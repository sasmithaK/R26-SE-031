from services.bkt_calibration import fit_bkt_by_kc
from services.bkt_engine import BKTEngine


def test_bkt_calibration_requires_real_evidence_thresholds():
    result = fit_bkt_by_kc([
        {
            "student_id": "one",
            "knowledge_component_id": "KC_TEST",
            "timestamp": "1",
            "is_correct": True,
        },
    ], min_kc_responses=10, min_students=5)

    assert result.parameters == {}


def test_bkt_calibration_fits_valid_bounded_parameters_deterministically():
    responses = []
    for student in range(30):
        # A learnable pattern: early errors followed by later successes.
        for order, correct in enumerate((False, False, True, True, True)):
            responses.append({
                "student_id": f"student-{student:02d}",
                "knowledge_component_id": "KC_TEST",
                "timestamp": f"{order:02d}",
                "is_correct": correct,
            })

    first = fit_bkt_by_kc(
        responses, min_kc_responses=100, min_students=20
    )
    second = fit_bkt_by_kc(
        responses, min_kc_responses=100, min_students=20
    )

    assert first == second
    params = first.parameters["KC_TEST"]
    assert all(0.0 < value < 1.0 for value in params)
    assert params[2] + params[3] < 0.5
    assert first.observation_counts["KC_TEST"] == 150
    assert first.student_counts["KC_TEST"] == 30
    assert first.validation_log_loss["KC_TEST"] < 1.0


def test_runtime_accepts_only_valid_active_registry_parameters():
    engine = BKTEngine()
    assert engine.apply_calibrated_parameters(
        "KC_TEST",
        {
            "p_initial": 0.25,
            "p_transition": 0.12,
            "p_guess": 0.15,
            "p_slip": 0.1,
        },
        model_version="bkt_test_v1",
        calibrated_at="2026-10-07T00:00:00Z",
    )
    assert engine.priors["KC_TEST"] == (0.25, 0.12, 0.15, 0.1)
    evidence = engine.get_model_evidence("KC_TEST")
    assert evidence["model_version"] == "bkt_test_v1"
    assert evidence["calibration_status"] == "empirically_calibrated"
    assert evidence["parameters"]["p_guess"] == 0.15

    assert not engine.apply_calibrated_parameters("KC_BAD", {
        "p_initial": 0.25,
        "p_transition": 0.12,
        "p_guess": 0.4,
        "p_slip": 0.2,
    })
    assert "KC_BAD" not in engine.priors


def test_saturated_legacy_mastery_can_recover_after_an_incorrect_attempt():
    engine = BKTEngine()

    after_error = engine.update_knowledge_state(
        1.0, "KC_VISUAL_IDENTIFICATION", False
    )

    assert 0.0 < after_error < engine.MASTERY_CEILING


def test_bkt_never_returns_an_absorbing_probability():
    engine = BKTEngine()

    after_success = engine.update_knowledge_state(
        1.0, "KC_VISUAL_IDENTIFICATION", True
    )
    after_failure = engine.update_knowledge_state(
        0.0, "KC_VISUAL_IDENTIFICATION", False
    )

    assert engine.MASTERY_FLOOR <= after_failure
    assert after_success <= engine.MASTERY_CEILING
