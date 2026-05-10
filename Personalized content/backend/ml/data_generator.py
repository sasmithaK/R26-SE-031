import datetime
import numpy as np

def generate_synthetic_data(num_samples: int = 5000):
    """
    Generates synthetic learner data based on 9 core monitoring metrics
    and splits them into latest_telemetry and student_baseline collections.
    """
    learner_types = [
        "Balanced Learner",
        "Audio Dependent Learner",
        "Struggling Reader",
        "Visual Overload Learner",
        "Fast Adaptive Learner"
    ]
    
    targets = np.random.choice(learner_types, size=num_samples, p=[0.3, 0.2, 0.2, 0.15, 0.15])
    
    telemetry_data = []
    baseline_data = []
    
    for i, label in enumerate(targets):
        student_id = f"SYN_STU_{i:04d}"
        now = datetime.datetime.now(datetime.UTC)
        
        # Default Baseline Metrics
        mean_hesitation = np.random.uniform(1500, 3000)
        std_hesitation = np.random.uniform(300, 800)
        mean_correction = np.random.uniform(0.05, 0.15)
        std_correction = np.random.uniform(0.01, 0.05)
        session_count = np.random.randint(5, 50)
        
        # Default Current Session Metrics
        cognitive_load = 0
        hesitation_time_ms = np.random.normal(mean_hesitation, std_hesitation)
        erratic_clicks = np.random.randint(0, 2)

        # Apply specific heuristics based on target label
        if label == "Audio Dependent Learner":
            mean_hesitation = np.random.uniform(3000, 5000)
            hesitation_time_ms = np.random.uniform(3000, 6000)
            cognitive_load = np.random.choice([0, 1])

        elif label == "Struggling Reader":
            mean_hesitation = np.random.uniform(4000, 8000)
            hesitation_time_ms = np.random.uniform(5000, 10000)
            mean_correction = np.random.uniform(0.3, 0.6)
            erratic_clicks = np.random.randint(3, 8)
            cognitive_load = 2

        elif label == "Visual Overload Learner":
            mean_hesitation = np.random.uniform(2000, 4000)
            hesitation_time_ms = np.random.uniform(2500, 5000)
            mean_correction = np.random.uniform(0.1, 0.3)
            erratic_clicks = np.random.randint(1, 4)
            cognitive_load = np.random.choice([1, 2])
            
        elif label == "Fast Adaptive Learner":
            mean_hesitation = np.random.uniform(800, 1500)
            hesitation_time_ms = np.random.uniform(800, 2000)
            mean_correction = np.random.uniform(0.01, 0.05)
            erratic_clicks = 0
            cognitive_load = 0
            
        hesitation_time_ms = max(500.0, float(hesitation_time_ms))
        
        telemetry_data.append({
            "student_id": student_id,
            "cognitive_load": int(cognitive_load),
            "hesitation_time_ms": round(hesitation_time_ms, 2),
            "erratic_clicks": float(erratic_clicks),
            "learner_type": label, # Save label here for ML training later
            "updated_at": now
        })
        
        baseline_data.append({
            "student_id": student_id,
            "mean_hesitation": round(float(mean_hesitation), 2),
            "std_hesitation": round(float(std_hesitation), 2),
            "mean_correction": round(float(mean_correction), 3),
            "std_correction": round(float(std_correction), 3),
            "session_count": int(session_count),
            "updated_at": now
        })
        
    return telemetry_data, baseline_data
