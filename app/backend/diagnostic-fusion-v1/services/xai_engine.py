from pathlib import Path
import numpy as np
import joblib
import shap
import pandas as pd

# Map model predictions to learning patterns
SUBTYPE_MAP = {
    0: "Typical Learning Pattern",
    1: "Phonological Learning Pattern",
    2: "Visual-Orthographic Learning Pattern",
    3: "Combined Learning Pattern"
}

class XAIEngine:
    def __init__(self):
        model_dir = Path(__file__).resolve().parents[1] / "models"
        model_path = model_dir / "xgboost_clinical_fusion.pkl"
        features_path = model_dir / "feature_names.pkl"
        
        if not model_path.is_file():
            print("WARNING: XGBoost model not found. Inference unavailable.")
            self.model = None
            self.feature_names = []
            self.explainer = None
            return
            
        if not features_path.is_file():
            raise FileNotFoundError(f"C3 feature contract is missing: {features_path.name}")

        self.model = joblib.load(model_path)
        self.feature_names = joblib.load(features_path)
        if not isinstance(self.feature_names, list) or not self.feature_names:
            raise ValueError("C3 feature contract must be a non-empty list")
        if getattr(self.model, "n_features_in_", None) != len(self.feature_names):
            raise ValueError("C3 model feature count does not match feature_names.pkl")
        if set(getattr(self.model, "classes_", [])) != {0, 1, 2, 3}:
            raise ValueError("C3 model class labels must match the four configured pattern classes")
        
        # Initialize TreeExplainer
        self.explainer = shap.TreeExplainer(self.model)
        
    def _translate_shap_to_human(self, feature_name, feature_value, shap_val):
        direction = "increased" if shap_val > 0 else "decreased" if shap_val < 0 else "did not change"
        return f"{feature_name}={feature_value:.3f} {direction} the relative feature contribution to the identified learning pattern."

    def _class_shap(self, df: pd.DataFrame, predicted_class: int) -> np.ndarray:
        shap_values = self.explainer.shap_values(df)
        if isinstance(shap_values, list):
            return np.asarray(shap_values[predicted_class][0], dtype=float)
        shap_values = np.asarray(shap_values)
        if shap_values.ndim == 3:
            return shap_values[0, :, predicted_class]
        return shap_values[0]

    def analyze_patient(self, request_data: dict, marginalize: dict | None = None) -> dict:
        """Run prediction and SHAP for one complete feature vector.

        ``marginalize`` maps an *unknown* covariate (for example gender) to the
        values it can take. Instead of inventing one value, the model is run
        for each value and the probabilities and SHAP values are averaged
        with equal weight. Every other feature must be measured.
        """
        if self.model is None:
            raise RuntimeError("Fusion model unavailable; no fabricated prediction is returned")
        marginalize = marginalize or {}
        required = [name for name in self.feature_names if name not in marginalize]
        missing = []
        for name in required:
            try:
                if not np.isfinite(float(request_data[name])):
                    missing.append(name)
            except (KeyError, TypeError, ValueError):
                missing.append(name)
        if missing:
            raise ValueError("Missing/non-finite fusion inputs: " + ", ".join(missing))

        variants = [dict(request_data)]
        for name, values in marginalize.items():
            variants = [{**row, name: value} for row in variants for value in values]
        frames = [pd.DataFrame([row], columns=self.feature_names) for row in variants]

        probas = np.mean([self.model.predict_proba(frame)[0] for frame in frames], axis=0)
        predicted_class = int(np.argmax(probas))
        class_shap_values = np.mean([self._class_shap(frame, predicted_class) for frame in frames], axis=0)

        feature_importance = []
        for i, feat_name in enumerate(self.feature_names):
            if feat_name in marginalize:
                continue  # averaged out; not a measured contribution
            val = float(frames[0].iloc[0][feat_name])
            s_val = float(class_shap_values[i])
            feature_importance.append({"feature_name": feat_name, "value": val, "shap_val": s_val, "abs_shap": abs(s_val)})
        feature_importance.sort(key=lambda x: x["abs_shap"], reverse=True)

        explanations = []
        for f in feature_importance[:3]:
            sign = "+" if f["shap_val"] > 0 else ""
            explanations.append({
                "feature_name": f["feature_name"],
                "value": round(f["value"], 3),
                "shap_impact": f"{sign}{f['shap_val']:.2f}",
                "human_readable": self._translate_shap_to_human(f["feature_name"], f["value"], f["shap_val"]),
            })

        return {
            "learner_profile": {
                "class_probabilities": {SUBTYPE_MAP[i]: round(float(p), 3) for i, p in enumerate(probas)},
                "primary_pattern": SUBTYPE_MAP[predicted_class],
                "confidence": round(float(np.max(probas)), 3),
                "modalities_used": ["speech-reading measures", "touch-interaction measures", "learner context"],
                "final_predicted_risk": round(float(1.0 - probas[0]), 3),
                "marginalized_covariates": sorted(marginalize),
                "validation_status": "synthetic_trained_model",
            },
            "shap_explanations": {"top_contributing_features": explanations},
        }

# Global singleton
xai_engine = None

def get_xai_engine():
    global xai_engine
    if xai_engine is None:
        xai_engine = XAIEngine()
    return xai_engine
