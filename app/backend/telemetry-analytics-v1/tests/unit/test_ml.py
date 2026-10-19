import pytest
from services.ml.inference import predict_c1_pattern

def test_predict_c1_pattern_never_returns_random_fallback():
    # Provide dummy features
    features_dict = {
        "accuracy": 0.8,
        "mean_latency_ms": 2000.0
    }
    
    result = predict_c1_pattern(features_dict)
    
    assert "model_name" in result
    assert "predicted_pattern" in result
    assert "probabilities" in result
    
    assert result["model_used"] in ["unavailable", "trained_random_forest_synthetic_only"]
    assert result["model_used"] != "mock_fallback"
    if result["model_used"] == "unavailable":
        assert result["predicted_pattern"] is None
        assert result["probabilities"] == {}
