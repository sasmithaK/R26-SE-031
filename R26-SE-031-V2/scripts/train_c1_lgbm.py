"""
scripts/train_c1_lgbm.py
=========================
LightGBM multi-output regression — C1 CBME MBSV prediction.

MODEL PURPOSE:
    Maps 13 raw behavioral features → 6 MBSV dimension scores [0,1].
    Each output is trained as an independent LightGBM regressor
    (scikit-learn MultiOutputRegressor wrapper).

FEATURE IMPORTANCE:
    LightGBM's gain-based feature importance is computed and saved to
    models/c1_lgbm_feature_importance.csv for SHAP-ready explainability.

METRICS (per target):
    - RMSE on 20% hold-out test set
    - R² (coefficient of determination)

Model saved to: models/c1_lgbm_mbsv.pkl  (joblib)

References:
    Ke, G. et al. (2017). LightGBM: A Highly Efficient Gradient Boosting
    Decision Tree. NeurIPS 2017.
    Shapley, L. S. (1953). A Value for n-Person Games. [Basis for SHAP]
"""

from __future__ import annotations
import sys, pickle
sys.stdout.reconfigure(encoding='utf-8')
from pathlib import Path
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.multioutput import MultiOutputRegressor
from sklearn.metrics import mean_squared_error, r2_score
import lightgbm as lgb

BASE      = Path(__file__).parent.parent
DATASETS  = BASE / "datasets"
MODELS    = BASE / "models"
MODELS.mkdir(exist_ok=True)

FEATURES = [
    "hesitation_ms", "correction_rate", "response_latency", "touch_pressure",
    "swipe_velocity", "replay_count", "hint_request_count", "stylus_deviation",
    "inter_tap_interval", "read_aloud_pause_ms", "syllable_rate",
    "disfluency_count", "kalman_innovation",
]
TARGETS = ["label_CLI", "label_PSI", "label_VSI", "label_FI", "label_ES", "label_ERI"]
TARGET_NAMES = ["CLI", "PSI", "VSI", "FI", "ES", "ERI"]


def train():
    print("[C1-LightGBM] Loading dataset...")
    df = pd.read_csv(DATASETS / "c1_behavioral_features.csv")
    print(f"  Rows: {len(df)}  |  Profile dist: {df.profile.value_counts().to_dict()}")

    X = df[FEATURES].values
    y = df[TARGETS].values

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )

    # LightGBM hyperparameters tuned for small tabular data
    base_model = lgb.LGBMRegressor(
        n_estimators=200,
        learning_rate=0.05,
        max_depth=6,
        num_leaves=31,
        min_child_samples=10,
        subsample=0.8,
        colsample_bytree=0.8,
        reg_alpha=0.1,
        reg_lambda=0.1,
        random_state=42,
        verbose=-1,
    )

    print("[C1-LightGBM] Training MultiOutputRegressor (6 MBSV targets)...")
    model = MultiOutputRegressor(base_model, n_jobs=-1)
    model.fit(X_train, y_train)

    # ── Evaluation ──────────────────────────────────────────────────────
    y_pred = model.predict(X_test)
    print("\n  Per-target metrics (test set):")
    print(f"  {'Target':<6}  {'RMSE':>7}  {'R²':>7}")
    print(f"  {'-'*24}")
    for i, name in enumerate(TARGET_NAMES):
        rmse = np.sqrt(mean_squared_error(y_test[:, i], y_pred[:, i]))
        r2   = r2_score(y_test[:, i], y_pred[:, i])
        print(f"  {name:<6}  {rmse:>7.4f}  {r2:>7.4f}")

    # ── Feature importance (average across estimators) ───────────────
    importances = np.zeros(len(FEATURES))
    for est in model.estimators_:
        importances += est.feature_importances_
    importances /= len(model.estimators_)
    fi_df = pd.DataFrame({"feature": FEATURES, "importance": importances})
    fi_df = fi_df.sort_values("importance", ascending=False)
    fi_path = MODELS / "c1_lgbm_feature_importance.csv"
    fi_df.to_csv(fi_path, index=False)
    print(f"\n  Top-3 features: {fi_df.feature.values[:3].tolist()}")

    # ── Save model ───────────────────────────────────────────────────
    out_path = MODELS / "c1_lgbm_mbsv.pkl"
    with open(out_path, "wb") as f:
        pickle.dump(model, f)
    print(f"\n[C1-LightGBM] Model saved → {out_path}")

    # ── Quick inference test ──────────────────────────────────────────
    sample = X_test[:1]
    pred   = model.predict(sample)[0]
    labels = dict(zip(TARGET_NAMES, [round(float(v), 4) for v in pred]))
    print(f"  Sample inference: {labels}")
    return model


if __name__ == "__main__":
    train()
