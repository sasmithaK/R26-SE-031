"""Train action-outcome models and export a dependency-free JSON artifact."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path


FEATURES = (
    "mastery", "difficulty_b", "fatigue", "struggle_score", "attempt_count",
    "incorrect_attempt_count", "latency_seconds", "hesitation_count",
    "misclick_count", "audio_replay_count", "options_count", "session_accuracy",
    "session_support_rate", "profile_max_probability",
)


def main() -> None:
    """Train, evaluate, and export the per-scaffold outcome models.

    Learners—not individual interaction rows—are split into train and test
    groups.  Consequently, all rows belonging to one simulated learner remain
    on one side of the split and cannot leak that learner's pattern into the
    held-out evaluation.
    """
    import numpy as np
    from sklearn.dummy import DummyClassifier
    from sklearn.ensemble import HistGradientBoostingClassifier, RandomForestClassifier
    from sklearn.linear_model import LogisticRegression
    from sklearn.metrics import accuracy_score, brier_score_loss, log_loss, roc_auc_score
    from sklearn.model_selection import GroupShuffleSplit
    from sklearn.preprocessing import StandardScaler

    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--seed", type=int, default=26031)
    args = parser.parse_args()
    with Path(args.input).open(encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    if not rows or {row.get("data_origin") for row in rows} != {"synthetic"}:
        raise RuntimeError("This training command requires explicitly synthetic rows.")

    # X contains the learner/task context and y is the binary next-response
    # outcome. ``groups`` is the learner identity used only to protect the
    # evaluation split; it is never supplied as a predictive feature.
    x = np.asarray([[float(row[name]) for name in FEATURES] for row in rows])
    y = np.asarray([int(row["next_independent_success"]) for row in rows])
    groups = np.asarray([row["student_id"] for row in rows])
    actions = np.asarray([row["action"] for row in rows])
    propensities = np.asarray([float(row["propensity"]) for row in rows])
    # Hold out 25% of learners (75% train / 25% test). GroupShuffleSplit keeps
    # every interaction from one student entirely in train or entirely in test.
    splitter = GroupShuffleSplit(n_splits=1, test_size=0.25, random_state=args.seed)
    train_index, test_index = next(splitter.split(x, y, groups))
    # Fit normalization only on training learners to prevent test statistics
    # leaking into model fitting. The learned mean/scale then transforms both.
    scaler = StandardScaler().fit(x[train_index])
    x_scaled = scaler.transform(x)
    models = {}
    fitted_by_action = {}
    evaluations = {}
    for action in sorted(set(actions)):
        # MODEL 1: binary logistic regression predicts independent success
        # separately for each scaffold action.
        # Each scaffold receives its own interpretable binary outcome model.
        # Fit with training rows for that action; evaluate on held-out learners.
        train = train_index[actions[train_index] == action]
        test = test_index[actions[test_index] == action]
        model = LogisticRegression(max_iter=2000, random_state=args.seed)
        model.fit(x_scaled[train], y[train])
        fitted_by_action[action] = model
        probabilities = model.predict_proba(x_scaled[test])[:, 1]
        predictions = probabilities >= 0.5
        evaluations[action] = {
            "n_train": int(len(train)),
            "n_test": int(len(test)),
            "accuracy": round(float(accuracy_score(y[test], predictions)), 6),
            "brier_score": round(float(brier_score_loss(y[test], probabilities)), 6),
            "log_loss": round(float(log_loss(y[test], probabilities, labels=[0, 1])), 6),
            "roc_auc": round(float(roc_auc_score(y[test], probabilities)), 6),
        }
        models[action] = {
            "intercept": float(model.intercept_[0]),
            "weights": {
                name: float(value)
                for name, value in zip(FEATURES, model.coef_[0])
            },
        }

    action_names = sorted(set(actions))
    action_one_hot = np.asarray([
        [1.0 if current == candidate else 0.0 for candidate in action_names]
        for current in actions
    ])
    comparison_x = np.column_stack([x_scaled, action_one_hot])
    # Compare the deployable logistic model against a class-prior baseline and
    # two nonlinear alternatives; these models are evaluation evidence only.
    comparison_models = {
        "class_prior": DummyClassifier(strategy="prior"),
        "logistic_regression": LogisticRegression(max_iter=2000, random_state=args.seed),
        "random_forest": RandomForestClassifier(
            n_estimators=180,
            min_samples_leaf=10,
            class_weight="balanced",
            random_state=args.seed,
            n_jobs=2,
        ),
        "hist_gradient_boosting": HistGradientBoostingClassifier(
            max_iter=150,
            max_leaf_nodes=15,
            learning_rate=0.06,
            random_state=args.seed,
        ),
    }
    comparison = {}
    for name, model in comparison_models.items():
        model.fit(comparison_x[train_index], y[train_index])
        probability = model.predict_proba(comparison_x[test_index])[:, 1]
        predicted = probability >= 0.5
        comparison[name] = {
            "accuracy": round(float(accuracy_score(y[test_index], predicted)), 6),
            "brier_score": round(float(brier_score_loss(y[test_index], probability)), 6),
            "log_loss": round(float(log_loss(y[test_index], probability, labels=[0, 1])), 6),
            "roc_auc": round(float(roc_auc_score(y[test_index], probability)), 6),
        }

    # Estimate policy value offline. A held-out row contributes only when the
    # learned recommendation matches the randomly logged synthetic action.
    recommended_actions = []
    for row_index in test_index:
        scores = {
            action: fitted_by_action[action].predict_proba(
                x_scaled[row_index].reshape(1, -1)
            )[0, 1]
            for action in action_names
        }
        recommended_actions.append(max(scores, key=scores.get))
    recommended_actions = np.asarray(recommended_actions)
    logged_actions = actions[test_index]
    matches = logged_actions == recommended_actions
    weights = np.where(matches, 1.0 / propensities[test_index], 0.0)
    ips_policy_value = (
        float(np.sum(weights * y[test_index]) / np.sum(weights))
        if np.sum(weights) else None
    )
    off_policy_evaluation = {
        "method": "self_normalized_inverse_propensity_weighting",
        "logged_action_match_count": int(np.sum(matches)),
        "test_count": int(len(test_index)),
        "estimated_next_independent_success": (
            round(ips_policy_value, 6) if ips_policy_value is not None else None
        ),
        "observed_random_policy_success": round(float(np.mean(y[test_index])), 6),
        "interpretation": "Simulation evidence only; not a child outcome claim.",
    }
    artifact = {
        "model_type": "per_action_logistic_outcome_model",
        "model_version": "c4-action-outcome-synthetic-v2",
        "trained_at": datetime.now(timezone.utc).isoformat(),
        "data_origin": "synthetic",
        "dataset_id": rows[0]["dataset_id"],
        "training_file_sha256": hashlib.sha256(
            Path(args.input).read_bytes()
        ).hexdigest(),
        "validation_status": "synthetic_only",
        "activation_allowed": False,
        "outcome": "next_independent_success",
        "feature_names": list(FEATURES),
        "feature_means": dict(zip(FEATURES, map(float, scaler.mean_))),
        "feature_scales": dict(zip(FEATURES, map(float, scaler.scale_))),
        "models_by_action": models,
        "held_out_group_evaluation": evaluations,
        "held_out_model_comparison": comparison,
        "off_policy_evaluation": off_policy_evaluation,
        "limitations": [
            "Trained on simulated learners, not observed Grade 1 participants.",
            "Valid for software/policy simulation and shadow-mode research only.",
            "Must not be activated until an observed-data validation artifact is approved.",
        ],
    }
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(artifact, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({"model_version": artifact["model_version"], "evaluation": evaluations}, indent=2))


if __name__ == "__main__":
    main()
