"""
scripts/train_c1_learner_type.py
=================================
Random Forest classifier — C1 CBME Learner Type (V/A/K) prediction.

MODEL PURPOSE:
    Classifies a child's dominant learning modality based on their interaction
    patterns: Visual (V), Auditory (A), or Kinesthetic (K).
    Output is used by C2 to bias initial typography arm selection.

FEATURES (7):
    replay_count, hint_request_count, stylus_deviation,
    swipe_velocity, read_aloud_pause_ms, disfluency_count, inter_tap_interval

METRICS:
    - Accuracy, macro-F1, per-class precision/recall on 20% hold-out
    - Confusion matrix printed to stdout

Model saved to: models/c1_learner_type_rf.pkl  (pickle)

References:
    Fleming, N. D. (2001). Teaching and Learning Styles: VARK Strategies.
    Dunn, R. & Dunn, K. (1978). Teaching Students Through Their Individual
        Learning Styles. Prentice-Hall.
    Breiman, L. (2001). Random Forests. Machine Learning, 45, 5-32.
"""

from __future__ import annotations
import sys, pickle
sys.stdout.reconfigure(encoding='utf-8')
from pathlib import Path
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split, StratifiedKFold, cross_val_score
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import (
    accuracy_score, f1_score, classification_report, confusion_matrix
)

BASE     = Path(__file__).parent.parent
DATASETS = BASE / "datasets"
MODELS   = BASE / "models"
MODELS.mkdir(exist_ok=True)

FEATURES = [
    "replay_count", "hint_request_count", "stylus_deviation",
    "swipe_velocity", "read_aloud_pause_ms", "disfluency_count",
    "inter_tap_interval",
]
TARGET = "learner_type"


def train():
    print("[C1-RandomForest] Loading learner type dataset...")
    df = pd.read_csv(DATASETS / "c1_learner_type_labels.csv")
    print(f"  Rows: {len(df)}  |  Class dist: {df[TARGET].value_counts().to_dict()}")

    X = df[FEATURES].values
    le = LabelEncoder()
    y = le.fit_transform(df[TARGET].values)   # V→2, A→0, K→1 (sorted)

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    model = RandomForestClassifier(
        n_estimators=200,
        max_depth=10,
        min_samples_leaf=5,
        class_weight="balanced",
        random_state=42,
        n_jobs=-1,
    )

    print("[C1-RandomForest] Training (5-fold CV)...")
    cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
    cv_scores = cross_val_score(model, X_train, y_train, cv=cv, scoring="f1_macro")
    print(f"  CV macro-F1: {cv_scores.mean():.4f} ± {cv_scores.std():.4f}")

    model.fit(X_train, y_train)
    y_pred = model.predict(X_test)

    acc  = accuracy_score(y_test, y_pred)
    f1   = f1_score(y_test, y_pred, average="macro")
    print(f"\n  Test accuracy: {acc:.4f}  |  Test macro-F1: {f1:.4f}")
    print("\n  Classification report:")
    print(classification_report(y_test, y_pred, target_names=le.classes_))

    cm = confusion_matrix(y_test, y_pred)
    print("  Confusion matrix (rows=true, cols=pred):")
    header = "       " + "  ".join(f"{c:>4}" for c in le.classes_)
    print(header)
    for i, row in enumerate(cm):
        print(f"  {le.classes_[i]:>4}  " + "  ".join(f"{v:>4}" for v in row))

    # Feature importance
    fi = sorted(zip(FEATURES, model.feature_importances_), key=lambda x: -x[1])
    print(f"\n  Top features: {[f for f,_ in fi[:3]]}")

    # Save model + encoder together
    artifact = {"model": model, "label_encoder": le, "features": FEATURES}
    out_path = MODELS / "c1_learner_type_rf.pkl"
    with open(out_path, "wb") as f:
        pickle.dump(artifact, f)
    print(f"\n[C1-RandomForest] Model saved → {out_path}")

    # Quick inference test
    sample = X_test[:1]
    pred_class = le.inverse_transform(model.predict(sample))[0]
    proba = model.predict_proba(sample)[0]
    print(f"  Sample: predicted={pred_class}  proba={dict(zip(le.classes_, [round(float(p),3) for p in proba]))}")
    return artifact


if __name__ == "__main__":
    train()
