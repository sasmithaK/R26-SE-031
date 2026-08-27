import os
import numpy as np
import pandas as pd
import joblib
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, classification_report
import xgboost as xgb

def generate_cohort(num_per_archetype=100):
    np.random.seed(42)
    
    X_xgb_list = []
    y_xgb_list = []
    
    X_rf_list = []
    y_rf_list = []
    
    archetypes = [
        "Neurotypical",
        "Visual-Orthographic",
        "Phonological",
        "Attention Deficit"
    ]
    
    for archetype_idx, archetype in enumerate(archetypes):
        for _ in range(num_per_archetype):
            # Base variables for XGB
            acoustic_latency = np.random.normal(800, 100)
            jitter = np.random.uniform(0.01, 0.03)
            peak_delta = np.random.choice([0, 1], p=[0.9, 0.1])
            shimmer = np.random.uniform(0.02, 0.05)
            silence_ratio = np.random.uniform(0.05, 0.15)
            
            t_first_touch = np.random.normal(900, 150)
            path_efficiency = np.random.normal(0.95, 0.05)
            oci = np.random.uniform(0.0, 0.1)
            dj = np.random.normal(40, 10)
            dwell_time = np.random.normal(200, 50)
            
            # Base variables for RF
            fatigue_drift = np.random.uniform(-0.1, 0.1)
            abandonment_rate = np.random.uniform(0, 0.05)
            accuracy_slope = np.random.uniform(-0.1, 0.5)
            motor_precision = np.random.uniform(85, 100)
            visual_proc_speed = np.random.uniform(70, 100)
            
            # Labels: XGB (0=Normal, 1=Phono, 2=Visual, 3=Double/ADHD for this mock)
            # Labels: RF (0=Low, 1=Mod, 2=High)
            if archetype == "Neurotypical":
                xgb_class = 0
                rf_class = 0
            elif archetype == "Visual-Orthographic":
                xgb_class = 2
                rf_class = 2
                
                t_first_touch = np.random.normal(2500, 300)
                path_efficiency = np.random.normal(0.60, 0.1)
                oci = np.random.uniform(0.5, 0.9)
                
                visual_proc_speed = np.random.uniform(10, 40)
                
            elif archetype == "Phonological":
                xgb_class = 1
                rf_class = 2
                
                acoustic_latency = np.random.normal(2800, 300)
                jitter = np.random.uniform(0.05, 0.1)
                peak_delta = np.random.choice([2, 3, 4], p=[0.5, 0.3, 0.2])
                
            elif archetype == "Attention Deficit":
                xgb_class = 3
                rf_class = 2
                
                t_first_touch = np.random.normal(300, 100) # impulsive
                fatigue_drift = np.random.uniform(0.5, 1.0)
                path_efficiency = np.random.normal(0.40, 0.2)
                abandonment_rate = np.random.uniform(0.2, 0.5)
                accuracy_slope = np.random.uniform(-0.8, -0.3)
                
            # Compile XGB features (c1_audio_vector + c2_kinematic_vector + student_age_months)
            xgb_feat = {
                'acoustic_latency_ms': acoustic_latency,
                'peak_count_delta': peak_delta,
                'intra_word_silence_ratio': silence_ratio,
                'local_jitter': jitter,
                'local_shimmer': shimmer,
                'time_to_first_touch_ms': t_first_touch,
                'orthographic_confusion_index': oci,
                'path_efficiency': path_efficiency,
                'dimensionless_jerk': dj,
                'dwell_time_ms': dwell_time,
                'student_age_months': np.random.randint(60, 108) # 5 to 9 years in months
            }
            
            # Compile RF features
            rf_feat = {
                "abandonment_rate": abandonment_rate,
                "accuracy_drift": np.random.uniform(-0.1, 0.1),
                "accuracy_slope": accuracy_slope,
                "assessment_risk_score": np.random.uniform(0, 1.0),
                "audio_dependency_score": np.random.uniform(0, 1.0),
                "avg_jerkiness": dj,
                "fatigue_drift": fatigue_drift,
                "first_touch_variability": np.random.uniform(0.1, 1.0),
                "hesitation_ratio": np.random.uniform(0, 4.0),
                "misclick_trend_slope": np.random.uniform(-0.1, 0.8),
                "motor_precision": motor_precision,
                "phonological_latency": acoustic_latency,
                "response_consistency": np.random.uniform(100, 3000),
                "session_duration_ratio": np.random.uniform(0.8, 2.5),
                "touch_cluster_count": np.random.uniform(1, 10),
                "visual_processing_speed": visual_proc_speed,
                "voice_hesitation_ms": np.random.uniform(0, 4000),
                "word_error_rate": np.random.uniform(0, 0.8)
            }
            
            X_xgb_list.append(xgb_feat)
            y_xgb_list.append(xgb_class)
            
            X_rf_list.append(rf_feat)
            y_rf_list.append(rf_class)
            
    df_xgb = pd.DataFrame(X_xgb_list)
    df_rf = pd.DataFrame(X_rf_list)
    
    # Ensure RF columns are strictly sorted alphabetically as expected by pipeline
    FEATURE_KEYS = sorted(list(X_rf_list[0].keys()))
    df_rf = df_rf[FEATURE_KEYS]
    
    return df_xgb, np.array(y_xgb_list), df_rf, np.array(y_rf_list)

def train_and_save():
    print("Generating synthetic cohort data...")
    df_xgb, y_xgb, df_rf, y_rf = generate_cohort(100)
    
    # --- Train XGBoost ---
    print("Training XGBoost Multi-Class model...")
    model_xgb = xgb.XGBClassifier(
        objective='multi:softprob',
        num_class=4,
        n_estimators=100,
        max_depth=4,
        learning_rate=0.1,
        random_state=42
    )
    model_xgb.fit(df_xgb, y_xgb)
    
    xgb_dir = os.path.join(os.path.dirname(__file__), "..", "diagnostic-fusion-v1", "models")
    os.makedirs(xgb_dir, exist_ok=True)
    joblib.dump(model_xgb, os.path.join(xgb_dir, "xgboost_clinical_fusion.pkl"))
    joblib.dump(df_xgb.columns.tolist(), os.path.join(xgb_dir, "feature_names.pkl"))
    print("Saved XGBoost model.")

    # --- Train Random Forest ---
    print("Training RandomForest Classifier...")
    model_rf = RandomForestClassifier(n_estimators=100, max_depth=10, random_state=42)
    model_rf.fit(df_rf, y_rf)
    
    rf_dir = os.path.join(os.path.dirname(__file__), "..", "telemetry-analytics-v1", "models")
    os.makedirs(rf_dir, exist_ok=True)
    joblib.dump(model_rf, os.path.join(rf_dir, "dyslexia_rf_model.pkl"))
    print("Saved RandomForest model.")
    print("Done!")

if __name__ == "__main__":
    train_and_save()
