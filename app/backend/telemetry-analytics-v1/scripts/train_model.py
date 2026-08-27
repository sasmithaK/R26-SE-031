import os
import json
import numpy as np
import joblib
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, accuracy_score

# Ensure models directory exists
MODELS_DIR = os.path.join(os.path.dirname(__file__), "..", "models")
os.makedirs(MODELS_DIR, exist_ok=True)
MODEL_PATH = os.path.join(MODELS_DIR, "dyslexia_rf_model.pkl")

# The exact 18 features expected by the pipeline, sorted alphabetically
FEATURE_KEYS = sorted([
    "abandonment_rate",
    "accuracy_drift",
    "accuracy_slope",
    "assessment_risk_score",
    "audio_dependency_score",
    "avg_jerkiness",
    "fatigue_drift",
    "first_touch_variability",
    "hesitation_ratio",
    "misclick_trend_slope",
    "motor_precision",
    "phonological_latency",
    "response_consistency",
    "session_duration_ratio",
    "touch_cluster_count",
    "visual_processing_speed",
    "voice_hesitation_ms",
    "word_error_rate"
])

def generate_synthetic_data(num_samples: int = 1000):
    """Generate synthetic telemetry features mimicking neurotypical and neurodivergent patterns."""
    X = []
    y = []
    
    for _ in range(num_samples):
        # 0 = Low Risk (Neurotypical), 1 = Moderate Risk, 2 = High Risk (Dyslexia/Dyspraxia)
        risk = np.random.choice([0, 1, 2], p=[0.6, 0.25, 0.15])
        
        # Base distributions depending on risk level
        # A high risk child might have higher latency, more jerkiness, higher hesitation
        if risk == 0:
            feat = {
                "abandonment_rate": np.random.uniform(0, 0.05),
                "accuracy_drift": np.random.uniform(-0.1, 0.1),
                "accuracy_slope": np.random.uniform(-0.1, 0.5),
                "assessment_risk_score": np.random.uniform(0, 0.2),
                "audio_dependency_score": np.random.uniform(0, 0.2),
                "avg_jerkiness": np.random.uniform(0, 2.0),
                "fatigue_drift": np.random.uniform(-0.1, 0.1),
                "first_touch_variability": np.random.uniform(0.1, 0.3),
                "hesitation_ratio": np.random.uniform(0, 0.5),
                "misclick_trend_slope": np.random.uniform(-0.1, 0.1),
                "motor_precision": np.random.uniform(85, 100),
                "phonological_latency": np.random.uniform(1000, 2500),
                "response_consistency": np.random.uniform(100, 500),
                "session_duration_ratio": np.random.uniform(0.8, 1.2),
                "touch_cluster_count": np.random.uniform(1, 3),
                "visual_processing_speed": np.random.uniform(70, 100),
                "voice_hesitation_ms": np.random.uniform(0, 500),
                "word_error_rate": np.random.uniform(0, 0.1)
            }
        elif risk == 1:
            feat = {
                "abandonment_rate": np.random.uniform(0.05, 0.15),
                "accuracy_drift": np.random.uniform(-0.2, 0.0),
                "accuracy_slope": np.random.uniform(-0.3, 0.1),
                "assessment_risk_score": np.random.uniform(0.2, 0.5),
                "audio_dependency_score": np.random.uniform(0.2, 0.6),
                "avg_jerkiness": np.random.uniform(2.0, 5.0),
                "fatigue_drift": np.random.uniform(0.1, 0.3),
                "first_touch_variability": np.random.uniform(0.3, 0.6),
                "hesitation_ratio": np.random.uniform(0.5, 2.0),
                "misclick_trend_slope": np.random.uniform(0.0, 0.3),
                "motor_precision": np.random.uniform(65, 85),
                "phonological_latency": np.random.uniform(2500, 4500),
                "response_consistency": np.random.uniform(500, 1500),
                "session_duration_ratio": np.random.uniform(1.1, 1.5),
                "touch_cluster_count": np.random.uniform(2, 5),
                "visual_processing_speed": np.random.uniform(40, 70),
                "voice_hesitation_ms": np.random.uniform(500, 1500),
                "word_error_rate": np.random.uniform(0.1, 0.3)
            }
        else:
            feat = {
                "abandonment_rate": np.random.uniform(0.15, 0.4),
                "accuracy_drift": np.random.uniform(-0.5, -0.1),
                "accuracy_slope": np.random.uniform(-0.6, -0.1),
                "assessment_risk_score": np.random.uniform(0.5, 1.0),
                "audio_dependency_score": np.random.uniform(0.6, 1.0),
                "avg_jerkiness": np.random.uniform(5.0, 12.0), # Tremors/Dyspraxia
                "fatigue_drift": np.random.uniform(0.3, 0.8),
                "first_touch_variability": np.random.uniform(0.5, 1.2),
                "hesitation_ratio": np.random.uniform(1.5, 4.0),
                "misclick_trend_slope": np.random.uniform(0.2, 0.8),
                "motor_precision": np.random.uniform(30, 65),
                "phonological_latency": np.random.uniform(4000, 8000),
                "response_consistency": np.random.uniform(1200, 3000),
                "session_duration_ratio": np.random.uniform(1.4, 2.5),
                "touch_cluster_count": np.random.uniform(4, 10),
                "visual_processing_speed": np.random.uniform(10, 40),
                "voice_hesitation_ms": np.random.uniform(1500, 4000),
                "word_error_rate": np.random.uniform(0.3, 0.8)
            }
            
        vector = [feat[k] for k in FEATURE_KEYS]
        X.append(vector)
        y.append(risk)
        
    return np.array(X), np.array(y)


def train():
    print("Generating synthetic clinical telemetry data...")
    X, y = generate_synthetic_data(2000)
    
    print(f"Generated {len(X)} samples. Splitting dataset...")
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    print("Training RandomForestClassifier...")
    clf = RandomForestClassifier(n_estimators=100, max_depth=10, random_state=42)
    clf.fit(X_train, y_train)
    
    print("Evaluating model...")
    y_pred = clf.predict(X_test)
    print("Accuracy:", accuracy_score(y_test, y_pred))
    print(classification_report(y_test, y_pred, target_names=["Low", "Moderate", "High"]))
    
    print(f"Saving model to {MODEL_PATH}...")
    joblib.dump(clf, MODEL_PATH)
    print("Done! The Sipsara backend will now use this model for inference.")

if __name__ == "__main__":
    train()
