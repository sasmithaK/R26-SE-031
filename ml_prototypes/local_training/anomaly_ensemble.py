# %% [markdown]
# # Cognitive Behavior Anomaly Detection Ensemble
# This notebook trains the Unsupervised Ensemble model for the Monitoring Service.
# It uses an Autoencoder for Reconstruction Error (MSE) and an Isolation Forest to establish a baseline.

# %%
import torch
import torch.nn as nn
import numpy as np
import pandas as pd
from sklearn.ensemble import IsolationForest
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import classification_report, accuracy_score
import matplotlib.pyplot as plt

# 1. PARAMETERS
NUM_FEATURES = 4 # e.g., latency_ms, dwell_time, erratic_clicks, cursor_velocity
NUM_SAMPLES = 2000

# %%
# 2. SYNTHETIC DATASET GENERATION
def generate_telemetry_data():
    np.random.seed(42)
    # Generate "Fluent/Normal" Interactions
    fluent_data = np.random.normal(loc=[1000, 500, 0.1, 50], scale=[200, 100, 0.5, 10], size=(int(NUM_SAMPLES * 0.8), NUM_FEATURES))
    
    # Generate "Anomalous/Dyslexic Struggle" Interactions
    # High latency, high dwell time, many erratic clicks
    anomalous_data = np.random.normal(loc=[4000, 2000, 4.0, 15], scale=[1000, 500, 1.5, 5], size=(int(NUM_SAMPLES * 0.2), NUM_FEATURES))
    
    # Ensure no negative clicks or times
    fluent_data = np.clip(fluent_data, 0, None)
    anomalous_data = np.clip(anomalous_data, 0, None)
    
    X = np.vstack([fluent_data, anomalous_data])
    
    # Labels for Meta-Classifier evaluation (0: Normal, 1: Frustrated/Anomaly)
    y = np.array([0] * len(fluent_data) + [1] * len(anomalous_data))
    
    return X, y, fluent_data

X, y, fluent_data = generate_telemetry_data()
print(f"Generated {len(X)} Telemetry Interactions.")

# %%
# 3. AUTOENCODER MODEL (Trained only on Fluent Data)
class TelemetryAutoencoder(nn.Module):
    def __init__(self, input_dim):
        super(TelemetryAutoencoder, self).__init__()
        self.encoder = nn.Sequential(
            nn.Linear(input_dim, 8),
            nn.ReLU(),
            nn.Linear(8, 4) # Bottleneck
        )
        self.decoder = nn.Sequential(
            nn.Linear(4, 8),
            nn.ReLU(),
            nn.Linear(8, input_dim)
        )

    def forward(self, x):
        encoded = self.encoder(x)
        decoded = self.decoder(encoded)
        return decoded

# Normalize data for Neural Net
X_tensor = torch.FloatTensor(X)
fluent_tensor = torch.FloatTensor(fluent_data)
# Simple min-max normalization
X_max = X_tensor.max(dim=0, keepdim=True)[0]
X_tensor = X_tensor / X_max
fluent_tensor = fluent_tensor / X_max

ae_model = TelemetryAutoencoder(NUM_FEATURES)
criterion = nn.MSELoss()
optimizer = torch.optim.Adam(ae_model.parameters(), lr=0.01)

print("\n--- Training Autoencoder on Fluent Data ---")
for epoch in range(100):
    optimizer.zero_grad()
    output = ae_model(fluent_tensor)
    loss = criterion(output, fluent_tensor)
    loss.backward()
    optimizer.step()
print(f"Final AE Loss: {loss.item():.4f}")

# Calculate Reconstruction Error (MSE) for ALL data
ae_model.eval()
with torch.no_grad():
    reconstructions = ae_model(X_tensor)
    mse_scores = torch.mean((reconstructions - X_tensor)**2, dim=1).numpy()

# %%
# 4. ISOLATION FOREST MODEL
print("\n--- Training Isolation Forest ---")
# IF is an unsupervised model, trained on all data to find outliers
iso_forest = IsolationForest(contamination=0.2, random_state=42)
iso_forest.fit(X)
# Outputs: 1 for inliers, -1 for outliers. We convert -1 to higher anomaly score
if_scores = -iso_forest.decision_function(X) 

# %%
# 5. META-CLASSIFIER ENSEMBLE
print("\n--- Training Logistic Regression Meta-Classifier ---")
# Combine MSE and IF scores as features
ensemble_features = np.column_stack((mse_scores, if_scores))

meta_clf = LogisticRegression()
meta_clf.fit(ensemble_features, y)

y_pred = meta_clf.predict(ensemble_features)

print("\nEnsemble Classification Report:")
print(classification_report(y, y_pred, target_names=["Normal (0)", "Frustrated (1)"]))

# %%
# 6. VISUALIZATION (Optional for Jupyter)
# plt.scatter(mse_scores, if_scores, c=y, cmap='coolwarm', alpha=0.5)
# plt.xlabel('Autoencoder Reconstruction Error (MSE)')
# plt.ylabel('Isolation Forest Anomaly Score')
# plt.title('Ensemble Decision Space')
# plt.show()
