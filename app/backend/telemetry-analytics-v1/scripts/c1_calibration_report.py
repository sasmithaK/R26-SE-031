"""Compare real sessions with the C1 simulator and the model's training ranges.

Input: one or more JSON files written by "Claude outputs/dump_student.py"
(or any JSON with collections.telemetry_sessions). Read-only.

For every activity it prints the observed medians next to the simulator's
parameters, so config/c1_simulation.yaml can be adjusted from real play.
For every learner it prints the learner-level features and flags any that
fall outside the training range (those learners get no model estimate).

Usage:  python scripts/c1_calibration_report.py "../../../Claude outputs/student_dump_Savi.json"
"""
import json
import statistics
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from research.c1_simulator import load_config  # noqa: E402
from services.c1.learner_window import build_learner_features, evidence_gaps  # noqa: E402
from services.ml.learner_inference import outside_training_range  # noqa: E402


def _median(values):
    values = [v for v in values if isinstance(v, (int, float)) and v > 0]
    return round(statistics.median(values)) if values else None


def main(paths):
    cfg = load_config()
    by_activity, learners = {}, []
    for path in paths:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        sessions = sorted(data.get("collections", {}).get("telemetry_sessions", []),
                          key=lambda s: str(s.get("completed_at") or ""))
        pairs = [({"session_id": s.get("session_id")}, s.get("events") or []) for s in sessions]
        learners.append((Path(path).stem, pairs))
        for _, events in pairs:
            for e in events:
                if e.get("is_abandoned"):
                    continue
                skill = "".join(ch for ch in str(e.get("skill_id")) if ch.isdigit())
                act = "".join(ch for ch in str(e.get("activity_id")) if ch.isdigit())
                by_activity.setdefault(f"{skill}.{act}", []).append(e)

    print("Activity | rounds | first touch ms (real / sim) | round ms (real / sim first+solve) | first-try (real / sim)")
    for key in sorted(by_activity):
        rows, sim = by_activity[key], cfg["activities"].get(key)
        first_try = [e.get("first_attempt_correct") for e in rows if isinstance(e.get("first_attempt_correct"), bool)]
        real_acc = round(sum(first_try) / len(first_try), 2) if first_try else None
        sim_text = (f"{sim[6]} | {sim[6] + sim[7]} | {sim[8]}") if sim else "not in simulator"
        print(f"{key} | {len(rows)} | {_median([e.get('first_touch_latency_ms') for e in rows])} | "
              f"{_median([e.get('total_round_latency_ms') for e in rows])} | {real_acc}  (sim: {sim_text})")

    print("\nLearner features vs training ranges")
    for name, pairs in learners:
        built = build_learner_features(pairs)
        gaps = evidence_gaps(built["evidence"])
        outside = outside_training_range(built["features"])
        print(f"- {name}: {built['evidence']['completed_rounds']} completed rounds; "
              f"{'needs ' + ', '.join(gaps) if gaps else 'enough evidence'}; "
              f"{len(outside)} feature(s) outside training range")
        for row in outside:
            print(f"    {row['feature']}: {row['value']} (training {row['training_range']})")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1:])
