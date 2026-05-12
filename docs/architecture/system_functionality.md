# System Functionality & Research Architecture
## Adaptive Sinhala Dyslexia Screening & Guidance Platform — R26-SE-031

> **Revised architecture (v2.0).** The previous single-scalar RSI output has been replaced by a
> **Multi-Dimensional Behavioral Signal Vector (MBSV)**. Each consuming component receives only
> the dimensions it owns. This eliminates the BKT ownership clash, the gamification ownership
> clash, and the content-delivery overlap documented in the original proposals.

---

## System Concept

The app is a **guardian-assisted early dyslexia screening and guided literacy tool** for Grade 1–2
Sinhala-medium children. A guardian sets up the child's profile. The app then runs a structured
screening battery (communication, verbal reasoning, sequencing) while continuously monitoring
behavioral signals. Based on screening outcomes, it delivers personalized learning sessions with
real-time UI adaptation, skill-appropriate content, and inline interventions — with session data
available to the guardian remotely.

### Core Research Question (Group-Level)

> *How can a multi-dimensional behavioral signal vector derived from touch interaction, stylus
> trace, response timing, and acoustic read-aloud proxies be used to simultaneously drive
> real-time visual adaptation, personalized content sequencing, and word-level intervention for
> Sinhala-medium dyslexia screening in Grade 1–2 learners?*

---

## The Multi-Dimensional Behavioral Signal Vector (MBSV)

The MBSV is the central architectural primitive — a **structured 6-dimension output vector**
produced exclusively by C1 (Monitoring). Every other component consumes **only its assigned
dimensions**. No component may re-derive a dimension owned by another component.

```
MBSV = {
  visual_strain_index:       float [0–1]   → consumed by C2 (UI adaptation)
  cognitive_load_index:      float [0–1]   → consumed by C3 (content difficulty)
  phonological_strain_index: float [0–1]   → consumed by C4 (intervention trigger)
  engagement_index:          float [0–1]   → consumed by C2 (gamification trigger)
  session_fatigue_index:     float [0–1]   → consumed by C3 (session pacing)
  error_pattern_vector:      int[4]        → consumed by C4 (error type classification)
                             [reversal_flag, omission_flag, substitution_flag, hesitation_flag]
}
```

### Ownership & Boundary Rules

| MBSV Dimension | Owned By | Consumer | Forbidden From |
| :--- | :--- | :--- | :--- |
| `visual_strain_index` | C1 | C2 | C3, C4 must not read this directly |
| `engagement_index` | C1 | C2 | C3, C4 must not read this directly |
| `cognitive_load_index` | C1 | C3 | C2, C4 must not read this directly |
| `session_fatigue_index` | C1 | C3 | C2, C4 must not read this directly |
| `phonological_strain_index` | C1 | C4 | C2, C3 must not read this directly |
| `error_pattern_vector` | C1 | C4 | C2, C3 must not read this directly |

---

## Component 1 — Cognitive Behavioral Monitoring Engine (CBME)
**Owner: IT22125798 (Gunasena) · Port: 8001**

### Research Question
> How can multi-task gradient-boosted inference on multimodal tablet behavioral signals produce a
> calibrated multi-dimensional behavioral profile that serves as a reliable proximate indicator of
> reading difficulty in Sinhala dyslexia screening — without requiring labeled clinical data or
> speech recognition?

### Theoretical Grounding

| Framework | Application |
| :--- | :--- |
| Sweller's Cognitive Load Theory (1988) | Justifies decomposing total load into visual, phonological, and fatigue dimensions |
| Welford's Incremental Statistics (1962) | Online personalized baseline (mean ± SD) without storing full history |
| Rayner's Eye-Movement Research (2001) | Benchmarks hesitation duration proxies (>400 ms = decoding difficulty) |
| Wolf & Bowers Double-Deficit Hypothesis (1999) | Motivates separate phonological and naming-speed signal dimensions |
| Wickens Multiple Resource Theory (1984) | Supports multi-channel monitoring (visual vs. phonological channel) |
| Fuchs et al. Oral Reading Fluency (2001) | Validates pause duration and articulation rate as fluency difficulty indicators |

### Input Features (12 total)

| Feature | Source | Research Basis |
| :--- | :--- | :--- |
| `hesitation_ms` | Flutter GestureDetector | Rayner (2001): >2000 ms = decoding difficulty |
| `correction_rate` | Flutter interaction log | Phonological awareness proxy |
| `response_latency` | Task start → completion | Wolf & Bowers (1999): slow naming speed |
| `touch_pressure` | Flutter GestureDetector | High pressure = frustration marker |
| `swipe_velocity` | Flutter GestureDetector | Low velocity = processing slowdown |
| `replay_count` | Audio replay button events | Phonological difficulty indicator |
| `hint_request_count` | Hint button events | Metacognitive load |
| `stylus_deviation` | RMS error vs. template | Fine-motor + visual-spatial difficulty |
| `inter_tap_interval` | Syllable-tapping variance | Phonological rhythm disruption (Goswami 2011) |
| `read_aloud_pause_ms` | On-device audio energy (no ASR) | Inter-word pause >400 ms (Fuchs et al. 2001) |
| `syllable_rate` | Audio energy envelope peaks | Slow articulation = naming-speed deficit |
| `disfluency_count` | Energy re-triggers per word | Phonological effort marker |

### Core Models

| Model | Role | Notes |
| :--- | :--- | :--- |
| **LightGBM (×6 instances)** | One model per MBSV dimension; multi-task training | Platt scaling for calibrated probability output |
| **Welford Online Algorithm** | Personalized Z-score baseline per student | No stored history required; numerical stability |
| **Kalman Filter (touch kinematics)** | Motor-control uncertainty signal as cognitive load proxy | Innovation norm → `kalman_innovation` feature |
| **Rule-based flags** | `error_pattern_vector` production | Pattern-matches correction_rate + disfluency_count |

### MBSV Dimension ← Feature Mapping

```
visual_strain_index       ← f(swipe_velocity, stylus_deviation, hesitation_ms, kalman_innovation)
cognitive_load_index      ← f(hesitation_ms, response_latency, correction_rate, disfluency_count)
phonological_strain_index ← f(replay_count, inter_tap_interval, read_aloud_pause_ms, syllable_rate)
engagement_index          ← f(hint_request_count, correction_rate, touch_pressure) [inverted]
session_fatigue_index     ← f(response_latency, hesitation_ms, syllable_rate) over session window
error_pattern_vector      ← rule-based flags from correction_rate + disfluency_count patterns
```

### Detailed I/O Contract

| Direction | Field | Type | Description |
| :--- | :--- | :--- | :--- |
| **Input from Flutter** | `student_id` | string | Unique learner identifier |
| | `touch_events` | `[{x, y, pressure, timestamp}]` | Raw touch stream |
| | `event_type` | enum | `TAP`, `SWIPE`, `DRAG`, `HESITATION` |
| | `session_latency` | int (ms) | Time since task was presented |
| | `replay_count` | int | Audio replay presses this task |
| | `hint_request_count` | int | Hint presses this task |
| | `audio_buffer` | bytes (optional) | 16kHz mono for acoustic features |
| **Output to System** | `mbsv` | object | Full MBSV (6 dimensions) |
| | `mbsv.visual_strain_index` | float [0–1] | → C2 only |
| | `mbsv.cognitive_load_index` | float [0–1] | → C3 only |
| | `mbsv.phonological_strain_index` | float [0–1] | → C4 only |
| | `mbsv.engagement_index` | float [0–1] | → C2 only |
| | `mbsv.session_fatigue_index` | float [0–1] | → C3 only |
| | `mbsv.error_pattern_vector` | int[4] | → C4 only |

### Dataset Strategy
- **Real-world Dataset Integration:** Utilizes `SPEAK-PP` (27k rows) and `Articulation Errors` (3k rows) to calibrate MBSV priors and validate error-type flags against authentic dyslexic linguistic patterns.
- **No labeled dyslexia data required for runtime:** Welford's baseline builds from each child's first 3–5 sessions.
- LightGBM priors calibrated from published benchmarks (Rayner 2001; Wolf & Bowers 1999; Fuchs et al. 2001) and fine-tuned using the `SPEAK-PP` error distribution.
- Acoustic benchmarks: typical Grade 1 inter-word pause <300 ms; struggling >600 ms (validated via `Articulation Errors` audio markers).
- Pilot: 10–15 children, teacher/guardian 5-point struggle rating per task = ground truth for SHAP evaluation.

---

## Component 2 — Adaptive Visual Learning Interface (AVLI)
**Owner: IT22642882 (Dinithi Perera) · Port: 8004**

> **Note:** C2 subsumes the former Visual Service (port 8004) and takes full ownership of the
> gamification controller. Gamification is a UI-state machine, not an educational intervention.

### Research Question
> Can a LinUCB contextual bandit learn, from within-session reading performance, which combination
> of abugida-specific typographic parameters reduces visual strain most effectively for individual
> Sinhala/Tamil dyslexic learners — outperforming static WCAG 2.1 accessibility presets?

### Theoretical Grounding

| Framework | Application |
| :--- | :--- |
| Wilkins Visual Stress Theory (1994) | Real-time visual parameter adjustment based on strain signals |
| Zorzi et al. (2012) Extra-Large Spacing | Empirical basis for letter spacing as highest-impact parameter |
| Cognitive Load Theory — Extraneous Load (Sweller 1988) | Typographic clutter = extraneous cognitive load |
| Self-Determination Theory (Ryan & Deci 2000) | Gamification design (autonomy + competence) |
| LinUCB Contextual Bandit (Li et al. 2010) | Per-learner exploration-exploitation for typography |
| Visual Crowding Effect (Whitney & Levi 2011) | Per-character complexity scores as context feature |

### MBSV Dimensions Consumed
- `visual_strain_index` → typography adaptation trigger
- `engagement_index` → gamification mode trigger

### Action Space (What C2 Controls)

| Parameter | Range | Note |
| :--- | :--- | :--- |
| `font_size` | 18–28 px | Standard |
| `letter_spacing` | 0–8 px | Standard |
| `word_spacing` | 4–20 px | Standard |
| `line_height` | 1.4–2.2 em | Standard |
| `background_contrast` | WCAG AA → AAA | Standard |
| `diacritic_offset` | −4 to +4 px vertical | **Sinhala/Tamil — novel** |
| `glyph_padding` | 0–6 px horizontal | **Sinhala/Tamil — novel** |
| `game_difficulty` | 1–5 | Gamification arm |

The `diacritic_offset` and `glyph_padding` parameters are the primary research novelty: Sinhala/Tamil
vowel signs attach above/below base consonants. When overall spacing increases, vowel signs can
visually disconnect. These parameters compensate, maintaining phonological unit integrity.

### Sinhala Orthographic Visual Complexity Model (SOVCM)
A novel context feature for LinUCB computed analytically from Unicode glyph specifications.
Provides per-character complexity scores (stroke count, enclosed regions, vertical/horizontal
asymmetry, pilla density) that allow the bandit to learn *character-specific* visual adaptations.

### LinUCB Context Vector
```
[visual_strain_index, engagement_index, session_number, child_age_normalized,
 task_complexity_score (SOVCM), crowding_load, phonological_strain_index]
```

### Gamification Controller
C2 owns gamification as a UI-state machine. When `engagement_index < 0.3` for two consecutive
30-second windows:
- Reading task fades; animated mini-game loads (letter puzzle, matching game, syllable clapping)
- After 2–3 minutes or completion, returns to reading task
- **C3 is notified** to select a slightly easier content item for re-entry

> **Boundary rationale:** Gamification here is a visual engagement mode-switch (C2's domain).
> C4 intervenes when a child struggles with a *specific word*. These are distinct phenomena.

### Detailed I/O Contract

| Direction | Field | Type | Description |
| :--- | :--- | :--- | :--- |
| **Input from C1** | `mbsv.visual_strain_index` | float | Typography trigger |
| | `mbsv.engagement_index` | float | Gamification trigger |
| **Input from Flutter** | `student_id` | string | For per-student arm history |
| | `session_number` | int | Exploration decay |
| | `current_content_text` | string | For SOVCM complexity computation |
| **Output to Flutter** | `typography_config` | object | Full UI parameter set |
| | `typography_config.font_size` | float | |
| | `typography_config.letter_spacing` | float | |
| | `typography_config.diacritic_offset` | float | Abugida-specific |
| | `typography_config.glyph_padding` | float | Abugida-specific |
| | `game_mode_trigger` | bool | True → engage gamification overlay |
| | `game_difficulty` | int (1–5) | Active only when `game_mode_trigger = true` |

### Dataset Strategy
- **Real-world Context Features:** SOVCM complexity scores are validated against the `SiTSE` text readability dataset (1,000 Sinhala sentences) to ensure typography adjustments match linguistic complexity.
- LinUCB requires **no pre-training dataset** — it learns online from session 1.
- Arms initialized from WCAG 2.1 AA/AAA presets + Zorzi et al. (2012) spacing prior.
- Every session generates reward data: `reward = (prev_visual_strain − curr_visual_strain) + 0.3 × accuracy_delta`.

---

## Component 3 — Personalized Learning Content Engine (PLCE)
**Owner: IT22154880 (Ekanayake) · Port: 8002**

> **Note:** C3 is the sole owner of BKT mastery modeling. C4 receives the mastery vector as an
> input via API — it does not compute or modify it. This resolves the BKT ownership clash.

### Research Question
> How accurately can Bayesian Knowledge Tracing parameterized on Sinhala NIE phonological skill
> sequences predict skill mastery and recommend appropriate next content — compared to a static
> curriculum progression baseline — for Grade 1–2 learners with no historical labeled data?

### Theoretical Grounding

| Framework | Application |
| :--- | :--- |
| Bayesian Knowledge Tracing (Corbett & Anderson 1994) | Core mastery estimation model |
| Item Response Theory — 2PL (Birnbaum 1968) | Content difficulty calibration (discrimination + difficulty) |
| Zone of Proximal Development (Vygotsky 1978) | Content recommended within mastery ± 0.15 window |
| Ebbinghaus Forgetting Curve (1885) | Retention decay R = e^(−t/S) for review scheduling |
| VARK Model (Fleming 1987) | Learner type from guardian-answered proxy questionnaire |

### MBSV Dimensions Consumed
- `cognitive_load_index` → difficulty modulation of next content item
- `session_fatigue_index` → pacing override (fatigue > 0.7 → consolidate, not advance)

### Sinhala Phonological Skill Graph (NIE-Derived)

```
Level 0: S0 — Akshara shape recognition
Level 1: S1 — Vowel identification · S2 — Basic consonant recognition
Level 2: S3 — CV syllable formation · S4 — Syllable counting
Level 3: S5 — 2-syllable word reading · S6 — 3-syllable word reading · S7 — Word-picture match
Level 4: S8 — Simple sentence reading · S9 — Sentence comprehension

Prerequisites:
  S0 → S1, S0 → S2
  S1 + S2 → S3
  S3 → S4
  S4 → S5
  S5 → S6, S5 → S7
  S6 + S7 → S8
  S8 → S9
```

### Core Models

| Model | Role | Notes |
| :--- | :--- | :--- |
| **BKT (Hidden Markov Model)** | Per-skill mastery estimation | 4 params: P_init, P_learn, P_slip, P_guess |
| **IRT 2PL** | Content item difficulty calibration | b parameter from teacher 1–5 ratings |
| **Ebbinghaus decay** | Mastery de-rating over time | Triggers spaced review |
| **VARK-proxy classifier** | Initial learner type tag | From guardian onboarding questionnaire |

### BKT Mastery Thresholds
- **Mastery achieved:** `p_know > 0.80` → advance to next skill
- **ZPD window (active target):** `0.45 ≤ p_know ≤ 0.80`
- **Fatigue override:** If `session_fatigue_index > 0.7` → select skill with `0.60 ≤ p_know ≤ 0.85` for fluency consolidation
- **Difficulty modulation:** `difficulty_target = 0.5 − (cognitive_load_index × 0.3)`

### Detailed I/O Contract

| Direction | Field | Type | Description |
| :--- | :--- | :--- | :--- |
| **Input from Flutter** | `student_id` | string | |
| | `skill_id` | string | e.g., `S3_syllable_formation` |
| | `is_correct` | bool | Task response |
| | `response_latency_ms` | int | Speed of response |
| **Input from C1** | `mbsv.cognitive_load_index` | float | Difficulty modulation |
| | `mbsv.session_fatigue_index` | float | Pacing override |
| **Output to Flutter** | `next_content_item` | object | Selected content |
| | `next_content_item.skill_id` | string | Target skill |
| | `next_content_item.irt_difficulty` | float | Item difficulty parameter |
| | `next_content_item.modality` | enum | `VISUAL`, `AUDITORY`, `KINESTHETIC` |
| **Output to C4** | `mastery_vector` | `{skill_id: p_know}` | All 9 skill mastery scores |

### Dataset Strategy
- **BKT priors:** ASSISTments 2009–2010 skill-builder dataset (public) → P_learn, P_slip, P_guess starting values; applied to Sinhala skill nodes by analogy.
- **Content repository:** ~135 items manually created (10–15 items × 9 skill nodes). Sinhala text + image + gTTS audio. Source: NIE Grade 1–2 curriculum.
- **IRT calibration:** 2 Sinhala teachers rate each item 1–5 → mapped to b parameter.

---

## Component 4 — Intelligent Intervention & Guidance Engine (IIGE)
**Owner: IT22267740 (Olivea) · Port: 8003**

> **Note:** C4 does not compute BKT mastery (that is C3's responsibility). C4 receives the mastery
> vector from C3 as a formal API input. C4 also does not own gamification — that is C2's domain.
> C4's sole responsibility is: *delivering the right phonological activity at the right time.*

### Research Question
> Does a personalized SM-2 spaced repetition scheduler combined with error-type-specific
> multi-activity intervention outperform a uniform review schedule in sustaining Sinhala
> phonological skill retention across sessions in Grade 1–2 learners with dyslexia-like
> difficulties?

### Theoretical Grounding

| Framework | Application |
| :--- | :--- |
| Ebbinghaus Forgetting Curve (1885) | SM-2 review scheduling: R = e^(−t/S) |
| Goswami Neural Oscillation Theory (2011) | Rhythmic interventions address phonological timing deficits |
| RTI 3-Tier Model (Fuchs & Fuchs 2006) | Tier 1 (inline hint) → Tier 2 (activity) → Tier 3 (guardian alert) |
| Bhide et al. (2013) Musical Phonological Training | Template song as evidence-based intervention |
| SM-2 Algorithm (Wozniak 1987) | Spaced repetition scheduling for long-term retention |

### MBSV Dimensions Consumed
- `phonological_strain_index` → intervention trigger threshold
- `error_pattern_vector` → error type classification input

### Additional Inputs
- `mastery_vector` → **from C3 API** (not recomputed by C4)
- `current_word` → from Flutter reading state
- `session_history` → from local DB (for SM-2 scheduling)

### Two-Stage Intervention Pipeline

```
Stage 0 (Passive):
  phonological_strain_index < 0.45              → no action

Stage 1 (Inline, 0-disruption):
  phonological_strain_index ≥ 0.45 for >5s     → word splits into syllables on screen
                                                   audio plays syllable by syllable (gTTS)
  child succeeds                                → log "Supported Success"; return to reading
  child still struggles after 10s              → Stage 2

Stage 2 (Activity overlay):
  classify error type (Phoneme Error Analyser)
  select activity from Activity Selection Matrix (error_type × mastery_level)
  activity runs in overlay (reading text dimmed)
  on completion: return to reading; update SM-2 schedule

Stage 3 (Escalation):
  same word fails 3+ times across sessions     → RTI Tier 3 alert → guardian dashboard
```

### Activity Selection Matrix

| Error Type | Mastery < 0.4 | Mastery 0.4–0.7 | Mastery > 0.7 |
| :--- | :--- | :--- | :--- |
| LONG_WORD | Tapping Game (slow tempo) | Tapping Game (normal tempo) | Syllable reading practice |
| VOWEL_CONFUSION | Finger Tracing | Template Song | Quick match drill |
| CONSONANT_CONFUSION | Picture-Word Match (easy) | Picture-Word Match (hard) | Minimal pair exercise |
| UNFAMILIAR | Audio + image presentation | Context sentence reading | Spaced repetition review |

### Sinhala Unicode Syllable Splitter
Rule-based splitter using Sinhala Unicode block (U+0D80–U+0DFF). Handles conjunct consonants
(C + AL_LAKUNA + C = no boundary inside). Target: ≥95% F1 on 200-word NIE validation set.

### Phoneme Error Analyser
Rule-based classifier using Unicode structure + `error_pattern_vector`. Output: one of
`LONG_WORD | VOWEL_CONFUSION | CONSONANT_CONFUSION | UNFAMILIAR`.

### SM-2 Spaced Repetition Scheduler
Applied per child, **per skill node** (not per word — too granular for 6-year-olds). Quality
score (0–5) mapped from activity accuracy percentage. SM-2 review words surfaced as 2-minute
warm-up at session start and listed on guardian dashboard.

### Detailed I/O Contract

| Direction | Field | Type | Description |
| :--- | :--- | :--- | :--- |
| **Input from C1** | `mbsv.phonological_strain_index` | float | Trigger threshold |
| | `mbsv.error_pattern_vector` | int[4] | Error type flags |
| **Input from C3** | `mastery_vector` | `{skill_id: p_know}` | Activity difficulty calibration |
| **Input from Flutter** | `student_id` | string | |
| | `current_word` | string | For syllable splitter + error analyser |
| **Output to Flutter** | `stage` | int (1–3) | Active intervention stage |
| | `syllable_segments` | `[string]` | Stage 1 output |
| | `activity_type` | enum | Stage 2 activity to launch |
| | `activity_difficulty` | int (1–5) | Calibrated by mastery_vector |
| | `sm2_review_words` | `[string]` | Words scheduled for today |
| **Output to Guardian Dashboard** | `tier3_alert` | object | RTI Tier 3 details |
| | `tier3_alert.word` | string | Consistently failing word |
| | `tier3_alert.suggested_activity` | string | Home practice suggestion |

### Dataset Strategy
- **Real-world Classifier Training:** The Phoneme Error Analyser is trained on the `SPEAK-PP` dataset (27,636 labeled error pairs) and the `Articulation Errors` dataset (3,000 pairs), achieving high fidelity in classifying Sinhala-specific dyslexic substitutions and omissions.
- **Word difficulty dataset:** 200–300 NIE curriculum words. Linguistic features auto-extracted via Unicode (syllable count, vowel sign count, consonant cluster length).
- **Random Forest (Model 1):** Trained on annotated word dataset + `SPEAK-PP` samples. 80/20 split, 5-fold CV, target F1 ≥ 0.85.
- **Decision Tree (Model 2):** Bootstrapped with rule-based fallback until N ≥ 50 intervention events logged from pilot.
- **SM-2 validation:** Within-session design — SM-2-scheduled words vs. unscheduled words in same child (no parallel control group required).

---

## Complete Session Data Flow

### Onboarding (Session 0 — with guardian)

```
1. Language Selection: Sinhala / Tamil
2. Child Profile: name, age, grade, school type, guardian contact
3. VARK Proxy Questionnaire (5 questions, guardian-answered) → learner tag (V/A/K) → C3
4. Baseline Calibration (10–12 min, 4 tasks):
     Task A: Symbol recognition (12 aksharas — tap correct shape)
     Task B: Syllable clapping (audio plays; child taps to syllable beats)
     Task C: Picture-word matching (3 options per word)
     Task D: Simple sentence listening (true/false)
   C1 collects behavioral signals → Welford's baseline initializes
5. Screening Report:
     MBSV baseline established
     At-risk flag: at_risk | monitoring | typically_developing
     C3 initializes BKT: all skills at p_know = 0.3
     Forwarded to guardian dashboard
```

### Learning Sessions (Sessions 1+)

```
Start → C4: SM-2 warm-up (2 min, if any due today)
      → C3: select first content item (ZPD-targeted, VARK-modality adjusted)
      → C2: apply current typography config

During task (every 5s):
  → C1: compute MBSV snapshot → publish to all consumers
  → C2: if visual_strain_index > 0.6 for 10s → LinUCB step → new typography config
        if engagement_index < 0.3 for 30s → trigger gamification mode → notify C3
  → C4: if phonological_strain_index > 0.45 for 5s → Stage 1 intervention
        if still ≥ 0.45 after 10s → Stage 2 activity

Task complete:
  → C3: BKT update for target skill; select next content
  → C4: SM-2 schedule update for Stage 2 words
  → C2: log reward for LinUCB update

Session end (20–25 min):
  → C3: session summary (skills, mastery delta)
  → C1: MBSV trend (increasing strain = fatigue flag for next session)
  → Guardian dashboard updated; RTI Tier 3 alerts pushed if any
```

---

## Technology Stack Reference

| Layer | Technology | Notes |
| :--- | :--- | :--- |
| Frontend | Flutter (Desktop + Mobile + Web) | Screening tasks, reading UI, activity overlays, guardian dashboard |
| C1 Backend | Python / FastAPI (port 8001) | Feature extraction, Welford's, LightGBM × 6, Kalman Filter |
| C2 Backend | Python / FastAPI (port 8004) | LinUCB, SOVCM, gamification state machine |
| C3 Backend | Python / FastAPI (port 8002) | BKT engine, content recommendation, Ebbinghaus decay |
| C4 Backend | Python / FastAPI (port 8003) | Syllable splitter, error classifier, SM-2, activity selection |
| Database | MongoDB Atlas | Async via `motor`; shared cluster for cross-service analytics |
| Persistence | Asynchronous | All DB I/O is non-blocking to ensure real-time UI responsiveness |
| Cloud Stack | Cloud-Native | Fully integrated with MongoDB Atlas for remote guardian monitoring |
| Audio | `flutter_sound` / `record` package | On-device energy extraction; no ASR |
| TTS | gTTS / flutter_tts | Syllable-by-syllable audio for Stage 1 |

---

*Document version 2.0 — revised per R26-SE-031 Optimization Plan (2026-05-12).*
*Previous version (v1.0) described the single RSI scalar architecture.*
