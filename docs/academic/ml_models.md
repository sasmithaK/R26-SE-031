# Machine Learning Architecture: Auditory & Reading Research (R26-SE-031)

This project comparatively evaluates models specifically for their ability to map **Auditory Phonemes** to **Visual Graphemes** in Sinhala for primary learners.

| Microservice | Research Feature | Primary Model | Secondary Model | Baseline Model | Target Research Metric |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Monitoring** | **Audio-Visual Mapping Latency** | **LSTM** (Time-series) | **1D-TCN** | **Mean Threshold** | Correlation between Audio-Replay frequency and Reading Error rate. |
| **Monitoring** | **Phonological Error Classification** | **LightGBM** | **SVM** | **Naive Bayes** | F1-Score for identifying specific Sinhala "Pilla" confusion. |
| **Content** | **Multimodal Skill Prediction** | **Transformer-DKT** | **RNN-DKT** | **BKT** | AUC for predicting if a student can read a word they just heard correctly. |
| **Intervention** | **Modality Optimization** | **DNN** | **Random Forest** | **Decision Tree** | Precision in selecting Audio-cue vs Visual-split for decoding. |
| **Visual** | **Reading Fluency Adaptation** | **LinUCB (Bandits)** | **DQN** | **WCAG Rules** | Reward: Increase in "Words Per Minute" (WPM) reading speed. |

---

### Key Research Themes
1. **Phonological Awareness:** Using ML to quantify how many times a student needs to hear a "Hraswa" sound before they can visually identify it.
2. **Synchronized Scaffolding:** Proving that AI-driven "Synchronized Highlighting" (highlighting letters during audio playback) reduces the cognitive load more effectively than static visual aids.
3. **Reading vs. Listening Gaps:** Mathematically identifying students who have a "high intelligence/listening" but "low reading" profile, which is a hallmark of dyslexia.
