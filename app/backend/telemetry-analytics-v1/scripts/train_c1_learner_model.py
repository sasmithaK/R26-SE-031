"""Train the learner-level C1 model on simulated sessions.

1. Simulate learners round by round (research/c1_simulator.py, parameters in
   config/c1_simulation.yaml).
2. Build each learner's features with the LIVE code
   (services/c1/learner_window.build_learner_features).
3. Keep only learners who pass the live evidence rule.
4. Train a gradient-boosting classifier that handles missing values natively
   (no imputation), and save metrics plus the training feature ranges used by
   the out-of-range guard.

Run from telemetry-analytics-v1:  python scripts/train_c1_learner_model.py
"""
import json
import math
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

import joblib
import numpy as np
from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.metrics import accuracy_score, classification_report, f1_score
from sklearn.model_selection import train_test_split

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from research.c1_simulator import CLASS_NAMES, load_config, simulate_learner  # noqa: E402
from services.c1.learner_window import (FEATURE_VERSION, RULES, build_learner_features,  # noqa: E402
                                        evidence_gaps)

SCHEMA_PATH = ROOT / "config" / "c1_features.json"
MODEL_PATH = ROOT / "models" / "c1_learner_model.pkl"
METRICS_PATH = ROOT / "models" / "c1_learner_model_metrics.json"
RANGES_PATH = ROOT / "models" / "c1_learner_feature_ranges.json"
REGISTRY_PATH = ROOT / "models" / "model_registry.json"


def feature_names():
    return json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))["features"]


def simulate(cfg):
    rng = np.random.default_rng(cfg["random_seed"])
    names = feature_names()
    rows, labels, groups = [], [], []
    skipped = 0
    for label, pattern in enumerate(CLASS_NAMES):
        for i in range(cfg["learners_per_class"]):
            _, sessions = simulate_learner(rng, pattern, cfg, f"{pattern[:3]}{i}")
            built = build_learner_features(sessions)
            if evidence_gaps(built["evidence"], RULES):
                skipped += 1
                continue
            values = built["features"]
            rows.append([math.nan if values.get(n) is None else float(values[n]) for n in names])
            labels.append(label)
            groups.append(bool(built["evidence"]["sound_task_rounds"]))
    return np.asarray(rows, dtype=float), np.asarray(labels), np.asarray(groups), names, skipped


def feature_ranges(X, names):
    ranges = {}
    for j, name in enumerate(names):
        col = X[:, j][~np.isnan(X[:, j])]
        if col.size:
            ranges[name] = {"p01": float(np.percentile(col, 1)), "p99": float(np.percentile(col, 99)),
                            "min": float(col.min()), "max": float(col.max())}
    return ranges


def main():
    cfg = load_config()
    X, y, has_sound, names, skipped = simulate(cfg)
    x_tr, x_te, y_tr, y_te, s_tr, s_te = train_test_split(
        X, y, has_sound, test_size=0.2, random_state=cfg["random_seed"], stratify=y)
    model = HistGradientBoostingClassifier(max_iter=300, learning_rate=0.08, max_depth=5,
                                           l2_regularization=1.0, early_stopping=True,
                                           random_state=cfg["random_seed"])
    model.fit(x_tr, y_tr)
    pred = model.predict(x_te)
    with_sound, without = s_te, ~s_te
    metrics = {
        "model": "c1_learner_model", "algorithm": "HistGradientBoostingClassifier (native missing values)",
        "feature_schema": FEATURE_VERSION, "features": names, "class_names": CLASS_NAMES,
        "simulator_version": cfg["version"], "trained_at": datetime.now(timezone.utc).isoformat(),
        "training_data": "simulated rounds -> live feature code (synthetic only)",
        "evidence_rule": RULES, "learners_eligible": int(len(y)), "learners_below_evidence_rule": skipped,
        "learners_without_sound_tasks": int((~has_sound).sum()),
        "test_learners": int(len(y_te)),
        "accuracy": round(float(accuracy_score(y_te, pred)), 4),
        "macro_f1": round(float(f1_score(y_te, pred, average="macro")), 4),
        "accuracy_with_sound_tasks": round(float(accuracy_score(y_te[with_sound], pred[with_sound])), 4)
        if with_sound.any() else None,
        "accuracy_without_sound_tasks": round(float(accuracy_score(y_te[without], pred[without])), 4)
        if without.any() else None,
        "classification_report": classification_report(y_te, pred, target_names=CLASS_NAMES,
                                                       output_dict=True, zero_division=0),
        "limitations": [
            "Trained on simulated learners only; simulator parameters are provisional (config/c1_simulation.yaml).",
            "Accuracy on simulated data shows the pipeline separates the simulated patterns; it is not clinical validity.",
            "Estimates are hidden when a learner's inputs fall outside the training ranges.",
        ],
    }
    model.sipsara_feature_schema = FEATURE_VERSION
    model.sipsara_feature_names = names
    model.sipsara_training_data = "synthetic_simulated_rounds"
    MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump(model, MODEL_PATH)
    METRICS_PATH.write_text(json.dumps(metrics, indent=2), encoding="utf-8")
    RANGES_PATH.write_text(json.dumps({"feature_schema": FEATURE_VERSION, "ranges": feature_ranges(X, names)},
                                      indent=2), encoding="utf-8")

    registry = json.loads(REGISTRY_PATH.read_text(encoding="utf-8")) if REGISTRY_PATH.exists() else {}
    registry["c1_learner_model"] = {
        "version": "3.0.0", "feature_schema": FEATURE_VERSION,
        "training_dataset": f"simulated-rounds-{cfg['version']}",
        "algorithm": "HistGradientBoostingClassifier", "artifact": MODEL_PATH.name,
        "ranges": RANGES_PATH.name, "enabled": True, "provenance": "synthetic_only",
        "validation_status": "integration_validated_not_clinically_validated",
        "class_names": CLASS_NAMES,
    }
    REGISTRY_PATH.write_text(json.dumps(registry, indent=2), encoding="utf-8")
    print(json.dumps({k: metrics[k] for k in ("learners_eligible", "learners_below_evidence_rule",
                                              "learners_without_sound_tasks", "accuracy", "macro_f1",
                                              "accuracy_with_sound_tasks", "accuracy_without_sound_tasks")},
                     indent=2))


if __name__ == "__main__":
    main()
