"""
services/ml_comparative.py
===========================
Comparative ML training and evaluation module.
Trains Random Forest, XGBoost, Logistic Regression, and a Stacking Ensemble
on clinician-labelled telemetry data using cost-sensitive learning.
"""

import os
import joblib
import numpy as np
from typing import Dict, Any, List

from sklearn.ensemble import RandomForestClassifier, StackingClassifier
from sklearn.linear_model import LogisticRegression
from xgboost import XGBClassifier
from sklearn.model_selection import StratifiedKFold, cross_val_predict
from sklearn.metrics import classification_report
from sklearn.preprocessing import LabelEncoder, StandardScaler

from sklearn.pipeline import Pipeline

import json as _json

_SCHEMA_PATH = os.path.join(os.path.dirname(__file__), "..", "config", "c1_features.json")
with open(_SCHEMA_PATH, "r", encoding="utf-8") as _schema_file:
    # Same 19-feature contract as the live C1 model (config/c1_features.json).
    FEATURE_COLUMNS = _json.load(_schema_file)["features"]

PATTERN_LABELS = (
    "TYPICAL",
    "VISUAL_ORTHOGRAPHIC_PATTERN",
    "PHONOLOGICAL_PATTERN",
    "COMBINED_PATTERN",
)

def build_balanced_pipeline(base_model):
    """Wrap any sklearn model with standard scaling. (Class balancing is handled via algorithm parameters)."""
    return Pipeline([
        ("scaler", StandardScaler()),
        ("model", base_model),
    ])

def build_stacking_ensemble():
    """
    Stacking ensemble: RF + XGBoost + LogReg -> Meta LogReg.
    Each base model outputs class probabilities that feed into the meta-learner.
    """
    estimators = [
        ("rf", RandomForestClassifier(
            n_estimators=100, max_depth=8, class_weight="balanced", random_state=42
        )),
        ("xgb", XGBClassifier(
            n_estimators=100, max_depth=6, scale_pos_weight=3,
            eval_metric="mlogloss", random_state=42
        )),
        ("lr", LogisticRegression(
            max_iter=1000, class_weight="balanced", random_state=42
        )),
    ]

    stacking_model = StackingClassifier(
        estimators=estimators,
        final_estimator=LogisticRegression(max_iter=1000, random_state=42),
        stack_method="predict_proba",
        cv=5,
        passthrough=False,
    )

    return build_balanced_pipeline(stacking_model)

def train_and_compare(features_list: List[Dict[str, float]], labels_list: List[str], output_dir: str = "staging") -> Dict[str, Any]:
    """
    Trains and compares multiple models using Stratified K-Fold CV.
    Returns metrics and saves the models to the specified staging directory to comply with PCCP.
    """
    if len(labels_list) < 15:
        return {"error": "Need at least 15 labelled samples to perform 5-fold CV."}

    # Prepare data arrays
    # Rows with a missing feature are dropped rather than filled with 0.
    kept = [
        (f, label) for f, label in zip(features_list, labels_list)
        if all(isinstance(f.get(col), (int, float)) for col in FEATURE_COLUMNS)
    ]
    if len(kept) < 15:
        return {"error": "Fewer than 15 complete labelled feature vectors."}
    features_list = [f for f, _ in kept]
    labels_list = [label for _, label in kept]
    X = np.array([[float(f[col]) for col in FEATURE_COLUMNS] for f in features_list])
    
    le = LabelEncoder()
    y = le.fit_transform(labels_list) 
    
    models = {
        "Random Forest": build_balanced_pipeline(
            RandomForestClassifier(n_estimators=100, max_depth=8, random_state=42)
        ),
        "XGBoost": build_balanced_pipeline(
            XGBClassifier(n_estimators=100, max_depth=6, eval_metric="mlogloss", random_state=42)
        ),
        "Logistic Regression": build_balanced_pipeline(
            LogisticRegression(max_iter=1000, random_state=42)
        ),
        "Stacking Ensemble": build_stacking_ensemble()
    }
    
    results = {}
    skf = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
    
    # Ensure staging directory exists for PCCP compliance
    os.makedirs(output_dir, exist_ok=True)
    
    # Save the label encoder so prediction phase knows the classes
    joblib.dump(le, f"{output_dir}/label_encoder.pkl")
    
    for name, model in models.items():
        try:
            # 1. Evaluate with cross-validation
            y_pred = cross_val_predict(model, X, y, cv=skf)
            report = classification_report(y, y_pred, target_names=le.classes_, output_dict=True)
            results[name] = report
            
            # 2. Train final model on full dataset
            model.fit(X, y)
            
            # 3. Save model artifact to staging (avoid hot-swapping)
            filename = name.lower().replace(' ', '_')
            joblib.dump(model, f"{output_dir}/{filename}.pkl")
        except Exception as e:
            results[name] = {"error": str(e)}
    
    return results
