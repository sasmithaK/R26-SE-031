import pandas as pd
import numpy as np
import lightgbm as lgb
import joblib
import os

# Create ml directory if it doesn't exist
os.makedirs('../monitoring-service/ml', exist_ok=True)

def generate_synthetic_telemetry(n_samples=1000):
    """
    Generate synthetic telemetry data representing a student's interactions.
    Features:
    - hesitation_time_ms: Time taken before the first touch.
    - swipe_velocity: Speed of dragging/swiping.
    - correction_rate: Number of times an action was undone.
    - cognitive_load: Target label (0: Low, 1: Medium, 2: High)
    """
    np.random.seed(42)
    
    data = []
    for _ in range(n_samples):
        # Generate target first to define realistic features
        cognitive_load = np.random.choice([0, 1, 2], p=[0.5, 0.3, 0.2])
        
        if cognitive_load == 0: # Low Load (Proficient)
            hesitation_time = np.random.normal(500, 100)
            swipe_velocity = np.random.normal(300, 50)
            correction_rate = np.random.poisson(0.1)
        elif cognitive_load == 1: # Medium Load
            hesitation_time = np.random.normal(1500, 300)
            swipe_velocity = np.random.normal(150, 40)
            correction_rate = np.random.poisson(1.0)
        else: # High Load (Frustrated/Struggling)
            hesitation_time = np.random.normal(4000, 800)
            swipe_velocity = np.random.normal(80, 20)
            correction_rate = np.random.poisson(3.0)
            
        data.append([
            max(0, hesitation_time), 
            max(0, swipe_velocity), 
            min(5, correction_rate), 
            cognitive_load
        ])
        
    return pd.DataFrame(data, columns=['hesitation_time_ms', 'swipe_velocity', 'correction_rate', 'cognitive_load'])

print("Generating synthetic data...")
df = generate_synthetic_telemetry(2000)

X = df[['hesitation_time_ms', 'swipe_velocity', 'correction_rate']]
y = df['cognitive_load']

print("Training LightGBM Model...")
model = lgb.LGBMClassifier(n_estimators=100, random_state=42)
model.fit(X, y)

accuracy = model.score(X, y)
print(f"Model Training Complete. Training Accuracy: {accuracy:.2f}")

# Save the model so the FastAPI service can load it
model_path = '../monitoring-service/ml/lgbm_cognitive_load.pkl'
joblib.dump(model, model_path)
print(f"Model saved to {model_path}")
