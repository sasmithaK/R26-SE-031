import os
import pandas as pd
import glob
import joblib
import json
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report

def main():
    data_dir = os.path.join(os.path.dirname(__file__), "..", "data", "synthetic")
    files = glob.glob(os.path.join(data_dir, "*.csv"))
    if not files:
        print("No synthetic data found. Run generate_synthetic.py first.")
        return
        
    latest_file = max(files, key=os.path.getctime)
    df = pd.read_csv(latest_file)
    
    schema_path = os.path.join(os.path.dirname(__file__), "..", "config", "c1_features.json")
    with open(schema_path, "r") as f:
        schema = json.load(f)
        
    features = schema["features"]
    
    X = df[features]
    y = df["pattern"]
    
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    clf = RandomForestClassifier(n_estimators=100, random_state=42, max_depth=5)
    clf.fit(X_train, y_train)
    
    y_pred = clf.predict(X_test)
    print("Model Evaluation:")
    print(classification_report(y_test, y_pred))
    
    model_out = os.path.join(os.path.dirname(__file__), "..", "models", "c1_random_forest.pkl")
    joblib.dump(clf, model_out)
    print(f"Model saved to {model_out}")

if __name__ == "__main__":
    main()
