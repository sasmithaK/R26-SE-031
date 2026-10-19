"""Generate reproducible synthetic rows for functional practice selection."""

from __future__ import annotations

import argparse
import csv
import math
import random
from pathlib import Path


FEATURES = (
    "primary_target_match", "component_overlap", "error_tag_overlap",
    "difficulty_fit", "role_fit", "novelty", "same_group",
    "micro_mastery", "support_dependency", "fatigue",
    "diagnostic_confidence", "confirmation_phase",
)


def sigmoid(value: float) -> float:
    """Map a simulated candidate-quality score to success probability."""
    return 1.0 / (1.0 + math.exp(-max(-30.0, min(30.0, value))))


def rows(seed: int, learners: int, decisions: int):
    """Yield reproducible candidate-practice outcomes for simulated learners."""
    rng = random.Random(seed)
    dataset_id = f"c4-synthetic-practice-v1-seed-{seed}"
    for learner in range(learners):
        mastery = rng.uniform(0.08, 0.78)
        for decision in range(decisions):
            confirmation = float(rng.random() < 0.45)
            target_match = rng.choice((0.0, 0.0, 0.5, 1.0))
            component = max(target_match, rng.uniform(0.0, 1.0))
            tag_match = rng.uniform(0.15, 1.0)
            difficulty_fit = rng.uniform(0.25, 1.0)
            role_fit = rng.choice((0.65, 1.0))
            novelty = rng.choice((0.33, 0.5, 1.0))
            same_group = float(rng.random() < 0.35)
            fatigue = rng.uniform(0.0, 0.9)
            confidence = rng.uniform(0.35, 1.0)
            support = 1.0 - mastery
            feature_values = {
                "primary_target_match": target_match,
                "component_overlap": component,
                "error_tag_overlap": tag_match,
                "difficulty_fit": difficulty_fit,
                "role_fit": role_fit,
                "novelty": novelty,
                "same_group": same_group,
                "micro_mastery": mastery,
                "support_dependency": support,
                "fatigue": fatigue,
                "diagnostic_confidence": confidence,
                "confirmation_phase": confirmation,
            }
            logit = (
                -1.0 + 1.25 * target_match + 0.60 * component
                + 0.55 * tag_match + 1.0 * difficulty_fit + 0.45 * role_fit
                + 0.35 * novelty + 0.15 * same_group + 1.5 * mastery
                - 0.55 * support - 0.85 * fatigue
                + 0.30 * confidence - 0.22 * confirmation
            )
            outcome = int(rng.random() < sigmoid(logit))
            yield {
                "student_id": f"synthetic-practice-{learner:04d}",
                "decision_id": f"{learner:04d}-{decision:03d}",
                **{key: round(value, 6) for key, value in feature_values.items()},
                "independent_success": outcome,
                "data_origin": "synthetic",
                "dataset_id": dataset_id,
                "validation_status": "synthetic_only",
                "calibration_eligible": False,
            }


def main() -> None:
    """Generate and save the synthetic targeted-practice training table."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    parser.add_argument("--seed", type=int, default=26031)
    parser.add_argument("--learners", type=int, default=500)
    parser.add_argument("--decisions", type=int, default=20)
    args = parser.parse_args()
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    generated = list(rows(args.seed, args.learners, args.decisions))
    with output.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(generated[0]))
        writer.writeheader()
        writer.writerows(generated)
    print(f"Wrote {len(generated)} synthetic practice rows to {output}")


if __name__ == "__main__":
    main()
