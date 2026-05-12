import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, f1_score, confusion_matrix
from sklearn.preprocessing import LabelEncoder
import numpy as np

class LearnerClassifierModels:
    def __init__(self):
        self.model = RandomForestClassifier(n_estimators=100, random_state=42)
        self.label_encoder = LabelEncoder()
        self.is_trained = False
        
    def train(self, X: pd.DataFrame, Y_series: pd.Series):
        # Encode targets
        Y = self.label_encoder.fit_transform(Y_series)
        
        X_train, X_test, Y_train, Y_test = train_test_split(X, Y, test_size=0.2, random_state=42)
        
        print("Training Random Forest Classifier...")
        self.model.fit(X_train, Y_train)
        self.is_trained = True
        
        # Evaluate
        Y_pred = self.model.predict(X_test)
        
        # 1. Feature Importances
        importances = self.model.feature_importances_
        feature_importance_list = [
            {"feature": col, "importance": float(imp)}
            for col, imp in zip(X.columns, importances)
        ]
        # Sort descending
        feature_importance_list.sort(key=lambda x: x["importance"], reverse=True)
        
        # 2. Confusion Matrix
        cm = confusion_matrix(Y_test, Y_pred)
        cm_list = cm.tolist()
        
        # 3. Class Distribution
        class_dist = Y_series.value_counts().to_dict()
        class_dist_list = [{"learner_type": k, "count": int(v)} for k, v in class_dist.items()]
        
        # 4. Labels reference
        labels = list(self.label_encoder.classes_)
        
        metrics = {
            "accuracy": float(accuracy_score(Y_test, Y_pred)),
            "f1_score": float(f1_score(Y_test, Y_pred, average='macro', zero_division=0)),
            "feature_importances": feature_importance_list,
            "confusion_matrix": cm_list,
            "class_distribution": class_dist_list,
            "labels": labels
        }
            
        return metrics

    def predict(self, X: pd.DataFrame, original_df: pd.DataFrame):
        if not self.is_trained:
            raise ValueError("Model not trained yet")
            
        Y_pred = self.model.predict(X)
        probs = self.model.predict_proba(X)
        
        results = []
        for i in range(len(X)):
            pred_idx = int(Y_pred[i])
            pred_label = self.label_encoder.inverse_transform([pred_idx])[0]
            confidence = float(probs[i][pred_idx])
            
            # Simple Heuristic Explainability based on original unscaled inputs
            row = original_df.iloc[i]
            reasons = []
            
            if row.get('hesitation_time_ms', 0) > 3000 or row.get('mean_hesitation', 0) > 3000:
                reasons.append("High hesitation")
            else:
                reasons.append("Low/Normal hesitation")
                
            if row.get('cognitive_load', 0) >= 1:
                reasons.append("Elevated cognitive load")
                
            if row.get('erratic_clicks', 0) > 2:
                reasons.append("High erratic clicks (frustration indicator)")
                
            if not reasons:
                reasons.append("Balanced behavioral metrics")
                
            reason_text = " + ".join(reasons).capitalize()
            
            results.append({
                "predicted_type": pred_label,
                "confidence": round(confidence * 100, 1),
                "reason": reason_text
            })
            
        return results
