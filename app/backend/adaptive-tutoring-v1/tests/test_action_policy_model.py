"""Verify scaffold-model ranking, reproducibility, and activation safeguards."""

import json
from types import SimpleNamespace

from services.action_policy_model import (
    ActionPolicyModel,
    candidate_actions,
    context_features,
)


def telemetry(**overrides):
    values = {
        "supported_actions": ["REMOVE_OPTION", "HIGHLIGHT_OPTION", "REPLAY_INSTRUCTION"],
        "original_options_count": 4,
        "minimum_visible_options": 2,
        "total_round_latency_ms": 8000,
        "attempt_count": 1,
        "incorrect_attempt_count": 1,
        "hesitation_count": 1,
        "misclick_count": 0,
        "audio_replay_count": 0,
    }
    values.update(overrides)
    return SimpleNamespace(**values)


def test_candidates_never_include_an_unsupported_scaffold():
    actions = candidate_actions(telemetry(supported_actions=["HIGHLIGHT_OPTION"]))
    assert actions == ["RETRY_CURRENT", "SCAFFOLD_HIGHLIGHT_CORRECT"]


def test_slow_audio_requires_audio_specific_evidence():
    capabilities = ["REPLAY_INSTRUCTION", "SLOW_AUDIO"]
    first_error = candidate_actions(
        telemetry(supported_actions=capabilities, hesitation_count=0)
    )
    repeated_audio_need = candidate_actions(
        telemetry(
            supported_actions=capabilities,
            audio_replay_count=1,
            hesitation_count=0,
        )
    )
    assert "SCAFFOLD_REPLAY_INSTRUCTION" in first_error
    assert "SCAFFOLD_SLOW_AUDIO" not in first_error
    assert "SCAFFOLD_SLOW_AUDIO" in repeated_audio_need


def test_correct_prefix_lock_is_not_an_ml_candidate():
    actions = candidate_actions(
        telemetry(supported_actions=["REVEAL_FIRST_TOKEN", "LOCK_CORRECT_TOKEN"])
    )
    assert "SCAFFOLD_REVEAL_FIRST_TOKEN" in actions
    assert "SCAFFOLD_LOCK_CORRECT_TOKEN" not in actions


def test_same_sorting_task_can_receive_learner_specific_support():
    model = ActionPolicyModel()
    current = telemetry(
        supported_actions=[
            "HIGHLIGHT_DESTINATION",
            "REPLAY_INSTRUCTION",
        ],
        original_options_count=2,
        attempt_count=2,
        incorrect_attempt_count=2,
        misclick_count=2,
        hesitation_count=0,
    )

    def decision(mastery):
        features = context_features(
            telemetry=current,
            struggle_score=3,
            mastery=mastery,
            difficulty_b=-1.0,
            fatigue=0.0,
            behavioral_context={
                "first_attempt_accuracy": 0.5,
                "support_rate": 0.3,
            },
            learner_profile={},
        )
        return model.evaluate(
            baseline_action="SCAFFOLD_REPLAY_INSTRUCTION",
            telemetry=current,
            features=features,
            requested_mode="simulation_model",
            data_origin="observed",
        )["applied_action"]

    assert decision(0.3) == "SCAFFOLD_HIGHLIGHT_DESTINATION"
    assert decision(0.9) == "SCAFFOLD_REPLAY_INSTRUCTION"


def test_synthetic_model_is_shadow_only_for_live_child():
    model = ActionPolicyModel()
    features = context_features(
        telemetry=telemetry(),
        struggle_score=3,
        mastery=0.4,
        difficulty_b=0.0,
        fatigue=0.2,
        behavioral_context={"first_attempt_accuracy": 0.5, "support_rate": 0.4},
        learner_profile={},
    )
    result = model.evaluate(
        baseline_action="SCAFFOLD_REMOVE_DISTRACTOR",
        telemetry=telemetry(),
        features=features,
        requested_mode="model",
        data_origin="observed",
    )
    assert result["model_validation_status"] == "synthetic_only"
    assert result["applied_action"] == "SCAFFOLD_REMOVE_DISTRACTOR"
    assert result["fallback_reason"] == "SYNTHETIC_OR_UNVALIDATED_MODEL_SHADOW_ONLY"
    assert set(result["predicted_next_independent_success"]) == set(result["candidate_actions"])


def test_explicit_simulation_model_executes_only_advertised_action():
    model = ActionPolicyModel()
    audio_telemetry = telemetry(
        supported_actions=[
            "HIGHLIGHT_OPTION",
            "REPLAY_INSTRUCTION",
            "SLOW_AUDIO",
        ],
        hesitation_count=4,
    )
    features = context_features(
        telemetry=audio_telemetry,
        struggle_score=3,
        mastery=0.4,
        difficulty_b=0.0,
        fatigue=0.2,
        behavioral_context={"first_attempt_accuracy": 0.5, "support_rate": 0.4},
        learner_profile={},
    )
    result = model.evaluate(
        baseline_action="SCAFFOLD_HIGHLIGHT_CORRECT",
        telemetry=audio_telemetry,
        features=features,
        requested_mode="simulation_model",
        data_origin="observed",
    )
    assert result["controls_live_adaptation"] is True
    assert result["execution_source"] == "synthetic_model_simulation"
    assert result["fallback_reason"] is None
    assert result["applied_action"] in result["candidate_actions"]
    assert result["applied_action"] in {
        "RETRY_CURRENT",
        "SCAFFOLD_HIGHLIGHT_CORRECT",
        "SCAFFOLD_REPLAY_INSTRUCTION",
        "SCAFFOLD_SLOW_AUDIO",
    }


def test_simulation_experiment_assignment_is_stable_and_auditable():
    model = ActionPolicyModel()
    current = telemetry(supported_actions=["HIGHLIGHT_OPTION"])
    features = context_features(
        telemetry=current,
        struggle_score=2,
        mastery=0.5,
        difficulty_b=0.0,
        fatigue=0.1,
        behavioral_context={},
        learner_profile={},
    )
    first = model.evaluate(
        baseline_action="SCAFFOLD_HIGHLIGHT_CORRECT",
        telemetry=current,
        features=features,
        requested_mode="simulation_experiment",
        data_origin="observed",
        assignment_key="student-1:session-1",
    )
    second = model.evaluate(
        baseline_action="SCAFFOLD_HIGHLIGHT_CORRECT",
        telemetry=current,
        features=features,
        requested_mode="simulation_experiment",
        data_origin="observed",
        assignment_key="student-1:session-1",
    )
    assert first["experiment_arm"] == second["experiment_arm"]
    assert first["policy_mode"] == second["policy_mode"]
    assert first["assignment_probability"] == 0.5
    assert first["assignment_mechanism"] == (
        "sha256_stable_50_50_simulation_experiment"
    )


def test_observed_model_requires_explicit_activation_flag(tmp_path):
    source = ActionPolicyModel().artifact
    artifact = dict(source)
    artifact["validation_status"] = "pilot_approved"
    artifact["activation_allowed"] = False
    path = tmp_path / "not-activated.json"
    path.write_text(json.dumps(artifact), encoding="utf-8")
    model = ActionPolicyModel(path)
    current = telemetry(supported_actions=["HIGHLIGHT_OPTION"])
    features = context_features(
        telemetry=current,
        struggle_score=2,
        mastery=0.5,
        difficulty_b=0.0,
        fatigue=0.1,
        behavioral_context={},
        learner_profile={},
    )

    result = model.evaluate(
        baseline_action="SCAFFOLD_HIGHLIGHT_CORRECT",
        telemetry=current,
        features=features,
        requested_mode="model",
        data_origin="observed",
    )

    assert result["controls_live_adaptation"] is False
    assert result["model_activation_allowed"] is False
    assert result["fallback_reason"] == "SYNTHETIC_OR_UNVALIDATED_MODEL_SHADOW_ONLY"
