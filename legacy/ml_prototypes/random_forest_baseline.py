from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score

def train_and_evaluate_rf(dataset):
    print("\n--- Training Random Forest (Baseline) ---")
    # Flatten sequential data for standard ML
    rf_x, rf_y = [], []
    for seq in dataset.data:
        # Predict the last step based on previous steps
        features = [item for sublist in seq[:-1] for item in sublist]
        rf_x.append(features)
        rf_y.append(seq[-1][1]) # target is the correct boolean of the last step
        
    rf = RandomForestClassifier(n_estimators=100)
    rf.fit(rf_x, rf_y)
    
    # Simple evaluation
    rf_preds = rf.predict(rf_x)
    rf_acc = accuracy_score(rf_y, rf_preds)
    print(f"Random Forest Training Accuracy: {rf_acc:.4f}")
    return rf, rf_acc
