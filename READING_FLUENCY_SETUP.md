# Reading Fluency Task - Complete Setup Guide

## Overview
The Reading Fluency Task is a new feature for the Dyslexia E-Learning app that:
- Tracks students' reading speed (WPM - words per minute)
- Calculates fluency levels based on sessions and performance
- Stores progress in MongoDB for teacher/parent monitoring
- All UI text is in Sinhala for grade 1 dyslexic students

## Fluency Level System

### Level Calculation Rules:
- **Level 1 (ආරම්භක)**: New students (0 sessions) or WPM < 20
- **Level 2 (වැඩිවෙමින්)**: 1-3 sessions with WPM 20-40
- **Level 3 (ප්‍රවාහිතා)**: 4+ sessions with WPM 35-60
- **Level 4 (උසස්)**: WPM >= 60

### Example:
- A new student starts at Level 1
- A student with 4 completed sessions at 35 WPM is at Level 3

## Flutter App Changes

### New Files Created:
1. **`lib/models/fluency_progress.dart`** - Data model for fluency tracking
2. **`lib/services/fluency_service.dart`** - API service to communicate with backend
3. **`lib/screens/reading_fluency_task.dart`** (updated) - Main reading task screen

### Modified Files:
1. **`lib/main.dart`** - Added route `/reading_fluency`
2. **`lib/screens/student_dashboard.dart`** - Added navigation card with Sinhala text "කියවීමේ ප්‍රවාහිතාව"
3. **`pubspec.yaml`** - Added `http: ^1.1.0` dependency

### Features:
- 4-word Sinhala sentences for students to read
- Per-word highlighting as students tap words
- Real-time WPM calculation
- Results dialog showing time, WPM, and fluency level
- Local storage via SharedPreferences
- **NEW**: MongoDB integration for progress tracking

## Backend Setup (MongoDB)

### Files:
- **`fluency_api.py`** - Flask API backend for MongoDB integration

### Prerequisites:
```bash
pip install flask pymongo
```

### Running the Backend:
```bash
# Ensure MongoDB is running
mongod

# In another terminal
python fluency_api.py
```

The API will be available at `http://localhost:5000`

### API Endpoints:

#### Save/Update Fluency Progress
```
POST /api/fluency
Content-Type: application/json

{
  "studentId": "student_123",
  "sessionsCompleted": 4,
  "avgWpm": 35.5,
  "fluencyLevel": 3,
  "lastUpdated": "2026-05-08T14:30:00Z"
}
```

#### Get Fluency Progress for a Student
```
GET /api/fluency/{studentId}
```

Response:
```json
{
  "studentId": "student_123",
  "sessionsCompleted": 4,
  "avgWpm": 35.5,
  "fluencyLevel": 3,
  "lastUpdated": "2026-05-08T14:30:00Z"
}
```

#### Update Fluency Progress
```
PUT /api/fluency/{studentId}
Content-Type: application/json

{
  "sessionsCompleted": 5,
  "avgWpm": 38.2,
  "fluencyLevel": 3,
  "lastUpdated": "2026-05-08T15:00:00Z"
}
```

#### Get Class Progress (for monitoring)
```
GET /api/fluency/class/{classId}
```

## How It Works

### Flow:
1. Student taps "ක්‍රීඩා කරමු!" (Play) → Student Dashboard
2. Taps "කියවීමේ ප්‍රවාහිතාව" (Reading Fluency) card
3. Sees the Sinhala sentence with 4 words
4. Taps "ආරම්භ කරන්න" (Start) button
5. As student reads, taps each word
6. Timer tracks reading time
7. WPM is calculated (4 words / minutes)
8. Session saved to:
   - Local device via SharedPreferences
   - MongoDB (if backend is available)
9. Fluency level is calculated and displayed
10. Results dialog shows progress

### Data Flow:
```
Flutter App
    ↓
SharedPreferences (Local backup)
    ↓
FluencyService (HTTP requests)
    ↓
Flask Backend (fluency_api.py)
    ↓
MongoDB (Student fluency progress)
```

## Student ID Management

The app generates or retrieves a student ID:
- First run: Auto-generated as `student_{timestamp}`
- Stored in SharedPreferences for consistency
- Used as key in MongoDB for tracking

## Testing

### Local Testing (No Backend):
1. Build and run the Flutter app
2. The app will use SharedPreferences locally
3. MongoDB save attempts will fail silently (logged to console)

### With Backend:
1. Ensure MongoDB is running: `mongod`
2. Start backend: `python fluency_api.py`
3. Update `FluencyService.baseUrl` if not `localhost:5000`
4. Run Flutter app - will sync progress to MongoDB

## Monitoring Student Progress

Teachers/Parents can:
1. View individual student progress via GET `/api/fluency/{studentId}`
2. View class progress via GET `/api/fluency/class/{classId}`
3. Track improvement across sessions
4. See current fluency level

## UI Text (All in Sinhala)

- "කියවීමේ ප්‍රවාහිතාව කර්තව්‍යය" - Reading Fluency Task (title)
- "වචන 4ක වාක්‍යය උච්චාරණය කරන්න." - Read the 4-word sentence aloud
- "ආරම්භ කරන්න" - Start button
- "කාලය:" - Time:
- "වචන/මිනිත්තු (අනුමාන):" - WPM (est):
- "සැසි ප්‍රතිඵල" - Session Result (dialog title)
- "මට්ටම 1 - ආරම්භක" - Level 1 - Beginner
- "මට්ටම 3 - ප්‍රවාහිතා" - Level 3 - Fluent
- "කියවීමේ ප්‍රවාහිතාව" - Reading Fluency (dashboard card)

## Future Enhancements

- [ ] Add audio TTS for sentence pronunciation
- [ ] Automatic word detection via microphone
- [ ] Multiple Sinhala sentence difficulty levels
- [ ] Parent dashboard for progress visualization
- [ ] Comparative analytics across students
- [ ] Export progress reports

## Troubleshooting

### MongoDB Connection Issues:
- Ensure MongoDB is running: `mongod`
- Check `FluencyService.baseUrl` matches your backend

### API Not Responding:
- Verify Flask backend is running: `python fluency_api.py`
- Check logs for errors
- Ensure port 5000 is available

### Data Not Syncing:
- Check Firebase/backend logs
- Verify student ID is consistent
- Check network connectivity

---

**Created**: May 8, 2026
**Language**: Sinhala (UI), English (Backend Docs)
**Target Users**: Grade 1 Dyslexic Students in Sri Lanka
