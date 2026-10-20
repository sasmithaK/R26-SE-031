import json
import os
import math
from .registry import registry

def get_feature_schema():
    schema_path = os.path.join(os.path.dirname(__file__), "..", "..", "config", "c1_features.json")
    if os.path.exists(schema_path):
        with open(schema_path, "r") as f:
            return json.load(f)
    return {"features": []}

FEATURE_SCHEMA = get_feature_schema()

def predict_c1_pattern(features_dict: dict) -> dict:
    """
    Takes the extracted behavioral features dict and runs ML inference.
    Returns the populated model metadata for the C1 Result.
    """
    model_name = "c1_random_forest"
    config = registry.get_config(model_name)
    
    class_names = config.get("class_names", [
        "TYPICAL", 
        "VISUAL_ORTHOGRAPHIC_PATTERN", 
        "PHONOLOGICAL_PATTERN", 
        "COMBINED_PATTERN"
    ])
    version = config.get("version", "unknown")
    schema_version = config.get("feature_schema", "unknown")
    
    # A classifier prediction is valid only when every canonical measurement
    # exists. Missingness is returned explicitly; it is never imputed to zero
    # or a neutral-looking value.
    feature_vector = []
    missing_features = []
    for f_name in FEATURE_SCHEMA.get("features", []):
        val = features_dict.get(f_name)
        if isinstance(val, bool) or not isinstance(val, (int, float)) or not math.isfinite(float(val)):
            missing_features.append(f_name)
        else:
            feature_vector.append(float(val))

    if not FEATURE_SCHEMA.get("features"):
        missing_features = ["feature_schema"]

    if missing_features:
        return {
            "model_name": model_name,
            "model_version": version,
            "feature_schema_version": schema_version,
            "predicted_pattern": None,
            "probabilities": {},
            "confidence": None,
            "model_used": "unavailable",
            "unavailable_reason": "required C1 features are missing or non-finite",
            "missing_feature_count": len(missing_features),
            "missing_features": missing_features,
        }

    # Try to load real model
    model = registry.load_model(model_name)
    
    if model:
        # Expected to be scikit-learn model
        import numpy as np
        X = np.array([feature_vector])
        
        # In a real model, classes_ maps to class_names correctly
        expected_features = getattr(model, "n_features_in_", len(feature_vector))
        artifact_schema = getattr(model, "sipsara_feature_schema", None)
        artifact_features = getattr(model, "sipsara_feature_names", None)
        if expected_features != len(feature_vector):
            return {
                "model_name": model_name,
                "model_version": version,
                "feature_schema_version": schema_version,
                "predicted_pattern": None,
                "probabilities": {},
                "confidence": None,
                "model_used": "unavailable",
                "unavailable_reason": (
                    f"artifact expects {expected_features} features; schema provides "
                    f"{len(feature_vector)}"
                ),
            }
        if artifact_schema and artifact_schema != FEATURE_SCHEMA.get("schema_version"):
            return {
                "model_name": model_name, "model_version": version,
                "feature_schema_version": schema_version, "predicted_pattern": None,
                "probabilities": {}, "confidence": None, "model_used": "unavailable",
                "unavailable_reason": "artifact schema does not match the live C1 schema",
            }
        if artifact_features and list(artifact_features) != FEATURE_SCHEMA.get("features", []):
            return {
                "model_name": model_name, "model_version": version,
                "feature_schema_version": schema_version, "predicted_pattern": None,
                "probabilities": {}, "confidence": None, "model_used": "unavailable",
                "unavailable_reason": "artifact feature order does not match the live C1 schema",
            }

        pred_idx = model.predict(X)[0]
        pred_probs = model.predict_proba(X)[0]
        
        model_classes = list(getattr(model, "classes_", range(len(pred_probs))))
        if pred_idx in class_names:
            predicted_class = str(pred_idx)
        else:
            predicted_class = class_names[int(pred_idx)]
        probs_dict = {
            (str(label) if label in class_names else class_names[int(label)]): round(float(probability), 3)
            for label, probability in zip(model_classes, pred_probs)
        }
        
        return {
            "model_name": model_name,
            "model_version": version,
            "feature_schema_version": schema_version,
            "predicted_pattern": predicted_class,
            "probabilities": probs_dict,
            "confidence": probs_dict.get(predicted_class, 0.0),
            "model_used": "trained_random_forest_model",
            "model_provenance": config.get("provenance", "unknown"),
            "missing_feature_count": 0,
            "missing_features": [],
        }
    return {
        "model_name": model_name,
        "model_version": version,
        "feature_schema_version": schema_version,
        "predicted_pattern": None,
        "probabilities": {},
        "confidence": None,
        "model_used": "unavailable",
        "unavailable_reason": config.get(
            "disabled_reason", "configured model artifact was not found"
        ),
    }
