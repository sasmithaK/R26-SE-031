import os
import joblib
import shap
import pandas as pd
import numpy as np

# Map model predictions to learning patterns
SUBTYPE_MAP = {
    0: "Typical",
    1: "Phonological",
    2: "Visual-Orthographic",
    3: "Combined"
}

class XAIEngine:
    def __init__(self):
        model_path = os.path.join(os.path.dirname(__file__), "../models/xgboost_clinical_fusion.pkl")
        features_path = os.path.join(os.path.dirname(__file__), "../models/feature_names.pkl")
        
        if not os.path.exists(model_path):
            print("WARNING: XGBoost model not found. Inference unavailable.")
            self.model = None
            self.feature_names = []
            self.explainer = None
            return
            
        self.model = joblib.load(model_path)
        self.feature_names = joblib.load(features_path)
        
        # Initialize TreeExplainer
        self.explainer = shap.TreeExplainer(self.model)
        
    def _translate_shap_to_human(self, feature_name, feature_value, shap_val):
        direction = "increased" if shap_val > 0 else "decreased" if shap_val < 0 else "did not change"
        return f"{feature_name}={feature_value:.3f} {direction} the explained class's raw model score relative to the SHAP reference. This is model attribution, not a clinical or causal conclusion."

    def analyze_patient(self, request_data: dict) -> dict:
        """
        Takes the flat dictionary of features, runs prediction and SHAP, and returns structured result.
        """
        if self.model is None:
            raise RuntimeError("Fusion model unavailable; no fabricated prediction is returned")
        else:
            missing = [name for name in self.feature_names if name not in request_data or not np.isfinite(float(request_data[name]))]
            if missing:
                raise ValueError("Missing/non-finite fusion inputs: " + ", ".join(missing))
            # Create DataFrame ensuring columns match exactly what model expects
            df = pd.DataFrame([request_data], columns=self.feature_names)
            
            # 1. Predict probabilities and class
            probas = self.model.predict_proba(df)[0]
            predicted_class = int(np.argmax(probas))
            
            # Final predicted risk is the probability of the predicted class (if it's a deficit) 
            # or the sum of all deficit probabilities.
            final_predicted_risk = float(1.0 - probas[0]) # 1 - P(Normal)
            
            # 2. SHAP Explanation
            # For multi-class, shap_values is a list of arrays (one for each class).
            # We'll explain the predicted class's output.
            shap_values = self.explainer.shap_values(df)
            
            # TreeExplainer might return a list for multiclass, or an array with shape (1, num_features, num_classes)
            if isinstance(shap_values, list):
                class_shap_values = shap_values[predicted_class][0]
            elif len(shap_values.shape) == 3:
                class_shap_values = shap_values[0, :, predicted_class]
            else:
                class_shap_values = shap_values[0]
    
            # Get top contributing features (sort by absolute SHAP value)
            feature_importance = []
            for i, feat_name in enumerate(self.feature_names):
                val = float(df.iloc[0][feat_name])
                s_val = float(class_shap_values[i])
                
                # We only really care about features that pushed the prediction HIGHER (positive SHAP)
                # if we are explaining a deficit, or all top features. Let's get top 3 by absolute value.
                feature_importance.append({
                    "feature_name": feat_name,
                    "value": val,
                    "shap_val": s_val,
                    "abs_shap": abs(s_val)
                })
                
            # Sort by absolute SHAP impact
            feature_importance.sort(key=lambda x: x["abs_shap"], reverse=True)
            top_features = feature_importance[:3] # keep top 3
            
            explanations = []
            for f in top_features:
                sign = "+" if f["shap_val"] > 0 else ""
                explanations.append({
                    "feature_name": f["feature_name"],
                    "value": round(f["value"], 3),
                    "shap_impact": f"{sign}{f['shap_val']:.2f}",
                    "human_readable": self._translate_shap_to_human(f["feature_name"], f["value"], f["shap_val"])
                })

        return {
            "learner_profile": {
                "class_probabilities": {SUBTYPE_MAP[i]: round(float(p), 3) for i, p in enumerate(probas)},
                "primary_pattern": SUBTYPE_MAP[predicted_class],
                "confidence": round(float(np.max(probas)), 3),
                "modalities_used": ["C2 speech acoustics", "C1 legacy kinematics", "demographics"],
                "final_predicted_risk": round(final_predicted_risk, 3),
                "validation_status": "synthetic_only"
            },
            "shap_explanations": {
                "top_contributing_features": explanations
            }
        }

# Global singleton
xai_engine = None

def get_xai_engine():
    global xai_engine
    if xai_engine is None:
        xai_engine = XAIEngine()
    return xai_engine
