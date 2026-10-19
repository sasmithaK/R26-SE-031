"""Train a dependency-free logistic practice-selector artifact."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import random
from datetime import datetime, timezone
from pathlib import Path


FEATURES = (
    "primary_target_match", "component_overlap", "error_tag_overlap",
    "difficulty_fit", "role_fit", "novelty", "same_group",
    "micro_mastery", "support_dependency", "fatigue",
    "diagnostic_confidence", "confirmation_phase",
)


def sigmoid(value: float) -> float:
    """Convert a bounded logistic score into an independent-success probability."""
    return 1.0 / (1.0 + math.exp(-max(-30.0, min(30.0, value))))


def auc(labels, probabilities):
    """Compute rank-based ROC-AUC without adding a runtime ML dependency."""
    pairs = sorted(zip(probabilities, labels))
    positives = sum(labels)
    negatives = len(labels) - positives
    if not positives or not negatives:
        return 0.5
    rank_sum = sum(index + 1 for index, (_, label) in enumerate(pairs) if label)
    return (rank_sum - positives * (positives + 1) / 2) / (positives * negatives)


def main() -> None:
    """Train, test, and export the targeted-practice logistic ranker.

    The split is performed on learner IDs before rows are collected. This
    guarantees that one simulated learner cannot occur in both training and
    testing, even though each learner has multiple candidate decisions.
    """
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--seed", type=int, default=26031)
    args = parser.parse_args()
    source = Path(args.input)
    with source.open(encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    if not rows or {row.get("data_origin") for row in rows} != {"synthetic"}:
        raise RuntimeError("Practice-selector training accepts synthetic rows only.")

    # Create a deterministic 75% learner-training / 25% learner-testing split.
    # Unlike a random row split, this preserves learner independence.
    learners = sorted({row["student_id"] for row in rows})
    rng = random.Random(args.seed)
    rng.shuffle(learners)
    split = int(len(learners) * 0.75)
    train_ids = set(learners[:split])
    train = [row for row in rows if row["student_id"] in train_ids]
    test = [row for row in rows if row["student_id"] not in train_ids]
    # Learn standardization statistics from training learners only.
    means = {
        name: sum(float(row[name]) for row in train) / len(train)
        for name in FEATURES
    }
    scales = {}
    for name in FEATURES:
        variance = sum((float(row[name]) - means[name]) ** 2 for row in train) / len(train)
        scales[name] = math.sqrt(variance) or 1.0

    # Fit L2-regularized logistic regression with batch gradient descent. The
    # resulting coefficients are exported as portable JSON for inference.
    weights = {name: 0.0 for name in FEATURES}
    intercept = 0.0
    learning_rate = 0.08
    regularization = 0.001
    for _ in range(900):
        grad_i = 0.0
        grad_w = {name: 0.0 for name in FEATURES}
        for row in train:
            x = {name: (float(row[name]) - means[name]) / scales[name] for name in FEATURES}
            predicted = sigmoid(intercept + sum(weights[name] * x[name] for name in FEATURES))
            error = predicted - int(row["independent_success"])
            grad_i += error
            for name in FEATURES:
                grad_w[name] += error * x[name]
        intercept -= learning_rate * grad_i / len(train)
        for name in FEATURES:
            weights[name] -= learning_rate * (
                grad_w[name] / len(train) + regularization * weights[name]
            )

    # The held-out rows are used only after training to calculate final metrics.
    probabilities = []
    labels = []
    for row in test:
        x = {name: (float(row[name]) - means[name]) / scales[name] for name in FEATURES}
        probabilities.append(sigmoid(intercept + sum(weights[name] * x[name] for name in FEATURES)))
        labels.append(int(row["independent_success"]))
    accuracy = sum((p >= 0.5) == bool(y) for p, y in zip(probabilities, labels)) / len(labels)
    brier = sum((p - y) ** 2 for p, y in zip(probabilities, labels)) / len(labels)

    artifact = {
        "model_type": "reviewed_item_independent_success_logistic_model",
        "model_version": "c4-practice-selector-synthetic-v1",
        "trained_at": datetime.now(timezone.utc).isoformat(),
        "data_origin": "synthetic",
        "dataset_id": rows[0]["dataset_id"],
        "training_file_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "validation_status": "synthetic_only",
        "activation_allowed": False,
        "outcome": "next_item_independent_success",
        "feature_names": list(FEATURES),
        # Round the portable JSON artifact so independent Python builds
        # reproduce byte-stable coefficients despite sub-ULP sum differences.
        "feature_means": {
            name: round(value, 12) for name, value in means.items()
        },
        "feature_scales": {
            name: round(value, 12) for name, value in scales.items()
        },
        "model": {
            "intercept": round(intercept, 12),
            "weights": {
                name: round(value, 12) for name, value in weights.items()
            },
        },
        "held_out_group_evaluation": {
            "train_learners": len(train_ids),
            "test_learners": len(learners) - len(train_ids),
            "test_rows": len(test),
            "accuracy": round(accuracy, 6),
            "brier_score": round(brier, 6),
            "roc_auc": round(auc(labels, probabilities), 6),
        },
        "limitations": [
            "Trained on simulated learners, not observed Grade 1 participants.",
            "May control only explicitly labelled simulation runs.",
            "Ranks reviewed items and never generates child-facing content.",
        ],
    }
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(artifact, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(artifact["held_out_group_evaluation"], indent=2))


if __name__ == "__main__":
    main()
