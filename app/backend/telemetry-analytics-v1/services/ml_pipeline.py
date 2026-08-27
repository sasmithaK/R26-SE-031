"""
services/ml_pipeline.py
========================
Machine Learning Analytics Pipeline for Dyslexia / Dyspraxia Cognitive Profiling.

Feature Extraction → Cognitive Index Computation → Risk Classification

This module processes raw telemetry events stored in MongoDB and produces
a structured cognitive profile per student, including:
  - Visual Processing Score
  - Phonological Awareness Score
  - Motor Precision Score
  - Sustained Attention Score
  - Fatigue Drift
  - Dyslexia subtype risk classification
"""

from __future__ import annotations

import math
import statistics
import os
import joblib
from typing import Any, Optional
import numpy as np
from sklearn.ensemble import RandomForestClassifier

from services.comp2_kinematics import extract_comp2_features


# ---------------------------------------------------------------------------
# Cognitive Index Tags — maps activity template types to cognitive domains
# ---------------------------------------------------------------------------
VISUAL_SKILLS_TEMPLATES = {
    "hidden_picture_game",
    "spot_difference",
    "shape_match",
    "visual_tracking",
    "pattern_completion",
}

PHONOLOGICAL_TEMPLATES = {
    "syllable_tap",
    "word_match",
    "letter_sound",
    "rhyme_sort",
    "phoneme_blend",
}

MOTOR_TEMPLATES = {
    "trace_letter",
    "drag_drop",
    "connect_dots",
    "shape_trace",
}


# ---------------------------------------------------------------------------
# Feature Extraction
# ---------------------------------------------------------------------------

def extract_features(events: list[dict[str, Any]]) -> dict[str, float]:
    """
    Compute the 6-dimensional cognitive feature vector from a list of
    raw TelemetryEvent dicts (as stored in MongoDB).

    Returns a dict with keys:
        visual_processing_speed   — higher = faster visual search
        motor_precision           — 0-100, penalised for misclicks
        hesitation_ratio          — average hesitations per round
        accuracy_slope            — linear trend in correctness (positive = improving)
        phonological_latency      — avg first-touch latency on phonological activities
        fatigue_drift             — latency difference between last-3 vs first-3 rounds
    """
    if not events:
        return _zero_features()

    n = len(events)

    # ---- Visual Processing Speed -------------------------------------------
    visual_events = [e for e in events if e.get("activity_name") in VISUAL_SKILLS_TEMPLATES]
    if visual_events:
        avg_ftl = statistics.mean(
            e.get("first_touch_latency_ms", 1500) for e in visual_events
        )
        # Logistic curve: Midpoint at 3500ms, smooth degradation
        visual_processing_speed = 100.0 / (1.0 + math.exp((avg_ftl - 3500) / 800))
    else:
        visual_processing_speed = 50.0  # neutral when no data

    # ---- Motor Precision Score ----------------------------------------------
    total_taps = 0
    for e in events:
        path = e.get("touch_path", [])
        # Only count discrete taps/downs, fallback to path length if old data
        taps = sum(1 for p in path if p.get("type", "tap") in ("tap", "down"))
        total_taps += taps if taps > 0 else len(path)
        
    total_misclicks = sum(e.get("misclick_count", 0) for e in events)
    if total_taps > 0:
        motor_precision = max(0.0, (1 - total_misclicks / total_taps) * 100)
    else:
        motor_precision = 100.0  # default if no touch data

    # ---- Cognitive Hesitation Ratio ----------------------------------------
    hesitation_ratio = statistics.mean(
        e.get("hesitation_count", 0) for e in events
    )

    # ---- Accuracy Slope (linear regression) --------------------------------
    if n >= 2:
        scores = [e.get("score", 0) for e in events]
        x_mean = (n - 1) / 2
        y_mean = statistics.mean(scores)
        numerator = sum((i - x_mean) * (scores[i] - y_mean) for i in range(n))
        denominator = sum((i - x_mean) ** 2 for i in range(n))
        accuracy_slope = numerator / denominator if denominator != 0 else 0.0
    else:
        accuracy_slope = 0.0

    # ---- Phonological Latency ----------------------------------------------
    phono_events = [e for e in events if e.get("activity_name") in PHONOLOGICAL_TEMPLATES]
    if phono_events:
        phonological_latency = statistics.mean(
            e.get("first_touch_latency_ms", 1500) for e in phono_events
        )
    else:
        phonological_latency = 1500.0  # neutral baseline

    # ---- Fatigue Drift (last-3 vs first-3 latency delta) -------------------
    if n >= 6:
        early_latency = statistics.mean(
            e.get("total_round_latency_ms", 0) for e in events[:3]
        )
        late_latency = statistics.mean(
            e.get("total_round_latency_ms", 0) for e in events[-3:]
        )
        # Relative fatigue: percentage slowdown
        fatigue_drift = ((late_latency / early_latency) - 1.0) if early_latency > 0 else 0.0
    else:
        fatigue_drift = 0.0

    return {
        "visual_processing_speed": round(visual_processing_speed, 2),
        "motor_precision": round(motor_precision, 2),
        "hesitation_ratio": round(hesitation_ratio, 3),
        "accuracy_slope": round(accuracy_slope, 3),
        "phonological_latency": round(phonological_latency, 2),
        "fatigue_drift": round(fatigue_drift, 2),
    }


# ---------------------------------------------------------------------------
# Cognitive Index Computation (0-100 scores for each domain)
# ---------------------------------------------------------------------------

def compute_cognitive_indices(features: dict[str, float]) -> dict[str, float]:
    """
    Convert raw feature vector into normalized 0-100 cognitive index scores
    for presentation in the parent analytics dashboard.
    """
    visual_processing_score = _clamp(features["visual_processing_speed"])

    # Motor precision is already 0-100
    motor_precision_score = _clamp(features["motor_precision"])

    # Phonological score: Logistic curve with midpoint at 4000ms
    phonological_latency = features["phonological_latency"]
    phonological_awareness_score = 100.0 / (1.0 + math.exp((phonological_latency - 4000) / 1000))

    # Sustained attention: Exponential decay based on hesitation ratio
    sustained_attention_score = _clamp(100.0 * math.exp(-features["hesitation_ratio"] / 2.0))

    return {
        "visual_processing_score": round(visual_processing_score, 1),
        "phonological_awareness_score": round(phonological_awareness_score, 1),
        "motor_precision_score": round(motor_precision_score, 1),
        "sustained_attention_score": round(sustained_attention_score, 1),
    }


# ---------------------------------------------------------------------------
# Risk Classifier — Rule-Based (upgradeable to sklearn RandomForest)
# ---------------------------------------------------------------------------

import os
import joblib

# Optional: define path to ML model
MODEL_PATH = os.path.join(os.path.dirname(__file__), "..", "models", "dyslexia_rf_model.pkl")

def classify_risk(
    features: dict[str, float],
    indices: dict[str, float],
) -> dict[str, str]:
    """
    Classify dyslexia subtype risk levels from feature vector and cognitive indices.

    If a trained Scikit-Learn model exists at MODEL_PATH, it uses the Random Forest
    to predict probabilities. Otherwise, it falls back to the clinical heuristic rules.
    """
    if os.path.exists(MODEL_PATH):
        try:
            model = joblib.load(MODEL_PATH)
            # Feature ordering must match training (assuming alphabetical for simplicity in this stub)
            # In production, use a DictVectorizer or Pandas DataFrame to guarantee order
            feature_keys = sorted(list(features.keys()))
            x_input = [[features[k] for k in feature_keys]]
            
            # Predict
            prediction = model.predict(x_input)[0]  # e.g. 0=Low, 1=Moderate, 2=High
            
            risk_map = {0: "Low", 1: "Moderate", 2: "High"}
            overall_risk = risk_map.get(prediction, "Moderate")
            
            return {
                "overall_risk": overall_risk,
                "dyslexia_risk": overall_risk,
                "dyspraxia_risk": overall_risk,
                "adhd_risk": overall_risk,
                "model_used": "RandomForest"
            }
        except Exception as e:
            # Fallback on error
            pass

    # --- FALLBACK HEURISTIC RULES ---
    """
    Classify dyslexia subtype risk levels from feature vector and cognitive indices.

    Risk categories: 'Low' | 'Moderate' | 'High'

    This uses interpretable rule-based thresholds derived from educational
    psychology research on early childhood learning difficulty indicators.
    Intended to be replaced / enhanced with a trained sklearn model once
    enough labelled data accumulates.
    """
    visual_risk = _threshold_risk(
        score=indices["visual_processing_score"],
        high_threshold=40,
        moderate_threshold=65,
    )
    phonological_risk = _threshold_risk(
        score=indices["phonological_awareness_score"],
        high_threshold=40,
        moderate_threshold=65,
    )
    motor_risk = _threshold_risk(
        score=indices["motor_precision_score"],
        high_threshold=50,
        moderate_threshold=72,
    )
    attention_risk = _threshold_risk(
        score=indices["sustained_attention_score"],
        high_threshold=45,
        moderate_threshold=68,
    )

    # Overall risk — highest individual component risk determines overall
    risk_levels = [visual_risk, phonological_risk, motor_risk, attention_risk]
    if "High" in risk_levels:
        overall = "Needs Attention"
    elif risk_levels.count("Moderate") >= 2:
        overall = "Moderate Risk"
    else:
        overall = "Low Risk"

    return {
        "overall_risk": overall,
        "visual_dyslexia_risk": visual_risk,
        "phonological_dyslexia_risk": phonological_risk,
        "motor_dysgraphia_risk": motor_risk,
        "attention_risk": attention_risk,
    }


# ---------------------------------------------------------------------------
# Intervention Recommendation Engine
# ---------------------------------------------------------------------------

def generate_interventions(
    risk: dict[str, str],
    features: dict[str, float],
) -> list[str]:
    """
    Generate a list of personalized skill-specific intervention recommendations
    based on the child's risk profile.
    """
    interventions: list[str] = []

    if risk["visual_dyslexia_risk"] in ("Moderate", "High"):
        interventions.append(
            "Increase practice on Visual Skills (Skills 1 & 2) - "
            "Spot the Difference and Hidden Picture activities improve visual scanning."
        )

    if risk["phonological_dyslexia_risk"] in ("Moderate", "High"):
        interventions.append(
            "Focus on Phonological Awareness activities (Skills 5 & 6) - "
            "Syllable tapping and letter-sound matching exercises strengthen phonemic awareness."
        )

    if risk["motor_dysgraphia_risk"] in ("Moderate", "High"):
        interventions.append(
            "Practice Letter Tracing activities (Skill 3) — "
            "Fine motor control exercises improve pen grip and letter formation."
        )

    if risk["attention_risk"] in ("Moderate", "High"):
        interventions.append(
            "Consider shorter, more frequent learning sessions (5-10 minutes) "
            "to reduce cognitive fatigue and improve sustained attention."
        )

    if features["fatigue_drift"] > 1500:
        interventions.append(
            "The child shows significant fatigue during longer activity sessions. "
            "Enabling the Daily Limit feature is recommended."
        )

    if features["accuracy_slope"] < -2.0:
        interventions.append(
            "Accuracy tends to decline across rounds within a session — "
            "this may indicate frustration or difficulty. Consider enabling easier levels."
        )

    if not interventions:
        interventions.append(
            "Great progress! Continue the current learning plan. "
            "Review completed skills weekly to reinforce retention."
        )

    return interventions


from services.feature_engineering import extract_advanced_features


# ---------------------------------------------------------------------------
# Full Pipeline Entry Point
# ---------------------------------------------------------------------------

def normalize_features_for_device(features: dict[str, Any], device_metrics: dict[str, Any]) -> dict[str, Any]:
    """Normalize kinematics and physical bounds based on the device."""
    if not device_metrics:
        return features

    os_type = device_metrics.get("os", "unknown")
    model = device_metrics.get("model", "").lower()
    
    # Rough heuristics for normalization: iPads/Tablets require larger physical drags.
    scalar = 1.0
    if "ipad" in model or "tablet" in model:
        scalar = 0.85
    elif os_type == "android" or "iphone" in model:
        scalar = 1.15
        
    normalized = features.copy()
    if "avg_jerkiness" in normalized:
        normalized["avg_jerkiness"] = round(normalized["avg_jerkiness"] * scalar, 4)
    if "avg_velocity" in normalized:
        normalized["avg_velocity"] = round(normalized["avg_velocity"] * (1 / scalar), 4)
        
    return normalized

def generate_cognitive_profile(
    telemetry_sessions: list[dict[str, Any]], 
    assessment_risk_score: float = 0.0
) -> dict[str, Any]:
    """
    Full end-to-end ML analytics pipeline.
    """
    all_events: list[dict[str, Any]] = []
    latest_device_metrics = {}
    
    for session in telemetry_sessions:
        all_events.extend(session.get("events", []))
        if session.get("device_metrics"):
            latest_device_metrics = session.get("device_metrics")

    base_features = extract_features(all_events)
    advanced_features = extract_advanced_features(all_events)
    
    # Normalize features using device metrics
    advanced_features = normalize_features_for_device(advanced_features, latest_device_metrics)
    
    # Combine into 19-dimensional feature vector (STT features stubbed for now)
    features = {
        **base_features,
        **advanced_features,
        "word_error_rate": 0.0,
        "voice_hesitation_ms": 0.0,
        "assessment_risk_score": round(assessment_risk_score, 4),
    }

    # Cognitive indices currently only use the base features
    indices = compute_cognitive_indices(base_features)
    risk = classify_risk(base_features, indices)
    interventions = generate_interventions(risk, base_features)

    return {
        "feature_vector": features,
        "cognitive_indices": indices,
        "risk_assessment": risk,
        "recommended_interventions": interventions,
        "data_points": len(all_events),
    }

# ---------------------------------------------------------------------------
# Component 2: Visual-Orthographic Tabular ML Pipeline
# ---------------------------------------------------------------------------

def generate_comp2_profile(telemetry_sessions: list[dict[str, Any]]) -> dict[str, Any]:
    """
    Component 2 Engine: Extracts rigorous kinematic features and runs them through
    a Random Forest classifier to output the visual dyslexia risk score.
    """
    all_events: list[dict[str, Any]] = []
    student_id = "unknown"
    for session in telemetry_sessions:
        if student_id == "unknown":
            student_id = session.get("student_id", "unknown")
        all_events.extend(session.get("events", []))
        
    visual_feature_vector = extract_comp2_features(all_events)
    
    # Machine Learning Classification (Tabular ML)
    # 1. Load model if exists
    risk_score = 0.5 # Default moderate
    model_path = os.path.join(os.path.dirname(__file__), "..", "models", "comp2_rf_model.pkl")
    
    # Ordered features for the model
    feature_arr = [
        visual_feature_vector.get("time_to_first_touch_ms", 0),
        visual_feature_vector.get("orthographic_confusion_index", 0),
        visual_feature_vector.get("path_efficiency_ratio", 1),
        visual_feature_vector.get("dimensionless_jerk", 0),
        visual_feature_vector.get("mean_dwell_time_ms", 0)
    ]
    
    if os.path.exists(model_path):
        try:
            model = joblib.load(model_path)
            prediction = model.predict_proba([feature_arr])[0][1] # Probability of being dyslexic
            risk_score = round(prediction, 2)
        except Exception:
            risk_score = _heuristic_comp2_risk(visual_feature_vector)
    else:
        # Fallback to heuristic risk scoring if model isn't trained yet
        risk_score = _heuristic_comp2_risk(visual_feature_vector)
        
    visual_feature_vector["visual_dyslexia_risk_score"] = risk_score
    
    return {
        "student_id": student_id,
        "component": "Component_2_Visual_Orthographic",
        "visual_feature_vector": visual_feature_vector
    }

def _heuristic_comp2_risk(features: dict[str, float]) -> float:
    # A heuristic mimicking the RF until data is trained
    oci = features.get("orthographic_confusion_index", 0.0)
    pe = features.get("path_efficiency_ratio", 1.0)
    
    risk = 0.0
    if oci > 0.6:
        risk += 0.4
    if pe < 0.7:
        risk += 0.3
        
    return min(1.0, round(risk, 2))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _clamp(value: float, lo: float = 0.0, hi: float = 100.0) -> float:
    return max(lo, min(hi, value))


def _threshold_risk(score: float, high_threshold: float, moderate_threshold: float) -> str:
    if score < high_threshold:
        return "High"
    if score < moderate_threshold:
        return "Moderate"
    return "Low"


def _zero_features() -> dict[str, float]:
    return {
        "visual_processing_speed": 50.0,
        "motor_precision": 100.0,
        "hesitation_ratio": 0.0,
        "accuracy_slope": 0.0,
        "phonological_latency": 1500.0,
        "fatigue_drift": 0.0,
    }
