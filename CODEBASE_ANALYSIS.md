# Comprehensive Codebase Analysis: Adaptive Sinhala Dyslexia Screening Platform (R26-SE-031)

**Project Code:** R26-SE-031  
**Owner:** Gunasena (IT22125798)  
**Date:** May 15, 2026  
**Status:** Implementation Complete  

---

## 📋 Executive Summary

This is a sophisticated **research-backed, adaptive dyslexia screening and intervention platform** designed for Grade 1–2 Sinhala-medium learners. The system combines:

- **Mobile Frontend**: Flutter app for child interaction & assessment
- **Backend Services**: Python microservices architecture (4 services)
- **Database**: MongoDB Atlas for cloud-based data persistence
- **ML/AI Components**: LightGBM models for behavioral signal processing
- **Research Foundation**: Cognitive Load Theory, Double-Deficit Hypothesis, Eye-Movement Research

The platform runs a **Multi-Dimensional Behavioral Signal Vector (MBSV)** architecture where telemetry from touch interactions, response timing, and acoustic proxies drives real-time UI adaptation, personalized content sequencing, and targeted interventions.

---

## 🏗️ Architecture Overview

### System Layers

```
┌─────────────────────────────────────────────────────────┐
│  MOBILE FRONTEND (Flutter) - dyslexia_app               │
│  - Assessment tasks (letter ID, reading fluency, etc.)   │
│  - Real-time telemetry capture                           │
│  - UI adaptation & gamification                          │
└────────────────┬────────────────────────────────────────┘
                 │ HTTP/REST
┌────────────────▼────────────────────────────────────────┐
│  BACKEND MICROSERVICES (Python/FastAPI)                 │
├─────────────────────────────────────────────────────────┤
│ • Port 8001: Monitoring Service (CBME)                  │
│ • Port 8002: Content Service (Mastery Tracking)         │
│ • Port 8003: Intervention Service (Decision Engine)     │
│ • Port 8004: Visual Service (UI Optimization)           │
└────────────────┬────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────┐
│  DATA LAYER                                              │
│  MongoDB Atlas (Cloud Database)                          │
│  - Database: dyslexia_app                               │
│  - Database: dyslexia_content                           │
└─────────────────────────────────────────────────────────┘
```

### Microservices Breakdown

| Service | Port | Purpose | Key Algorithms |
|---------|------|---------|-----------------|
| **Monitoring (C1)** | 8001 | Cognitive Behavioral Monitoring Engine - processes telemetry, generates MBSV | LightGBM ×6, Welford Online, Kalman Filter, Rule-based flags |
| **Content (C2)** | 8002 | Mastery tracking, forgetting curve, content sequencing | Ebbinghaus Forgetting Curve, BKT (Bayesian Knowledge Tracing) |
| **Intervention (C3)** | 8003 | Selects optimal intervention types based on behavioral signals | Random Forest, Multi-Armed Bandit logic |
| **Visual (C4)** | 8004 | UI adaptation, layout optimization, gamification triggers | RL-based optimization, A/B testing |

---

## 📱 Frontend: Flutter Application (dyslexia_app)

### Technology Stack
- **Language**: Dart 3.11.4+
- **Framework**: Flutter
- **State Management**: Provider 6.1.1
- **Audio**: flutter_tts 4.2.5
- **Local Storage**: sqflite 2.4.2, shared_preferences 2.0.20
- **Charting**: fl_chart 1.0.0
- **Fonts**: google_fonts 8.1.0
- **Signature Capture**: signature 6.3.0

### Project Structure

```
dyslexia_app/
├── lib/
│   ├── main.dart                          # App entry point
│   ├── models/                            # Data models
│   │   ├── assessment_results.dart
│   │   ├── comprehension_progress.dart
│   │   ├── fluency_progress.dart
│   │   ├── learner_profile.dart
│   │   ├── letter_identification_score.dart
│   │   ├── letter_picture_task.dart
│   │   ├── mbsv.dart                     # MBSV vector model
│   │   ├── telemetry.dart                # Behavioral telemetry
│   │   ├── typography_config.dart
│   │   └── visual_config.dart
│   ├── screens/                           # UI screens
│   │   ├── ab_testing_runner.dart
│   │   ├── drawing_interpretation_game.dart
│   │   ├── draw_a_man_test.dart
│   │   ├── firefly_tracking_game.dart
│   │   ├── letter_identification_task.dart
│   │   ├── letter_puzzle_game.dart
│   │   ├── login_signup_screen.dart
│   │   ├── questionnaire_report_screen.dart
│   │   └── [many more task screens]
│   ├── data/
│   │   └── reading_passages.dart          # Content library
│   └── services/
│       ├── api_service.dart
│       └── telemetry_service.dart
├── assets/
│   ├── images/
│   └── audio/
├── android/
├── ios/
├── web/
├── macos/
└── pubspec.yaml
```

### Key Assessment Tasks

1. **Letter Identification Task** - Visual letter recognition with timing & accuracy metrics
2. **Reading Fluency Assessment** - Passage reading with pause duration tracking
3. **Comprehension Tasks** - Structured questionnaires
4. **Firefly Tracking Game** - Visual pursuit & attention
5. **Draw-A-Man Test** - Fine motor & spatial awareness
6. **Drawing Interpretation** - Creative/visual reasoning
7. **Letter Puzzle Game** - Gamified letter learning
8. **Questionnaire** - Guardian-reported observations (screening battery)

### Telemetry Capture

The app captures 12 core telemetry features per interaction:

```dart
TelemetryData {
  hesitation_ms: Duration,           // Pause time before/during interaction
  correction_rate: float,             // % of corrections made
  response_latency: Duration,         // Task start → completion
  touch_pressure: float,              // Force applied (if available)
  swipe_velocity: float,              // Speed of swipe gestures
  replay_count: int,                  // Audio replay button presses
  hint_request_count: int,            // Help requests
  stylus_deviation: float,            // RMS error vs. template
  inter_tap_interval: float,          // Variance in tap timing
  read_aloud_pause_ms: float,         // Pause duration in speech
  syllable_rate: float,               // Articulation speed
  disfluency_count: int,              // Speech interruptions
}
```

---

## 🔌 Backend: Python Microservices

### Core API: fluency_api.py

**Type**: Flask REST API  
**Purpose**: Primary backend for assessment data, questionnaire submissions, and progress tracking

#### Collections (MongoDB)

| Collection | Purpose | Key Fields |
|-----------|---------|-----------|
| `fluency_progress` | Reading fluency assessment results | student_id, wpm, accuracy, session_date |
| `letter_identification` | Letter recognition scores | student_id, letter, response_time, correct |
| `comprehension_progress` | Reading comprehension tracking | student_id, passage_id, score, timestamp |
| `questionnaire_submissions` | Guardian questionnaire responses | respondent_role, student_data, risk_level |
| `task_scores` | Aggregated task performance | student_id, task_type, score, session_id |

#### Key Endpoints

- `POST /api/questionnaire` - Save questionnaire (with multiple endpoint aliases for typos)
- `POST /api/fluency` - Save fluency assessment
- `POST /api/letter-identification` - Save letter ID results
- `POST /api/comprehension` - Save comprehension data
- `GET /api/student/<student_id>` - Retrieve student profile

#### Design Features

- **CORS Support**: All endpoints allow cross-origin requests
- **Error Handling**: Missing field validation, graceful error responses
- **MongoDB Connection**: Uses environment variables + .env fallback
- **Async Ready**: Structured for async migration (Flask → FastAPI)

### Microservices Architecture

#### Service 1: Monitoring Service (C1) - Port 8001

**Responsibility**: Cognitive Behavioral Monitoring Engine (CBME)

**Algorithms**:
- **LightGBM Models** (×6 instances): One per MBSV dimension with multi-task gradient boosting
- **Welford Online Algorithm**: Personalized Z-score baseline without storing full history
- **Kalman Filter**: Motor-control uncertainty → cognitive load proxy
- **Rule-Based Flags**: Error pattern detection from interaction logs

**Outputs** (MBSV Vector):
```python
{
  'visual_strain_index': float,        # [0–1] UI difficulty
  'cognitive_load_index': float,       # [0–1] Mental effort
  'phonological_strain_index': float,  # [0–1] Speech/decoding difficulty
  'engagement_index': float,           # [0–1] Interest level (inverted)
  'session_fatigue_index': float,      # [0–1] Tiredness accumulation
  'error_pattern_vector': [int, int, int, int]  # [reversal, omission, substitution, hesitation]
}
```

**Research Basis**:
- Sweller's Cognitive Load Theory (1988)
- Rayner's Eye-Movement Research (2001)
- Wolf & Bowers Double-Deficit Hypothesis (1999)
- Welford's Incremental Statistics (1962)
- Wickens Multiple Resource Theory (1984)

#### Service 2: Content Service (C2) - Port 8002

**Responsibility**: Mastery tracking & content sequencing

**Algorithms**:
- **Ebbinghaus Forgetting Curve**: Spaced repetition timing
- **Bayesian Knowledge Tracing (BKT)**: Probability of skill mastery
- **Content Difficulty Scaling**: Adaptive sequencing based on cognitive load

**Consumes from MBSV**: 
- `cognitive_load_index` (overall mental effort)
- `session_fatigue_index` (session pacing)
- `engagement_index` (gamification triggers)

#### Service 3: Intervention Service (C3) - Port 8003

**Responsibility**: Intervention decision engine

**Algorithms**:
- **Random Forest Classifier**: Selects intervention type (Audio, Visual, Break)
- **Multi-Armed Bandit**: Explores intervention effectiveness over time

**Consumes from MBSV**:
- `phonological_strain_index` (trigger audio support)
- `visual_strain_index` (trigger visual breaks)
- `error_pattern_vector` (target specific error types)

**Intervention Types**:
- **Audio**: Repeat word, phonetic breakdown, listen to pronunciation
- **Visual**: Reduce font size, change background contrast, spatial hints
- **Break**: Pause activity, gamification reward, session restart

#### Service 4: Visual Service (C4) - Port 8004

**Responsibility**: UI adaptation & layout optimization

**Algorithms**:
- **RL-based A/B Testing**: Multi-Armed Bandit for layout variants
- **Engagement-Driven UI**: Font size, color contrast, button placement optimization

**Consumes from MBSV**:
- `visual_strain_index` (font/contrast/spacing)
- `engagement_index` (gamification elements)

---

## 🗄️ Data Layer: MongoDB Atlas

### Database Structure

#### Database 1: `dyslexia_app` (Primary)
- **fluency_progress** - Reading speed & accuracy
- **letter_identification** - Letter recognition assessments
- **comprehension_progress** - Text comprehension scores
- **questionnaire_submissions** - Guardian screening battery responses
- **task_scores** - Aggregated task performance

#### Database 2: `dyslexia_content` (Content Library)
- **questionnaires** - Assessment templates
- **tasks** - Task definitions & content

### MongoDB Connection

```python
MONGO_URI = "mongodb+srv://kavindugunasena_db_user:[PASSWORD]@cluster0.ypxuqen.mongodb.net/"
DB_NAME = 'dyslexia_app'
CONTENT_DB_NAME = 'dyslexia_content'
```

**Connection Features**:
- Async driver ready (motor library)
- 20-second timeout
- Environment variable fallback

---

## 🔬 Research Architecture

### Core Research Question (Group-Level)

> *How can a multi-dimensional behavioral signal vector derived from touch interaction, stylus trace, response timing, and acoustic read-aloud proxies be used to simultaneously drive real-time visual adaptation, personalized content sequencing, and word-level intervention for Sinhala-medium dyslexia screening in Grade 1–2 learners?*

### Theoretical Framework

| Theory | Application |
|--------|-------------|
| **Cognitive Load Theory** (Sweller, 1988) | Decompose total load into visual, phonological, fatigue |
| **Double-Deficit Hypothesis** (Wolf & Bowers, 1999) | Separate phonological & naming-speed deficits |
| **Eye-Movement Research** (Rayner, 2001) | Hesitation >400 ms = decoding difficulty |
| **Multiple Resource Theory** (Wickens, 1984) | Multi-channel monitoring (visual vs. phonological) |
| **Incremental Statistics** (Welford, 1962) | Online baselines without storing full history |
| **Oral Reading Fluency** (Fuchs et al., 2001) | Pause duration & articulation rate proxies |

### MBSV Ownership & Boundaries

**Critical Architecture Rule**: Each MBSV dimension has ONE owner; other services may only *consume* it, not derive it.

| Dimension | Owner | Consumer | Forbidden |
|-----------|-------|----------|-----------|
| visual_strain_index | C1 (Monitoring) | C2 (Visual) | C3, C4 |
| cognitive_load_index | C1 | C3 (Content) | C2, C4 |
| phonological_strain_index | C1 | C4 (Intervention) | C2, C3 |
| engagement_index | C1 | C2 | C3, C4 |
| session_fatigue_index | C1 | C3 | C2, C4 |
| error_pattern_vector | C1 | C4 | C2, C3 |

---

## 📁 Project File Organization

### Root Directory Key Files

```
R26-SE-031/
├── README.md                              # Quick start guide
├── QUICK_START.md                         # Setup instructions
├── QUICK_START_GUIDE.md                   # Detailed setup
├── FULL_IMPLEMENTATION_PLAN.md            # 200+ page implementation roadmap
├── IMPLEMENTATION_COMPLETE_SUMMARY.md     # Completion status
├── VIVA_TALKING_POINTS.md                 # Demo presentation guide
├── MONGODB_SETUP.md                       # Database setup
├── ASSESSMENT_SCORING_ANALYSIS.md         # Scoring methodology
├── SINHALA_PHONOLOGICAL_TASK.md           # Sinhala-specific assessment
├── fluency_api.py                         # Primary Flask API
├── dyslexia_app/                          # Flutter mobile app
├── legacy/                                # Previous versions (deprecated)
└── docs/                                  # Architecture documentation
    └── architecture/
        ├── system_functionality.md
        ├── system_analysis_roadmap.md
        └── ml_models.md
```

### Documentation Coverage

- **Implementation Status**: COMPLETE (as of May 14, 2026)
- **Architecture**: Fully documented with research basis
- **Setup**: Multiple guides for different audiences (dev, demo, deployment)
- **Viva Talking Points**: 19KB guide for presentation & defense

---

## 🛠️ Tech Stack Summary

### Frontend
- **Language**: Dart 3.11.4+
- **Framework**: Flutter
- **State Management**: Provider
- **Database**: SQLite (local) + shared_preferences
- **APIs**: HTTP client for REST
- **Audio**: flutter_tts for text-to-speech
- **UI Components**: Material Design, custom widgets

### Backend
- **Language**: Python 3.9+
- **Frameworks**: Flask (primary), FastAPI (planned)
- **Web Server**: Uvicorn
- **Database**: MongoDB (Atlas cloud)
- **Async**: Motor (async MongoDB driver)
- **ML**: LightGBM, scikit-learn, joblib
- **Data**: pandas, numpy
- **Task Processing**: Kalman filter, Welford algorithm

### DevOps & Deployment
- **Version Control**: Git
- **Cloud Database**: MongoDB Atlas
- **Port Configuration**: 8001–8004 for microservices
- **CORS**: Enabled for cross-origin requests

---

## 🔄 Data Flow

### Assessment Session Flow

```
1. Student logs in (login_signup_screen.dart)
   ↓
2. Select assessment task (Task-specific screen)
   ↓
3. Capture telemetry → TelemetryData (12 features)
   ↓
4. Submit to fluency_api (Flask)
   ↓
5. Process in Monitoring Service (Port 8001)
   ├─ Run LightGBM models (×6)
   ├─ Generate MBSV vector
   ├─ Store in MongoDB
   ↓
6. Content Service (Port 8002) receives MBSV
   ├─ Updates mastery tracking (BKT)
   ├─ Sequences next content
   ↓
7. Intervention Service (Port 8003) checks MBSV
   ├─ Triggers intervention if needed
   ↓
8. Visual Service (Port 8004) adapts UI
   ├─ Adjusts font, colors, layout
   ↓
9. Results sent back to Flutter app
   ↓
10. Update UI, trigger next task
```

---

## ⚠️ Key Architecture Decisions

1. **Multi-Dimensional Over Single-Scalar**: Previous RSI (Reading Strain Index) replaced with MBSV for cleaner ownership boundaries
2. **Cloud-First Database**: MongoDB Atlas instead of local instance for scalability & remote access
3. **Microservices Over Monolith**: 4 independent services allow parallel development & clear responsibilities
4. **Research-Backed Features**: Every algorithm grounded in peer-reviewed literature
5. **No ASR (Automatic Speech Recognition)**: Audio features derived from energy envelopes instead—improves privacy & robustness for Sinhala
6. **Provider for State Management**: Lightweight, performant for this use case
7. **Welford Online Statistics**: Personalized baselines without storing full history

---

## 🎯 Quality Assurance

### Artifacts in Repository
- **FULL_IMPLEMENTATION_PLAN.md**: 200+ page specification with every component detailed
- **ASSESSMENT_SCORING_ANALYSIS.md**: Validation of scoring methodologies
- **COMPILATION_FIXES_SUMMARY.md**: Known issues & resolutions
- **Test Coverage**: Multiple guides on expected vs. actual outputs

### Known Status
- All services functional
- Flutter app runs on iOS, Android, Web
- MongoDB integration complete
- CORS properly configured
- Telemetry capture validated
- MBSV vector generation tested

---

## 📊 Performance Characteristics

| Component | Metric | Target |
|-----------|--------|--------|
| Telemetry Capture | Latency | <50 ms |
| MBSV Generation | Latency | <500 ms |
| API Response | Latency | <1 s |
| Task Load Time | Time | <2 s |
| Session Duration | Typical | 15–25 min |
| Battery Impact | Estimation | Low (no ASR) |

---

## 🚀 Getting Started

### Prerequisites
```bash
# Backend
pip install fastapi uvicorn motor pymongo joblib pandas numpy requests

# Frontend
flutter pub get
```

### Run Services

```bash
# Terminal 1: Monitoring Service
uvicorn monitoring-service.main:app --port 8001 --reload

# Terminal 2: Content Service
uvicorn content-service.main:app --port 8002 --reload

# Terminal 3: Intervention Service
uvicorn intervention-service.main:app --port 8003 --reload

# Terminal 4: Visual Service
uvicorn visual-service.main:app --port 8004 --reload

# Terminal 5: Fluency API
python fluency_api.py

# Terminal 6: Flutter app
cd dyslexia_app
flutter run
```

### Access Demo Dashboard
Once services are running:
```
http://127.0.0.1:8001/demo/index.html
```

---

## 📚 Key References & Resources

- **System Design**: `docs/architecture/system_functionality.md`
- **Implementation Roadmap**: `FULL_IMPLEMENTATION_PLAN.md`
- **Setup Guide**: `QUICK_START_GUIDE.md`
- **Presentation**: `VIVA_TALKING_POINTS.md`
- **Database Config**: `MONGODB_SETUP.md`
- **Assessment Details**: `ASSESSMENT_SCORING_ANALYSIS.md`

---

## 🎓 Research Contribution

This platform advances dyslexia screening by:

1. **Removing ASR Dependency**: Acoustic features from energy envelopes (not speech-to-text)
2. **Multi-Dimensional Signals**: MBSV replaces single-metric approaches with 6-dimensional telemetry
3. **Sinhala Adaptation**: First adaptive screening platform for Sinhala Grade 1–2
4. **Real-Time Intervention**: AI-driven decision engine at engagement moment
5. **Scalable Cloud Architecture**: MongoDB Atlas enables remote educator dashboards

---

## 📝 Notes

- **Project Owner**: Gunasena (IT22125798)
- **University**: SLIIT
- **Course**: RP-IT4010 (Research Project)
- **Status**: Implementation Complete (May 14, 2026)
- **Git History**: Full commit history preserved in .git/
- **Deprecated**: Legacy services in `/legacy` folder (not in active use)

---

**Last Updated**: May 15, 2026  
**Analysis Version**: 1.0
