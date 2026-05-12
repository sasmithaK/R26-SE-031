# Dyslexia Microservices - MongoDB Atlas & Demo

This repository contains a 4-service microservice architecture migrated to **MongoDB Atlas** for high-fidelity cognitive load monitoring and intervention.

## 🚀 Services Overview

1.  **Monitoring Service (Port 8001)**: Core telemetry processing and ML-based cognitive load estimation. Includes the **Side-by-Side Demo Dashboard**.
2.  **Content Service (Port 8002)**: Mastery tracking and forgetting curve logic (Ebbinghaus algorithm).
3.  **Intervention Service (Port 8003)**: Random Forest model for selecting optimal intervention types (Audio, Visual, Break).
4.  **Visual Service (Port 8004)**: UI adaptation and RL-based layout optimization (Multi-Armed Bandit).

## 🛠 Setup & Run

### 1. Prerequisites
- Python 3.9+
- MongoDB Atlas cluster (already configured in code)
- Dependencies: `pip install fastapi uvicorn motor pymongo joblib pandas numpy requests`

### 2. Seed Data
Populate the cloud database with demo data:
```bash
python simulate_demo_data.py
```

### 3. Start Services
Run each service in a separate terminal from the root directory:

**Monitoring:**
```bash
uvicorn monitoring-service.main:app --port 8001 --reload
```

**Content:**
```bash
uvicorn content-service.main:app --port 8002 --reload
```

**Intervention:**
```bash
uvicorn intervention-service.main:app --port 8003 --reload
```

**Visual:**
```bash
uvicorn visual-service.main:app --port 8004 --reload
```

## 📺 Demo Dashboard
Once the services are running, access the premium demo interface at:
**[http://127.0.0.1:8001/demo/index.html](http://127.0.0.1:8001/demo/index.html)**

### Dashboard Features:
- **Side-by-Side View**: Live camera feed (biometric scan) vs. student interaction telemetry.
- **Real-time Prediction**: ML model predicts cognitive load level (Low/Medium/High) instantly.
- **Automatic Intervention**: Triggers intervention events when load spikes.
- **Log Stream**: Full visibility into telemetry parameters and system events.

## ☁️ Database Configuration
The system uses a shared MongoDB Atlas cluster:
- **URI**: `mongodb+srv://kavindugunasena_db_user:2Vp8ipkprifuEH8t@cluster0.ypxuqen.mongodb.net/`
- **Driver**: `motor` (Asynchronous)
