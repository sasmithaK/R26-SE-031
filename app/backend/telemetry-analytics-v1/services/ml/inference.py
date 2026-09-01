import json
import os
from .registry import registry
from .calibration import mock_predict

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
    
    # Construct feature vector based on canonical order
    feature_vector = []
    for f_name in FEATURE_SCHEMA.get("features", []):
        val = features_dict.get(f_name)
        # Use 0.0 for missing features (imputation strategy can be improved)
        feature_vector.append(val if val is not None else 0.0)

    # Try to load real model
    model = registry.load_model(model_name)
    
    if model:
        # Expected to be scikit-learn model
        import numpy as np
        X = np.array([feature_vector])
        
        # In a real model, classes_ maps to class_names correctly
        pred_idx = model.predict(X)[0]
        pred_probs = model.predict_proba(X)[0]
        
        predicted_class = class_names[pred_idx] if isinstance(pred_idx, int) else pred_idx
        probs_dict = {class_names[i]: round(float(pred_probs[i]), 3) for i in range(len(class_names))}
        
        return {
            "model_name": model_name,
            "model_version": version,
            "feature_schema_version": schema_version,
            "predicted_pattern": predicted_class,
            "probabilities": probs_dict,
            "confidence": probs_dict.get(predicted_class, 0.0),
            "model_used": "trained_random_forest"
        }
    else:
        # Fallback for dev/uncalibrated state
        predicted_class, probs_dict = mock_predict(feature_vector, class_names)
        return {
            "model_name": model_name,
            "model_version": version,
            "feature_schema_version": schema_version,
            "predicted_pattern": predicted_class,
            "probabilities": probs_dict,
            "confidence": probs_dict.get(predicted_class, 0.0),
            "model_used": "mock_fallback"
        }
