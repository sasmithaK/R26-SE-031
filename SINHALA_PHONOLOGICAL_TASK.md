# Sinhala Phonological Task — Comprehensive Behavioral Monitoring

## Overview

The **Sinhala Phonological Task** is a research-grade assessment that captures all 12 behavioral parameters from the R26-SE-031 monitoring architecture, processing them through the C1 Monitoring Service in real-time, and displaying 6-dimensional MBSV predictions alongside raw feature logs.

---

## Features Monitored

| # | Feature | Measurement | Icon |
|---|---------|-------------|------|
| 1 | `hesitation_ms` | Time before first interaction | ⏱️ |
| 2 | `correction_rate` | Corrections / total interactions | ❌ |
| 3 | `response_latency` | Task start → completion time | ⚡ |
| 4 | `touch_pressure` | Normalized force (0-1) | 🖐️ |
| 5 | `swipe_velocity` | Pixels/ms during interaction | 🎯 |
| 6 | `replay_count` | Audio replay button presses | 🔊 |
| 7 | `hint_request_count` | Hint button presses | 💡 |
| 8 | `stylus_deviation` | Fine-motor error (letter tracing) | ✏️ |
| 9 | `inter_tap_interval` | Timing variance in tapping tasks | 🎵 |
| 10 | `read_aloud_pause_ms` | Inter-word silence duration | 🎤 |
| 11 | `syllable_rate` | Syllables/second in read-aloud | 🗣️ |
| 12 | `disfluency_count` | Restarts/prolongations detected | 🔄 |

---

## MBSV Dimensions Predicted

Real-time predictions from C1 with color-coded health indicators:

| Dimension | Range | Indicator | Interpretation |
|-----------|-------|-----------|-----------------|
| 🧠 **Cognitive Load** | 0.0–1.0 | Red (high) → Green (low) | Task complexity overload signal |
| 🗣️ **Phonological Strain** | 0.0–1.0 | Red → Green | Phonological processing difficulty |
| 👁️ **Visual Strain** | 0.0–1.0 | Red → Green | Visual crowding / crowding load |
| 😴 **Fatigue** | 0.0–1.0 | Red → Green | Cumulative session fatigue |
| 😊 **Engagement** | 0.0–1.0 | Green (high) → Red (low) | Intrinsic motivation level |
| 📊 **Error Pattern Vector** | [4 flags] | Binary flags | [Reversal, Omission, Substitution, Hesitation] |

---

## Task Structure

### **Task 1: Syllable Tapping (🎯 Phonological Awareness)**

**Objective**: Segment Sinhala words into syllables by tapping each segment

**Word**: ශිෂ්‍ය (Shiṣya — "student")  
**Syllables**: [ශි] [ෂ්‍ය]

**Monitors**:
- `hesitation_ms` — How long before first tap?
- `inter_tap_interval` — Timing between syllable taps
- `correction_rate` — How many false taps were corrected?
- `touch_pressure` — Stress in finger taps

---

### **Task 2: Word Reading (📖 Decoding Fluency)**

**Objective**: Read aloud a sentence containing a target word slowly and clearly

**Sentence**: එය පනතට අනුව සිදු විය। (Aya panatata anuva sidu viyi.)  
**Target Word**: පනත (Panata — "law")

**Monitors**:
- `read_aloud_pause_ms` — Pause duration between words (audio energy thresholding)
- `syllable_rate` — Speaking speed (syllables/sec)
- `disfluency_count` — Restarts or prolongations detected
- `replay_count` — How many audio replays requested?
- `swipe_velocity` — Screen interactions during reading

---

### **Task 3: Letter Tracing (✏️ Visual-Motor Control)**

**Objective**: Trace the outline of a Sinhala letter precisely

**Letter**: අ (A — first vowel)

**Monitors**:
- `stylus_deviation` — RMS error from template path
- `touch_pressure` — Motor tension during trace
- `swipe_velocity` — Trace smoothness
- `hesitation_ms` — Hesitation before starting
- `correction_rate` — Pen-up (correction) events

---

## UI Layout

```
┌─────────────────────────────────────────────────────────────────┐
│  🇱🇰 සිංහල ශබ්ද-අක්ෂර සම්බන්ධතා කර්තව්‍ය                           │
│  Task 1 / 3: 🎯 වචන කොටස ගණනය කිරීම                           │
├──────────────────────────── TASK AREA ──────────────────────────┤
│                                           │                      │
│  ශිෂ්‍ය                                 │  📊 MBSV Status      │
│  [ශි] [ෂ්‍ය]                           │  🧠 Cognitive 0.45  │
│                                           │  🗣️ Phonological 0.38
│  [💡 Hint] [🔊 Replay] [❌ Correct]     │  👁️ Visual 0.52     │
│                                           │  😴 Fatigue 0.28    │
│  [📊 Compute] [➡️ Next]                 │  😊 Engagement 0.72  │
│                                           │                      │
│                                           │ ⚙️ Raw Features    │
│                                           │ hesitation_ms: 1200  │
│                                           │ correction_rate: 0.2 │
│                                           │ swipe_velocity: 95   │
│                                           │ ... (12 total)      │
│                                           │                      │
│                                           │ 📝 Live Log          │
│                                           │ 15:42 🚀 Task start │
│                                           │ 15:42 ❌ Correction 1 │
│                                           │ 15:43 💡 Hint #1    │
│                                           │ 15:44 📊 Computing...│
│                                           │ 15:44 ✅ MBSV ready!│
└───────────────────────────────────────────────────────────────┘
```

---

## How to Use

### **1. Start the System**

Ensure backend services are running:
```bash
cd R26-SE-031-V2
python start_services.py --test
```

All 4 services should respond [OK], especially C1 on port 8011.

### **2. Launch Flutter Web**

```bash
cd sample_demo_with_monitoring
flutter run -d web
```

### **3. Navigate to the Task**

From the home dashboard, click:  
**"Sinhala Phonological (Monitoring)"** card  
Or use sidebar: **Menu → Sinhala Phonological Task**

### **4. Complete Each Task**

- **Task 1**: Tap each syllable of ශිෂ්‍ය
- **Task 2**: Read the sentence aloud slowly
- **Task 3**: Trace the letter අ within the box

Interactive buttons:
- **💡 Hint** — Request help (increments `hint_request_count`)
- **🔊 Replay** — Replay audio (increments `replay_count`)
- **❌ Correct** — Mark as error (increments `correction_rate`)

### **5. Compute MBSV**

Click **📊 Compute** to send telemetry to C1 and receive MBSV predictions.

The right panel updates with:
- **Color-coded MBSV bars** (red = high strain, green = low strain)
- **Raw feature values** (all 12 parameters)
- **Live log** of events

### **6. Review & Proceed**

Read the MBSV output:
- If **Cognitive Load** is high → task too difficult
- If **Engagement** is low → offer gamification
- If **Phonological Strain** is high → audio features detected difficulty

Click **➡️ Next** to move to the next task (or end session after task 3).

---

## Research Application

### **Behavioral Profile Construction**

Each task builds a multi-modal profile:

| Task | Touch Features | Acoustic Features | Visual Features |
|------|----------------|-------------------|-----------------|
| Syllable Tapping | ✓ pressure, velocity, intervals | ✗ | ✗ |
| Word Reading | ✓ pressure, velocity | ✓ pause, rate, disfluency | ✗ |
| Letter Tracing | ✓ pressure, velocity, deviation | ✗ | ✓ visual strain |

Combined, these feed into the LightGBM model → produces all 6 MBSV dimensions.

### **Validation Mapping**

Map MBSV predictions to Lokubalasuriya Observation Matrix (2019) skill ratings:

```
MBSV phonological_strain_index  ←→  SLP rating for "Phonological Processing"
MBSV cognitive_load_index       ←→  SLP rating for "Reading Decoding"
MBSV visual_strain_index        ←→  SLP rating for "Visual-Spatial Attention"
MBSV session_fatigue_index      ←→  SLP rating for "Fatigue Over Time"
```

During a pilot study (10–15 children), a trained SLP completes the Observation Matrix while the child performs this task. Pearson r between MBSV outputs and SLP ratings validates the system.

---

## Real-Time Log Interpretation

```
[15:40] 🚀 කර්තව්‍ය ආරම්භ කරන ලදී         → Task started
[15:40] ⏳ එක්ක ඉඩ ගිණුම් නිතර කිරීම...    → Waiting for first interaction
[15:41] ❌ නිවැරදි කිරීම # 1                → Correction registered
[15:41] 💡 ඉඟිය ඉල්ලා ගත්තේ # 1            → Hint requested
[15:42] 🔊 ශබ්දය නැවත වාදනය කරන ලදී # 1   → Audio replayed
[15:43] 📊 C1 බනින්න... (MBSV ගණනය කිරීම) → Computing with C1
[15:43] ✅ MBSV ලබා ගත්තේ!                 → MBSV received
[15:43] 📈 සිතින්න: CLI=0.45 | PSI=0.38    → MBSV results displayed
[15:44] ➡️ අදාල කර්තව්‍ය ශ්‍රේණිය 2/3        → Moving to next task
```

---

## Troubleshooting

### **"Failed to connect to Monitoring Service (C1)"**

→ C1 service not running. Check:
```bash
cd R26-SE-031-V2
python start_services.py --test
```

C1 should show [OK] on port 8011.

### **No Audio Features Detected**

→ Mock acoustic values are synthetic for demo. In production, integrate:
```dart
// Uncomment in sinhala_phonological_task.dart
// final audioBuffer = await _recordAudio();
// final acousticFeatures = await C1.extractAcousticFeatures(audioBuffer);
```

### **MBSV Values All 0.5**

→ LightGBM model not loaded. Train it first:
```bash
cd R26-SE-031-V2
python scripts/train_c1_lgbm_real_data.py
```

Without a trained model, C1 falls back to rule-based MBSV (reasonable but not data-driven).

---

## Research Extensions

1. **Pilot Validation**: Compare MBSV outputs to Lokubalasuriya Observation Matrix (10–15 children)
2. **Feature Importance**: Run SHAP analysis to see which of the 12 features most predict each MBSV dimension
3. **Longitudinal Study**: Track a cohort of 30–50 children weekly; measure MBSV trends vs. teacher-rated reading growth
4. **Acoustic Validation**: Integrate real audio recording + analyze pause and syllable rate against SLP benchmarks
5. **Intervention Linkage**: Feed MBSV to C4 (intervention engine) and measure if SM-2 difficulty adaptation improves fluency outcomes

---

## References

- Lokubalasuriya et al. (2019). *Speech Assessment Protocol for Sinhala-Speaking Children.*
- Sweller, J. (1988). *Cognitive Load Theory and Instructional Design.* Cognitive Science, 12(2), 257–285.
- Fuchs, L. S., et al. (2001). *Oral Reading Fluency and its Relationship to Reading Comprehension.* Reading Psychology, 22(1), 47–76.
- Wolf, C., & Bowers, P. G. (1999). *The Double-Deficit Hypothesis for the Developmental Dyslexias.* Journal of Learning Disabilities, 32(4), 299–322.

---

**Status**: Ready for pilot validation  
**Last Updated**: May 2026  
**Component**: R26-SE-031-V2 / sample_demo_with_monitoring
