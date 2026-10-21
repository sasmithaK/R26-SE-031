# Sipsara - Learn, Play & Grow! 🚀

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-005571?style=for-the-badge&logo=fastapi)
![MongoDB](https://img.shields.io/badge/MongoDB-%234ea94b.svg?style=for-the-badge&logo=mongodb&logoColor=white)
![PyTorch](https://img.shields.io/badge/PyTorch-%23EE4C2C.svg?style=for-the-badge&logo=PyTorch&logoColor=white)

**Sipsara** is an adaptive, interactive educational application tailored specifically for Grade 1 students. It combines a highly engaging gamified Flutter frontend with a robust, AI-powered FastAPI backend to provide personalized learning journeys through Speech-to-Text (STT), Text-to-Speech (TTS), and Machine Learning analytics.

---

## 🌟 Key Features

* **Adaptive Learning Engine:** Uses Scikit-Learn to analyze student interactions and adapt difficulty in real-time.
* **Interactive Audio/Voice Processing:** Integrates `gTTS` and PyTorch-based NLP transformers for seamless voice-based interactions (TTS & STT).
* **Rich Gamified UI:** Built in Flutter, featuring beautiful animations, progress tracking (`fl_chart`), and interactive elements to keep children engaged.
* **Secure Authentication:** Multi-layered security using JWT, complete with Google/Microsoft Social OAuth and OTP-based email verification.
* **Real-time Progress Dashboard:** Parents and teachers can track performance via integrated interactive charts and reports.
* **Smart Device Features:** QR/Barcode scanning (`mobile_scanner`) and device sensor utilization for interactive mini-games.

---

## 🏗 Architecture & Tech Stack

The completed adaptive-learning implementation, item-bank contract, model
status, calibration workflow, and verification commands are documented in
[Component 4](docs/component4/README.md).

### Frontend (Mobile App)
* **Framework:** Flutter (Dart) `v3.11.4+`
* **State Management & Logic:** Designed for seamless UI rendering and background processing.
* **Audio & Multimedia:** `just_audio`, `audioplayers`, `flutter_tts`
* **Visuals:** `fl_chart`, `font_awesome_flutter`, `google_fonts`

### Backend (Core API Service)
* **Framework:** FastAPI (Python 3)
* **Database:** MongoDB (using `Motor` for asynchronous operations)
* **Machine Learning:** `scikit-learn`, `numpy` for analytics pipelines.
* **AI & NLP:** `torch`, `transformers`, `gTTS`, `librosa`, `soundfile`
* **Security:** `passlib`, `PyJWT`, `slowapi` (rate limiting)

---

## 🚀 Getting Started

### Prerequisites
* **Flutter SDK:** ^3.11.4
* **Python:** 3.10+
* **MongoDB:** Local instance or MongoDB Atlas cluster

### 1. Backend Setup (`/app/backend/api`)

Navigate to the backend directory and set up the Python environment:

```bash
cd app/backend/api
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

Create a `.env` file with your environment variables (MongoDB URI, JWT Secrets, SMTP credentials).

Run the backend server:
```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### 2. Frontend Setup (`/app/frontend`)

Navigate to the Flutter frontend directory and fetch dependencies:

```bash
cd app/frontend
flutter pub get
```

Run the application on an emulator or connected device:
```bash
flutter run
```

---

## 📁 Repository Structure

```text
├── app/
│   ├── frontend/        # Flutter Mobile Application
│   │   ├── lib/         # Dart source code (screens, widgets, services)
│   │   ├── assets/      # Images, audio, and curriculum data
│   │   └── pubspec.yaml # Flutter dependencies
│   ├── backend/         # Backend Services
│       └── api/         # FastAPI Application (api)
│           ├── routers/ # API Endpoints
│           ├── schemas/ # Pydantic Data Models
│           └── services/# Business Logic & ML Models
└── README.md            # Project Documentation
```

---

## 🛡 Security & Compliance

Sipsara takes student data privacy seriously. All analytics are anonymized, and authentication utilizes industry-standard encryption. The backend API is rate-limited (`slowapi`) and enforces strong JWT token validation to prevent unauthorized access.

---

## 🤝 Contributing

Contributions are welcome! Please ensure you follow the existing coding style and run `flutter analyze` for the frontend and `pytest` for the backend before submitting pull requests.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
