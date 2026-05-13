import os
import joblib
import shap
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

def main():
    print("Loading Random Forest Intervention Model...")
    model_path = os.path.join(os.path.dirname(__file__), 'ml', 'intervention_rf.pkl')
    
    if not os.path.exists(model_path):
        # Fallback to final_models
        model_path = os.path.join(os.path.dirname(__file__), '..', 'final_models', 'intervention_rf.pkl')

    if not os.path.exists(model_path):
        print(f"Error: Could not find model at {model_path}")
        return

    rf_model = joblib.load(model_path)
    
    features = ["latency_ms", "erratic_clicks", "mastery_level", "prev_failures"]
    
    # 1. Generate Dummy Data mimicking the training distribution
    np.random.seed(42)
    N = 300
    lat = np.random.exponential(2500, N).clip(300, 12000)
    errat = np.random.exponential(1.5, N).clip(0, 15)
    mast = np.random.beta(2, 2, N)
    fails = np.random.poisson(1.5, N).clip(0, 8)
    
    X = pd.DataFrame(np.column_stack([lat, errat, mast, fails]), columns=features)
    
    # 2. Setup SHAP Explainer
    print("Computing SHAP values...")
    explainer = shap.TreeExplainer(rf_model)
    
    # Calculate shap_values for all instances
    # Random Forest with >2 classes returns a list of arrays (one for each class).
    shap_values = explainer.shap_values(X)
    
    # For a multi-class model, we usually explain one class. 
    # Class 2 = Break/Restart intervention (Severe overload)
    target_class = 2 
    class_shap_values = shap_values[:, :, target_class] if len(np.shape(shap_values)) == 3 else shap_values[target_class]
    
    output_dir = os.path.join(os.path.dirname(__file__), '..', 'docs', 'shap_visuals')
    os.makedirs(output_dir, exist_ok=True)
    
    # 3. Generate Summary Plot (Beeswarm)
    print("Generating Beeswarm Plot...")
    plt.figure(figsize=(10, 6))
    shap.summary_plot(class_shap_values, X, show=False)
    plt.title("SHAP Summary: Factors Triggering 'Break' Intervention", fontsize=14, pad=20)
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'beeswarm_break_intervention.png'), dpi=300)
    plt.close()
    
    # 4. Generate Waterfall Plot for a specific high-load student
    print("Generating Waterfall Plot...")
    # Find a student who is struggling (high latency, high errors)
    struggling_idx = np.argmax(X['latency_ms'].values + (X['erratic_clicks'].values * 1000))
    
    # We need an Explanation object for the waterfall plot
    # TreeExplainer expected value for the target class
    exp_value = explainer.expected_value[target_class]
    
    shap_exp = shap.Explanation(values=class_shap_values[struggling_idx], 
                                base_values=exp_value, 
                                data=X.iloc[struggling_idx].values, 
                                feature_names=features)
    
    plt.figure(figsize=(10, 6))
    shap.waterfall_plot(shap_exp, show=False)
    plt.title("Individual SHAP Explanation: Why 'Break' was triggered", fontsize=14, pad=20)
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'waterfall_student_struggle.png'), dpi=300)
    plt.close()
    
    print(f"Visualizations saved successfully to {output_dir}")

if __name__ == "__main__":
    main()
