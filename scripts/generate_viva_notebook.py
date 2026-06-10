import json
import os

def create_viva_notebook():
    notebook = {
        "cells": [
            {
                "cell_type": "markdown",
                "metadata": {},
                "source": [
                    "# R26-SE-031: VIVA Audit - MBSV Explainability\n",
                    "This notebook demonstrates how the **C1 Monitoring Engine** uses behavioral telemetry to infer the learner's cognitive state.\n",
                    "\n",
                    "### Objectives:\n",
                    "1. Load the trained LightGBM model.\n",
                    "2. Visualize feature importance (SHAP values).\n",
                    "3. Show the scientific mapping between features and the 6 MBSV dimensions."
                ]
            },
            {
                "cell_type": "code",
                "execution_count": None,
                "metadata": {},
                "outputs": [],
                "source": [
                    "import pickle\n",
                    "import pandas as pd\n",
                    "import numpy as np\n",
                    "import matplotlib.pyplot as plt\n",
                    "from pathlib import Path\n",
                    "\n",
                    "# Load Model\n",
                    "model_path = '../models/c1_lgbm_mbsv.pkl'\n",
                    "with open(model_path, 'rb') as f:\n",
                    "    model = pickle.load(f)\n",
                    "\n",
                    "print(f\"Loaded LightGBM Model: {model}\")"
                ]
            },
            {
                "cell_type": "markdown",
                "metadata": {},
                "source": [
                    "## 1. Feature Importance (Scientific Validation)\n",
                    "We visualize which signals the model relies on most for predicting cognitive load and phonological strain."
                ]
            },
            {
                "cell_type": "code",
                "execution_count": None,
                "metadata": {},
                "outputs": [],
                "source": [
                    "features = [\n",
                    "    'hesitation_ms', 'correction_rate', 'response_latency', 'touch_pressure',\n",
                    "    'swipe_velocity', 'replay_count', 'hint_request_count', 'stylus_deviation',\n",
                    "    'inter_tap_interval', 'read_aloud_pause_ms', 'syllable_rate',\n",
                    "    'disfluency_count', 'kalman_innovation'\n",
                    "]\n",
                    "\n",
                    "# Average importance across all 6 targets\n",
                    "importances = np.zeros(len(features))\n",
                    "for est in model.estimators_:\n",
                    "    importances += est.feature_importances_\n",
                    "importances /= len(model.estimators_)\n",
                    "\n",
                    "fi_df = pd.DataFrame({'feature': features, 'importance': importances})\n",
                    "fi_df = fi_df.sort_values('importance', ascending=True)\n",
                    "\n",
                    "plt.figure(figsize=(10, 6))\n",
                    "plt.barh(fi_df['feature'], fi_df['importance'], color='skyblue')\n",
                    "plt.title('Global Feature Importance (C1 Monitoring Engine)')\n",
                    "plt.xlabel('Importance Score')\n",
                    "plt.grid(axis='x', linestyle='--', alpha=0.7)\n",
                    "plt.show()"
                ]
            },
            {
                "cell_type": "markdown",
                "metadata": {},
                "source": [
                    "## 2. Scientific Logic: Mapping Features to Indices\n",
                    "| Index | Scientific Basis | Key Drivers |\n",
                    "| :--- | :--- | :--- |\n",
                    "| **CLI** | Sweller's Cognitive Load Theory | Hesitation, Kalman Innovation |\n",
                    "| **PSI** | Phonological Deficit Hypothesis | Disfluency, Omission Errors |\n",
                    "| **VSI** | Visual Stress & Crowding | Stylus Deviation, Swipe Velocity |"
                ]
            }
        ],
        "metadata": {
            "kernelspec": {
                "display_name": "Python 3",
                "language": "python",
                "name": "python3"
            },
            "language_info": {
                "codemirror_mode": {
                    "name": "ipython",
                    "version": 3
                },
                "file_extension": ".py",
                "mimetype": "text/x-python",
                "name": "python",
                "nbconvert_exporter": "python",
                "pygments_lexer": "ipython3",
                "version": "3.8.10"
            }
        },
        "nbformat": 4,
        "nbformat_minor": 4
    }
    
    with open('viva_audit/MBSV_Scientific_Validation.ipynb', 'w') as f:
        json.dump(notebook, f, indent=2)
    print("✓ Created viva_audit/MBSV_Scientific_Validation.ipynb")

if __name__ == "__main__":
    create_viva_notebook()
