import pytest
from services.ml.inference import predict_c1_pattern

def test_predict_c1_pattern_fallback():
    # Provide dummy features
    features_dict = {
        "accuracy": 0.8,
        "mean_latency_ms": 2000.0
    }
    
    result = predict_c1_pattern(features_dict)
    
    assert "model_name" in result
    assert "predicted_pattern" in result
    assert "probabilities" in result
    
    # Check that fallback is used if real model doesn't exist
    assert result["model_used"] in ["mock_fallback", "trained_random_forest"]
