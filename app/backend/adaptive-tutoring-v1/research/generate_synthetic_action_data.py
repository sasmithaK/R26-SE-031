"""Generate reproducible, clearly labelled Grade-1-like policy simulations.

The distributions are engineering assumptions for pipeline testing. They are
not observations of Sri Lankan children and cannot calibrate BKT/Rasch.
"""

from __future__ import annotations

import argparse
import csv
import math
import random
from pathlib import Path


ACTIONS = (
    "RETRY_CURRENT",
    "SCAFFOLD_REMOVE_DISTRACTOR",
    "SCAFFOLD_HIGHLIGHT_CORRECT",
    "SCAFFOLD_REPLAY_INSTRUCTION",
    "SCAFFOLD_SLOW_AUDIO",
    "SCAFFOLD_REVEAL_FIRST_TOKEN",
    "SCAFFOLD_SHOW_WORKED_EXAMPLE",
)

FEATURES = (
    "mastery", "difficulty_b", "fatigue", "struggle_score", "attempt_count",
    "incorrect_attempt_count", "latency_seconds", "hesitation_count",
    "misclick_count", "audio_replay_count", "options_count", "session_accuracy",
    "session_support_rate", "profile_max_probability",
)


def sigmoid(value: float) -> float:
    """Map a simulated scaffold-effect score to a binary-success probability."""
    return 1.0 / (1.0 + math.exp(-max(-30.0, min(30.0, value))))


def generate_rows(seed: int, learners: int, interactions: int):
    """Yield reproducible labelled scaffold outcomes for simulated learners.

    Actions are assigned uniformly, so their logged propensity is known and
    later supports inverse-propensity policy evaluation.
    """
    rng = random.Random(seed)
    dataset_id = f"c4-synthetic-policy-v1-seed-{seed}"
    for learner in range(learners):
        mastery = rng.uniform(0.12, 0.72)
        support_history = rng.uniform(0.05, 0.65)
        for sequence in range(interactions):
            mastery_before = mastery
            support_history_before = support_history
            difficulty = rng.uniform(-1.2, 1.2)
            fatigue = min(1.0, max(0.0, rng.gauss(0.18 + sequence * 0.012, 0.12)))
            struggle = min(8.0, max(0.0, rng.gauss(2.2 + fatigue * 1.8, 1.1)))
            attempts = 1 + int(struggle >= 2.0) + int(struggle >= 4.0)
            incorrect = max(1, attempts - 1)
            latency = max(1.0, rng.lognormvariate(2.0 + fatigue * 0.5, 0.3))
            hesitation = int(struggle >= 3.0) + int(struggle >= 5.0)
            misclick = int(rng.random() < 0.12 + fatigue * 0.2)
            audio_replays = int(rng.random() < 0.08 + 0.13 * hesitation)
            if audio_replays and rng.random() < 0.2:
                audio_replays += 1
            options = rng.choice((2, 3, 4, 5))
            session_accuracy = min(1.0, max(0.0, mastery + rng.gauss(0.0, 0.12)))
            profile = min(1.0, max(0.0, rng.gauss(0.25, 0.18)))
            action = rng.choice(ACTIONS)
            propensity = 1.0 / len(ACTIONS)

            base = 1.4 + 2.2 * mastery - 0.65 * difficulty - 0.55 * fatigue
            base -= 0.30 * struggle + 0.08 * max(0.0, latency - 8.0)
            effects = {
                "RETRY_CURRENT": -0.15 + 0.35 * mastery - 0.18 * struggle,
                "SCAFFOLD_REMOVE_DISTRACTOR": 0.30 + 0.10 * options + 0.12 * struggle,
                "SCAFFOLD_HIGHLIGHT_CORRECT": 0.72 + 0.18 * struggle - 0.25 * mastery,
                "SCAFFOLD_REPLAY_INSTRUCTION": 0.18 + 0.35 * hesitation,
                "SCAFFOLD_SLOW_AUDIO": (
                    0.08 + 0.42 * audio_replays + 0.18 * hesitation
                ),
                "SCAFFOLD_REVEAL_FIRST_TOKEN": 0.45 + 0.15 * struggle,
                "SCAFFOLD_SHOW_WORKED_EXAMPLE": (
                    0.25 + 0.25 * struggle + 0.35 * incorrect
                    - 0.20 * mastery
                ),
            }
            probability = sigmoid(base + effects[action])
            outcome = rng.random() < probability
            mastery = min(0.99, max(0.01, mastery + (0.035 if outcome else -0.012)))
            support_history = 0.8 * support_history + 0.2 * (action != "RETRY_CURRENT")
            yield {
                "student_id": f"synthetic-{learner:04d}",
                "session_id": f"synthetic-{learner:04d}-{sequence // 5:03d}",
                "item_id": f"SIM-R{sequence + 1:03d}",
                "action": action,
                "propensity": propensity,
                "next_independent_success": int(outcome),
                "mastery": round(mastery_before, 6),
                "difficulty_b": round(difficulty, 6),
                "fatigue": round(fatigue, 6),
                "struggle_score": round(struggle, 6),
                "attempt_count": attempts,
                "incorrect_attempt_count": incorrect,
                "latency_seconds": round(latency, 6),
                "hesitation_count": hesitation,
                "misclick_count": misclick,
                "audio_replay_count": audio_replays,
                "options_count": options,
                "session_accuracy": round(session_accuracy, 6),
                "session_support_rate": round(support_history_before, 6),
                "profile_max_probability": round(profile, 6),
                "data_origin": "synthetic",
                "dataset_id": dataset_id,
                "validation_status": "synthetic_only",
                "calibration_eligible": False,
            }


def main() -> None:
    """Generate the requested synthetic cohort and write it as a CSV dataset."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    parser.add_argument("--seed", type=int, default=26031)
    parser.add_argument("--learners", type=int, default=600)
    parser.add_argument("--interactions", type=int, default=24)
    args = parser.parse_args()
    path = Path(args.output)
    path.parent.mkdir(parents=True, exist_ok=True)
    rows = list(generate_rows(args.seed, args.learners, args.interactions))
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    print(f"Wrote {len(rows)} labelled synthetic rows to {path}")


if __name__ == "__main__":
    main()
