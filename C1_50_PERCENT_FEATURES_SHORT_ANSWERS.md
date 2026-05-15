# C1: 50% FEATURES — SHORT ANSWERS
## Simple Language | Technical Depth | Research Grounding
**For**: Quick presentation & viva reference

---

# THE 12 FEATURES (50% Implementation)

## CATEGORY 1: TIMING FEATURES (4 features)

### Feature 1: `hesitation_ms`

**Simple**: How long before student taps answer?

**Technical**: Time from stimulus display to first interaction (ms)
```
hesitation_ms = time_at_tap - time_at_display
```

**What it reveals**:
- <300ms: Automatic (knows answer)
- 300–800ms: Normal decoding
- >1000ms: Struggle (sounding out)

**Research**: Rayner (2001) — Eye-movement studies show dyslexic readers fixate longer. Hesitation >400ms = decoding difficulty marker. For Sinhala aksharas (complex shapes), typical Grade 1 = 400–500ms; struggling = 1200–2000ms.

**How to demo**: "Student sees akshara, hesitates 2 seconds, taps. System logs hesitation_ms = 1850. That's 4× longer than baseline, so SIGNAL of difficulty."

---

### Feature 2: `response_latency`

**Simple**: Total time from task start to answer.

**Technical**: Elapsed time from task display to task completion (ms)
```
response_latency = time_task_complete - time_task_start
```

**What it reveals**:
- <2000ms: Quick (fluent)
- 2000–5000ms: Normal (decoding required)
- >5000ms: Severe struggle

**Research**: Wolf & Bowers (1999) — Naming speed deficit. Slow response latency indicates naming speed is compromised. Combined with high hesitation_ms, signals phonological + speed deficit (Double Deficit = highest dyslexia risk).

**How to demo**: "Task takes 5.2 seconds. Typical Grade 1 takes 2–3 seconds. This child's processing speed is slow. That's a signal for cognitive_load_index to be high."

---

### Feature 3: `read_aloud_pause_ms` (Acoustic)

**Simple**: Silence time between words when reading aloud.

**Technical**: Duration of energy envelope dips (silence) between voiced segments (ms)
```python
# On-device audio energy → detect silence bursts
silence_duration = time_silence_end - time_silence_start
read_aloud_pause_ms = mean(all_silence_durations)
```

**What it reveals**:
- <200ms: Fluent, smooth
- 200–400ms: Normal
- >600ms: Struggling (long pauses = decoding difficulty)

**Research**: Fuchs et al. (2001) — Oral Reading Fluency norms. Grade 1 typical: <300ms pause between words. Dyslexia: >600ms pause. Our acoustic feature uses energy thresholding (no ASR), on-device (privacy), zero external dependency.

**Why no ASR**: Sinhala speech recognition doesn't exist at scale. Energy envelope approach is novel for low-resource languages.

**How to demo**: "Child reads 'බල්ලා දුවයි' (dog runs). Between the two words, there's a 850ms pause. That's 2.8× longer than normal. Signal: phonological difficulty."

---

### Feature 4: `syllable_rate`

**Simple**: How fast child speaks (syllables per second).

**Technical**: Count energy peaks in audio envelope per second
```python
# Energy envelope → peak detection → count peaks per duration
syllable_rate = num_peaks / duration_seconds
```

**What it reveals**:
- 2.5–3.5 syl/sec: Typical Grade 1
- 1.5–2.0 syl/sec: Slow (normal variation)
- <1.0 syl/sec: Very slow (articulation difficulty)

**Research**: Wolf & Bowers (1999) — Slow articulation rate is naming-speed deficit marker. Goswami (2011) — Neural oscillation theory ties rhythmic speech to phonological processing. Low syllable_rate indicates phonological timing disruption.

**How to demo**: "Child reads 3-syllable word in 2 seconds. That's 1.5 syllables/second. Typical is 3.0. So articulation is HALF normal speed. That signals phonological_strain_index should be elevated."

---

## CATEGORY 2: TOUCH KINEMATICS FEATURES (4 features)

### Feature 5: `touch_pressure`

**Simple**: How hard child presses screen (0–100%).

**Technical**: Normalized touch force from touchscreen hardware
```dart
double pressure = event.pressure;  // 0.0–1.0 from Flutter
double pressurePercent = pressure * 100;
```

**What it reveals**:
- 10–30%: Relaxed, confident
- 30–60%: Normal effort
- 60%+: Tension (frustration, anxiety, high cognitive load)

**Research**: Sweller (1988) — Cognitive Load Theory. High load → physical tension. Child under cognitive stress unconsciously presses harder (stress response). Touch pressure is downstream effect of cognitive overload.

**How to demo**: "Task 1: student relaxed, pressure = 25%. Task 5 (harder): pressure = 72%. That's 3× increase. Signal: cognitive load is building up through the session."

---

### Feature 6: `swipe_velocity`

**Simple**: Speed of finger movement (pixels per millisecond).

**Technical**: Distance moved / time elapsed (px/ms)
```dart
double distance = currentPos.distance(previousPos);
double timeElapsed = now.difference(lastTime).inMilliseconds;
double velocity = distance / timeElapsed;
```

**What it reveals**:
- >0.3 px/ms: Quick, confident (automatic response)
- 0.1–0.3 px/ms: Deliberate (thinking while moving)
- <0.1 px/ms: Very slow (hesitation, uncertainty)

**Research**: Wickens (1984) — Multiple Resource Theory. Cognitive load taxes motor channel. High load → slower, more deliberate movements (divided attention). Low velocity signals child is processing while moving (not automatic).

**How to demo**: "Scrolling through word list: slow velocity (0.08 px/ms) because child is reading each word. After successful warm-up: high velocity (0.4 px/ms). Signal: as cognitive load decreases, movements become automatic."

---

### Feature 7: `stylus_deviation`

**Simple**: How far off-target the child's tracing is (RMS error).

**Technical**: Root-mean-square distance from expected path
```python
# Expected path: template letter (e.g., "අ")
# Actual path: where child traced
# RMS = sqrt(mean(distances^2))
rms_deviation = np.sqrt(np.mean([dist**2 for dist in distances]))
```

**What it reveals**:
- <5px: Good fine-motor control
- 5–15px: Normal (Grade 1 development)
- >15px: Motor control difficulty OR visual-spatial difficulty

**Research**: Hamstra-Bletz & Blöte (1993) — Poor handwriting/tracing is dyslexia marker. Fine-motor control is visuo-motor integration. High deviation indicates either motor difficulty OR visual-spatial difficulty (can't perceive letter shape correctly).

**How to demo**: "Child traces letter 'අ'. Template expects specific path. Child's actual trace deviates 22px on average. Normal Grade 1 = 8px. Signal: visual-spatial processing is difficult (visual_strain_index should be high)."

---

### Feature 8: `kalman_innovation`

**Simple**: How "jumpy" or unpredictable is the touch trajectory?

**Technical**: Kalman filter predicts next position; innovation = prediction error
```python
# Kalman assumes smooth motion (constant velocity model)
# When actual touches deviate from prediction → high innovation
# High innovation = high motor uncertainty = high cognitive load
innovation = ||actual_position - predicted_position||
```

**What it reveals**:
- <10px: Smooth trajectory (low motor uncertainty)
- 10–30px: Normal variation
- >30px: Very jittery (high motor uncertainty = high cognitive load)

**Research**: Sweller (1988) — Under high cognitive load, fine-motor control degrades. Kalman filter innovation quantifies this motor uncertainty. Theoretically grounded in control theory: predictable motion = low load, erratic motion = high load.

**Why Kalman**: Simpler alternative is std_dev(velocity), but Kalman is more theoretically sound (separates signal from noise at frame level).

**How to demo**: "During easy task: smooth swipe, innovation = 6px (predictable). During hard task: child's hand wavers, innovation = 35px (unpredictable). Signal: cognitive load increased dramatically."

---

## CATEGORY 3: BEHAVIORAL ENGAGEMENT FEATURES (4 features)

### Feature 9: `replay_count`

**Simple**: How many times student replays audio.

**Technical**: Count of replay button taps (integer)
```dart
int replayCount = 0;
onReplayButtonTap() {
  replayCount++;
}
```

**What it reveals**:
- 0–1: Confident (knows word from single exposure)
- 1–2: Seeking confirmation
- 3+: Phonological difficulty (can't extract sound info from single exposure)

**Research**: Direct phonological difficulty indicator. A child who replays 3+ times is struggling to process the speech sound. Correlates with phonological awareness deficit (Wolf & Bowers 1999).

**How to demo**: "Word 'ශ්‍ර' plays once. Student hesitates, replays, hesitates, replays, replays (3 times total). System logs replay_count = 2. Signal: this child struggles with phonological decoding. Phonological_strain_index should be HIGH."

---

### Feature 10: `hint_request_count`

**Simple**: How many times student asks for hint.

**Technical**: Count of hint button taps (integer)
```dart
int hintCount = 0;
onHintButtonTap() {
  hintCount++;
}
```

**What it reveals**:
- 0–1 per task: Independent, self-aware
- 1–2 per task: Seeking scaffolding (normal)
- 3+ per task: High metacognitive load (can't self-correct)

**Research**: Sweller's germane load. Hints provide extraneous scaffolding. A child who requests 3+ hints per task isn't learning independent decoding strategies. Indicates cognitive overload preventing metacognitive development.

**How to demo**: "Task sequence: Student requests 0, 1, 2, 3, 2 hints per task. Hint_request_count trending up. Signal: student is becoming MORE dependent on help (overloaded). Intervention should reduce task difficulty."

---

### Feature 11: `correction_rate`

**Simple**: Fraction of errors child catches and corrects.

**Technical**: Count of self-corrections / total attempts
```
correction_rate = corrections_made / total_attempts
```

**What it reveals**:
- >60%: Good self-monitoring (metacognitively aware)
- 30–60%: Developing awareness
- <30%: Poor self-monitoring = phonological awareness deficit

**Research**: Phonological awareness = ability to hear when you make mistakes. Low correction_rate means child can't hear their own errors. Correlates with poor phonological processing (Wolf & Bowers 1999, Goswami 2011).

**How to demo**: "Across 6 tasks: 1 error corrected, 5 not corrected. Correction_rate = 1/6 = 17%. Typical Grade 1 = 50%+. Signal: child has poor phonological self-monitoring. Phonological_strain_index should be ELEVATED."

---

### Feature 12: `inter_tap_interval`

**Simple**: Variability in timing between sequential taps (CV = coefficient of variation).

**Technical**: Standard deviation / mean of inter-tap intervals
```python
intervals = [tap[i] - tap[i-1] for i in 1..n]
cv = std(intervals) / mean(intervals)
```

**What it reveals**:
- <0.15 CV: Good sense of rhythm (consistent timing)
- 0.15–0.30 CV: Normal variation
- >0.30 CV: Disrupted rhythm (phonological timing difficulty)

**Research**: Goswami (2011) — Neural Oscillation Theory. Dyslexia involves disrupted rhythmic neural processing. Poor inter-tap timing reflects disrupted phonological rhythm (can't perceive syllabic beats consistently). Experimental task: tap once per syllable while word plays.

**How to demo**: "Word has 4 syllables, played at normal speech rate. Typical child taps at 350ms, 340ms, 360ms, 350ms (CV = 0.03, very consistent). Dyslexic child taps at 200ms, 400ms, 300ms, 500ms (CV = 0.40, erratic). Signal: phonological rhythm is disrupted."

---

# MBSV OUTPUT (6 DIMENSIONS)

### Dimension 1: `visual_strain_index` [0–1]

**What it measures**: Is the child struggling to SEE/RECOGNIZE letters?

**Formula**: 
```
visual_strain = LightGBM_model(['swipe_velocity', 'stylus_deviation', 'hesitation_ms', 'kalman_innovation'])
```

**Interpretation**:
- <0.3: No visual strain (sees/recognizes letters easily)
- 0.3–0.6: Moderate strain (visual processing requires effort)
- >0.6: High strain (letters are hard to distinguish/recognize)

**Action**: C2 (UI) adapts typography: increase font size, letter spacing, contrast

**Research grounding**: Sweller + Wilkins Visual Stress Theory

---

### Dimension 2: `cognitive_load_index` [0–1]

**What it measures**: Total mental effort required for the task.

**Formula**:
```
cognitive_load = LightGBM_model(['hesitation_ms', 'response_latency', 'correction_rate', 'disfluency_count'])
```

**Interpretation**:
- <0.3: Low load (task is easy, automatic)
- 0.3–0.6: Moderate load (normal learning effort)
- >0.6: High load (task exceeds capacity)

**Action**: C3 (Content) steps down difficulty or recommends break

**Research grounding**: Sweller's Cognitive Load Theory

---

### Dimension 3: `phonological_strain_index` [0–1]

**What it measures**: Difficulty with sound processing (phonology).

**Formula**:
```
phonological_strain = LightGBM_model(['replay_count', 'inter_tap_interval', 'read_aloud_pause_ms', 'syllable_rate'])
```

**Interpretation**:
- <0.3: No phonological strain (sounds are easy)
- 0.3–0.6: Moderate strain (phonological processing requires effort)
- >0.6: High strain (phonological deficit evident)

**Action**: C4 (Intervention) provides phonological support: syllable splitting, tapping games, blending practice

**Research grounding**: Wolf & Bowers (1999), Goswami (2011)

---

### Dimension 4: `engagement_index` [0–1]

**What it measures**: Is child motivated and trying?

**Formula**:
```
engagement = 1 - LightGBM_model(['hint_request_count', 'correction_rate', 'touch_pressure'])
# (inverted: low hints/normal pressure/good corrections = HIGH engagement)
```

**Interpretation**:
- >0.7: Highly engaged (motivated, trying hard)
- 0.4–0.7: Moderate engagement
- <0.4: Low engagement (frustrated, giving up)

**Action**: C2 triggers gamification (mini-game break) to re-engage

**Research grounding**: Self-Determination Theory (Ryan & Deci 2000)

---

### Dimension 5: `session_fatigue_index` [0–1]

**What it measures**: Accumulated tiredness through session.

**Formula**:
```
session_fatigue = LightGBM_model([response_latency, hesitation_ms, syllable_rate] over time_window)
# Compares early-session vs. late-session values
# If response_latency is INCREASING, fatigue is building
```

**Interpretation**:
- <0.3: Fresh, no fatigue
- 0.3–0.6: Moderate fatigue building
- >0.6: High fatigue (recommend session end)

**Action**: C3 recommends session break or consolidation (easier content)

**Research grounding**: Ebbinghaus Forgetting Curve + sustained attention research

---

### Dimension 6: `error_pattern_vector` [4 flags]

**What it measures**: Which error TYPES is child making?

**Formula** (Rule-based, no ML):
```python
reversal_flag = 1 if (correction_rate > 0.7 AND visual_strain_index > 0.6) else 0
omission_flag = 1 if disfluency_count > 3 else 0
substitution_flag = 1 if (swipe_velocity < 0.1 AND touch_pressure > 70) else 0
hesitation_flag = 1 if hesitation_ms > 1500 else 0
error_pattern_vector = [reversal_flag, omission_flag, substitution_flag, hesitation_flag]
```

**Interpretation**:
- [0,0,0,0]: Typical (no errors)
- [1,0,0,0]: Reversals (letter confusion)
- [0,1,0,0]: Omissions (skipping words)
- [0,0,1,0]: Substitutions (wrong word)
- [0,0,0,1]: Hesitations (long pauses)

**Action**: C4 selects intervention activity based on error type. E.g., reversal → picture-word matching; hesitation → tapping game

**Research grounding**: Dyslexia phonological profile analysis

---

# HOW TO PRESENT IN DEMO (30 SECONDS PER FEATURE)

### Feature Template (Repeat for each):

**[Display feature name on screen]**

**YOU SAY:**

> "[Feature name] measures [simple description]. 
> 
> **How we measure it**: [Technical method, 1 line]
> 
> **What it reveals**: [Typical vs. at-risk range]
> 
> **Research**: [Citation(s)]
> 
> **In this student's case**: [Specific value + interpretation]"

---

# EXAMPLE LIVE DELIVERY (3 minutes)

**Student hesitates 1.8 seconds on word "ශ්‍ර"**

---

**YOU SAY:**

> "We captured **hesitation_ms: 1850**. 
>
> That's how long between when the letter appeared and when the student tapped. 
>
> For Sinhala aksharas, typical Grade 1 is 400–500ms. This student took 1.8 seconds. That's 3–4× longer than typical.
>
> Rayner's eye-movement research (2001) says hesitation >400ms is a decoding difficulty marker. So this long hesitation signals: 'This child is struggling to decode the letter.'
>
> That's ONE signal. But we capture 12 signals total. When we combine all 12 and feed them to our LightGBM models, we get the MBSV. In this case, visual_strain_index came out **0.62** — moderate visual strain.
>
> That means the student is struggling to see/recognize the letter, not just being slow."

**Duration**: ~1 minute (comfortable pace)

---

# VIVA: "EXPLAIN FEATURE X IN 1 MINUTE"

**Template for viva answers**:

1. **What it measures** (1 sentence, simple)
2. **How we measure it** (1 sentence, technical)
3. **Typical vs. at-risk range** (2 values)
4. **Research citation** (1 paper + what it says)
5. **Why it matters for dyslexia** (1 sentence, connecting to theory)

**Example (hesitation_ms)**:

> "Hesitation_ms measures how long the student pauses before responding. We measure it as time from stimulus display to first tap. Typical Grade 1: 300–500ms. Struggling: >1000ms. Rayner (2001) showed dyslexic readers fixate longer on difficult words — hesitation >400ms is a decoding difficulty marker. Long hesitation indicates the child's visual-phonological processing is slow, so visual_strain_index will be elevated."

**Duration**: ~45 seconds (fits in viva time)

---

# QUICK MNEMONICS

## 12 Features by Category

**TIMING** (How long?):
- hesitation_ms
- response_latency
- read_aloud_pause_ms
- syllable_rate

**TOUCH** (How does body respond?):
- touch_pressure
- swipe_velocity
- stylus_deviation
- kalman_innovation

**BEHAVIOR** (What does child do?):
- replay_count
- hint_request_count
- correction_rate
- inter_tap_interval

---

## 6 MBSV Dimensions by Function

**UI Adaptation** (C2 uses):
- visual_strain_index
- engagement_index

**Content Selection** (C3 uses):
- cognitive_load_index
- session_fatigue_index

**Intervention** (C4 uses):
- phonological_strain_index
- error_pattern_vector

---

# RESEARCH CITATIONS (Alphabetical)

1. **Fuchs et al. (2001)** — Oral Reading Fluency. Pause >600ms = dyslexia marker.
2. **Goswami (2011)** — Neural Oscillation Theory. Disrupted rhythm = dyslexia.
3. **Hamstra-Bletz & Blöte (1993)** — Poor handwriting/tracing = dyslexia marker.
4. **Rayner (2001)** — Eye-movement research. Fixation >400ms = decoding difficulty.
5. **Ryan & Deci (2000)** — Self-Determination Theory. Engagement drives learning.
6. **Sweller (1988)** — Cognitive Load Theory. High load → motor degradation.
7. **Wickens (1984)** — Multiple Resource Theory. Load taxes motor channel.
8. **Wolf & Bowers (1999)** — Double-Deficit Hypothesis. Phonological + speed deficits.
9. **Welford (1962)** — Incremental Statistics. Numerically stable baseline.
10. **Ke et al. (2017)** — LightGBM. 20× faster than XGBoost.

---

**Created**: May 15, 2026  
**For**: IT22125798 (Gunasena) — Quick Reference for 50% Demo  
**Format**: Scannable, short answers, technical + research grounded
