# 🧠 Content Personalization Engine — Phase 01

## Project Overview
The **Content Personalization Engine** is a core component of the Sinhala Adaptive Dyslexia Platform. Its primary role in Phase 01 is **Learner Classification**. 

The system ingests real-time behavioral telemetry (hesitation times, click patterns, cognitive load) from the student's device and uses Machine Learning to classify them into specific learner profiles. These profiles are then used to dynamically adapt curriculum content in Phase 02.

---

## 🚀 Key Features
- **Real-Time Integration:** Directly pulls data from the `monitoring_db` established by the Monitoring Service.
- **Explainable AI:** Uses a **Random Forest Classifier** that doesn't just give a prediction, but also provides a human-readable "Reason" (e.g., *"High hesitation + high erratic clicks"*).
- **Academic Validation:** Includes a built-in evaluation dashboard showing **Accuracy**, **F1-Score**, **Confusion Matrices**, and **Feature Importance**.
- **Simulator:** A dedicated UI to mock student behavior and test the AI classification engine instantly.

---

## 🛠 Tech Stack
- **Backend:** Python, FastAPI, Scikit-Learn (ML), Motor (Async MongoDB Driver).
- **Frontend:** React, Tailwind CSS, Recharts (Data Visualization), Lucide Icons.
- **Database:** MongoDB (Local instance using `monitoring_db`).

---

## 📂 Architecture & Data Flow

### 1. Data Source
The engine monitors two specific collections in the `monitoring_db`:
- `student_baseline`: Historical averages for the student (mean hesitation, correction rates).
- `latest_telemetry`: Real-time session data (current hesitation, erratic clicks, cognitive load).

### 2. Machine Learning Pipeline
- **Ingestion:** The system joins the two tables by `student_id`.
- **Feature Engineering:** All 8 raw metrics are normalized using a `StandardScaler`.
- **Classification:** A Random Forest model predicts the `learner_type` (Balanced, Struggling Reader, Audio Dependent, etc.).
- **Persistence:** Predictions are saved to the `learner_predictions` collection for use by the curriculum engine.

---

## 🖥️ How to Run

### Backend
1. Navigate to `backend/`.
2. Activate the virtual environment: `source venv/bin/activate`.
3. Start the server: `python main.py`.

### Frontend
1. Navigate to `frontend/`.
2. Start the development server: `npm run dev`.

---

## 📊 Dashboard Navigation
- **Model Training:** View model health, confusion matrices, and which features the AI considers most important.
- **Simulator:** Adjust sliders to mimic different dyslexic behaviors and see how the AI classifies the student.
- **Results:** View the final **Student Profile Card** with confidence scores and reasoning.
