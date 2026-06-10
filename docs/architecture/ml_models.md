# Machine Learning Architecture
## Adaptive Sinhala Dyslexia Screening & Guidance Platform — R26-SE-031

> **Revised (v2.0).** Model ownership has been restructured so that every ML model lives in
> exactly one component. BKT now exclusively belongs to C3. Gamification control belongs to C2.
> The ε-Greedy Bandit has been replaced by **LinUCB** (contextual, superior for per-learner
> adaptation). The single RSI scalar has been replaced by the **6-dimension MBSV**.

---

## Master Model Registry

| Component | Service | Model | Type | Primary Research Metric |
| :--- | :--- | :--- | :--- | :--- |
| **C1 — CBME** | Monitoring (8001) | **LightGBM × 6** | Gradient-Boosted Trees (multi-task) | Cohen's d between easy/hard MBSV distributions |
| **C1 — CBME** | Monitoring (8001) | **Welford Online Algorithm** | Incremental variance estimator | Convergence stability (1–5 sessions) |
| **C1 — CBME** | Monitoring (8001) | **Kalman Filter (touch)** | Linear dynamical system | Innovation norm correlation with hesitation_ms |
| **C1 — CBME** | Monitoring (8001) | **Isolation Forest** *(100%)* | Unsupervised anomaly detector | Precision/Recall for session-handoff outliers |
| **C2 — AVLI** | Visual (8004) | **LinUCB Contextual Bandit** | Online contextual RL | Cumulative reward: LinUCB vs. WCAG 2.1 static baseline |
| **C3 — PLCE** | Content (8002) | **BKT (Hidden Markov Model)** | Probabilistic mastery model | Mastery curve slope vs. fixed NIE curriculum baseline |
| **C3 — PLCE** | Content (8002) | **IRT 2PL** | Item difficulty calibration | Inter-rater reliability (Krippendorff's α) for b parameter |
| **C3 — PLCE** | Content (8002) | **Ebbinghaus Decay** | Mathematical retention model | AUC on ASSISTments validation set |
| **C4 — IIGE** | Intervention (8003) | **Sinhala Unicode Syllable Splitter** | Rule-based NLP | F1 on 200-word NIE validation set (target ≥ 0.95) |
| **C4 — IIGE** | Intervention (8003) | **Random Forest (word difficulty)** | Supervised classifier | F1 ≥ 0.75 across 4 error-type classes (5-fold CV) |
| **C4 — IIGE** | Intervention (8003) | **Decision Tree** *(100% / pilot data)* | Supervised classifier | Accuracy vs. rule-based fallback |
| **C4 — IIGE** | Intervention (8003) | **SM-2 Scheduler** | Spaced repetition algorithm | 4-week word retention (SM-2 vs. no-review baseline) |

---

## Component 1 (C1 — CBME) Model Details

### Model 1A: LightGBM Multi-Task Inference (×6)
**File:** `monitoring-service/ml/lgbm_visual_strain.pkl` *(+ 5 additional, one per dimension)*

| Item | Detail |
| :--- | :--- |
| **Architecture** | 6 independent LightGBM regressors; same 12 input features, different training targets |
| **Output calibration** | Platt scaling → calibrated probability [0–1] per dimension |
| **Training data** | N=500 synthetic sessions with research-calibrated distributions |
| **Pilot validation** | Ground truth from teacher 5-point struggle rating per task |

**Input features (12):**
`hesitation_ms`, `correction_rate`, `response_latency`, `touch_pressure`, `swipe_velocity`,
`replay_count`, `hint_request_count`, `stylus_deviation`, `inter_tap_interval`,
`read_aloud_pause_ms`, `syllable_rate`, `disfluency_count`

**Output → MBSV mapping:**

| MBSV Dimension | Primary Features |
| :--- | :--- |
| `visual_strain_index` | `swipe_velocity`, `stylus_deviation`, `hesitation_ms`, `kalman_innovation` |
| `cognitive_load_index` | `hesitation_ms`, `response_latency`, `correction_rate`, `disfluency_count` |
| `phonological_strain_index` | `replay_count`, `inter_tap_interval`, `read_aloud_pause_ms`, `syllable_rate` |
| `engagement_index` | `hint_request_count`, `correction_rate`, `touch_pressure` *(inverted)* |
| `session_fatigue_index` | `response_latency`, `hesitation_ms`, `syllable_rate` *(rolling window)* |
| `error_pattern_vector` | Rule-based flags from `correction_rate` + `disfluency_count` patterns |

**SHAP Validation**: Top-3 features per dimension must be theoretically consistent with cited literature
(e.g., `replay_count` must rank top-3 for `phonological_strain_index` — Fuchs et al. 2001).

---

### Model 1B: Welford Online Algorithm (Personalized Baseline)
**File:** `monitoring-service/ml/welford_state.json` *(per-student)*

| Item | Detail |
| :--- | :--- |
| **Purpose** | Compute running mean + variance per student without storing full history |
| **Formula** | `z_score = (raw_value − personal_mean) / (personal_std + 1e-8)` |
| **Convergence** | Stable after 3–5 sessions (< 50 data points per feature) |
| **Storage** | `{student_id, feature_name, count, mean, M2}` per feature |
| **Citation** | Welford (1962), *Technometrics* |

This makes LightGBM models **child-agnostic**: the same model weights apply across all children
because all input features are Z-scored against the child's own baseline.

---

### Model 1C: Kalman Filter (Touch Kinematics)
**File:** `monitoring-service/core/kalman_touch.py`

| Item | Detail |
| :--- | :--- |
| **State vector** | `[x, y, x_velocity, y_velocity]` |
| **Observation** | `[x, y]` from Flutter GestureDetector (~60 Hz) |
| **Output** | Kalman **innovation norm** → fed as `kalman_innovation` into LightGBM feature set |
| **Theoretical basis** | High cognitive load degrades fine-motor precision → larger innovation (Sweller 1988) |

---

### Model 1D: Isolation Forest *(100% deliverable)*
**File:** `monitoring-service/ml/iso_forest_session.pkl`

| Item | Detail |
| :--- | :--- |
| **Purpose** | Detect session outliers (e.g., device handed to sibling mid-session) |
| **Training** | Unsupervised on normal session behavioral patterns |
| **Output** | Anomaly score; triggers session-invalidation flag in MBSV stream |

---

## Component 2 (C2 — AVLI) Model Details

### Model 2A: LinUCB Contextual Bandit
**File:** `visual-service/ml/linucb_typography.pkl`

| Item | Detail |
| :--- | :--- |
| **Algorithm** | LinUCB (Li et al. 2010) — linear upper confidence bound |
| **Arms** | 8 discretized typography parameter combinations |
| **Context vector** | `[visual_strain_index, engagement_index, session_number, child_age_norm, task_complexity (SOVCM), crowding_load, phonological_strain_index]` — 7 dimensions |
| **Exploration param** | `α = 0.1` |
| **Prior initialization** | WCAG 2.1 AA/AAA presets + Zorzi et al. (2012) spacing data |
| **Reward** | `(prev_visual_strain − curr_visual_strain) + 0.3 × reading_accuracy_delta` |

**Novel action space dimensions (Sinhala/Tamil specific):**

| Dimension | Range | Rationale |
| :--- | :--- | :--- |
| `diacritic_offset` | −4 to +4 px vertical | Compensates vowel sign detachment when spacing increases |
| `glyph_padding` | 0–6 px horizontal | Maintains phonological unit integrity for abugida scripts |

**Evaluation:** Cumulative reward: LinUCB learned policy vs. fixed WCAG 2.1 static baseline across all sessions.

---

### SOVCM: Sinhala Orthographic Visual Complexity Model
**File:** `visual-service/data/sovcm_table.json`

| Item | Detail |
| :--- | :--- |
| **Scope** | 54 base akshara + 18 common vowel sign forms (~72 entries) |
| **Properties** | `stroke_count`, `enclosed_regions`, `vertical_asymmetry`, `horizontal_asymmetry`, `pilla_density`, `composite_score` |
| **Production** | `composite_score = 0.3×stroke + 0.25×enclosed + 0.2×v_asym + 0.15×h_asym + 0.1×pilla_density` |
| **Validation** | Inter-rater agreement across 3 Sinhala-literate annotators (Krippendorff's α target > 0.75) |
| **Usage** | Provides `task_complexity_score` and `crowding_load` context features for LinUCB |

---

## Component 3 (C3 — PLCE) Model Details

### Model 3A: Bayesian Knowledge Tracing (BKT)
**File:** `content-service/ml/bkt_engine.py` *(per-student state in DB)*

| Item | Detail |
| :--- | :--- |
| **Type** | Hidden Markov Model — 4-parameter BKT |
| **Parameters** | `P_init=0.3`, `P_learn=0.1`, `P_slip=0.1`, `P_guess=0.2` (from ASSISTments priors) |
| **Skill nodes** | 9 (S0–S9, Sinhala phonological skill graph) |
| **Mastery threshold** | `p_know > 0.80` → advance skill |
| **ZPD window** | `0.45 ≤ p_know ≤ 0.80` → active learning zone |
| **Citation** | Corbett & Anderson (1994), *User Modeling and User-Adapted Interaction* |

**BKT Update Rule:**

```
P(know | correct) = P(know) × (1−P_slip) / [P(know) × (1−P_slip) + (1−P(know)) × P_guess]
P(know | wrong)  = P(know) × P_slip     / [P(know) × P_slip     + (1−P(know)) × (1−P_guess)]
P(know_next)     = P(know_posterior) + (1 − P(know_posterior)) × P_learn
```

**Validation:** AUC on ASSISTments 2009–2010 test set (validates implementation correctness);
mastery curve slope per child vs. fixed NIE curriculum order.

---

### Model 3B: IRT 2PL Item Difficulty Calibration
**File:** `content-service/data/content_repository.json` *(b parameter per item)*

| Item | Detail |
| :--- | :--- |
| **Purpose** | Assign difficulty parameter `b` to each of ~135 content items |
| **Method** | 2 Sinhala teachers rate each item 1–5; `b = (rating − 3) / 1.5` |
| **Use** | `difficulty_target = 0.5 − (cognitive_load_index × 0.3)`; select item minimizing `|item.b − difficulty_target|` |

---

### Model 3C: Ebbinghaus Forgetting Curve
**File:** `content-service/core/forgetting_curve.py`

| Item | Detail |
| :--- | :--- |
| **Formula** | `R = e^(−t/S)` where `t` = days since last practice, `S` = memory strength from mastery |
| **Effect** | Content not practiced for >7 days receives reduced effective mastery weight |
| **Interaction with BKT** | Applied as a multiplier to `p_know` before ZPD window check |

---

## Component 4 (C4 — IIGE) Model Details

### Model 4A: Sinhala Unicode Syllable Splitter
**File:** `intervention-service/core/syllable_splitter.py`

| Item | Detail |
| :--- | :--- |
| **Type** | Rule-based NLP using Sinhala Unicode block (U+0D80–U+0DFF) |
| **Rules** | Consonant + vowel sign = one syllable; conjunct (C + AL_LAKUNA + C) = no internal boundary |
| **Validation dataset** | 200-word NIE Grade 1–2 vocabulary, hand-annotated by Sinhala language reviewer |
| **Target metric** | F1 ≥ 0.95 on validation set |
| **Output** | `[syllable_1, syllable_2, ...]` for Stage 1 inline display |

---

### Model 4B: Random Forest — Word Difficulty / Error Type Classifier
**File:** `intervention-service/ml/word_error_rf.pkl`

| Item | Detail |
| :--- | :--- |
| **Type** | Random Forest (multi-class, 100 trees) |
| **Classes** | `LONG_WORD`, `VOWEL_CONFUSION`, `CONSONANT_CONFUSION`, `UNFAMILIAR` |
| **Training data** | 200–300 annotated NIE curriculum words; purely linguistic features (Unicode-derived) |
| **Features** | `syllable_count` (auto via splitter), `vowel_sign_count` (Unicode), `consonant_cluster_length` (Unicode), `word_frequency_rank` (corpus count) |
| **Split** | 80/20 train/test, 5-fold CV |
| **Target** | F1 ≥ 0.75 across all 4 classes |
| **No audio required** | All features computed from Unicode character analysis alone |

---

### Model 4C: Decision Tree — Intervention Outcome Predictor *(100% / pilot data)*
**File:** `intervention-service/ml/intervention_dt.pkl`

| Item | Detail |
| :--- | :--- |
| **Bootstrap** | Rule-based fallback for first 50 intervention events |
| **Training trigger** | Retrained when pilot logs N ≥ 50 intervention outcome events |
| **Features** | `error_type`, `mastery_level`, `phonological_strain_index`, `activity_used`, `outcome` |
| **Evaluation** | Accuracy vs. rule-based activity selection matrix |

---

### Model 4D: SM-2 Spaced Repetition Scheduler
**File:** `intervention-service/core/sm2_scheduler.py`

| Item | Detail |
| :--- | :--- |
| **Algorithm** | SM-2 (Wozniak 1987) |
| **Granularity** | Per child, per **skill node** (not per word — too granular for 6-year-olds) |
| **Quality mapping** | Activity accuracy 0–100% → quality 0–5 |
| **Interval formula** | `interval_n = interval_(n-1) × easiness_factor`; `EF ≥ 1.3` |
| **Output** | `interval` (days) → stored in `sm2_schedules` DB table |
| **Validation** | Within-session design: SM-2-scheduled words vs. unscheduled words (same child) |
| **Citation** | Wozniak & Gorzelanczyk (1994), *Acta Neurobiologiae Experimentalis* |

---

## Key Research Themes

### 1. No Labeled Sinhala Dyslexia Data Required
Each component avoids the need for a pre-labeled dyslexia corpus:
- C1 uses **synthetic benchmark validation** + Welford's personalized baseline
- C2 uses **online learning** from session 1
- C3 uses **ASSISTments priors** (transfer) + manual content creation from NIE curriculum
- C4 uses **Unicode rules** (no audio, no recordings) + pilot-bootstrapped Decision Tree

### 2. Explainability (XAI) — C1 Responsibility
SHAP feature importance computed per LightGBM model. Validates that the top-3 features per
MBSV dimension are consistent with the cited research literature. SHAP endpoint exposed at
`/api/v1/monitoring/shap/{student_id}`.

### 3. No ASR (Acoustic = Energy Only)
Acoustic features (`read_aloud_pause_ms`, `syllable_rate`, `disfluency_count`) are extracted
entirely from audio energy envelopes — no speech recognition, no transcription. This is more
scientifically defensible than ASR for child speech in low-resource languages and preserves
on-device privacy.

### 4. What NOT to Attempt
- ❌ Sinhala child speech ASR (Wav2Vec 2.0 etc. — unreliable for child speech in low-resource languages)
- ❌ Real-time eye tracking (use `hesitation_ms` + `replay_count` as validated proxies — Rayner 2001)
- ❌ New labeled clinical dyslexia data collection (use NIE curriculum + synthetic benchmarks)

---

## Individual Research Contribution Summary

| Student | Core ML Contribution | Primary Evaluation Metric |
| :--- | :--- | :--- |
| IT22125798 — C1 | Multi-output MBSV via multi-task LightGBM + Welford's + Kalman Filter | Cohen's d (easy vs. hard MBSV); SHAP top-3 feature consistency |
| IT22642882 — C2 | LinUCB contextual bandit for abugida-script typography + SOVCM | Cumulative reward: LinUCB policy vs. WCAG 2.1 static |
| IT22154880 — C3 | BKT on NIE Sinhala phonological skill graph + cognitive-load-modulated ZPD | Mastery curve slope vs. fixed NIE curriculum |
| IT22267740 — C4 | Sinhala Unicode syllable splitter + SM-2 spaced repetition for phonological intervention | 4-week retention (SM-2 vs. no-review); Stage 2 RSI reduction |

---

*Document version 2.0 — revised per R26-SE-031 Optimization Plan (2026-05-12).*
*Previous version (v1.0) is preserved in git history.*
