"""Export simulated learners for C3 training (touch side).

For each simulated learner this runs the LIVE telemetry code:
  * C1 learner-level features  (services/c1/learner_window.py)
  * one kinematic row per session (services/comp2_kinematics.py)
and writes them as JSON lines. ``diagnostic-fusion-v1/scripts/train_c3_model.py``
adds simulated reading recordings and trains C3 on the result.

Usage (from telemetry-analytics-v1):
    python scripts/export_c3_simulation.py ../diagnostic-fusion-v1/research/c3_touch_simulation.jsonl
"""
import json
import sys
import zlib
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from research.c1_simulator import CLASS_NAMES, add_touch_streams, load_config, simulate_learner  # noqa: E402
from services.c1.learner_window import build_learner_features, evidence_gaps  # noqa: E402
from services.comp2_kinematics import extract_comp2_features, normalize_touch_events  # noqa: E402

LEARNERS_PER_CLASS = 1500
SEED = 1234


def age_speed_scale(age_months: int) -> float:
    """Younger children respond more slowly: about 12% per year around age 6."""
    return 1.0 + 0.12 * (72 - age_months) / 12


def main(out_path: str):
    cfg = load_config()
    rng = np.random.default_rng(SEED)
    out = Path(out_path)
    out.parent.mkdir(parents=True, exist_ok=True)
    written = 0
    with out.open("w", encoding="utf-8") as handle:
        for pattern in CLASS_NAMES:
            for i in range(LEARNERS_PER_CLASS):
                learner_id = f"{pattern[:3]}-{i}"
                age_months = int(rng.integers(60, 96))
                learner, sessions = simulate_learner(rng, pattern, cfg, learner_id, age_speed_scale(age_months))
                move_rng = np.random.default_rng(zlib.crc32(learner_id.encode()) + SEED)
                add_touch_streams(move_rng, pattern, learner, sessions, cfg)
                built = build_learner_features(sessions)
                c1_ok = not evidence_gaps(built["evidence"])
                motion_rows = []
                for _, events in sessions:
                    normalized = normalize_touch_events(events)
                    if normalized:
                        row = extract_comp2_features(normalized)
                        row["dwell_time_ms"] = row.get("mean_dwell_time_ms")
                        motion_rows.append({k: v for k, v in row.items() if v is not None})
                handle.write(json.dumps({
                    "learner_id": learner_id, "pattern": pattern, "age_months": age_months,
                    "speed": learner["speed"], "c1_features": built["features"] if c1_ok else None,
                    "motion_rows": motion_rows,
                }) + "\n")
                written += 1
    print(f"wrote {written} simulated learners to {out}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else str(ROOT.parent / "diagnostic-fusion-v1" / "research" / "c3_touch_simulation.jsonl"))
