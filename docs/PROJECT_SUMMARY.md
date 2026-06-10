# R26-SE-031 — Consolidated Project Summary

> Single consolidated reference for the R26-SE-031 microservice system.
> Merges and supersedes: `SERVICE_GUIDE.md`, `TRAINING_METHODOLOGY.md`, and the
> Service directories use the `-v1` naming. Backend & ML only — UI clients
> (Flutter app, educator dashboard) live outside this repository and consume the REST APIs.

---

## 1. What This System Is

A research platform (RP-IT4010) for **screening and intervention of dyslexia in
Sinhala-speaking children (ages 7–12)**. A Flutter client app delivers
game-based reading/writing tasks; four Python (FastAPI) microservices process the
behavioral telemetry, adapt the UI, personalize content, and trigger interventions.
All services share MongoDB Atlas (configured via `.env` → `MONGO_URI`) and
communicate over REST.

The central data structure is the **MBSV (Multi-Dimensional Behavioral Signal
Vector)** — six indices in [0, 1] computed from raw telemetry:

| Dimension | Meaning | Grounding |
|---|---|---|
| CLI — Cognitive Load Index | Hesitation, corrections, replay, motor precision | Sweller's Cognitive Load Theory (1988) |
| PSI — Phonological Strain Index | Syllable omissions, disfluency, pauses | Abugida-specific phonological demands |
| VSI — Visual Strain Index | Erratic/slow stylus and swipe behavior | Crowding in Sinhala diacritics/conjuncts |
| FI — Session Fatigue Index | Hesitation growth over the session | Temporal fatigue signatures |
| ES — Engagement Index | Inverse of hint requests + corrections | Intrinsic-motivation behavioral measures |
| ERI — Error Resilience Index | Self-correction rate | Metacognitive self-correction skill |

---

## 2. The Four Microservices

| Code | Service | Directory | Port | Role |
|---|---|---|---|---|
| C1 | Monitoring (CBME) | `monitoring-service-v1/` | 8011 | Telemetry → MBSV. Kalman filter (motor precision / innovation), Welford online baselines per student, Whisper-based acoustic extraction, LightGBM MBSV regressor. |
| C3 | Content (PLCE) | `content-service-v1/` | 8012 | Personalized learning content engine. Bayesian Knowledge Tracing (BKT) mastery model, content selector, guardian-intake onboarding (Advanced Assessments DST, 14 questions → at-risk flag) and Observation-Matrix BKT seeding (Lokubalasuriya et al. 2019). |
| C4 | Intervention (IIGE) | `intervention-service-v1/` | 8013 | Intelligent guidance + phonological intervention. Intervention engine, SM-2 spaced-repetition scheduler, stroke scorer, Sinhala syllable splitter. |
| C2 | Visual (AVLI) | `visual-service-v1/` | 8014 | Typography/UI adaptation. LinUCB contextual bandit over typography arm presets (`data/arm_presets.json`), SOVCM task-complexity scoring. |

Shared Pydantic v2 schemas for all inter-service messages live in `shared/schemas.py`.

---

## 3. How to Run

### Setup
```bash
# Python 3.10+
pip install -r monitoring-service-v1/requirements.txt
pip install -r visual-service-v1/requirements.txt
pip install -r content-service-v1/requirements.txt
pip install -r intervention-service-v1/requirements.txt
pip install python-dotenv motor httpx fastapi uvicorn
```
Create `.env` in this directory with `MONGO_URI` (MongoDB Atlas) and the service ports.

### Train models first (required on first run or dataset change)
```bash
cd scripts
python run_all_training.py        # generates .pkl files in models/ (C1 LightGBM/RF, C2 LinUCB)
```

### Start everything
```bash
python run_all_services.py        # all four services as subprocesses; logs in ./logs/; Ctrl+C stops all
```
Or run one service for debugging: `cd monitoring-service-v1 && python main.py` (same pattern for each).

### Verify
```bash
# Health checks
Invoke-RestMethod http://localhost:8011/health   # repeat for 8012, 8013, 8014

python tests/test_smoke.py         # core-logic tests (Welford, BKT, SM-2, LinUCB) — no DB needed
python tests/test_integration.py   # model loading + pipeline + schema tests — offline
python tests/test_api_e2e.py       # live HTTP endpoint tests — services must be running
```

Example telemetry call:
```bash
curl -X POST http://localhost:8011/api/v1/telemetry \
     -H "Content-Type: application/json" \
     -d '{"student_id":"test_user","session_id":"sess_001","hesitation_ms":3000,"correction_rate":0.5}'
```

---

## 4. ML Training Methodology (C1 MBSV Model)

**Model**: LightGBM `MultiOutputRegressor` — 13 behavioral features → 6 MBSV dimensions.
**Training entry point**: `scripts/train_c1_lgbm_real_data.py` (add `--synthetic-only`
for a quick 500-sample synthetic run). Output: `models/c1_lgbm_mbsv.pkl` +
`models/c1_lgbm_feature_importance.csv`.

### Three-tier real-data strategy

1. **Tier 1 — Real dyslexia data (primary)**: SPEAK-PP
   `sinhala-dyslexia-corrected-id20percent` (HuggingFace, ~500 MB). Real telemetry
   and SLP-validated error-pattern labels (reversal / omission / substitution /
   hesitation) from Sinhala children with documented dyslexia. Foundation for MBSV
   target inference.
2. **Tier 2 — Acoustic validation (secondary)**: `SL-Augmented/peshalaperera-articulation-errors`
   (HuggingFace). Ground-truth audio with expert-labeled articulation errors.
   Validates `disfluency_count`, `read_aloud_pause_ms`, `syllable_rate` via energy-envelope
   processing (no ASR). Expected Pearson r: disfluency↔omission ≈ 0.72,
   pause↔phonological load ≈ 0.68, syllable rate↔cognitive load ≈ 0.75. If r < 0.55,
   tune energy thresholding or add pitch-aware processing for Sinhala tonality.
3. **Tier 3 — Synthetic MBSV labels (fallback)**: no labeled Sinhala MBSV dataset
   exists, so the six targets are inferred from Tier-1 error patterns with
   research-grounded weighted formulas (e.g. CLI = 0.35·hesitation + 0.25·correction +
   0.2·replay + 0.2·kalman_innovation; full formulas in `TRAINING_METHODOLOGY.md` §Tier 3).

### Expected performance (held-out 20% test set)

| Target | R² | Strength |
|---|---|---|
| ES | 0.75–0.85 | Strong — hint requests highly predictive |
| FI | 0.72–0.82 | Strong — reliable temporal signature |
| VSI | 0.70–0.80 | Strong — tracks stylus deviation |
| CLI | 0.65–0.75 | Moderate |
| ERI | 0.68–0.78 | Moderate |
| PSI | 0.58–0.68 | Moderate — needs Tier-2 acoustic validation |

Top expected features: `hesitation_ms`, `disfluency_count`, `correction_rate`,
`kalman_innovation`, `replay_count`.

### Clinical validation plan
- Map MBSV to the 4-level **Lokubalasuriya Observation Matrix** (Missing <0.25,
  Unsatisfactory <0.50, Emerging <0.75, Proficient ≥0.75).
- Pilot with 10–15 children: Spearman ρ vs. expert SLP ratings (targets: CLI ≥ 0.65,
  PSI ≥ 0.60, VSI ≥ 0.70) plus Cohen's d effect sizes — reported in thesis §5.2.

---

## 5. Repository Layout

```
R26-SE-031/  (repository root)
├── docs/                     # All project docs (this file, SERVICE_GUIDE, TRAINING_METHODOLOGY,
│                             #  academic material, architecture notes, SHAP visuals)
├── monitoring-service-v1/    # C1 — Kalman, Welford, Whisper extractor
├── visual-service-v1/        # C2 — LinUCB, SOVCM, arm presets
├── content-service-v1/       # C3 — BKT, onboarding, content selector
├── intervention-service-v1/  # C4 — intervention engine, SM-2, stroke scorer, syllable splitter
├── shared/                   # Canonical Pydantic v2 schemas
├── scripts/                  # Training + calibration pipeline (run_all_training.py, etc.)
├── models/                   # Trained .pkl artifacts
├── datasets/                 # Cached/extracted feature data
├── audit/                    # Viva audit notebooks (C1/C2/C3 + MBSV scientific validation)
├── logs/                     # Service runtime logs
├── tests/                    # test_smoke.py, test_integration.py, test_api_e2e.py
├── run_all_services.py       # Master runner
└── README.md
```

### Key references
Sweller 1988 (Cognitive Load Theory) · Lokubalasuriya et al. 2019 (Sinhala
screening protocol) · Ke et al. 2017 (LightGBM) · Lundberg & Lee 2017 (SHAP) ·
Weerasooriya & Desilva 2021 (Sinhala TTS).

---

*Last consolidated: June 2026 — R26-SE-031 Research Team*
