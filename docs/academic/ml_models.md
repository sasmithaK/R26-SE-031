# Machine Learning Architecture: Auditory & Reading Research (R26-SE-031)

This project comparatively evaluates models specifically for their ability to map **Auditory Phonemes** to **Visual Graphemes** in Sinhala for primary learners. It incorporates advanced anomaly detection and Explainable AI (XAI) to ensure ethical and transparent medical/educational assessments.

| Microservice | Research Feature | Primary Model | Secondary Model | Ensemble / XAI Strategy | Target Research Metric |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Monitoring** | **Personalized Frustration Baseline** | **Isolation Forest** | **One-Class SVM** | Learns what a "normal" response time is per student to detect true anomalies rather than using static thresholds. | Precision/Recall for detecting anomalous cognitive load. |
| **Monitoring** | **Cognitive Struggle Detection** | **Autoencoder (Neural Net)** | **LightGBM** | **Ensemble Meta-Classifier (Logistic Regression):** Combines Autoencoder Reconstruction Error (MSE) and Isolation Forest scores. | F1-Score for identifying specific Sinhala "Pilla" confusion. |
| **Content** | **Multimodal Skill Prediction** | **Transformer-DKT** | **LSTM-DKT** | Ensembles deep sequential history against a Random Forest baseline. | AUC for predicting if a student can read a word they just heard correctly. |
| **Intervention** | **Modality Optimization** | **Random Forest** | **Decision Tree** | **Explainable AI (SHAP & LIME):** Generates transparent reports on *why* a specific audio/visual cue was chosen. | Precision in selecting Audio-cue vs Visual-split for decoding. |
| **Visual** | **Reading Fluency Adaptation** | **LinUCB (Bandits)** | **DQN** | Real-time state exploitation. | Reward: Increase in "Words Per Minute" (WPM) reading speed. |

---

### Key Research Themes & Advanced Integrations
1. **Unsupervised Anomaly Detection:** Instead of assuming a 5-second delay is "frustration", the system uses an Isolation Forest to learn a specific child's motor-coordination baseline, flagging statistically significant deviations as cognitive struggle.
2. **Reconstruction Error as a Cognitive Metric:** An Autoencoder trained exclusively on "fluent" interactions will fail to reconstruct erratic telemetry caused by dyslexia triggers (e.g., Bandi Akshara). The resulting high Mean Squared Error (MSE) acts as a mathematical trigger for intervention.
3. **Transparent & Ethical AI (XAI):** Utilizing SHAP (SHapley Additive exPlanations) ensures the Intervention Service does not act as a "Black Box". Teachers and parents receive exact percentage breakdowns of why the AI made an instructional decision.
