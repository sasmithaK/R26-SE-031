# Assessment Score Collection Analysis & Implementation

## Current Score Collection Status

### ✅ Score 1: Letter Score (0-3)
**Source:** `lib/screens/letter_identification_task.dart`
- **Tracking:** Visual Discrimination correct answers + Phonological Awareness correct answers
- **Collection Method:** `LetterIdentificationScore` model stores individual attempts
- **Calculation:** Count correct answers across all 4 letter identification tasks
- **Storage:** Already saved to MongoDB via `LetterIdentificationService`

### ✅ Score 2: Words Per Minute (WPM)
**Source:** `lib/screens/reading_fluency_task.dart`
- **Tracking:** Reading fluency task with 3 levels
- **Calculation:** `Total words read / (elapsed time in seconds) * 60`
- **Current State:** Calculated in `_calculateWPM()` method
- **Storage:** Saved locally in SharedPreferences as `rf_avg_wpm` and to MongoDB via `FluencyService`

### ✅ Score 3: Comprehension Score (0-3)
**Source:** `lib/screens/reading_comprehension_task.dart`
- **Tracking:** Picture-sentence matching task with 3 questions
- **Calculation:** Count correct image selections
- **Current State:** Tracked as `correctAnswers` variable
- **Storage:** Saved locally in SharedPreferences as `rc_correct_answers` and to MongoDB via `ComprehensionService`

### ✅ Score 4: Word Error Count (0-20+)
**Source:** `lib/screens/reading_fluency_task.dart`
- **Tracking:** Words read incorrectly during fluency task
- **Calculation:** Count misread words (user marks with "error" button)
- **Current State:** Tracked as `errorCount` variable
- **Storage:** Saved locally in SharedPreferences as `rf_avg_wer` (word error rate)

---

## Score Rating System

### Letter Score Rating
- **0 or 1 correct** → **Weak**
- **2 correct** → **Moderate**
- **3 correct** → **Strong**

### Words Per Minute Rating (Grade 1 Dyslexic Benchmark)
- **Below 15 WPM** → **Weak**
- **15 to 25 WPM** → **Moderate**
- **Above 25 WPM** → **Strong**

### Comprehension Score Rating
- **0 or 1 correct** → **Weak**
- **2 correct** → **Moderate**
- **3 correct** → **Strong**

### Word Error Count Rating
- **More than 3 errors** → **Weak**
- **2 or 3 errors** → **Moderate**
- **0 or 1 errors** → **Strong**

---

## Implementation Added

### 1. New Model: `assessment_results.dart`
- Stores all 4 scores + their ratings
- Includes student metadata (name, age, grade)
- Contains `toJson()` / `fromJson()` for MongoDB serialization
- Method `getPerformanceSummary()` to give overall rating (excellent/good/fair/needs_support)

### 2. New Service: `assessment_results_service.dart`
- Rating conversion functions:
  - `rateLetterScore(score)` → weak/moderate/strong
  - `rateWordsPerMinute(wpm)` → weak/moderate/strong
  - `rateComprehensionScore(score)` → weak/moderate/strong
  - `rateWordErrors(errorCount)` → weak/moderate/strong
- `createAssessmentResults()` - combines all 4 scores into single object with ratings
- `saveAssessmentResults()` - saves to MongoDB via endpoint `/api/assessment-results`
- `getAssessmentHistory()` - retrieves all assessments for a student
- `getLatestAssessment()` - retrieves most recent assessment

---

## Data Flow: Where to Call `saveAssessmentResults()`

### Option 1: After Student Dashboard (Recommended)
At the end of the assessment flow (`wcag_assessment_flow.dart` → `student_dashboard.dart`):
```dart
// Collect the 4 scores from completed tasks
final results = AssessmentResultsService.createAssessmentResults(
  studentId: studentId,
  studentName: studentName,
  studentAge: studentAge,
  studentGrade: studentGrade,
  letterScore: await getLetterScoreFromTask(),      // 0-3
  wordsPerMinute: await getWPMFromTask(),           // double
  comprehensionScore: await getComprehensionScore(), // 0-3
  wordErrorCount: await getWordErrorCount(),        // int
);

await AssessmentResultsService.saveAssessmentResults(results);
```

### Option 2: Create Results Summary Screen
Add a new screen after Student Dashboard that:
1. Displays the 4 scores with ratings
2. Shows overall performance (excellent/good/fair/needs_support)
3. Saves results to MongoDB
4. Navigates to dashboard

---

## Backend MongoDB Schema

Collection: `assessment_results`
```json
{
  "_id": ObjectId,
  "studentId": "student_123",
  "studentName": "Kasun Silva",
  "studentAge": 6,
  "studentGrade": "Grade 1",
  "assessmentParameters": {
    "letterScore": 3,
    "wordsPerMinute": 18.5,
    "comprehensionScore": 2,
    "wordErrorCount": 2
  },
  "ratings": {
    "letterRating": "strong",
    "wpmRating": "moderate",
    "comprehensionRating": "moderate",
    "errorRating": "moderate"
  },
  "assessedAt": "2026-05-11T10:30:00.000Z",
  "createdAt": "2026-05-11T10:30:00.000Z"
}
```

---

## Files Modified/Created

### Created:
- ✅ `lib/models/assessment_results.dart` - Data model
- ✅ `lib/services/assessment_results_service.dart` - Service with rating logic

### To Modify (Not Yet Modified - Per User Request):
- `lib/screens/student_dashboard.dart` - Call save function at appropriate point
- Backend API - Add `/api/assessment-results` endpoint if not exists

---

## Rating Thresholds Summary

| Parameter | Weak | Moderate | Strong |
|-----------|------|----------|--------|
| Letter Score | 0-1/3 | 2/3 | 3/3 |
| WPM | <15 | 15-25 | >25 |
| Comprehension | 0-1/3 | 2/3 | 3/3 |
| Errors | >3 | 2-3 | 0-1 |

---

## Next Steps

1. Collect actual scores from each task
2. Call `AssessmentResultsService.saveAssessmentResults(results)` after assessment complete
3. (Optional) Create a results summary screen
4. Test MongoDB persistence
