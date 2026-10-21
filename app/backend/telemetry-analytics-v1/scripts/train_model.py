"""Train C1's synthetic-only RF against the live 19-feature contract."""
import json
from pathlib import Path

import joblib
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, classification_report
from sklearn.model_selection import train_test_split

ROOT = Path(__file__).resolve().parents[1]
MODEL_PATH = ROOT / "models" / "dyslexia_rf_model.pkl"
METRICS_PATH = ROOT / "models" / "c1_random_forest_synthetic_metrics.json"
SCHEMA_PATH = ROOT / "config" / "c1_features.json"
RANDOM_SEED = 42
CLASS_NAMES = ["TYPICAL", "VISUAL_ORTHOGRAPHIC_PATTERN", "PHONOLOGICAL_PATTERN", "COMBINED_PATTERN"]


def schema_features():
    return json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))["features"]


def u(rng, low, high):
    return float(rng.uniform(low, high))


def sample_row(rng, label):
    """Synthetic values use exactly the units emitted by C1's live processor."""
    if label == 0:
        acc, lat, hes, mis, replay, fat, load = u(rng,.75,.98),u(rng,900,2600),u(rng,0,.35),u(rng,0,.12),u(rng,0,.18),u(rng,0,.20),u(rng,0,.35)
        visual, phono, motor, attention = u(rng,65,98),u(rng,60,98),u(rng,70,100),u(rng,70,100)
    elif label == 1:
        acc, lat, hes, mis, replay, fat, load = u(rng,.38,.78),u(rng,2300,5200),u(rng,.15,.80),u(rng,.10,.60),u(rng,0,.35),u(rng,.08,.55),u(rng,.28,.78)
        visual, phono, motor, attention = u(rng,15,62),u(rng,55,95),u(rng,30,82),u(rng,35,85)
    elif label == 2:
        acc, lat, hes, mis, replay, fat, load = u(rng,.35,.75),u(rng,2500,5800),u(rng,.12,.78),u(rng,.03,.35),u(rng,.12,.85),u(rng,.08,.58),u(rng,.30,.80)
        visual, phono, motor, attention = u(rng,50,94),u(rng,12,60),u(rng,50,94),u(rng,35,85)
    else:
        acc, lat, hes, mis, replay, fat, load = u(rng,.10,.55),u(rng,4500,8500),u(rng,.60,2.20),u(rng,.25,1.00),u(rng,.25,1.00),u(rng,.35,1.00),u(rng,.65,1.00)
        visual, phono, motor, attention = u(rng,2,45),u(rng,2,45),u(rng,0,65),u(rng,5,60)
    return {
        "accuracy":acc, "mean_latency_ms":lat, "median_latency_ms":lat*u(rng,.80,1.04),
        "latency_std_ms":lat*u(rng,.08,.32), "mean_first_touch_latency_ms":lat*u(rng,.58,.92),
        "hesitation_rate":hes, "misclick_rate":mis, "replay_rate":replay,
        "completion_rate":u(rng,max(.30,acc),1.0),
        "latency_drift":u(rng,-.15,.12) if label == 0 else u(rng,-.05,.75),
        "error_drift":u(rng,-.15,.10) if label == 0 else u(rng,-.05,.70),
        "hesitation_drift":u(rng,-.15,.12) if label == 0 else u(rng,-.05,.70),
        "accuracy_slope":u(rng,-.05,.22) if label == 0 else u(rng,-.55,.08),
        "visual_processing_index":visual, "phonological_task_index":phono,
        "motor_interaction_index":motor, "attention_stability_index":attention,
        "fatigue_score":fat, "cognitive_load_score":load,
    }


def generate_synthetic_data(samples_per_class=750):
    features, rng = schema_features(), np.random.default_rng(RANDOM_SEED)
    rows, labels = [], []
    for label in range(len(CLASS_NAMES)):
        for _ in range(samples_per_class):
            row = sample_row(rng, label)
            rows.append([row[name] for name in features]); labels.append(label)
    return np.asarray(rows, dtype=float), np.asarray(labels, dtype=int), features


def train():
    X, y, features = generate_synthetic_data()
    x_train, x_test, y_train, y_test = train_test_split(X, y, test_size=.20, random_state=RANDOM_SEED, stratify=y)
    model = RandomForestClassifier(n_estimators=300, max_depth=10, min_samples_leaf=2, random_state=RANDOM_SEED, class_weight="balanced_subsample", n_jobs=-1)
    model.fit(x_train, y_train)
    predicted = model.predict(x_test)
    metrics = {
        "model":"c1_random_forest", "model_version":"2.0.0", "training_data":"synthetic_only",
        "random_seed":RANDOM_SEED, "feature_schema":"c1-features-v1", "feature_count":len(features),
        "features":features, "samples":int(len(X)), "test_samples":int(len(x_test)),
        "accuracy":round(float(accuracy_score(y_test,predicted)),4),
        "classification_report":classification_report(y_test,predicted,target_names=CLASS_NAMES,output_dict=True,zero_division=0),
    }
    model.sipsara_feature_schema = "c1-features-v1"
    model.sipsara_feature_names = features
    model.sipsara_training_data = "synthetic_only"
    MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump(model, MODEL_PATH)
    METRICS_PATH.write_text(json.dumps(metrics,indent=2),encoding="utf-8")
    print(json.dumps({key:metrics[key] for key in ("model_version","feature_count","samples","accuracy")},indent=2))


if __name__ == "__main__":
    train()
