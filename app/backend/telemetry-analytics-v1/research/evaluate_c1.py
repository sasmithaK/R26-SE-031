import os
import joblib
import pandas as pd
import glob
import json
from sklearn.metrics import confusion_matrix, accuracy_score

def main():
    model_path = os.path.join(os.path.dirname(__file__), "..", "models", "c1_random_forest.pkl")
    if not os.path.exists(model_path):
        print("Model not found. Train first.")
        return
        
    clf = joblib.load(model_path)
    
    data_dir = os.path.join(os.path.dirname(__file__), "..", "data", "synthetic")
    files = glob.glob(os.path.join(data_dir, "*.csv"))
    if not files:
        return
        
    latest_file = max(files, key=os.path.getctime)
    df = pd.read_csv(latest_file)
    
    schema_path = os.path.join(os.path.dirname(__file__), "..", "config", "c1_features.json")
    with open(schema_path, "r") as f:
        schema = json.load(f)
        
    X = df[schema["features"]]
    y = df["pattern"]
    
    preds = clf.predict(X)
    
    print(f"Accuracy: {accuracy_score(y, preds):.3f}")
    print("Confusion Matrix:")
    print(confusion_matrix(y, preds))

if __name__ == "__main__":
    main()
