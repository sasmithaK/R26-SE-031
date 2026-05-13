# R26-SE-031: Quick-Start Guide
## Running the Complete System

**Updated:** 2026-05-13  
**Status:** Ready for Demo & Viva

---

## 📋 System Status Checklist

- ✅ All 4 backend services implemented (C1, C2, C3, C4)
- ✅ Models trained and saved (LightGBM, LinUCB, Random Forest)
- ✅ Flutter app with full integration hooks
- ✅ MBSVListenerService & TelemetryCollector wired
- ✅ InterventionOverlay widget created
- ✅ Complete integration test suite
- ✅ Viva talking points & demo script

---

## 🚀 Running the System (5 Minutes)

### Terminal 1: Start All Backend Services
```bash
cd "D:\01 ACADEMIA\4th Year\Y4.S1\RP-IT4010\00 - Implementation\R26-SE-031\R26-SE-031-V2"

# Start all 4 services (runs in parallel)
python run_all_services.py

# Expected output:
# C1 Monitoring Service (8011): Running on http://127.0.0.1:8011
# C2 Visual Service (8014):     Running on http://127.0.0.1:8014
# C3 Content Service (8012):    Running on http://127.0.0.1:8012
# C4 Intervention Service (8013): Running on http://127.0.0.1:8013
```

### Terminal 2: Run Integration Test
```bash
# Wait 5 seconds for services to fully start, then:
python COMPLETE_INTEGRATION_TEST.py

# Expected output:
# ✓ C1: 3 passed, 0 failed
# ✓ C2: 2 passed, 0 failed
# ✓ C3: 3 passed, 0 failed
# ✓ C4: 2 passed, 0 failed
# ✓ ALL 10 TESTS PASSED!
```

### Terminal 3: Start Flutter App
```bash
cd "D:\01 ACADEMIA\4th Year\Y4.S1\RP-IT4010\00 - Implementation\R26-SE-031\dyslexia_app"

flutter run

# Select target (e.g., Chrome for web, or Android emulator)
# App should load and display welcome screen
```

---

## 🎬 Demo Flow (13 Minutes)

Follow the script below exactly as written. Timing is tight.

### **Step 1 [2 min]: Onboarding**
1. App loads → Tap "Create Account"
2. Name: "Kavidu"
3. Age: 7
4. Grade: 2
5. Questionnaire loads (shows C3 content-service working) → Answer questions to get at_risk_moderate score
6. Save → Student Preferences screen → Choose yellow theme, font size 22

**What it shows:** C3 is running, database working, UI responsiveness

### **Step 2 [3 min]: WCAG Assessment**
1. **Story Reading Game:** 
   - Tap 3–4 words deliberately
   - Watch word highlighting animation
   - Observe telemetry being logged in terminal 1 (C1 logs)

2. **Reading Fluency:**
   - Read "බල්ලා දුවයි" (simple sentence)
   - Click "Mark Error" once
   - Shows WPM ≈ 18, 1 error

3. **Reading Comprehension:**
   - Select wrong image first (game allows this)
   - Then select correct image
   - Shows correction event in logs

**What it shows:** C1 is receiving telemetry, app is connected

### **Step 3 [2 min]: MBSV Rising**
1. Back to StoryReadingGame
2. Deliberately pause 3+ seconds before tapping each word
3. Watch logs in Terminal 1:
   ```
   [Telemetry] C1 returned 200
   [MBSV] Updated: MBSV(v=0.35, p=0.58, ...)
   [MBSV] Updated: MBSV(v=0.40, p=0.65, ...)
   ```
4. **Point out:** phonological_strain_index rising (0.58 → 0.65)

**What it shows:** MBSV listener is working, strain signal is real-time

### **Step 4 [2 min]: Intervention Fires** ⭐ Most Impressive
1. Continue story reading with deliberate hesitation
2. On a long word (e.g., "ගුරුවරයා"), let strain exceed 0.45
3. **InterventionOverlay pops up automatically!**
   - Shows syllables: "ගු · රු · ව · රයා"
   - TTS plays each syllable in sequence
   - Tiles highlight as audio plays
4. Tap "දිගටම කරමු" to dismiss
5. Notice strain drops after intervention in logs

**What it shows:** Closed-loop adaptation: behavior → signal → intervention → improved behavior

### **Step 5 [2 min]: Guardian Dashboard** (if available)
1. Open browser → Navigate to `http://127.0.0.1:3000` (or wherever dashboard is deployed)
2. Show mastery heatmap for "Kavidu"
   - Skills S4, S5 showing updated mastery (white → light teal)
   - Columns represent skill progression
3. Show SM-2 words scheduled for review
4. Show MBSV trend chart (if implemented)

**What it shows:** Data persistence, mastery tracking, backend-frontend integration

---

## 🧪 What Each Service Does (For Evaluators)

### C1: Monitoring (Port 8011)
```bash
# Poll current MBSV for a student
curl http://127.0.0.1:8011/api/v1/mbsv/Kavidu

# Response:
{
  "student_id": "Kavidu",
  "mbsv": {
    "visual_strain_index": 0.35,
    "phonological_strain_index": 0.58,
    "cognitive_load_index": 0.12,
    "engagement_index": 0.75,
    "session_fatigue_index": 0.02,
    "error_pattern_vector": [1, 0, 2, 1]
  }
}
```

### C2: Visual Adaptation (Port 8014)
```bash
# Request typography config based on context
curl -X POST http://127.0.0.1:8014/api/v1/ui/typography \
  -H "Content-Type: application/json" \
  -d '{
    "student_id": "Kavidu",
    "context": {
      "visual_strain_index": 0.6,
      "engagement_index": 0.8
    }
  }'

# Response:
{
  "config": {
    "font_size": 24,
    "letter_spacing": 4,
    "background_color": "#FFFDE7"
  }
}
```

### C3: Content & Mastery (Port 8012)
```bash
# Get current mastery vector
curl http://127.0.0.1:8012/api/v1/mastery/Kavidu

# Response:
{
  "S0": 0.15, "S1": 0.22, "S2": 0.18, ..., "S8": 0.05,
  "last_updated": "2026-05-13T14:30:00Z"
}

# Update mastery after task completion
curl -X POST http://127.0.0.1:8012/api/v1/mastery/update \
  -H "Content-Type: application/json" \
  -d '{
    "student_id": "Kavidu",
    "skill_id": "S5",
    "correct": true,
    "response_latency_ms": 1500
  }'
```

### C4: Intervention & SM-2 (Port 8013)
```bash
# Request syllable split
curl -X POST http://127.0.0.1:8013/api/v1/intervention/check \
  -H "Content-Type: application/json" \
  -d '{"word": "ගුරුවරයා"}'

# Response:
{
  "syllables": ["ගු", "රු", "ව", "රයා"],
  "phonological_complexity": 3.2
}

# Get SM-2 review schedule
curl http://127.0.0.1:8013/api/v1/intervention/sm2/schedule/Kavidu

# Response:
{
  "due_words": [
    {"word": "ගුරුවරයා", "next_review": "2026-05-14"},
    {"word": "බල්ලා", "next_review": "2026-05-16"}
  ]
}
```

---

## 🔍 Troubleshooting

### Issue: "Port 8011 already in use"
```bash
# Find and kill the process
netstat -ano | findstr :8011
taskkill /PID <PID> /F

# Or: Change the port
set C1_PORT=9001
python monitoring-service-v2/main.py
```

### Issue: "C1 returns 404 for telemetry"
- Check Flask is running: `python monitoring-service-v2/main.py`
- Verify endpoint path: `/api/v1/telemetry` (not `/telemetry`)
- Check JSON format matches: `student_id`, `session_id`, `event_type`, `hesitation_ms`, etc.

### Issue: "Flutter app can't reach backend"
- Verify ports in `api_config.dart` match actual services (8011, 8012, 8013, 8014)
- Test manually: `curl http://127.0.0.1:8011/api/v1/health`
- Check firewall isn't blocking local connections

### Issue: "InterventionOverlay doesn't appear"
- Verify C4 is running: `curl http://127.0.0.1:8013/api/v1/health`
- Check MBSV is above 0.45: watch Terminal 1 logs for `phonological_strain_index`
- Ensure TTS is initialized: check Flutter logs for "TTS init"

---

## 📚 Key Files & Locations

| File | Location | Purpose |
|------|----------|---------|
| Full Implementation Plan | `FULL_IMPLEMENTATION_PLAN.md` | Step-by-step dev guide |
| Codebase Analysis | `R26-SE-031_Codebase_Analysis.md` | Architecture review |
| Viva Talking Points | `VIVA_TALKING_POINTS.md` | Viva prep (THIS IS CRITICAL) |
| Integration Tests | `R26-SE-031-V2/COMPLETE_INTEGRATION_TEST.py` | Run before demo |
| Backend Services | `R26-SE-031-V2/*/main.py` | C1, C2, C3, C4 APIs |
| Flutter Services | `dyslexia_app/lib/services/*.dart` | Integration layer |
| SHAP Visuals | `docs/shap_visuals/*.png` | For viva slides |

---

## 💡 Important Points for Evaluators

### "Why is this research-grade, not just a prototype?"

1. **Grounded in literature:** MBSV dimensions map to dyslexia subtypes (Stanovich, 2005)
2. **Models are real:** LightGBM, LinUCB, Random Forest trained on behavioral data
3. **Closed-loop:** Behavior → signal → adaptation → behavior (not one-directional)
4. **Validated features:** Hesitation_ms calibrated to Rayner (2001) norms
5. **Ready for pilot:** All components tested, logged, debuggable

### "What's novel about this?"

1. **Multimodal MBSV:** 6D signal vs. single reading speed
2. **Sinhala-specific:** Language-aware typography (SOVCM with diacritic_offset)
3. **Closed-loop adaptation:** Not just tracking; actively intervening based on live signal
4. **Spaced repetition for Sinhala:** SM-2 applied to low-literacy orthography support
5. **Integrated system:** C1+C2+C3+C4 working together (not siloed)

### "What are the limitations?"

1. **Synthetic training data:** Ecological validity tested in pilot, not yet
2. **Small sample:** 50 students (designed for), tested on synthetic data
3. **No clinical validation:** Not a diagnostic tool; screening/support only
4. **Limited error analysis:** NLP for Sinhala is sparse; using RF on acoustic features
5. **Offline learning:** A/B test for LinUCB happens after viva

---

## 🎯 Success Metrics for Demo

- [ ] All 4 services running without crashes
- [ ] Integration test passes all 10 checks
- [ ] Flutter app connects and retrieves MBSV
- [ ] Telemetry events logged in C1 (visible in terminal)
- [ ] Intervention overlay triggers automatically
- [ ] TTS plays syllables correctly
- [ ] Mastery updates visible in dashboard (if deployed)
- [ ] Demo completes in ≤ 15 minutes
- [ ] No unhandled exceptions
- [ ] Evaluators can ask questions & get answers

---

## ✅ Pre-Demo Checklist (Run 24 hours before)

- [ ] All backend code reviewed & committed to git
- [ ] Models loaded successfully (check `models/` directory)
- [ ] Integration test passes locally
- [ ] Flutter app compiles & runs (check `flutter pub get`)
- [ ] API ports confirmed (8011, 8012, 8013, 8014)
- [ ] Telemetry sending confirmed (watch C1 logs)
- [ ] MBSV listener polling confirmed (check logs)
- [ ] Intervention overlay tested (trigger phonological_strain > 0.45)
- [ ] Guardian dashboard accessible (if deployed)
- [ ] VIVA_TALKING_POINTS.md reviewed by all team members
- [ ] Practice demo script 2-3 times
- [ ] Take screenshots of success state for backup slides

---

## 🎓 For Viva

**Open files before viva starts:**
1. Terminal 1: All services running
2. Terminal 2: Ready to run integration test
3. Terminal 3: Flutter app running
4. Browser: Guardian dashboard (if available)
5. Browser (second tab): VIVA_TALKING_POINTS.md for reference

**Have ready:**
- Live access to Python REPL (show Welford, BKT, LinUCB)
- SHAP visualizations (`docs/shap_visuals/`)
- GitHub repo link (show code)
- Integration test passing screenshot

**Your story:**
- 30 sec: Problem (Sinhala dyslexia, 1-10% of children affected)
- 30 sec: Your solution (4-component adaptive system)
- 2 min: Demo (show it working)
- 3 min: Deep dive on most interesting component (C1 or C4)
- 2 min: Validation/grounding in research
- 2 min: Next steps (pilot, RCT)

**Remember:** You've built a solid system. Be proud. You should speak with confidence.

---

**Last updated:** 2026-05-13  
**Status:** Ready for Demo & Viva  
**Next step:** Run `python run_all_services.py` and `python COMPLETE_INTEGRATION_TEST.py`
