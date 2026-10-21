"""Train C3 on simulated learners aggregated by the live C3 code.

1. Touch side: research/c3_touch_simulation.jsonl, produced by
   telemetry-analytics-v1/scripts/export_c3_simulation.py (round-level
   simulator -> live C1 learner features + live movement extractor). If the
   file is missing it is generated (about 2 minutes).
2. Reading side: per-recording features simulated from config/c3_simulation.yaml.
3. Each learner is aggregated with services/c3_features.build_c3_inputs and
   kept only if it passes the live evidence rule.
4. XGBoost with native missing values; held-out metrics, probability
   calibration check (reliability bins, Brier score), and the training
   feature ranges for the out-of-range guard.

Run from diagnostic-fusion-v1:  python scripts/train_c3_model.py
"""
import json
import math
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

import joblib
import numpy as np
import xgboost as xgb
import yaml
from sklearn.metrics import accuracy_score, brier_score_loss, classification_report, f1_score
from sklearn.model_selection import train_test_split

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from services.c3_features import FEATURES, FEATURE_VERSION, build_c3_inputs, evidence_gaps  # noqa: E402

TOUCH_FILE = ROOT / "research" / "c3_touch_simulation.jsonl"
MODELS = ROOT / "models"
# Class order matches services/xai_engine.SUBTYPE_MAP.
CLASS_INDEX = {"TYPICAL": 0, "PHONOLOGICAL_PATTERN": 1, "VISUAL_ORTHOGRAPHIC_PATTERN": 2, "COMBINED_PATTERN": 3}
CLASS_NAMES = ["Typical", "Phonological", "Visual-Orthographic", "Combined"]


def ensure_touch_file():
    if TOUCH_FILE.exists():
        return
    telemetry = ROOT.parent / "telemetry-analytics-v1"
    subprocess.run([sys.executable, "scripts/export_c3_simulation.py", str(TOUCH_FILE)], cwd=telemetry, check=True)


def simulate_recordings(rng, learner: dict, cfg: dict) -> list:
    pattern = learner["pattern"]
    n = int(rng.integers(cfg["recordings_per_learner"][0], cfg["recordings_per_learner"][1] + 1))
    onset = cfg["voice_onset"]
    learner_onset = (onset["typical_median_ms"] * onset["multiplier"][pattern]
                     * math.sqrt(learner["speed"]) * math.exp(rng.normal(0, onset["learner_log_sd"])))
    silence = float(rng.uniform(*cfg["silence_ratio"][pattern]))
    jitter, shimmer = float(rng.uniform(*cfg["jitter"])), float(rng.uniform(*cfg["shimmer"]))
    rows = []
    for _ in range(n):
        if rng.random() > cfg["usable_probability"][pattern]:
            rows.append({"measurement_status": "retry_required"})
            continue
        rows.append({
            "measurement_status": "valid",
            "acoustic_latency_ms": learner_onset * math.exp(rng.normal(0, onset["recording_log_sd"])),
            "syllabic_event_mismatch": int(rng.poisson(cfg["beat_mismatch"][pattern])),
            "intra_word_silence_ratio": float(np.clip(silence + rng.normal(0, cfg["silence_noise_sd"]), 0, 0.9)),
            "local_jitter": jitter * math.exp(rng.normal(0, cfg["voice_noise_sd"])),
            "local_shimmer": shimmer * math.exp(rng.normal(0, cfg["voice_noise_sd"])),
        })
    return rows


def build_dataset(cfg):
    rng = np.random.default_rng(cfg["random_seed"])
    X, y, skipped = [], [], 0
    with TOUCH_FILE.open(encoding="utf-8") as handle:
        for line in handle:
            learner = json.loads(line)
            recordings = simulate_recordings(rng, learner, cfg)
            usable = [r for r in recordings if r["measurement_status"] == "valid"]
            age = round(learner["age_months"] / 12, 2)
            if evidence_gaps(len(usable), len(learner["motion_rows"]), age,
                             cfg["min_usable_recordings"], cfg["min_movement_sessions"]):
                skipped += 1
                continue
            values, _ = build_c3_inputs(usable, learner["motion_rows"], learner["c1_features"], age)
            X.append([math.nan if values[f] is None else float(values[f]) for f in FEATURES])
            y.append(CLASS_INDEX[learner["pattern"]])
    return np.asarray(X, dtype=float), np.asarray(y), skipped


def reliability(probs, y_true, bins=5):
    conf = probs.max(axis=1)
    correct = (probs.argmax(axis=1) == y_true).astype(float)
    edges = np.linspace(0, 1, bins + 1)
    table = []
    for lo, hi in zip(edges[:-1], edges[1:]):
        mask = (conf >= lo) & (conf < hi if hi < 1 else conf <= hi)
        if mask.any():
            table.append({"confidence": f"{lo:.1f}-{hi:.1f}", "learners": int(mask.sum()),
                          "mean_confidence": round(float(conf[mask].mean()), 3),
                          "observed_accuracy": round(float(correct[mask].mean()), 3)})
    return table


def main():
    cfg = yaml.safe_load((ROOT / "config" / "c3_simulation.yaml").read_text(encoding="utf-8"))
    ensure_touch_file()
    X, y, skipped = build_dataset(cfg)
    x_tr, x_te, y_tr, y_te = train_test_split(X, y, test_size=0.2, random_state=cfg["random_seed"], stratify=y)
    params = dict(objective="multi:softprob", num_class=4, n_estimators=300, max_depth=4, learning_rate=0.06,
                  subsample=0.9, colsample_bytree=0.9, min_child_weight=3, random_state=cfg["random_seed"])
    model = xgb.XGBClassifier(**params)
    model.fit(x_tr, y_tr)
    probs = model.predict_proba(x_te)
    pred = probs.argmax(axis=1)
    brier = float(np.mean([brier_score_loss((y_te == k).astype(int), probs[:, k]) for k in range(4)]))
    metrics = {
        "model": "C3 XGBoost (native missing values)", "model_version": "C3-v2.0",
        "feature_version": FEATURE_VERSION, "features": FEATURES, "class_names": CLASS_NAMES,
        "trained_at": datetime.now(timezone.utc).isoformat(),
        "training_data": "simulated learners: touch side via live C1/movement code, reading side simulated per recording",
        "simulator": cfg["version"], "learners_eligible": int(len(y)), "learners_below_evidence_rule": skipped,
        "learners_without_c1_evidence": int(np.isnan(X[:, FEATURES.index("c1_first_try_accuracy")]).sum()),
        "test_learners": int(len(y_te)),
        "accuracy": round(float(accuracy_score(y_te, pred)), 4),
        "macro_f1": round(float(f1_score(y_te, pred, average="macro")), 4),
        "mean_brier_score": round(brier, 4),
        "reliability": reliability(probs, y_te),
        "classification_report": classification_report(y_te, pred, target_names=CLASS_NAMES, output_dict=True),
        "limitations": [
            "Synthetic training only; reading features are simulated, not computed from audio.",
            "Separating simulated patterns is not clinical validity.",
            "No estimate is shown when a learner's inputs are outside the training ranges.",
        ],
    }
    # Deploy a model trained on all eligible learners.
    final = xgb.XGBClassifier(**params)
    final.fit(X, y)
    MODELS.mkdir(exist_ok=True)
    joblib.dump(final, MODELS / "xgboost_clinical_fusion.pkl")
    joblib.dump(list(FEATURES), MODELS / "feature_names.pkl")
    ranges = {}
    for j, name in enumerate(FEATURES):
        col = X[:, j][~np.isnan(X[:, j])]
        if col.size:
            ranges[name] = {"p01": float(np.percentile(col, 1)), "p99": float(np.percentile(col, 99))}
    (MODELS / "c3_feature_ranges.json").write_text(json.dumps({"feature_version": FEATURE_VERSION, "ranges": ranges}, indent=2), encoding="utf-8")
    (MODELS / "c3_model_metrics.json").write_text(json.dumps(metrics, indent=2), encoding="utf-8")
    print(json.dumps({k: metrics[k] for k in ("learners_eligible", "learners_below_evidence_rule",
                                              "learners_without_c1_evidence", "accuracy", "macro_f1",
                                              "mean_brier_score", "reliability")}, indent=2))


if __name__ == "__main__":
    main()
