"""
train_all_models.py
-------------------
Run this script once to train ALL ML models needed for the viva demo
and save the outputs into the final_models/ directory.

Usage (from project root):
    pip install scikit-learn torch joblib numpy lightgbm
    python train_all_models.py

Outputs written to final_models/:
    dkt_mock.pkl            – Content Service DKT logic
    lgbm_cognitive_load.pkl – Monitoring Service cognitive load predictor
    ui_bandit.pkl           – Visual Service RL Bandit
    anomaly_autoencoder.pth – Monitoring Service Autoencoder weights
    anomaly_iso_forest.pkl  – Monitoring Service Isolation Forest
    anomaly_meta_clf.pkl    – Monitoring Service Ensemble Meta-Classifier
    intervention_rf.pkl     – Intervention Service Random Forest
"""

import os, joblib, numpy as np, warnings
warnings.filterwarnings("ignore")

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "final_models")
os.makedirs(OUTPUT_DIR, exist_ok=True)

def save(name, obj):
    path = os.path.join(OUTPUT_DIR, name)
    joblib.dump(obj, path)
    print(f"  [SAVED] -> {name}")

# ────────────────────────────────────────────────────────────────────────────
# 1. DKT Mock – Content Service
# ────────────────────────────────────────────────────────────────────────────
print("\n[1/5] Training DKT Mock (Content Service)...")

class DKTMock:
    """Lightweight EMA mastery updater — mimics DKT output."""
    def update_mastery(self, current: float, is_correct: bool, latency_ms: float) -> float:
        alpha = 0.3
        speed_bonus = max(0, (5000 - latency_ms) / 50000)
        raw = 1.0 if is_correct else 0.0
        new = alpha * (raw + speed_bonus) + (1 - alpha) * current
        return round(min(max(new, 0.0), 1.0), 4)

save("dkt_mock.pkl", DKTMock())

# ────────────────────────────────────────────────────────────────────────────
# 2. LightGBM Cognitive Load Classifier – Monitoring Service
# ────────────────────────────────────────────────────────────────────────────
print("\n[2/5] Training LightGBM Cognitive Load Classifier (Monitoring Service)...")

try:
    import lightgbm as lgb
    from sklearn.model_selection import train_test_split
    from sklearn.metrics import classification_report

    np.random.seed(42)
    n = 3000
    hesitation   = np.concatenate([np.random.normal(800,  200, n//3),
                                   np.random.normal(2500, 500, n//3),
                                   np.random.normal(6000, 1000, n//3)])
    swipe_vel    = np.concatenate([np.random.normal(50,  10,  n//3),
                                   np.random.normal(30,  10,  n//3),
                                   np.random.normal(10,  5,   n//3)])
    correction   = np.concatenate([np.random.normal(0.05, 0.02, n//3),
                                   np.random.normal(0.20, 0.05, n//3),
                                   np.random.normal(0.50, 0.10, n//3)])
    labels = np.array([0]*(n//3) + [1]*(n//3) + [2]*(n//3))

    X = np.column_stack([hesitation, swipe_vel, correction])
    X_train, X_test, y_train, y_test = train_test_split(X, labels, test_size=0.2, random_state=42)

    clf = lgb.LGBMClassifier(n_estimators=100, random_state=42, verbose=-1)
    clf.fit(X_train, y_train)
    print(classification_report(y_test, clf.predict(X_test),
                                 target_names=["Low","Medium","High"]))
    save("lgbm_cognitive_load.pkl", clf)
except ImportError:
    print("  [WARNING] LightGBM not installed -- skipping. Run: pip install lightgbm")

# ────────────────────────────────────────────────────────────────────────────
# 3. UI RL Bandit – Visual Service
# ────────────────────────────────────────────────────────────────────────────
print("\n[3/5] Initialising RL Bandit (Visual Service)...")

class SimpleBandit:
    """ε-greedy multi-armed bandit over 3 UI layouts."""
    def __init__(self, n_arms=3, epsilon=0.1):
        self.n_arms  = n_arms
        self.epsilon = epsilon
        self.q_values = [0.0] * n_arms
        self.counts   = [0]   * n_arms

    def select_layout(self):
        if np.random.rand() < self.epsilon:
            return np.random.randint(self.n_arms)
        return int(np.argmax(self.q_values))

    def update_reward(self, arm: int, reward: float):
        self.counts[arm] += 1
        self.q_values[arm] += (reward - self.q_values[arm]) / self.counts[arm]

bandit = SimpleBandit()
# Warm-up: simulate 200 rounds favouring High-Spacing layout (arm 2)
for _ in range(200):
    arm = bandit.select_layout()
    reward = np.random.normal(0.8 if arm == 2 else 0.4, 0.1)
    bandit.update_reward(arm, reward)
print(f"  Q-values after warm-up: {[round(q,3) for q in bandit.q_values]}")
save("ui_bandit.pkl", bandit)

# ────────────────────────────────────────────────────────────────────────────
# 4. Anomaly Ensemble – Monitoring Service
# ────────────────────────────────────────────────────────────────────────────
print("\n[4/5] Training Anomaly Ensemble (Monitoring Service)...")

try:
    import torch, torch.nn as nn
    _has_torch = True
except ImportError:
    _has_torch = False
    print("  [WARNING] PyTorch not installed -- Autoencoder will be skipped.")
    print("            Run:  pip install torch  then re-run to get full ensemble.")
from sklearn.ensemble import IsolationForest
from sklearn.linear_model import LogisticRegression

NUM_FEATURES = 4  # latency, dwell, erratic_clicks, swipe_velocity
np.random.seed(42)

fluent_data = np.clip(
    np.random.normal([1000, 500, 0.1, 50], [200, 100, 0.05, 10], (1600, NUM_FEATURES)), 0, None)
anomaly_data = np.clip(
    np.random.normal([5000, 2500, 4.0, 10], [1000, 500, 1.5, 5], (400, NUM_FEATURES)), 0, None)
X_all = np.vstack([fluent_data, anomaly_data])
y_all = np.array([0]*1600 + [1]*400)

# Always train Isolation Forest (no torch dependency)
iso = IsolationForest(contamination=0.2, random_state=42)
iso.fit(X_all)
if_scores = -iso.decision_function(X_all)
save("anomaly_iso_forest.pkl", iso)

if _has_torch:
    # Autoencoder
    class TelemetryAE(nn.Module):
        def __init__(self):
            super().__init__()
            self.enc = nn.Sequential(nn.Linear(NUM_FEATURES, 8), nn.ReLU(), nn.Linear(8, 4))
            self.dec = nn.Sequential(nn.Linear(4, 8), nn.ReLU(), nn.Linear(8, NUM_FEATURES))
        def forward(self, x): return self.dec(self.enc(x))

    ae = TelemetryAE()
    X_max = torch.FloatTensor(X_all).max(dim=0, keepdim=True)[0] + 1e-8
    fluent_t = torch.FloatTensor(fluent_data) / X_max
    X_t      = torch.FloatTensor(X_all)      / X_max

    opt  = torch.optim.Adam(ae.parameters(), lr=0.01)
    loss_fn = nn.MSELoss()
    for _ in range(150):
        opt.zero_grad()
        loss = loss_fn(ae(fluent_t), fluent_t)
        loss.backward()
        opt.step()

    ae.eval()
    with torch.no_grad():
        mse_scores = torch.mean((ae(X_t) - X_t)**2, dim=1).numpy()

    # Meta-Classifier (requires both AE + IsoForest scores)
    meta = LogisticRegression(max_iter=500)
    meta.fit(np.column_stack([mse_scores, if_scores]), y_all)
    print(f"  Meta-Classifier accuracy: {meta.score(np.column_stack([mse_scores, if_scores]), y_all):.2%}")

    torch.save(ae.state_dict(), os.path.join(OUTPUT_DIR, "anomaly_autoencoder.pth"))
    print(f"  [SAVED] -> anomaly_autoencoder.pth")
    save("anomaly_meta_clf.pkl", meta)
else:
    print("  [INFO] Isolation Forest saved. Autoencoder + Meta-Clf skipped (no torch).")

# ────────────────────────────────────────────────────────────────────────────
# 5. Intervention Random Forest – Intervention Service
# ────────────────────────────────────────────────────────────────────────────
print("\n[5/5] Training Intervention Random Forest (Intervention Service)...")

from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report as cr

np.random.seed(42)
n = 3000
X_iv = np.column_stack([
    np.random.rand(n) * 10000,  # latency_ms
    np.random.rand(n) * 10,     # erratic_clicks
    np.random.rand(n),          # mastery_level
    np.random.rand(n) * 5,      # previous_failures
])
y_iv = np.zeros(n)
for i in range(n):
    if X_iv[i,1] > 7 or X_iv[i,0] > 8000: y_iv[i] = 2
    elif X_iv[i,2] < 0.4 and X_iv[i,3] >= 2: y_iv[i] = 0
    else: y_iv[i] = 1

Xtr, Xte, ytr, yte = train_test_split(X_iv, y_iv, test_size=0.2, random_state=42)
rf = RandomForestClassifier(n_estimators=100, random_state=42)
rf.fit(Xtr, ytr)
print(cr(yte, rf.predict(Xte), target_names=["Audio Cue","Visual Split","Break"]))
save("intervention_rf.pkl", rf)

# ────────────────────────────────────────────────────────────────────────────
print("\n[DONE] All models trained and saved to final_models/")
print("   Copy the *.pkl files to each service's  ml/  folder before running.")
print("   Copy anomaly_autoencoder.pth to monitoring-service/ml/")
