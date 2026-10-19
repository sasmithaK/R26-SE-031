"""Auditable ML action ranking with a deterministic production safety gate.

The model estimates the probability that the *next* response will be an
independent success for each scaffold action supported by the current screen.
It never invents content or option IDs. Synthetic-only artifacts are allowed
to control an explicitly labelled simulation run, but are not allowed to
control the ordinary observed-child ``model`` mode.
"""

from __future__ import annotations

import json
import hashlib
import math
import os
from pathlib import Path
from typing import Any, Dict, Iterable, List


APPROVED_ACTIVE_STATUSES = {"pilot_approved", "validated_observed"}
DEFAULT_MODEL_PATH = Path(__file__).resolve().parent.parent / "models" / "c4_action_outcome_v1.json"

# Some activities expose a more precise semantic action than the original
# synthetic experiment. These aliases reuse the closest fitted outcome model
# while keeping the rendered command truthful and activity-specific.
MODEL_ACTION_ALIASES = {
    "SCAFFOLD_DISABLE_DISTRACTOR": "SCAFFOLD_REMOVE_DISTRACTOR",
    "SCAFFOLD_HIGHLIGHT_DESTINATION": "SCAFFOLD_HIGHLIGHT_CORRECT",
}

# Direct answer-revealing help has a larger instructional cost. Ranking by
# expected success minus this small cost makes the model choose the least
# intrusive action when two actions are predicted to work similarly.
ACTION_COSTS = {
    "RETRY_CURRENT": 0.00,
    "SCAFFOLD_REPLAY_INSTRUCTION": 0.015,
    "SCAFFOLD_SLOW_AUDIO": 0.02,
    "SCAFFOLD_REMOVE_DISTRACTOR": 0.045,
    "SCAFFOLD_DISABLE_DISTRACTOR": 0.045,
    "SCAFFOLD_HIGHLIGHT_DESTINATION": 0.07,
    "SCAFFOLD_REVEAL_FIRST_TOKEN": 0.09,
    "SCAFFOLD_HIGHLIGHT_CORRECT": 0.11,
}


def _bounded(value: Any, low: float = 0.0, high: float = 1.0) -> float:
    """Convert an input to float and clamp it to its valid model range."""
    try:
        return max(low, min(high, float(value)))
    except (TypeError, ValueError):
        return low


def candidate_actions(telemetry: Any) -> List[str]:
    """Return only scaffold actions the current activity can safely render."""
    capabilities = set(getattr(telemetry, "supported_actions", None) or [])
    options = int(getattr(telemetry, "original_options_count", 0) or 0)
    minimum = max(2, int(getattr(telemetry, "minimum_visible_options", 2) or 2))
    actions = ["RETRY_CURRENT"]
    if options > minimum and capabilities.intersection({"REMOVE_OPTION", "REMOVE_OPTIONS"}):
        actions.append("SCAFFOLD_REMOVE_DISTRACTOR")
    if options > minimum and capabilities.intersection({"DISABLE_OPTION", "DISABLE_OPTIONS"}):
        actions.append("SCAFFOLD_DISABLE_DISTRACTOR")
    if capabilities.intersection({"HIGHLIGHT_OPTION", "HIGHLIGHT_OPTIONS"}):
        actions.append("SCAFFOLD_HIGHLIGHT_CORRECT")
    if "REVEAL_FIRST_TOKEN" in capabilities:
        actions.append("SCAFFOLD_REVEAL_FIRST_TOKEN")
    if "REPLAY_INSTRUCTION" in capabilities:
        actions.append("SCAFFOLD_REPLAY_INSTRUCTION")
    # Slow playback is a distinct listening treatment, not another name for
    # replay. Offer it only when the learner has supplied audio-specific
    # evidence (a manual replay or repeated hesitation); otherwise replay is
    # the lower-cost, less intrusive first support.
    audio_replays = int(getattr(telemetry, "audio_replay_count", 0) or 0)
    hesitations = int(getattr(telemetry, "hesitation_count", 0) or 0)
    if "SLOW_AUDIO" in capabilities and (audio_replays > 0 or hesitations >= 2):
        actions.append("SCAFFOLD_SLOW_AUDIO")
    if "HIGHLIGHT_DESTINATION" in capabilities:
        actions.append("SCAFFOLD_HIGHLIGHT_DESTINATION")
    # Correct-prefix locking is a deterministic sequence invariant. It is
    # applied locally after every sequence error and is intentionally not an
    # ML action: the model must never recommend undoing already-correct work.
    return actions


def context_features(
    *,
    telemetry: Any,
    struggle_score: int,
    mastery: float,
    difficulty_b: float,
    fatigue: float,
    behavioral_context: Dict[str, Any] | None,
    learner_profile: Dict[str, float] | None,
    personal_latency_factor: float = 1.0,
) -> Dict[str, float]:
    """Convert live learner, task, baseline, and telemetry evidence to features."""
    behavior = behavioral_context or {}
    profile = learner_profile or {}
    latency = float(getattr(telemetry, "total_round_latency_ms", 0) or 0)
    personal_latency_factor = max(
        0.90, min(1.15, float(personal_latency_factor or 1.0))
    )
    return {
        "mastery": _bounded(mastery),
        "difficulty_b": _bounded(difficulty_b, -3.0, 3.0),
        "fatigue": _bounded(fatigue),
        "struggle_score": _bounded(struggle_score, 0.0, 8.0),
        "attempt_count": _bounded(getattr(telemetry, "attempt_count", 0), 0.0, 10.0),
        "incorrect_attempt_count": _bounded(getattr(telemetry, "incorrect_attempt_count", 0), 0.0, 10.0),
        # Normalize the observed duration by the conservative personal timing
        # factor before the action model compares scaffold candidates.
        "latency_seconds": _bounded(
            latency / personal_latency_factor / 1000.0, 0.0, 120.0
        ),
        "hesitation_count": _bounded(getattr(telemetry, "hesitation_count", 0), 0.0, 10.0),
        "misclick_count": _bounded(getattr(telemetry, "misclick_count", 0), 0.0, 10.0),
        "audio_replay_count": _bounded(
            getattr(telemetry, "audio_replay_count", 0), 0.0, 10.0
        ),
        "options_count": _bounded(getattr(telemetry, "original_options_count", 0), 0.0, 12.0),
        "session_accuracy": _bounded(behavior.get("first_attempt_accuracy")),
        "session_support_rate": _bounded(behavior.get("support_rate")),
        "profile_max_probability": max(
            [_bounded(value) for value in profile.values()] or [0.0]
        ),
    }


class ActionPolicyModel:
    """Load portable coefficients and rank safe scaffold actions in real time."""

    def __init__(self, path: Path | None = None):
        """Resolve the configured artifact path and load it once at startup."""
        self.path = Path(os.getenv("C4_ACTION_MODEL_PATH", str(path or DEFAULT_MODEL_PATH)))
        self.artifact: Dict[str, Any] = {}
        self.reload()

    def reload(self) -> None:
        """Reload the JSON artifact, leaving an empty model on invalid input."""
        try:
            self.artifact = json.loads(self.path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            self.artifact = {}

    def _score(self, action: str, features: Dict[str, float]) -> float:
        """Predict next-independent-success probability for one scaffold."""
        model_action = MODEL_ACTION_ALIASES.get(action, action)
        model = (self.artifact.get("models_by_action") or {}).get(model_action)
        if not model:
            return 0.5
        z = float(model.get("intercept", 0.0))
        weights = model.get("weights") or {}
        means = self.artifact.get("feature_means") or {}
        scales = self.artifact.get("feature_scales") or {}
        for name, value in features.items():
            scale = float(scales.get(name, 1.0) or 1.0)
            standardized = (float(value) - float(means.get(name, 0.0))) / scale
            z += float(weights.get(name, 0.0)) * standardized
        z = max(-30.0, min(30.0, z))
        return 1.0 / (1.0 + math.exp(-z))

    def evaluate(
        self,
        *,
        baseline_action: str,
        telemetry: Any,
        features: Dict[str, float],
        requested_mode: str | None,
        data_origin: str,
        assignment_key: str | None = None,
    ) -> Dict[str, Any]:
        """Rank eligible actions and apply the policy-mode safety gate.

        ``simulation_model`` applies the synthetic model for the labelled
        research demonstration. Ordinary ``model`` mode requires an approved
        observed-data artifact; otherwise the deterministic baseline remains
        applied while the recommendation is retained for auditing.
        """
        requested_policy_mode = str(
            requested_mode or os.getenv("C4_POLICY_MODE", "shadow")
        ).lower()
        experiment_arm = None
        assignment_probability = 1.0
        assignment_mechanism = "configured_policy_mode"
        mode = requested_policy_mode
        if mode == "simulation_experiment":
            # Stable learner/session assignment makes the demonstration
            # reproducible and avoids changing the arm between attempts.
            bucket = int(
                hashlib.sha256(
                    str(assignment_key or "unassigned").encode("utf-8")
                ).hexdigest()[:8],
                16,
            ) % 2
            experiment_arm = "ML_SIMULATION" if bucket else "BASELINE_RULES"
            mode = "simulation_model" if bucket else "baseline"
            assignment_probability = 0.5
            assignment_mechanism = "sha256_stable_50_50_simulation_experiment"
        if mode == "simulation":
            mode = "simulation_model"
        if mode not in {"baseline", "shadow", "simulation_model", "model"}:
            mode = "shadow"
        candidates = candidate_actions(telemetry)
        if baseline_action not in candidates:
            candidates.append(baseline_action)
        predictions = {
            action: round(self._score(action, features), 6)
            for action in candidates
        }
        utilities = {
            action: round(
                probability - ACTION_COSTS.get(action, 0.05),
                6,
            )
            for action, probability in predictions.items()
        }
        recommendation = max(utilities, key=utilities.get) if utilities else baseline_action
        ordered = sorted(utilities.values(), reverse=True)
        confidence = ordered[0] - ordered[1] if len(ordered) > 1 else 0.0
        status = str(self.artifact.get("validation_status") or "model_unavailable")
        model_version = self.artifact.get("model_version")
        activation_allowed = bool(self.artifact.get("activation_allowed", False))

        applied = baseline_action
        controls_live_adaptation = False
        execution_source = "deterministic_capability_policy"
        if mode == "baseline":
            fallback = "BASELINE_MODE"
        elif not self.artifact:
            fallback = "MODEL_ARTIFACT_UNAVAILABLE"
        elif mode == "simulation_model":
            # This is an explicit research-demonstration mode. It gives the
            # synthetic model real control of authored scaffold commands while
            # retaining observed/synthetic provenance on every stored row.
            applied = recommendation
            controls_live_adaptation = True
            execution_source = "synthetic_model_simulation"
            fallback = None
        elif status not in APPROVED_ACTIVE_STATUSES or not activation_allowed:
            fallback = "SYNTHETIC_OR_UNVALIDATED_MODEL_SHADOW_ONLY"
        elif mode != "model":
            fallback = "MODEL_OBSERVATION_ONLY"
        else:
            applied = recommendation
            controls_live_adaptation = True
            execution_source = "validated_observed_model"
            fallback = None

        return {
            "policy_mode": mode,
            "requested_policy_mode": requested_policy_mode,
            "experiment_arm": experiment_arm,
            "assignment_probability": assignment_probability,
            "assignment_mechanism": assignment_mechanism,
            "model_version": model_version,
            "model_validation_status": status,
            "model_activation_allowed": activation_allowed,
            "candidate_actions": candidates,
            "scoring_model_by_action": {
                action: MODEL_ACTION_ALIASES.get(action, action)
                for action in candidates
            },
            "predicted_next_independent_success": predictions,
            "action_utilities": utilities,
            "model_recommendation": recommendation,
            "model_confidence": round(confidence, 6),
            "baseline_action": baseline_action,
            "applied_action": applied,
            "fallback_reason": fallback,
            "data_origin": data_origin,
            "controls_live_adaptation": controls_live_adaptation,
            "execution_source": execution_source,
            "simulation_disclosure": (
                "Synthetic-trained policy controls this explicitly labelled "
                "simulation; it is not observed-child efficacy evidence."
                if mode == "simulation_model" else None
            ),
        }


action_policy_model = ActionPolicyModel()
