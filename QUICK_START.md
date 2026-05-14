# R26-SE-031 Quick Start — Sinhala Dyslexia Screening Platform

## Prerequisites

- Python 3.8+ installed
- Flutter 3.0+ with web support enabled
- Git (for cloning if needed)

## Step 1: Start Backend Services (5 minutes)

Open a terminal and run:

```bash
cd R26-SE-031-V2
python start_services.py
```

You should see:
```
[OK] C1-CBME: Running on port 8011
[OK] C2-AVLI: Running on port 8014
[WAIT] C3-PLCE: Running on port 8012 but not yet responding
[WAIT] C4-IIGE: Running on port 8013 but not yet responding
```

Keep this terminal open. Services will continue running in the background.

## Step 2: Start Flutter Web (3 minutes)

Open a NEW terminal and run:

```bash
cd sample_demo_with_monitoring
flutter clean
flutter pub get
flutter run -d web
```

Wait for the message:
```
Launching lib/main.dart on Chrome...
```

Your browser should open automatically. If not, open the URL shown (usually http://localhost:5173).

## Step 3: Interact with the App

You should see:
- **Left panel**: Word matching task with Sinhala words
- **Right panel**: Real-time MBSV monitoring (6 dimensions)
  - Cognitive Load Index
  - Phonological Strain Index
  - Visual Strain Index
  - Session Fatigue Index
  - Engagement Index
  - Error Resilience Index

Click on words in the task. Watch the MBSV values update in real-time from C1!

## Step 4: Verify Integration (Optional)

In a new terminal:

```bash
cd R26-SE-031-V2
python start_services.py --test
```

Expected output:
```
[OK] C1-CBME  http://127.0.0.1:8011/health
[OK] C2-AVLI  http://127.0.0.1:8014/health
[OK] C3-PLCE  http://127.0.0.1:8012/health
[OK] C4-IIGE  http://127.0.0.1:8013/health

4/4 services responding
```

## Step 5: Run Integration Tests (Optional)

```bash
cd R26-SE-031-V2
python COMPLETE_INTEGRATION_TEST.py
```

Should show:
```
C1: 3 passed
C2: 2 passed
C3: 3 passed
C4: 3 passed
```

## Step 6: Train ML Model (Optional)

To train the MBSV prediction model with real or synthetic data:

```bash
cd R26-SE-031-V2
python scripts/train_c1_lgbm_real_data.py
```

This trains on HuggingFace Sinhala dyslexia datasets (or synthetic fallback).

## Troubleshooting

### Services Won't Start

**Error**: "Port 8011 is already in use"

Windows:
```bash
netstat -ano | findstr "801"
taskkill /PID <pid> /F
```

Linux/Mac:
```bash
lsof -i :8011 | grep LISTEN | awk '{print $2}' | xargs kill -9
```

### Flutter Web Shows Errors

**Error**: "Failed to connect to Monitoring Service"

1. Make sure services are running: `python start_services.py --test`
2. Check that ports 8011-8014 are open
3. Try refreshing the browser
4. Check browser console (F12) for CORS errors

### MongoDB Not Connecting

**This is OK!** Services automatically fall back to in-memory storage for demo mode. Data won't persist between restarts, but the system will work fine for testing.

## System Architecture

```
Flutter Web App (localhost:5173)
    |
    +---> C1: Monitoring Service (8011)
    |     - Processes touch telemetry
    |     - Computes 6D MBSV
    |     - Uses Kalman filter for motor precision
    |
    +---> C2: Visual Service (8014)
    |     - LinUCB contextual bandit
    |     - Typography adaptation
    |     - Gamification control
    |
    +---> C3: Content Service (8012)
    |     - Bayesian Knowledge Tracing
    |     - Mastery estimation
    |
    +---> C4: Intervention Service (8013)
    |     - SM-2 spaced repetition
    |     - RTI escalation
```

## Service Ports

| Service | Port | Purpose |
|---------|------|---------|
| C1-CBME | 8011 | Behavioral monitoring |
| C2-AVLI | 8014 | Visual adaptation |
| C3-PLCE | 8012 | Content sequencing |
| C4-IIGE | 8013 | Intervention logic |

## Key Features

- **Real-time MBSV**: 6-dimensional behavioral signal from touch kinematics
- **Adaptive Typography**: LinUCB bandit learning Sinhala-specific fonts
- **Kalman Filter**: Motor-control uncertainty as cognitive load proxy
- **Acoustic Validation**: Disfluency detection from on-device audio
- **LightGBM Model**: Predicts MBSV from behavioral features

## Next Steps

1. Train the ML model: `python scripts/train_c1_lgbm_real_data.py`
2. Conduct validation study with real children
3. Deploy to production with MongoDB Atlas
4. Integrate with C3 & C4 for full system

## Documentation

- **STARTUP_GUIDE.md** — Detailed setup & troubleshooting
- **TRAINING_METHODOLOGY.md** — ML model training with real Sinhala data
- **SERVICE_GUIDE.md** — Service architecture & API documentation

---

**Status**: Ready to run ✓
**Last Updated**: May 2026
**Contact**: R26-SE-031 Research Team
