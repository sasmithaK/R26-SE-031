# Machine Learning Architecture Overview & Comparative Research Models (R26-SE-031)

To ensure high academic rigor and prove research worthiness, this project does not rely on a single algorithm per feature. Instead, every functional area defines a **Primary Advanced Model**, a **Secondary Advanced Model**, and a **Baseline Model**. 

These models will be trained on the same datasets, allowing us to comparatively test execution speed, processing footprint on mobile devices, and overall accuracy to scientifically determine the mathematically superior approach for dyslexic Sinhala/Tamil learners.

| Microservice Component | Functional Feature | Primary Advanced Model | Secondary Advanced Model (Comparison) | Baseline Model (Control) | Target Research Evaluation Metric | Data Types Required |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`monitoring-service`** | **Facial Expression (Emotion)** | **MobileNetV2** (CNN fine-tuned on emotion datasets) | **Vision Transformers (ViT)** (For capturing global spatial dependencies) | **Support Vector Machine (SVM)** (Trained on Facial Action Units) | F1-Score vs. On-Device Inference Time (ms) | `[x, y, z]` 3D facial landmark matrix via MediaPipe |
| **`monitoring-service`** | **Eye Movement & Gaze Tracking** | **Long Short-Term Memory (LSTM)** (Sequence modeling) | **Temporal Convolutional Network (1D-TCN)** | **Hidden Markov Model (HMM)** | ROC-AUC for classifying Fixations vs Regressions | Sequential pupil `(x, y)` coordinates mapped against time `(t)` |
| **`monitoring-service`** | **UI Telemetry Analytics** | **LightGBM** (Highly efficient Gradient Boosting) | **XGBoost** (Robust tabular boosting) | **Random Forest Classifier** | Precision/Recall for Cognitive Block Detection | Tabular JSON (Dwell time, Mistap count, Velocity) |
| **`visual-service`** | **Adaptive Visual Interface** | **Contextual Bandits (LinUCB)** (Online learning exploration) | **Deep Q-Networks (DQN)** (Deep Reinforcement Learning) | **Static WCAG 2.1 Ruleset** (No machine learning) | Cumulative Reward (RSI Reduction over 10 sessions) | State Vector (Student RSI) + Action Space (Font, Spacing parameters) |
| **`intervention-service`**| **Phoneme Error Classification**| **Deep Neural Networks (DNN)** (Capable of complex non-linear Unicode mapping) | **Support Vector Machine (SVM)** (High margin classification for textual bounds) | **Random Forest Classifier** | Cross-Entropy Loss on Sinhala/Tamil syllable splits | Deterministic NLP string properties (Length, Vowel modifiers) |
| **`intervention-service`**| **Skill Mastery Tracking** | **Bayesian Knowledge Tracing (BKT)** (Probabilistic states) | **Performance Factors Analysis (PFA)** (Extension of logistic regression) | **Simple Moving Average** (Last 5 scores) | Root Mean Square Error (RMSE) on predicting the next answer correctly | Binary array `(Skill_ID, Result_0_1, Timestamp)` |
| **`content-service`** | **Personalized Content Engine**| **Transformer-based DKT (SAKT)** (Self-Attentive Knowledge Tracing) | **RNN-based DKT (Deep Knowledge Tracing)** | **Item-Based Collaborative Filtering** | Area Under the ROC Curve (AUC) for predicting future gaps | Sequential arrays of `[Question_ID, Binary_Result]` |

### Research Methodology Justification
By establishing this triad of models for every distinct feature, the thesis can objectively prove computational findings:
1. **Accuracy vs Efficiency Trade-offs:** e.g., Proving that while Vision Transformers might be 2% more accurate at detecting frustration, MobileNetV2 runs 400% faster on a standard student tablet battery.
2. **Cold-Start Resilience:** e.g., Proving that Contextual Bandits outperform Deep Q-Networks significantly during the first 10 minutes of a brand-new student utilizing the system, which is paramount for early primary learners.
3. **Language Context:** e.g., Demonstrating how standard English NLP classifiers collapse when exposed to Sinhala abugida clusters, allowing the DNN to mathematically outperform standard baselines.
