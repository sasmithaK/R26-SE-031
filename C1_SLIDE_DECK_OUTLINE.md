# C1 PRESENTATION SLIDE DECK OUTLINE
## Visual Guide with Slide-by-Slide Content

---

# 2-MINUTE PRESENTATION SLIDES (4–5 slides)

---

## SLIDE 1: TITLE SLIDE

```
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║   Component 1: Cognitive Behavioral Monitoring Engine (C1)     ║
║   ─────────────────────────────────────────────────────────    ║
║                                                                ║
║   Identifying Dyslexia in Sinhala Grade 1–2 Students          ║
║   Through Real-Time Behavioral Analysis                       ║
║                                                                ║
║   ─────────────────────────────────────────────────────────    ║
║   Gunasena (IT22125798)                                       ║
║   SLIIT | R26-SE-031                                          ║
║   May 15, 2026                                                ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
```

**Duration**: 10 seconds on screen

---

## SLIDE 2: THE PROBLEM

```
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║                    THE PROBLEM                                ║
║   ─────────────────────────────────────────────────────────    ║
║                                                                ║
║   Current Dyslexia Screening in Sri Lanka:                   ║
║                                                                ║
║   ✗ Subjective      Teachers' observations vary              ║
║   ✗ Time-consuming  Individual assessment required           ║
║   ✗ Reactive        Only when problems become obvious        ║
║   ✗ Late            By Grade 2, gap has widened              ║
║                                                                ║
║   ─────────────────────────────────────────────────────────    ║
║                                                                ║
║   Result: Many children with dyslexia go unidentified        ║
║   until Grade 4–5, missing critical intervention window      ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
```

**Duration**: 25 seconds on screen  
**Speaker note**: Explain each point briefly. Emphasize "early intervention matters."

---

## SLIDE 3: THE SOLUTION — C1 OVERVIEW

```
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║                   THE SOLUTION: C1                            ║
║   ─────────────────────────────────────────────────────────    ║
║                                                                ║
║                     4-STEP PROCESS                            ║
║                                                                ║
║   1. BEHAVIORAL CAPTURE                                       ║
║      Measure 12 signals during reading tasks                 ║
║                                                                ║
║   2. PERSONALIZED BASELINE                                    ║
║      Normalize to child's own baseline (Welford)             ║
║                                                                ║
║   3. MACHINE LEARNING                                         ║
║      LightGBM computes 6-dimensional MBSV                    ║
║                                                                ║
║   4. REAL-TIME SIGNAL                                         ║
║      MBSV drives UI adaptation, content, interventions       ║
║                                                                ║
║   ✓ Objective   ✓ Real-time   ✓ Scalable                    ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
```

**Duration**: 40 seconds on screen  
**Speaker note**: Walk through the 4 steps. Emphasize "objective and real-time."

---

## SLIDE 4: THE 12 BEHAVIORAL FEATURES

```
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║              THE 12 BEHAVIORAL FEATURES                       ║
║   ─────────────────────────────────────────────────────────    ║
║                                                                ║
║   TIMING (4)              TOUCH (4)           BEHAVIOR (4)    ║
║   ─────────────────────────────────────────────────────────   ║
║   • hesitation_ms         • touch_pressure    • replay_count  ║
║   • response_latency      • swipe_velocity    • hint_count    ║
║   • read_aloud_pause_ms   • stylus_deviation  • correction_%  ║
║   • syllable_rate         • kalman_innovation • tap_interval  ║
║                                                                ║
║   ─────────────────────────────────────────────────────────    ║
║   All captured automatically. Zero extra burden.              ║
║   Grounded in dyslexia research (Rayner, Wolf & Bowers,     ║
║   Fuchs, Goswami, Sweller, etc.)                            ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
```

**Duration**: 20 seconds on screen  
**Speaker note**: Brief overview of 12 features. Emphasize "automatically captured" and "research-grounded."

---

## SLIDE 5: THE MBSV OUTPUT

```
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║             MBSV: 6-Dimensional Signal Vector                ║
║   ─────────────────────────────────────────────────────────    ║
║                                                                ║
║   Typical Reader          At-Risk Reader                     ║
║   ────────────────────────────────────────────────────────    ║
║                                                                ║
║   visual_strain:     0.15  →  0.62  (visual difficulty)     ║
║   cognitive_load:    0.25  →  0.75  (mental effort)         ║
║   phonological:      0.10  →  0.68  (sound processing)      ║
║   engagement:        0.85  →  0.30  (motivation)            ║
║   session_fatigue:   0.05  →  0.45  (tiredness)             ║
║   error_pattern:  [0,0,0,0] → [1,0,1,1] (error types)       ║
║                                                                ║
║   ─────────────────────────────────────────────────────────    ║
║                                                                ║
║   Real-time signal that triggers adaptation in other         ║
║   components (UI, content, interventions)                    ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
```

**Duration**: 20 seconds on screen  
**Speaker note**: Compare typical vs. at-risk. Explain what each dimension means. Emphasize "real-time signal."

---

## SLIDE 6: WHY THIS MATTERS

```
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║                 WHY THIS MATTERS                              ║
║   ─────────────────────────────────────────────────────────    ║
║                                                                ║
║   Impact Timeline:                                            ║
║                                                                ║
║   Identified in Grade 1    →  Catch-up by Grade 3            ║
║   Identified in Grade 2    →  Catch-up by Grade 4            ║
║   Identified in Grade 4    →  Persistent difficulty          ║
║                                                                ║
║   ─────────────────────────────────────────────────────────    ║
║                                                                ║
║   C1 enables EARLY IDENTIFICATION + EARLY INTERVENTION        ║
║                                                                ║
║   Benefits:                                                   ║
║   ✓ Every month of early intervention improves outcomes       ║
║   ✓ Prevents reading gap from widening                       ║
║   ✓ Reduces stigma (support, not labeling)                   ║
║   ✓ Data-driven decisions (not hunches)                      ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
```

**Duration**: 10 seconds on screen  
**Speaker note**: Emphasize impact of early intervention. Close with call to action for demo.

---

# 5-MINUTE DEMO SLIDES (Optional visual aids)

---

## DEMO AID 1: Feature Capture Diagram

```
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║                   FEATURE CAPTURE FLOW                        ║
║                                                                ║
║   ┌─────────────────┐                                         ║
║   │  Student reads  │                                         ║
║   │  on tablet      │                                         ║
║   └────────┬────────┘                                         ║
║            │                                                   ║
║            ▼                                                   ║
║   ┌─────────────────────────────────────┐                    ║
║   │  12 Behavioral Signals Captured     │                    ║
║   │  • hesitation_ms = 1850             │                    ║
║   │  • touch_pressure = 72              │                    ║
║   │  • swipe_velocity = 0.15            │                    ║
║   │  • replay_count = 0                 │                    ║
║   │  • ... (8 more features)            │                    ║
║   └────────┬────────────────────────────┘                    ║
║            │                                                   ║
║            ▼                                                   ║
║   ┌─────────────────┐                                         ║
║   │  JSON sent to   │                                         ║
║   │  backend (real- │                                         ║
║   │  time streaming)│                                         ║
║   └─────────────────┘                                         ║
║                                                                ║
║   This happens automatically. Student sees nothing unusual.   ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
```

**Use during**: Demo Minute 0–1

---

## DEMO AID 2: MBSV Computation Pipeline

```
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║                   MBSV COMPUTATION PIPELINE                   ║
║                                                                ║
║   ┌──────────────────────┐                                    ║
║   │ 12 Raw Features      │                                    ║
║   │ hesitation_ms: 1850  │                                    ║
║   │ replay_count: 0      │                                    ║
║   │ syllable_rate: 3.0   │                                    ║
║   │ ... (9 more)         │                                    ║
║   └──────────┬───────────┘                                    ║
║              │                                                 ║
║              ▼                                                 ║
║   ┌──────────────────────────────────┐                        ║
║   │ Welford's Baseline Normalization │                        ║
║   │ Z-score = (1850 - 1816) / 82     │                        ║
║   │         = +0.41 standard devs    │                        ║
║   └──────────┬───────────────────────┘                        ║
║              │                                                 ║
║              ▼                                                 ║
║   ┌──────────────────────────────────┐                        ║
║   │ LightGBM Model Ensemble (×6)     │                        ║
║   │ visual_strain model              │                        ║
║   │ cognitive_load model             │                        ║
║   │ phonological_strain model        │                        ║
║   │ engagement model                 │                        ║
║   │ session_fatigue model            │                        ║
║   │ error_classifier                 │                        ║
║   └──────────┬───────────────────────┘                        ║
║              │                                                 ║
║              ▼                                                 ║
║   ┌──────────────────────┐                                    ║
║   │ MBSV Vector          │                                    ║
║   │ visual: 0.62         │                                    ║
║   │ cognitive: 0.75      │                                    ║
║   │ phonological: 0.68   │                                    ║
║   │ engagement: 0.30     │                                    ║
║   │ fatigue: 0.45        │                                    ║
║   │ errors: [1,0,1,1]    │                                    ║
║   └──────────────────────┘                                    ║
║                                                                ║
║   Latency: < 200ms                                            ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
```

**Use during**: Demo Minute 2–3

---

## DEMO AID 3: Real-Time Adaptation

```
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║              REAL-TIME ADAPTATION (Multi-Component)            ║
║                                                                ║
║                                                                ║
║       C1 Computes MBSV                                        ║
║            │                                                   ║
║            │ phonological_strain: 0.68                        ║
║            │ visual_strain: 0.62                              ║
║            │ engagement: 0.30                                 ║
║            │                                                   ║
║    ┌───────┼────────┬─────────────┐                           ║
║    │       │        │             │                           ║
║    ▼       ▼        ▼             ▼                           ║
║  C2(UI)  C3(Cont)  C4(Interv)  Dashboard                     ║
║    │       │        │             │                           ║
║    │ Inc   │ Step   │ Trigger     │ Guardian                 ║
║    │ font  │ down   │ phonolog    │ notification             ║
║    │ size  │ diff  │ support    │                            ║
║    │       │       │             │                           ║
║    └───────┼──────────────────────┘                           ║
║            │                                                   ║
║            ▼                                                   ║
║       Flutter App Updates in Real-Time                       ║
║       • Typography changes                                   ║
║       • Content recommendation changes                       ║
║       • Intervention activity launches                       ║
║       • Guardian sees updated MBSV dashboard                 ║
║                                                                ║
║                                                                ║
║       All within 200ms. Student & guardian see changes.      ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
```

**Use during**: Demo Minute 3–4

---

## DEMO AID 4: Research Grounding Citations

```
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║              RESEARCH GROUNDING                               ║
║   ─────────────────────────────────────────────────────────    ║
║                                                                ║
║   hesitation_ms, response_latency                            ║
║   → Rayner (2001): Eye-movement research                    ║
║      Dyslexic readers fixate longer (>400ms)                 ║
║                                                                ║
║   syllable_rate (naming speed)                               ║
║   → Wolf & Bowers (1999): Double-Deficit Hypothesis         ║
║      Slow naming speed = deficit                             ║
║                                                                ║
║   read_aloud_pause_ms                                        ║
║   → Fuchs et al. (2001): Oral Reading Fluency              ║
║      Grade 1 typical <300ms; dyslexia >600ms                ║
║                                                                ║
║   inter_tap_interval variance                                ║
║   → Goswami (2011): Neural Oscillation Theory               ║
║      Disrupted rhythm = dyslexia marker                      ║
║                                                                ║
║   touch_pressure, stylus_deviation                           ║
║   → Sweller (1988): Cognitive Load Theory                   ║
║      High load → motor control degradation                   ║
║                                                                ║
║   Welford's algorithm                                        ║
║   → Welford (1962): Incremental Statistics                  ║
║      Numerically stable, zero stored history                 ║
║                                                                ║
║   LightGBM                                                    ║
║   → Ke et al. (2017): Fast gradient boosting               ║
║      20× faster than XGBoost                                 ║
║                                                                ║
║   ─────────────────────────────────────────────────────────    ║
║   20+ years of reading research → formalized as algorithms   ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
```

**Use during**: Demo Minute 4–5

---

# OPTIONAL: SLIDE 7 (if time permits)

```
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║              NEXT STEPS (100% Implementation)                 ║
║   ─────────────────────────────────────────────────────────    ║
║                                                                ║
║   50% Implementation (Current):                              ║
║   ✓ 12-feature capture                                       ║
║   ✓ Welford's baseline                                       ║
║   ✓ LightGBM MBSV computation                               ║
║   ✓ Real-time API (200ms latency)                           ║
║   ✓ Synthetic validation                                     ║
║                                                                ║
║   100% Implementation (Future):                              ║
║   → Pilot study (10–15 children)                            ║
║   → Lokubalasuriya Observation Matrix validation            ║
║   → ROC-AUC analysis (target AUC ≥ 0.75)                   ║
║   → Teacher feedback & usability study                       ║
║   → Guardian remote dashboard (live MBSV trends)            ║
║   → Intervention outcome tracking                            ║
║   → Deployment in 5+ pilot schools                          ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
```

**Use if**: Time permits or if explicitly asked "What's next?"

---

# SLIDE DESIGN GUIDELINES

## Color Scheme (Accessible)
```
Background:    White (#FFFFFF)
Text:          Dark blue (#1A1A4D)
Accent:        Sinhala red (#DC143C) for emphasis
Highlight:     Light green (#90EE90) for success/completion
Warning:       Orange (#FF8C00) for issues/concerns
```

## Font Guidelines
```
Title:         20–24pt, Bold, Sans-serif (Arial, Roboto)
Body:          14–16pt, Regular, Sans-serif
Code/Data:     12pt, Monospace (Courier)
Line spacing:  1.5x (readable)
```

## Slide Layout
```
Each slide:
- Title (top, 5% of height)
- Content (middle, 80% of height)
- Footer (bottom 5%): Slide #, Date
- Max 5 bullet points per slide (not dense)
- Whitespace is good (not cluttered)
```

## Animation Tips
```
Recommended: Fade-in for content (not distracting)
Avoid: Spinning, bouncing, or fast transitions
Timing: 0.3–0.5 second per element (snappy, not slow)
```

---

# PRESENTER NOTES (For Each Slide)

## Slide 1: Title Slide
- Take a breath. Make eye contact.
- Smile. You're the expert here.
- Pause 3 seconds before starting.

## Slide 2: Problem
- Speak slowly. This is context-setting.
- Pause after "The challenge" — let it sink in.
- Emphasize "by Grade 2, the gap has widened" (emotional resonance).

## Slide 3: Solution
- Point to each of the 4 steps.
- Say "4-step process" clearly.
- Emphasize "real-time signal drives adaptation."

## Slide 4: 12 Features
- You don't need to explain each feature here — 2-minute presentation is short.
- Just show the 12, emphasize "automatically captured," cite research.

## Slide 5: MBSV Output
- This is the payoff slide. Examiners should see the concrete output.
- Spend time on the comparison (typical vs. at-risk).
- Point to specific values: "visual strain 0.62 means visual difficulty."

## Slide 6: Why This Matters
- End on impact. This is your closing.
- "Early intervention changes lives."
- Transition to demo: "Now let me show you how this works in practice."

---

# QUICK REFERENCE: SLIDE TIMING

```
2-Minute Presentation Breakdown:

Slide 1 (Title)         0:00 – 0:10   (10 sec)
Slide 2 (Problem)       0:10 – 0:35   (25 sec)
Slide 3 (Solution)      0:35 – 1:15   (40 sec)
Slide 4 (12 Features)   1:15 – 1:35   (20 sec)
Slide 5 (MBSV Output)   1:35 – 1:55   (20 sec)
Slide 6 (Impact)        1:55 – 2:00   (5 sec)

Total: 120 seconds (2 minutes)
```

---

# DEMO VISUAL AIDS

During demo, you may want to display:
1. **Live Flutter app** (tablet) — student perspective
2. **Terminal logs** (laptop) — backend processing
3. **API response JSON** — MBSV output
4. **Before/after UI** — typography adaptation
5. **Diagram on screen** — system flow (optional)

Prepare screenshots of all 5 as backups in case live demo fails.

---

**Created**: May 15, 2026  
**For**: IT22125798 (Gunasena) — Component 1 Presentation  
**Format**: PowerPoint or Google Slides (copy this outline)
