# %% [markdown]
# # Explainable AI (XAI) Intervention Recommender
# This notebook trains a Random Forest model to predict the optimal intervention.
# Crucially, it uses SHAP and LIME to generate human-readable explanations for WHY the AI made its choice.

# %%
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report
import matplotlib.pyplot as plt

# Ensure these are installed: pip install shap lime
try:
    import shap
    import lime
    import lime.lime_tabular
except ImportError:
    print("WARNING: SHAP or LIME not installed. Run 'pip install shap lime' to use the XAI features.")

# %%
# 1. SYNTHETIC INTERVENTION DATASET GENERATION
# Features: Latency(ms), Erratic_Clicks, Mastery_Level (0.0-1.0), Previous_Failures
NUM_SAMPLES = 3000
feature_names = ["Latency_ms", "Erratic_Clicks", "Mastery_Level", "Previous_Failures"]

np.random.seed(42)
X = np.random.rand(NUM_SAMPLES, 4)
# Scale features
X[:, 0] *= 10000 # Latency up to 10s
X[:, 1] *= 10    # Clicks up to 10
X[:, 2] *= 1.0   # Mastery 0 to 1
X[:, 3] *= 5     # Failures up to 5

# Target/Labels: 0 (Give Audio Cue), 1 (Visual Split/Color Pillas), 2 (Give Break)
y = np.zeros(NUM_SAMPLES)

# Simple deterministic rules for synthetic data to make the AI learnable
for i in range(NUM_SAMPLES):
    if X[i, 1] > 7 or X[i, 0] > 8000:
        y[i] = 2 # High frustration -> Break
    elif X[i, 2] < 0.4 and X[i, 3] >= 2:
        y[i] = 0 # Low mastery + History of failure -> Audio Cue
    else:
        y[i] = 1 # Visual Split

X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# %%
# 2. TRAIN RANDOM FOREST MODEL
print("--- Training Intervention Random Forest ---")
rf_model = RandomForestClassifier(n_estimators=100, random_state=42)
rf_model.fit(X_train, y_train)

y_pred = rf_model.predict(X_test)
target_names = ["Audio Cue", "Visual Split", "Break"]
print(classification_report(y_test, y_pred, target_names=target_names))

# %%
# 3. SHAP EXPLAINER (Game-Theoretic Feature Attribution)
print("\n--- Generating SHAP Explanations ---")
if 'shap' in globals():
    explainer = shap.TreeExplainer(rf_model)
    # Explain the first 100 test samples to save time
    shap_values = explainer.shap_values(X_test[:100])
    
    # SHAP natively plots in Jupyter Notebooks.
    # We create a summary plot for Class 0 ("Audio Cue")
    # Uncomment to render in Jupyter:
    # shap.summary_plot(shap_values[0], X_test[:100], feature_names=feature_names)
    print("SHAP values computed successfully. Uncomment shap.summary_plot to view.")

# %%
# 4. LIME EXPLAINER (Local HTML Explanations)
print("\n--- Generating LIME Explanations ---")
if 'lime' in globals():
    lime_explainer = lime.lime_tabular.LimeTabularExplainer(
        X_train, 
        feature_names=feature_names, 
        class_names=target_names, 
        discretize_continuous=True
    )

    # Pick a specific struggling student (e.g., student at index 0 of test set)
    student_idx = 0
    student_features = X_test[student_idx]
    
    exp = lime_explainer.explain_instance(student_features, rf_model.predict_proba, num_features=4)
    
    # Display explanation in console
    print(f"\nExplaining prediction for Student {student_idx}:")
    print(f"Predicted Intervention: {target_names[int(y_pred[student_idx])]}")
    print(exp.as_list())
    
    # Save as HTML report for teachers
    exp.save_to_file('student_0_intervention_report.html')
    print("Saved detailed explanation to 'student_0_intervention_report.html'")
