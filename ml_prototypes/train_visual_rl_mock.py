import joblib
import os
import numpy as np

os.makedirs('../visual-service/ml', exist_ok=True)

class ContextualBanditUI:
    """
    A simple Reinforcement Learning (Contextual Bandit) mock for the Visual Service.
    It learns which UI layout yields the best reward (e.g., fastest correct answer).
    Actions:
    0 = Default Layout
    1 = Bionic Reading (Bolded starting syllables)
    2 = High Spacing + Highlighted Diacritics (Pilla)
    """
    def __init__(self, epsilon=0.2):
        self.epsilon = epsilon
        self.q_values = {0: 0.0, 1: 0.0, 2: 0.0}
        self.action_counts = {0: 0, 1: 0, 2: 0}
        
    def select_layout(self):
        # Epsilon-greedy selection: balance exploration and exploitation
        if np.random.rand() < self.epsilon:
            return np.random.choice([0, 1, 2])
        else:
            return max(self.q_values, key=self.q_values.get)
            
    def update_reward(self, action, reward):
        self.action_counts[action] += 1
        n = self.action_counts[action]
        value = self.q_values[action]
        new_value = ((n - 1) * value + reward) / n
        self.q_values[action] = new_value

print("Initializing Visual Service RL Mock...")
model = ContextualBanditUI()
# Pre-train slightly with dummy values so the PoC favors Bionic Reading
model.update_reward(0, 1.0)
model.update_reward(1, 4.5) 
model.update_reward(2, 2.0)

model_path = '../visual-service/ml/ui_bandit.pkl'
joblib.dump(model, model_path)
print(f"Visual Model saved to {model_path}")
