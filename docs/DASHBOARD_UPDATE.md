# Dashboard update — C1, C2, C3 (2026-10-20)

Platform framing: Sipsara connects parents, children and professionals, collects
consented learning evidence, and supports remote monitoring. It shows
*potential patterns for professional review*; it does not diagnose.

## What changed

### Backend

| Area | Change | Files |
| --- | --- | --- |
| C1 error types | Errors are categorised only from the type the task reports. The knowledge-component fallback that labelled every picture-task mistake as "visual confusion" was removed. New category `visual_task_error`; missing types are `unknown_error` ("type not recorded"). | `telemetry-analytics-v1/services/behavioral_engine.py` |
| C1 fatigue | One definition shared with `services/c1/fatigue.py`: first 3 vs last 3 rounds, at least 6 rounds, only slowing/more errors/more hesitation count, score 0–1 with LOW/MODERATE/HIGH/VERY_HIGH. No more negative "fatigue". | `behavioral_engine.py`, `schemas/c1.py` |
| C1 kinematics | Reports `orthographic_confusion_coverage`; the letter-confusion index is hidden when the confusion map cannot classify the child's errors. | `services/comp2_kinematics.py` |
| C1 legacy | Removed `/telemetry/{id}/analytics`, `/comp2`, `/report/pdf` (dyslexia-risk labels, default 0.5 risk, wrong model feature order), `ml_pipeline.py`, `feature_engineering.py`, `report_generator.py`, both `ml_engine.py` copies, `ml/calibration.py` (random mock predictions), `/c1/students/{id}/c3-ai-summary`. The curriculum endpoint no longer rewrites activities with a second heuristic policy. | `telemetry-analytics-v1`, `api/routers/activities.py` |
| C1 research training | `/ml/train` now trains only on professional feedback rows with the live 19-feature schema; rows with missing features are dropped, never zero-filled. | `routers/ml.py`, `services/ml_comparative.py` |
| C2 latency | Reading latency = voice onset after recording starts. Time to press the record button is stored separately (`record_start_delay_ms`). | `speech-monitoring-v1/services/acoustic_service.py`, `routers/stt.py` |
| C2 settings | Quality-gate thresholds, fusion weights and pause bounds moved to `c2_settings.json`. Gemini TTS model/voice configurable (`GEMINI_TTS_MODEL`, `GEMINI_TTS_VOICE`); unused `google.genai` import removed. | `speech-monitoring-v1/c2_settings.json`, `services/*` |
| C3 fusion | Fuses the learner's last 14 days (`C3_WINDOW_DAYS`) instead of one session. Needs ≥2 usable recordings and ≥2 touch-movement sessions (`C3_MIN_USABLE_RECORDINGS`, `C3_MIN_MOVEMENT_SESSIONS`). **No default values are filled in**: missing evidence or age skips the model and is listed. Unknown gender is averaged over both values (marginalised), not assumed. Stored with window, counts, inputs, `validation_status = synthetic_trained_model`. | `diagnostic-fusion-v1/main.py`, `services/xai_engine.py` |
| Learner context | Optional `birth_year`, `birth_month`, `gender` on students (needed for C3 age). | `api/schemas/students.py`, `routers/students.py` |
| Dashboards API | C1 view over a time window: trial-weighted numbers, real knowledge-component list with counts, error types with counts, C1 indices + baseline, RF estimate, touch-movement medians, date-labelled trends. C2: usable-recording rate, quality issues, per-sentence items with word-level differences, per-session medians. C3: coverage checklist, plain-language SHAP lines, low-agreement flag, latest professional review. Overview: coverage + monitoring alerts. | `api/routers/therapist_dashboard.py`, `api/services/dashboard_data.py`, `api/schemas/dashboards.py` |
| Professional feedback | `POST/GET /api/v1/therapist/students/{id}/feedback` (specialists only): agree/disagree/unsure, optional pattern and note, stored with a feature snapshot in `professional_feedback`. | `therapist_dashboard.py` |
| Monitoring alerts | Inactive ≥7 days, <50% clear recordings (≥3 recordings), high fatigue in ≥2 sessions, questionnaire incomplete. Shown on therapist home, students list and learner summary. | `dashboard_data.py`, `api/routers/therapist.py` |
| Therapist worklist | A learning area is flagged only with ≥5 observed responses in that area (fixes "word recognition 20%" from an untouched prior). | `api/routers/therapist.py` |
| Parent API | Parents no longer receive pattern names or probabilities. Plain-language PDF learning summary at `GET /api/v1/parent/students/{id}/report` (was 501). | `api/routers/parent_dashboard.py`, `api/utils/pdf_generator.py` |
| Settings | Dashboard thresholds in `api/dashboard_settings.json`. Google client IDs via `GOOGLE_CLIENT_IDS`. C3 summary thresholds via `C3_SUMMARY_RETRY_RATE`, `C3_SUMMARY_WORD_ACCURACY`. | |
| Security | OTP and clinic codes use `secrets`; OTPs are no longer printed to logs (opt-in `DEBUG_PRINT_OTP=true` for local debugging); OAuth accounts detected by `auth_provider`, not a placeholder password. | `api/services/auth_utils.py`, `api/routers/auth.py` |

### Flutter app

| Area | Change |
| --- | --- |
| Typography | New `DashText` (in `theme/app_theme.dart`): no 0.80 down-scaling, 12 pt floor (13 pt body), normal word spacing. All parent and therapist dashboard screens use it; child screens keep `AppTypography`. |
| Shared kit | `widgets/dashboard/dashboard_kit.dart`: cards, status chips, metric tiles (2 or 4 per row), overflow-safe rows, percent bars with baseline marker, coverage checklist, alert list, probability bar, date-labelled trend chart. |
| Therapist learner screen | Tabs: Summary · Activities · Reading · Combined profile · Adaptive support · Parent questionnaire. Summary tab no longer blank (infinite-width Row removed). New tab widgets in `screens/therapist/therapist_component_tabs.dart` with professional-feedback sheet for C1 and C3. |
| Therapist home and students | "Needs attention" alerts, coverage chips per learner, mastery chip shows response count, "Learning overview". |
| Parent screens | "Neural patterns" wording removed; activity names resolved ("Picture sorting"); empty states say what to do next; pattern estimate removed; PDF learning summary button; hub stats now real (sessions in last 7 days, connected therapists) instead of hard-coded 24 and 1. |
| Fake content removed | Scripted therapist chat/messages and invented parent notifications replaced with honest "coming soon" screens. |
| Add/edit child | Optional birth month/year and gender. |
| No longer used | `widgets/c1/*`, `models/c1/*`, `services/c1_parent_service.dart`, `services/c1_therapist_service.dart`, `utils/skill_registry.dart` (see cleanup list below). |

## Optional cleanup (files no longer used)

Nothing imports these any more. Delete them when convenient (`git rm`):

```
app/backend/api/services/ml_engine.py
app/backend/telemetry-analytics-v1/services/ml_pipeline.py
app/backend/telemetry-analytics-v1/services/ml_engine.py
app/backend/telemetry-analytics-v1/services/feature_engineering.py
app/backend/telemetry-analytics-v1/services/report_generator.py
app/backend/telemetry-analytics-v1/services/ml/calibration.py
app/frontend/lib/widgets/c1/            (whole folder)
app/frontend/lib/models/c1/             (whole folder)
app/frontend/lib/services/c1_parent_service.dart
app/frontend/lib/services/c1_therapist_service.dart
app/frontend/lib/utils/skill_registry.dart
shared/skill_registry.py
```

## Not changed (owned by C4)

`adaptive-tutoring-v1/*` and `therapist_adaptive_evidence_view.dart`. The C4 tab keeps its own styling.

## Before the demo

1. `pip install -r` is unchanged. Redeploy Render (API) and Azure (C1–C3 image).
2. Run `flutter pub get && flutter analyze && flutter test` — this update was syntax-checked but not compiled here.
3. Edit each demo child and add birth month/year so the combined profile can run.
4. Give each demo child ≥2 clear reading recordings and ≥2 drag-activity sessions within 14 days, or lower the C3 minimums by environment variable for the demo.
5. Note: `.dockerignore` excludes `*.wav`, so cached TTS audio is not in the Azure image; set `GEMINI_API_KEY` on Azure.

## Tests

Backend: 89 tests pass (API 46, C1 32, C3 4, C2 7 with `PRELOAD_STT=false`). New: `api/tests/test_dashboard_improvements.py`, `diagnostic-fusion-v1/tests/test_window_fusion.py`, extra cases in `test_behavioral_engine.py` and `test_telemetry.py`.
