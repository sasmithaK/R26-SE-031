# Sinhala Phonological Task â€” Comprehensive Behavioral Monitoring

## Overview

The **Sinhala Phonological Task** is a research-grade assessment that captures all 12 behavioral parameters from the R26-SE-031 monitoring architecture, processing them through the C1 Monitoring Service in real-time, and displaying 6-dimensional MBSV predictions alongside raw feature logs.

---

## Features Monitored

| # | Feature | Measurement | Icon |
|---|---------|-------------|------|
| 1 | `hesitation_ms` | Time before first interaction | â±ï¸ |
| 2 | `correction_rate` | Corrections / total interactions | âŒ |
| 3 | `response_latency` | Task start â†’ completion time | âš¡ |
| 4 | `touch_pressure` | Normalized force (0-1) | ðŸ–ï¸ |
| 5 | `swipe_velocity` | Pixels/ms during interaction | ðŸŽ¯ |
| 6 | `replay_count` | Audio replay button presses | ðŸ”Š |
| 7 | `hint_request_count` | Hint button presses | ðŸ’¡ |
| 8 | `stylus_deviation` | Fine-motor error (letter tracing) | âœï¸ |
| 9 | `inter_tap_interval` | Timing variance in tapping tasks | ðŸŽµ |
| 10 | `read_aloud_pause_ms` | Inter-word silence duration | ðŸŽ¤ |
| 11 | `syllable_rate` | Syllables/second in read-aloud | ðŸ—£ï¸ |
| 12 | `disfluency_count` | Restarts/prolongations detected | ðŸ”„ |

---

## MBSV Dimensions Predicted

Real-time predictions from C1 with color-coded health indicators:

| Dimension | Range | Indicator | Interpretation |
|-----------|-------|-----------|-----------------|
| ðŸ§  **Cognitive Load** | 0.0â€“1.0 | Red (high) â†’ Green (low) | Task complexity overload signal |
| ðŸ—£ï¸ **Phonological Strain** | 0.0â€“1.0 | Red â†’ Green | Phonological processing difficulty |
| ðŸ‘ï¸ **Visual Strain** | 0.0â€“1.0 | Red â†’ Green | Visual crowding / crowding load |
| ðŸ˜´ **Fatigue** | 0.0â€“1.0 | Red â†’ Green | Cumulative session fatigue |
| ðŸ˜Š **Engagement** | 0.0â€“1.0 | Green (high) â†’ Red (low) | Intrinsic motivation level |
| ðŸ“Š **Error Pattern Vector** | [4 flags] | Binary flags | [Reversal, Omission, Substitution, Hesitation] |

---

## Task Structure

### **Task 1: Syllable Tapping (ðŸŽ¯ Phonological Awareness)**

**Objective**: Segment Sinhala words into syllables by tapping each segment

**Word**: à·à·’à·‚à·Šâ€à¶º (Shiá¹£ya â€” "student")  
**Syllables**: [à·à·’] [à·‚à·Šâ€à¶º]

**Monitors**:
- `hesitation_ms` â€” How long before first tap?
- `inter_tap_interval` â€” Timing between syllable taps
- `correction_rate` â€” How many false taps were corrected?
- `touch_pressure` â€” Stress in finger taps

---

### **Task 2: Word Reading (ðŸ“– Decoding Fluency)**

**Objective**: Read aloud a sentence containing a target word slowly and clearly

**Sentence**: à¶‘à¶º à¶´à¶±à¶­à¶§ à¶…à¶±à·”à·€ à·ƒà·’à¶¯à·” à·€à·’à¶ºà¥¤ (Aya panatata anuva sidu viyi.)  
**Target Word**: à¶´à¶±à¶­ (Panata â€” "law")

**Monitors**:
- `read_aloud_pause_ms` â€” Pause duration between words (audio energy thresholding)
- `syllable_rate` â€” Speaking speed (syllables/sec)
- `disfluency_count` â€” Restarts or prolongations detected
- `replay_count` â€” How many audio replays requested?
- `swipe_velocity` â€” Screen interactions during reading

---

### **Task 3: Letter Tracing (âœï¸ Visual-Motor Control)**

**Objective**: Trace the outline of a Sinhala letter precisely

**Letter**: à¶… (A â€” first vowel)

**Monitors**:
- `stylus_deviation` â€” RMS error from template path
- `touch_pressure` â€” Motor tension during trace
- `swipe_velocity` â€” Trace smoothness
- `hesitation_ms` â€” Hesitation before starting
- `correction_rate` â€” Pen-up (correction) events

---

## UI Layout

```
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚  ðŸ‡±ðŸ‡° à·ƒà·’à¶‚à·„à¶½ à·à¶¶à·Šà¶¯-à¶…à¶šà·Šà·‚à¶» à·ƒà¶¸à·Šà¶¶à¶±à·Šà¶°à¶­à· à¶šà¶»à·Šà¶­à·€à·Šâ€à¶º                           â”‚
â”‚  Task 1 / 3: ðŸŽ¯ à·€à¶ à¶± à¶šà·œà¶§à·ƒ à¶œà¶«à¶±à¶º à¶šà·’à¶»à·“à¶¸                           â”‚
â”œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ TASK AREA â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤
â”‚                                           â”‚                      â”‚
â”‚  à·à·’à·‚à·Šâ€à¶º                                 â”‚  ðŸ“Š MBSV Status      â”‚
â”‚  [à·à·’] [à·‚à·Šâ€à¶º]                           â”‚  ðŸ§  Cognitive 0.45  â”‚
â”‚                                           â”‚  ðŸ—£ï¸ Phonological 0.38
â”‚  [ðŸ’¡ Hint] [ðŸ”Š Replay] [âŒ Correct]     â”‚  ðŸ‘ï¸ Visual 0.52     â”‚
â”‚                                           â”‚  ðŸ˜´ Fatigue 0.28    â”‚
â”‚  [ðŸ“Š Compute] [âž¡ï¸ Next]                 â”‚  ðŸ˜Š Engagement 0.72  â”‚
â”‚                                           â”‚                      â”‚
â”‚                                           â”‚ âš™ï¸ Raw Features    â”‚
â”‚                                           â”‚ hesitation_ms: 1200  â”‚
â”‚                                           â”‚ correction_rate: 0.2 â”‚
â”‚                                           â”‚ swipe_velocity: 95   â”‚
â”‚                                           â”‚ ... (12 total)      â”‚
â”‚                                           â”‚                      â”‚
â”‚                                           â”‚ ðŸ“ Live Log          â”‚
â”‚                                           â”‚ 15:42 ðŸš€ Task start â”‚
â”‚                                           â”‚ 15:42 âŒ Correction 1 â”‚
â”‚                                           â”‚ 15:43 ðŸ’¡ Hint #1    â”‚
â”‚                                           â”‚ 15:44 ðŸ“Š Computing...â”‚
â”‚                                           â”‚ 15:44 âœ… MBSV ready!â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
```

---

## How to Use

### **1. Start the System**

Ensure backend services are running:
```bash
cd <repo-root>
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
Or use sidebar: **Menu â†’ Sinhala Phonological Task**

### **4. Complete Each Task**

- **Task 1**: Tap each syllable of à·à·’à·‚à·Šâ€à¶º
- **Task 2**: Read the sentence aloud slowly
- **Task 3**: Trace the letter à¶… within the box

Interactive buttons:
- **ðŸ’¡ Hint** â€” Request help (increments `hint_request_count`)
- **ðŸ”Š Replay** â€” Replay audio (increments `replay_count`)
- **âŒ Correct** â€” Mark as error (increments `correction_rate`)

### **5. Compute MBSV**

Click **ðŸ“Š Compute** to send telemetry to C1 and receive MBSV predictions.

The right panel updates with:
- **Color-coded MBSV bars** (red = high strain, green = low strain)
- **Raw feature values** (all 12 parameters)
- **Live log** of events

### **6. Review & Proceed**

Read the MBSV output:
- If **Cognitive Load** is high â†’ task too difficult
- If **Engagement** is low â†’ offer gamification
- If **Phonological Strain** is high â†’ audio features detected difficulty

Click **âž¡ï¸ Next** to move to the next task (or end session after task 3).

---

## Research Application

### **Behavioral Profile Construction**

Each task builds a multi-modal profile:

| Task | Touch Features | Acoustic Features | Visual Features |
|------|----------------|-------------------|-----------------|
| Syllable Tapping | âœ“ pressure, velocity, intervals | âœ— | âœ— |
| Word Reading | âœ“ pressure, velocity | âœ“ pause, rate, disfluency | âœ— |
| Letter Tracing | âœ“ pressure, velocity, deviation | âœ— | âœ“ visual strain |

Combined, these feed into the LightGBM model â†’ produces all 6 MBSV dimensions.

### **Validation Mapping**

Map MBSV predictions to Lokubalasuriya Observation Matrix (2019) skill ratings:

```
MBSV phonological_strain_index  â†â†’  SLP rating for "Phonological Processing"
MBSV cognitive_load_index       â†â†’  SLP rating for "Reading Decoding"
MBSV visual_strain_index        â†â†’  SLP rating for "Visual-Spatial Attention"
MBSV session_fatigue_index      â†â†’  SLP rating for "Fatigue Over Time"
```

During a pilot study (10â€“15 children), a trained SLP completes the Observation Matrix while the child performs this task. Pearson r between MBSV outputs and SLP ratings validates the system.

---

## Real-Time Log Interpretation

```
[15:40] ðŸš€ à¶šà¶»à·Šà¶­à·€à·Šâ€à¶º à¶†à¶»à¶¸à·Šà¶· à¶šà¶»à¶± à¶½à¶¯à·“         â†’ Task started
[15:40] â³ à¶‘à¶šà·Šà¶š à¶‰à¶© à¶œà·’à¶«à·”à¶¸à·Š à¶±à·’à¶­à¶» à¶šà·’à¶»à·“à¶¸...    â†’ Waiting for first interaction
[15:41] âŒ à¶±à·’à·€à·à¶»à¶¯à·’ à¶šà·’à¶»à·“à¶¸ # 1                â†’ Correction registered
[15:41] ðŸ’¡ à¶‰à¶Ÿà·’à¶º à¶‰à¶½à·Šà¶½à· à¶œà¶­à·Šà¶­à·š # 1            â†’ Hint requested
[15:42] ðŸ”Š à·à¶¶à·Šà¶¯à¶º à¶±à·à·€à¶­ à·€à·à¶¯à¶±à¶º à¶šà¶»à¶± à¶½à¶¯à·“ # 1   â†’ Audio replayed
[15:43] ðŸ“Š C1 à¶¶à¶±à·’à¶±à·Šà¶±... (MBSV à¶œà¶«à¶±à¶º à¶šà·’à¶»à·“à¶¸) â†’ Computing with C1
[15:43] âœ… MBSV à¶½à¶¶à· à¶œà¶­à·Šà¶­à·š!                 â†’ MBSV received
[15:43] ðŸ“ˆ à·ƒà·’à¶­à·’à¶±à·Šà¶±: CLI=0.45 | PSI=0.38    â†’ MBSV results displayed
[15:44] âž¡ï¸ à¶…à¶¯à·à¶½ à¶šà¶»à·Šà¶­à·€à·Šâ€à¶º à·à·Šâ€à¶»à·šà¶«à·’à¶º 2/3        â†’ Moving to next task
```

---

## Troubleshooting

### **"Failed to connect to Monitoring Service (C1)"**

â†’ C1 service not running. Check:
```bash
cd <repo-root>
python start_services.py --test
```

C1 should show [OK] on port 8011.

### **No Audio Features Detected**

â†’ Mock acoustic values are synthetic for demo. In production, integrate:
```dart
// Uncomment in sinhala_phonological_task.dart
// final audioBuffer = await _recordAudio();
// final acousticFeatures = await C1.extractAcousticFeatures(audioBuffer);
```

### **MBSV Values All 0.5**

â†’ LightGBM model not loaded. Train it first:
```bash
cd <repo-root>
python scripts/train_c1_lgbm_real_data.py
```

Without a trained model, C1 falls back to rule-based MBSV (reasonable but not data-driven).

---

## Research Extensions

1. **Pilot Validation**: Compare MBSV outputs to Lokubalasuriya Observation Matrix (10â€“15 children)
2. **Feature Importance**: Run SHAP analysis to see which of the 12 features most predict each MBSV dimension
3. **Longitudinal Study**: Track a cohort of 30â€“50 children weekly; measure MBSV trends vs. teacher-rated reading growth
4. **Acoustic Validation**: Integrate real audio recording + analyze pause and syllable rate against SLP benchmarks
5. **Intervention Linkage**: Feed MBSV to C4 (intervention engine) and measure if SM-2 difficulty adaptation improves fluency outcomes

---

## References

- Lokubalasuriya et al. (2019). *Speech Assessment Protocol for Sinhala-Speaking Children.*
- Sweller, J. (1988). *Cognitive Load Theory and Instructional Design.* Cognitive Science, 12(2), 257â€“285.
- Fuchs, L. S., et al. (2001). *Oral Reading Fluency and its Relationship to Reading Comprehension.* Reading Psychology, 22(1), 47â€“76.
- Wolf, C., & Bowers, P. G. (1999). *The Double-Deficit Hypothesis for the Developmental Dyslexias.* Journal of Learning Disabilities, 32(4), 299â€“322.

---

**Status**: Ready for pilot validation  
**Last Updated**: May 2026  
**Component**: R26-SE-031-V2 / sample_demo_with_monitoring
