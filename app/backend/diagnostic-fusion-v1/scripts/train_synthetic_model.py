import os
import numpy as np
import pandas as pd
import xgboost as xgb
import joblib

def generate_synthetic_data(num_samples=1000):
    np.random.seed(42)
    
    # 4 classes: 0 (Normal), 1 (Phonological), 2 (Visual), 3 (Double Deficit)
    y = np.random.choice([0, 1, 2, 3], size=num_samples, p=[0.4, 0.25, 0.25, 0.1])
    
    # Initialize features
    acoustic_latency = np.zeros(num_samples)
    peak_delta = np.zeros(num_samples)
    silence_ratio = np.zeros(num_samples)
    jitter = np.zeros(num_samples)
    shimmer = np.zeros(num_samples)
    
    t_first_touch = np.zeros(num_samples)
    oci = np.zeros(num_samples)
    path_efficiency = np.zeros(num_samples)
    dj = np.zeros(num_samples)
    dwell_time = np.zeros(num_samples)
    
    for i in range(num_samples):
        cls = y[i]
        
        # Base normal values
        acoustic_latency[i] = np.random.normal(500, 100) # 500ms
        peak_delta[i] = np.random.choice([0, 1], p=[0.9, 0.1])
        silence_ratio[i] = np.random.uniform(0.05, 0.15)
        jitter[i] = np.random.uniform(0.01, 0.03)
        shimmer[i] = np.random.uniform(0.02, 0.05)
        
        t_first_touch[i] = np.random.normal(600, 150)
        oci[i] = np.random.uniform(0.0, 0.1)
        path_efficiency[i] = np.random.uniform(0.8, 1.0)
        dj[i] = np.random.normal(40, 10)
        dwell_time[i] = np.random.normal(200, 50)
        
        # Apply clinical effects
        if cls == 1 or cls == 3: # Phonological or Double
            acoustic_latency[i] = np.random.normal(1500, 300)
            peak_delta[i] = np.random.choice([2, 3, 4], p=[0.5, 0.3, 0.2])
            silence_ratio[i] = np.random.uniform(0.3, 0.6)
            jitter[i] = np.random.uniform(0.05, 0.1)
        
        if cls == 2 or cls == 3: # Visual or Double
            oci[i] = np.random.uniform(0.5, 0.9)
            dj[i] = np.random.normal(150, 40)
            t_first_touch[i] = np.random.normal(1800, 400)
            path_efficiency[i] = np.random.uniform(0.3, 0.6)

    age = np.random.randint(5, 8, num_samples)
    gender = np.random.choice([0, 1], size=num_samples)
    time_of_day = np.random.randint(8, 16, num_samples)
    
    df = pd.DataFrame({
        'acoustic_latency_ms': acoustic_latency,
        'peak_count_delta': peak_delta,
        'intra_word_silence_ratio': silence_ratio,
        'local_jitter': jitter,
        'local_shimmer': shimmer,
        'time_to_first_touch_ms': t_first_touch,
        'orthographic_confusion_index': oci,
        'path_efficiency_ratio': path_efficiency,  # matches comp2_kinematics.py + schemas.py
        'dimensionless_jerk': dj,
        'dwell_time_ms': dwell_time,
        'age': age,
        'gender': gender,
        'time_of_day_hour': time_of_day
    })
    
    return df, y

def train_and_save():
    from sklearn.model_selection import train_test_split
    from sklearn.metrics import classification_report

    print("Generating synthetic clinical data...")
    X, y = generate_synthetic_data(1500)
    
    # Proper 80/20 stratified split for honest evaluation
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, stratify=y, random_state=42
    )

    model = xgb.XGBClassifier(
        objective='multi:softprob',
        num_class=4,
        n_estimators=100,
        max_depth=4,
        learning_rate=0.1,
        random_state=42
    )
    
    print("Training XGBoost Multi-Class model on 80% training set...")
    model.fit(X_train, y_train)
    
    # Evaluate on HELD-OUT test set (not training set)
    preds_test = model.predict(X_test)
    print("\n=== Held-Out Test Set Evaluation (20% = 300 samples) ===")
    print(classification_report(
        y_test, preds_test,
        target_names=["Typical", "Phonological", "Visual-Orthographic", "Combined"]
    ))
    
    # Also report training accuracy for comparison (to show gap)
    preds_train = model.predict(X_train)
    train_acc = np.mean(preds_train == y_train)
    print(f"Training Accuracy (in-sample, N={len(X_train)}): {train_acc*100:.2f}%")
    
    # Save the model (retrain on full data for deployment)
    model_full = xgb.XGBClassifier(
        objective='multi:softprob',
        num_class=4,
        n_estimators=100,
        max_depth=4,
        learning_rate=0.1,
        random_state=42
    )
    model_full.fit(X, y)

    os.makedirs("../models", exist_ok=True)
    model_path = "../models/xgboost_clinical_fusion.pkl"
    joblib.dump(model_full, model_path)
    print(f"\nFull model saved to {model_path}")
    
    # Save feature names for reference during SHAP
    feature_names = X.columns.tolist()
    joblib.dump(feature_names, "../models/feature_names.pkl")
    print(f"Feature names saved: {feature_names}")

if __name__ == "__main__":
    # Go to script directory to ensure relative paths work
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    train_and_save()
