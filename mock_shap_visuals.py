import os
import matplotlib.pyplot as plt
import numpy as np

def generate_mock_beeswarm(output_dir):
    # Simulated feature importance distributions
    features = ["latency_ms", "erratic_clicks", "prev_failures", "mastery_level"]
    np.random.seed(42)
    
    fig, ax = plt.subplots(figsize=(10, 6))
    
    # Generate scatter points for each feature
    y_positions = [3, 2, 1, 0]
    
    # latency_ms (positive impact on Break intervention)
    shap_latency = np.random.normal(loc=0.15, scale=0.1, size=300)
    feat_latency = (shap_latency - shap_latency.min()) / (shap_latency.max() - shap_latency.min())
    
    # erratic_clicks (positive impact)
    shap_erratic = np.random.normal(loc=0.08, scale=0.06, size=300)
    feat_erratic = (shap_erratic - shap_erratic.min()) / (shap_erratic.max() - shap_erratic.min())
    
    # prev_failures (positive impact)
    shap_fails = np.random.normal(loc=0.04, scale=0.04, size=300)
    feat_fails = (shap_fails - shap_fails.min()) / (shap_fails.max() - shap_fails.min())
    
    # mastery_level (negative impact)
    shap_mastery = np.random.normal(loc=-0.05, scale=0.05, size=300)
    feat_mastery = 1 - ((shap_mastery - shap_mastery.min()) / (shap_mastery.max() - shap_mastery.min()))
    
    all_shaps = [shap_latency, shap_erratic, shap_fails, shap_mastery]
    all_feats = [feat_latency, feat_erratic, feat_fails, feat_mastery]
    
    for y, shap_vals, feat_vals in zip(y_positions, all_shaps, all_feats):
        # Adding some jitter to y
        jitter = np.random.normal(0, 0.05, size=len(shap_vals))
        
        # Color map from blue (low) to red (high)
        colors = plt.cm.coolwarm(feat_vals)
        
        ax.scatter(shap_vals, y + jitter, c=colors, s=15, alpha=0.7, edgecolors='none')

    ax.axvline(0, color='gray', linestyle='-', linewidth=1, alpha=0.5)
    
    ax.set_yticks(y_positions)
    ax.set_yticklabels(features, fontsize=12)
    ax.set_xlabel("SHAP value (impact on model output)", fontsize=12)
    ax.set_title("SHAP Summary: Factors Triggering 'Break' Intervention", fontsize=14, pad=20)
    
    # Custom colorbar
    sm = plt.cm.ScalarMappable(cmap=plt.cm.coolwarm, norm=plt.Normalize(vmin=0, vmax=1))
    sm.set_array([])
    cbar = plt.colorbar(sm, ax=ax, aspect=50)
    cbar.set_label('Feature value', fontsize=12)
    cbar.set_ticks([0, 1])
    cbar.set_ticklabels(['Low', 'High'])
    
    # Style
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.spines['left'].set_visible(False)
    ax.yaxis.set_tick_params(length=0)
    
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'beeswarm_break_intervention.png'), dpi=300, bbox_inches='tight')
    plt.close()


def generate_mock_waterfall(output_dir):
    fig, ax = plt.subplots(figsize=(10, 6))
    
    features = ["Expected Value", "mastery_level=0.15", "prev_failures=2", "erratic_clicks=5", "latency_ms=8500", "f(x)"]
    values = [0.10, 0.05, 0.08, 0.15, 0.32, 0.70] # Cumulative sum = 0.70
    
    x = np.arange(len(features))
    
    # Base bars
    starts = [0, 0.10, 0.15, 0.23, 0.38, 0]
    
    colors = ['gray', '#ff0051', '#ff0051', '#ff0051', '#ff0051', 'gray']
    
    ax.barh(x, values, left=starts, color=colors, height=0.6, alpha=0.8)
    
    # Connecting lines
    for i in range(1, len(features)-1):
        ax.plot([starts[i], starts[i]], [x[i-1], x[i]], color='gray', linestyle='--', linewidth=1)
        ax.plot([starts[i]+values[i], starts[i]+values[i]], [x[i], x[i+1]], color='gray', linestyle='--', linewidth=1)
        
    # Labels
    for i, (v, s) in enumerate(zip(values, starts)):
        if i == 0 or i == len(features) - 1:
            ax.text(s + v/2, i, f"{v:.2f}", ha='center', va='center', color='white', fontweight='bold')
        else:
            ax.text(s + v + 0.01, i, f"+{v:.2f}", ha='left', va='center', color='#ff0051', fontweight='bold')
            
    ax.set_yticks(x)
    ax.set_yticklabels(features, fontsize=12)
    ax.set_xlabel("SHAP value (impact on output probability)", fontsize=12)
    ax.set_title("Individual SHAP Explanation: High Cognitive Load Student", fontsize=14, pad=20)
    
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.spines['left'].set_visible(False)
    ax.yaxis.set_tick_params(length=0)
    ax.invert_yaxis()
    
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'waterfall_student_struggle.png'), dpi=300, bbox_inches='tight')
    plt.close()

if __name__ == "__main__":
    output_dir = os.path.join(os.path.dirname(__file__), 'docs', 'shap_visuals')
    os.makedirs(output_dir, exist_ok=True)
    
    print("Generating Mock Beeswarm plot...")
    generate_mock_beeswarm(output_dir)
    print("Generating Mock Waterfall plot...")
    generate_mock_waterfall(output_dir)
    print(f"Visuals saved successfully to {output_dir}")
