import os
import json
import random
import csv
from datetime import datetime

NUM_SAMPLES = 1000
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "synthetic")

def generate_row():
    # Helper to generate synthetic features
    # 0 = TYPICAL, 1 = VISUAL, 2 = PHONO, 3 = COMBINED
    pattern = random.choices([0, 1, 2, 3], weights=[0.6, 0.15, 0.15, 0.1], k=1)[0]
    
    # Base features for typical
    accuracy = random.uniform(0.7, 1.0)
    latency = random.uniform(1500, 3500)
    hesitation = random.uniform(0, 0.5)
    misclick = random.uniform(0, 0.2)
    
    # Modify based on pattern
    if pattern == 1: # VISUAL
        accuracy = random.uniform(0.4, 0.8)
        misclick = random.uniform(0.3, 1.2)
    elif pattern == 2: # PHONO
        latency = random.uniform(3500, 8000)
        hesitation = random.uniform(0.8, 2.5)
    elif pattern == 3: # COMBINED
        accuracy = random.uniform(0.3, 0.7)
        latency = random.uniform(4000, 9000)
        hesitation = random.uniform(1.0, 3.0)
        misclick = random.uniform(0.5, 1.5)
        
    return {
        "pattern": pattern,
        "accuracy": accuracy,
        "mean_latency_ms": latency,
        "median_latency_ms": latency * random.uniform(0.9, 1.1),
        "latency_std_ms": latency * random.uniform(0.1, 0.4),
        "mean_first_touch_latency_ms": latency * 0.4,
        "hesitation_rate": hesitation,
        "misclick_rate": misclick,
        "replay_rate": random.uniform(0, 0.5) if pattern in [2, 3] else random.uniform(0, 0.1),
        "completion_rate": 1.0 if accuracy > 0.5 else random.uniform(0.6, 1.0),
        "latency_drift": random.uniform(-0.2, 0.5),
        "error_drift": random.uniform(-0.1, 0.4),
        "hesitation_drift": random.uniform(-0.1, 0.6),
        "accuracy_slope": random.uniform(-0.05, 0.05)
    }

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    out_file = os.path.join(OUTPUT_DIR, f"synthetic_c1_{int(datetime.now().timestamp())}.csv")
    
    schema_path = os.path.join(os.path.dirname(__file__), "..", "config", "c1_features.json")
    with open(schema_path, "r") as f:
        schema = json.load(f)
        
    headers = ["pattern"] + schema["features"]
    
    with open(out_file, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=headers)
        writer.writeheader()
        for _ in range(NUM_SAMPLES):
            writer.writerow(generate_row())
            
    print(f"Generated {NUM_SAMPLES} samples at {out_file}")

if __name__ == "__main__":
    main()
