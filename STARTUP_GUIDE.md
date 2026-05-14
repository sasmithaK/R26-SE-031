# R26-SE-031 Startup Guide — Flask Services + Flutter Web

## Overview

The platform has two components:
1. **Backend**: 4 Python FastAPI microservices (C1 Monitoring, C2 Visual, C3 Content, C4 Intervention)
2. **Frontend**: Flutter Web application (sample_demo_with_monitoring or dyslexia_app)

Both must be running simultaneously for the system to work.

---

## Prerequisites

### **Python Environment**

```bash
# Install dependencies for all services
pip install fastapi uvicorn motor pandas numpy lightgbm scikit-learn scipy pydantic python-dotenv datasets shap
```

### **Flutter Environment**

```bash
# Ensure Flutter is installed
flutter --version

# Install web support
flutter config --enable-web
```

---

## Step 1: Start the Python Services

### **Terminal 1: Start all 4 microservices**

```bash
cd R26-SE-031/R26-SE-031-V2
python run_all_services.py
```

**Expected output**:
```
============================================================
  STARTING R26-SE-031-V2 MICROSERVICES
============================================================
  [START] C1 Monitoring         on port 8011...
  [START] C2 Visual             on port 8014...
  [START] C3 Content            on port 8012...
  [START] C4 Intervention       on port 8013...
```

**Verify services are running**:
```bash
# In a new terminal, test each service
curl http://127.0.0.1:8011/health
curl http://127.0.0.1:8014/health
curl http://127.0.0.1:8012/health
curl http://127.0.0.1:8013/health
```

Each should return: `{"status": "ok", "service": "C1-CBME", ...}`

---

## Step 2: Build and Run Flutter Web

### **Terminal 2: Flutter development server**

```bash
cd R26-SE-031/sample_demo_with_monitoring

# Clean build artifacts
flutter clean
flutter pub get

# Run on web (http://localhost:5173 or similar)
flutter run -d web

# Or build for production
flutter build web
# Then serve from build/web/ directory
```

**Expected output**:
```
Debug service listening on ws://127.0.0.1:65114/4wayGOIdXcQ=/ws
The Flutter DevTools debugger and profiler on Chrome is available at: http://127.0.0.1:65114/4wayGOIdXcQ=/devtools/?uri=ws://127.0.0.1:65114/4wayGOIdXcQ=/ws
```

---

## Step 3: Verify No Errors

### **Errors That Should Now Be Fixed**

✅ **`_JsonMap` parsing error**: Fixed by updating `MBSV._parseErrorPattern()` to handle both Map and List formats

✅ **Font errors** (`NotoSansSinhala failed`): Fixed by changing default font to `'Noto Sans'` (available via Google Fonts)

✅ **Asset loading errors** (404): Fixed by running `flutter clean` and proper `flutter build web`

⚠️ **Service connection errors**: Fixed by starting services with `run_all_services.py`

### **Remaining Warnings (Non-Critical)**

- Font fallback messages: Expected on first load; Flutter will use system font until Google Fonts loads
- `@deprecated` warnings: Ignore; part of Flutter dependency lifecycle

---

## Step 4: Test the System

### **Test 1: Service Health**

```bash
# All services should respond with HTTP 200
curl http://127.0.0.1:8011/health
curl http://127.0.0.1:8014/health
```

### **Test 2: C1 Telemetry Endpoint**

```bash
curl -X POST http://127.0.0.1:8011/api/v1/telemetry \
  -H "Content-Type: application/json" \
  -d '{
    "student_id": "TEST_001",
    "session_id": "TEST_SESSION",
    "task_id": "word_matching",
    "event_type": "TAP",
    "hesitation_ms": 500,
    "correction_rate": 0.2,
    "response_latency": 1500,
    "touch_pressure": 0.7,
    "swipe_velocity": 100,
    "replay_count": 1,
    "hint_request_count": 0,
    "touch_events": [{"x": 100, "y": 200, "pressure": 0.7, "timestamp_ms": 1000}],
    "stylus_deviation": 5,
    "read_aloud_pause_ms": 200,
    "syllable_rate": 4.0,
    "disfluency_count": 0
  }'
```

**Expected response**:
```json
{
  "student_id": "TEST_001",
  "session_id": "TEST_SESSION",
  "timestamp_ms": 1715702400000,
  "mbsv": {
    "visual_strain_index": 0.25,
    "cognitive_load_index": 0.35,
    "phonological_strain_index": 0.15,
    "engagement_index": 0.85,
    "session_fatigue_index": 0.20,
    "error_pattern_vector": {"reversal": 0, "omission": 0, "substitution": 0, "hesitation": 0}
  },
  "shap_available": false,
  "session_outlier": false
}
```

### **Test 3: C2 Typography Endpoint**

```bash
curl -X POST http://127.0.0.1:8014/api/v1/ui/typography \
  -H "Content-Type: application/json" \
  -d '{
    "student_id": "TEST_001",
    "session_id": "TEST_SESSION",
    "visual_strain_index": 0.3,
    "engagement_index": 0.7,
    "session_number": 1,
    "child_age_years": 8,
    "current_content_text": "ගහ",
    "phonological_strain_index": 0.2
  }'
```

**Expected response**:
```json
{
  "student_id": "TEST_001",
  "linucb_arm_selected": 2,
  "typography_config": {
    "font_size": 20.0,
    "font_family": "NotoSansSinhala",
    "letter_spacing": 2.0,
    "word_spacing": 8.0,
    "line_height": 1.6,
    "background_contrast": "WCAG_AA",
    "diacritic_offset": 0.0,
    "glyph_padding": 0.0
  },
  "game_mode_trigger": false,
  "game_difficulty": 2
}
```

### **Test 4: Flutter Web UI**

Open the Flutter Web app at the local URL (usually http://localhost:5173 or http://localhost:8080):
1. You should see the "Word Matching Task" screen
2. Click on a word to test touch event tracking
3. Check the monitoring panel (right side) for MBSV values (should update from C1)
4. Images should load without 404 errors
5. Sinhala text should render without font error messages

---

## Troubleshooting

### **Problem: "Failed to fetch" when calling services**

**Cause**: Services not running or not listening on ports 8011/8014

**Solution**:
```bash
# Check if services are running
ps aux | grep python
# Or on Windows
tasklist | findstr python

# Kill any existing processes and restart
python run_all_services.py
```

### **Problem: "NotoSansSinhala failed" font errors**

**Cause**: Flutter defaulting to unavailable system font

**Solution**: Already fixed (changed to 'Noto Sans' from Google Fonts)

### **Problem: Images showing 404 errors in Flutter Web**

**Cause**: Build cache issue or improper asset bundling

**Solution**:
```bash
flutter clean
flutter pub get
flutter run -d web
```

Or rebuild for web:
```bash
flutter build web --release
# Then serve build/web/ folder via HTTP server
```

### **Problem: Sinhala text not rendering correctly**

**Cause**: Font not loaded or missing diacritic rendering support

**Solution**:
- Ensure 'Noto Sans' is being used (not system font)
- Check that Google Fonts dependency is in pubspec.yaml (`google_fonts: ^6.1.0`)
- Verify that diacritic_offset and glyph_padding are being applied from C2 response

### **Problem: "TypeError: _JsonMap is not a subtype of Iterable"**

**Cause**: Old Dart MBSV model trying to parse error_pattern_vector as List when it's a Map

**Solution**: Already fixed (added `_parseErrorPattern()` helper method)

---

## Architecture Overview

### **Service Ports**

| Service | Port | Purpose | Status Endpoint |
|---------|------|---------|-----------------|
| C1 CBME | 8011 | Behavioral monitoring → MBSV | `/health` |
| C2 AVLI | 8014 | Visual adaptation (LinUCB) | `/health` |
| C3 PLCE | 8012 | Content engine (not yet impl.) | `/health` |
| C4 IIGE | 8013 | Intervention engine (not yet impl.) | `/health` |

### **Data Flow**

```
Flutter App
    ↓
[1] Send telemetry → C1 (port 8011)
    ↓
C1 processes → compute MBSV (6 dimensions)
    ↓
[2] MBSV returned to Flutter
    ↓
Flutter sends context + MBSV → C2 (port 8014)
    ↓
C2 runs LinUCB → selects typography arm
    ↓
[3] Typography config returned to Flutter
    ↓
Flutter displays with adaptive layout
    ↓
[4] User reads & interacts
    ↓
Flutter sends reward signal → C2
    ↓
C2 updates LinUCB weights
```

---

## Quick Start (Copy-Paste Ready)

```bash
# Terminal 1: Start services
cd ~/path/to/R26-SE-031/R26-SE-031-V2
python run_all_services.py

# Terminal 2: Start Flutter
cd ~/path/to/R26-SE-031/sample_demo_with_monitoring
flutter clean && flutter pub get && flutter run -d web
```

Open browser → Flutter Web loads → Calls C1 & C2 services → System works!

---

## MongoDB Setup (Optional, for persistence)

If you need to persist MBSV events to MongoDB:

```bash
# Install MongoDB locally or use MongoDB Atlas
# Update .env in R26-SE-031-V2/ with:
MONGO_URI=mongodb://localhost:27017
MONGO_DB=dyslexia_platform

# Services will auto-connect on startup
```

---

## Next Steps

1. ✅ Start services with `python run_all_services.py`
2. ✅ Run Flutter Web with `flutter run -d web`
3. ✅ Test services with curl commands above
4. ✅ Verify no errors in Flutter console
5. 📊 Train LightGBM model: `python scripts/train_c1_lgbm_real_data.py`
6. 🧪 Run integration tests: `python COMPLETE_INTEGRATION_TEST.py`
7. 📝 Document results for thesis

---

**Status**: Ready to run  
**Last Updated**: May 2026  
**Contact**: R26-SE-031 Research Team
