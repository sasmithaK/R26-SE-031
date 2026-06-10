# R26-SE-031 — Sinhala Dyslexia Screening & Intervention Platform (Backend & ML)

Research platform (RP-IT4010) for screening and intervention of dyslexia in
Sinhala-speaking children. Four FastAPI microservices process behavioral
telemetry from client tasks into the **MBSV** (Multi-Dimensional Behavioral
Signal Vector — six indices: cognitive load, phonological strain, visual
strain, fatigue, engagement, error resilience), drive UI adaptation policy,
personalize content, and trigger interventions. This repository contains the
backend services and ML pipeline; client applications consume the REST APIs.

## Architecture

| Component | Directory | Port | Core algorithms |
|---|---|---|---|
| C1 Monitoring (CBME) | `monitoring-service-v1/` | 8011 | Kalman filter, Welford baselines, Whisper acoustics, LightGBM MBSV regressor |
| C3 Content (PLCE) | `content-service-v1/` | 8012 | Bayesian Knowledge Tracing, content selector, guardian-intake onboarding |
| C4 Intervention (IIGE) | `intervention-service-v1/` | 8013 | Intervention engine, SM-2 scheduler, stroke scorer, Sinhala syllable splitter |
| C2 Visual (AVLI) | `visual-service-v1/` | 8014 | LinUCB contextual bandit, SOVCM visual-complexity model |

Shared Pydantic schemas and the async MongoDB layer live in `shared/`.
All tunables (BKT priors, LinUCB alpha, strain thresholds) are configured via `.env`.

## Setup

```bash
# Python 3.10+
pip install -r monitoring-service-v1/requirements.txt \
            -r visual-service-v1/requirements.txt \
            -r content-service-v1/requirements.txt \
            -r intervention-service-v1/requirements.txt
```

Create a `.env` in the repo root with `MONGO_URI`, `MONGO_DB_NAME`, and the
algorithm tunables (see `SERVICE_GUIDE.md`).

## Train models

Required on first run or after dataset changes — generates the `.pkl`
artifacts in `models/` (C1 LightGBM/RF, C2 LinUCB warm-start, C4 RF):

```bash
python scripts/run_all_training.py
```

## Run

```bash
python run_all_services.py     # all four services; logs in ./logs/; Ctrl+C stops all
```

Or one service at a time: `cd monitoring-service-v1 && python main.py`.

## Test

```bash
python tests/test_smoke.py        # 11 offline module checks (no DB, no services)
python tests/test_integration.py  # model loading + end-to-end pipeline (offline)
python tests/test_api_e2e.py      # live HTTP endpoint suite (services must be running)
```

Health check: `GET http://localhost:8011/health` (same for 8012–8014).

## Documentation

- **[PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)** — consolidated overview: architecture, MBSV, run/test guide, ML methodology
- [SERVICE_GUIDE.md](SERVICE_GUIDE.md) — detailed service execution & testing
- [TRAINING_METHODOLOGY.md](TRAINING_METHODOLOGY.md) — three-tier real-data training strategy (SPEAK-PP, acoustic validation, synthetic MBSV) with formulas & references
- [docs/](docs) — academic proposals, architecture notes, viva material
- [audit/](audit) — viva validation notebooks (C1/C2/C3 + MBSV scientific validation)
