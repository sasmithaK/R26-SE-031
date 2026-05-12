# System Analysis & Implementation Roadmap (v2.0)
## Adaptive Sinhala Dyslexia Screening & Guidance Platform — R26-SE-031

---

## 1. System Explanation: How it Works

The architecture is a **Closed-Loop Adaptive System** designed to screen and assist Grade 1–2
Sinhala-medium primary students with potential dyslexia-related reading difficulties.

### Architecture Pattern: Hub-and-Spoke via MBSV

```
                          ┌──────────────────────────┐
                          │   C1 — CBME (Port 8001)  │
                          │  Monitoring Service       │
                          │  Produces MBSV (6 dims)  │
                          └────────────┬─────────────┘
              ┌──────────────────┬────┴────┬──────────────────────┐
              ▼                  ▼         ▼                       ▼
  ┌───────────────────┐  (unused) │  ┌────────────────────┐  ┌───────────────────┐
  │ C2 — AVLI         │           │  │ C3 — PLCE          │  │ C4 — IIGE         │
  │ Visual (8004)     │           │  │ Content (8002)     │  │ Intervention (8003)│
  │ Consumes:         │           │  │ Consumes:          │  │ Consumes:          │
  │  visual_strain    │           │  │  cognitive_load    │  │  phonological_strain│
  │  engagement_index │           │  │  session_fatigue   │  │  error_pattern_vec │
  └───────────────────┘           │  └────────────────────┘  └───────────────────┘
                                  │        │                         │
                                  └────────┴─────────────────────────┘
                                           ▼
                                    Flutter App (UI)
```

**Critical design rule:** Each component consumes **only its assigned MBSV dimensions**.
No component reads or re-derives another component's dimensions.

### Core Workflow

1. **Flutter App** captures touch events, audio (on-device energy only), and task responses.
2. **C1 (CBME)** converts raw events → MBSV (6 dimensions). Uses Welford's algorithm to
   personalize features per child; LightGBM × 6 for calibrated dimension inference.
3. **C2 (AVLI)** reads `visual_strain_index` + `engagement_index` → LinUCB bandit selects
   typography config; manages gamification overlay state.
4. **C3 (PLCE)** reads `cognitive_load_index` + `session_fatigue_index` → BKT updates skill
   mastery; selects next content item in ZPD window.
5. **C4 (IIGE)** reads `phonological_strain_index` + `error_pattern_vector` → decides intervention
   stage; syllable splitter + activity selection; updates SM-2 schedule.

---

## 2. Analysis: Resolved Issues (From v1.0 → v2.0)

### Problems Diagnosed in the Original Architecture

| Problem | v1.0 Status | v2.0 Resolution |
| :--- | :--- | :--- |
| **RSI scalar information loss** | Single float RSI; visual, cognitive, phonological signals conflated | Replaced by 6-dimension MBSV with strict ownership boundaries |
| **BKT ownership clash** | C3 (IT22154880) and C4 (IT22267740) both claimed BKT | BKT lives exclusively in C3; C4 receives mastery_vector via API |
| **Gamification ownership clash** | C2 (IT22642882) and C4 (IT22267740) both claimed gamification | Gamification is a UI state machine → C2 owns it exclusively |
| **Content delivery overlap** | C4 proposed phonics exercises; C2 also proposed literacy exercises | C3 is sole content recommendation engine; C4 delivers inline activities only |
| **ε-Greedy Bandit (C2)** | Context-free; ignores child age, content complexity | Replaced by LinUCB (contextual) with SOVCM as context feature |
| **EMA as DKT** | Simple exponential moving average labeled "DKT" | Replaced by proper BKT (HMM, 4 parameters, Corbett & Anderson 1994) |
| **Hardcoded MONGO_URI** | Duplicated in 8+ locations | → Centralize in `.env` file (Phase 1 action) |
| **Variable naming** | `hesitation_ms` vs `latency_ms` across services | → Standardize via shared Pydantic schema (Phase 1 action) |
| **No acoustic analysis** | Audio button events only (replay count) | On-device energy envelope: pause_ms, syllable_rate, disfluency_count |
| **No dataset plan** | ML models referenced without data source | Integrated Hugging Face Datasets: SiTSE (NLPC-UOM), SPEAK-PP (Correction), peshalaperera (Articulation) |

---

## 3. Implementation Roadmap

### Milestone A — 50% Demo (Closed-Loop Proof of Concept)

**Target:** Demonstrate a single closed loop: Flutter task → C1 MBSV → C3 content recommendation.

| # | Task | Component | Output |
| :--- | :--- | :--- | :--- |
| A1 | Instrument existing Flutter tasks to emit structured telemetry events | Flutter | `POST /api/v1/telemetry` payload |
| A2 | Implement Welford's algorithm per-student (6 features) | C1 | `welford_state.json` |
| A3 | Train LightGBM × 6 on N=500 synthetic sessions | C1 | 6 model `.pkl` files |
| A4 | Wire LightGBM pipeline → produce MBSV JSON | C1 | `/api/v1/mbsv/{student_id}` |
| A5 | Build 9-node Sinhala skill graph with BKT engine | C3 | `bkt_engine.py` |
| A6 | Build NIE content repository (135 items, 9 skills × ~15 items) | C3 | `content_repository.json` |
| A7 | Wire `cognitive_load_index` → ZPD window → content selection | C3 | `/api/v1/content/next/{student_id}` |
| A8 | Flutter polls C3 for next task; renders it | Flutter | Adaptive task delivery |
| A9 | Implement Sinhala Unicode syllable splitter | C4 | `syllable_splitter.py` |
| A10 | Build SM-2 scheduler (per-skill, quality→interval) | C4 | `sm2_scheduler.py` |
| A11 | Wire `phonological_strain_index` → Stage 1 inline intervention | C4 | Stage 1 UI in Flutter |
| A12 | LinUCB initialization with WCAG prior (no live reward yet) | C2 | `linucb_typography.pkl` |

**50% Demo Script:**
1. Child opens app → onboarding questionnaire → baseline calibration (4 tasks).
2. C1 initializes Welford's state; LightGBM produces first MBSV.
3. C3 selects first BKT-targeted content item.
4. Child reads word → hesitates 2000+ ms → `phonological_strain_index > 0.45`.
5. C4 → Stage 1: word splits into syllables; audio plays.
6. Child answers → C3 BKT updates mastery; next item selected.
7. Live MBSV dashboard visible (supervisor/evaluator view).

---

### Milestone B — 100% System (Full Research Deliverable)

| # | Task | Component | Output |
| :--- | :--- | :--- | :--- |
| B1 | Add Kalman Filter for touch kinematics → `kalman_innovation` feature | C1 | `kalman_touch.py` |
| B2 | Add on-device audio energy extraction (pause_ms, syllable_rate) | C1 (Flutter) | Audio features in telemetry |
| B3 | SHAP evaluation endpoint; validate top-3 features per dimension | C1 | `/api/v1/monitoring/shap/{student_id}` |
| B4 | Isolation Forest for session outlier detection | C1 | `iso_forest_session.pkl` |
| B5 | Full LinUCB reward loop (visual_strain delta + accuracy delta) | C2 | Per-session reward logging |
| B6 | SOVCM character complexity table (54 base + 18 vowel signs) | C2 | `sovcm_table.json` |
| B7 | Gamification state machine (engagement_index < 0.3 → mini-game) | C2 | Overlay UI in Flutter |
| B8 | Ebbinghaus decay multiplier on BKT mastery | C3 | `forgetting_curve.py` |
| B9 | IRT 2PL difficulty calibration (teacher rating → b parameter) | C3 | `b` field in `content_repository.json` |
| B10 | Phoneme error analyser (Unicode + error_pattern_vector → error type) | C4 | `phoneme_error_analyser.py` |
| B11 | Activity selection matrix + Stage 2 activity overlay (4 activity types) | C4 | Activity UI in Flutter |
| B12 | RTI Tier 3 alert generation + guardian dashboard push | C4 | Guardian notification |
| B13 | MongoDB Atlas migration (all services, async via `motor`) | All | Production DB |
| B14 | Guardian monitoring dashboard (Mastery Heatmap, SM-2 calendar) | Flutter | Dashboard screen |
| B15 | Docker Compose for all 4 services + shared `.env` | DevOps | `docker-compose.yml` |
| B16 | Shared Pydantic schema library for inter-service payloads | All | `shared/schemas.py` |
| B17 | 5-session synthetic simulation → MBSV sensitivity report | C1 | Research validation artifact |
| B18 | Syllable splitter & model validation (using SiTSE, SPEAK-PP, and peshalaperera datasets) | C4/C1 | Validation results |
| B19 | SM-2 retention evaluation (within-session; SM-2 vs. no-review) | C4 | 4-week retention data |
| B20 | LinUCB vs. WCAG static baseline comparison report | C2 | Research evaluation artifact |
| B21 | BKT mastery curve vs. fixed NIE curriculum order comparison | C3 | Research evaluation artifact |

---

## 4. Engineering Excellence Checklist

### Configuration
- [ ] Single `.env` file for `MONGO_URI`, service ports, feature thresholds
- [ ] `python-dotenv` in all services; no hardcoded secrets anywhere

### Payload Standardization
- [ ] Shared `schemas.py` with Pydantic models for all inter-service requests/responses
- [ ] Canonical field names across all services:

| Canonical Name | Old Variants (Deprecated) |
| :--- | :--- |
| `hesitation_ms` | `latency_ms`, `response_time` |
| `is_correct` | `correct`, `answer_correct` |
| `phonological_strain_index` | `phonological_index`, `audio_struggle` |

### Containerization
- [ ] `Dockerfile` per service (Python 3.11, FastAPI, uvicorn)
- [ ] `docker-compose.yml`: C1–C4 + MongoDB

### Database
- [ ] SQLite → MongoDB migration: Milestone B13
- [ ] `motor` async client in all services
- [ ] Collections: `mbsv_events`, `bkt_states`, `sm2_schedules`, `linucb_arms`, `content_items`

### Observability
- [ ] Structured JSON logging per service (`structlog`)
- [ ] SHAP explanation logged per MBSV computation
- [ ] Intervention audit trail (what triggered, what selected, outcome)

---

## 5. New Services Created in v2.0

> Per team agreement, existing services are NOT removed. The following new services are created
> alongside the existing implementations to cleanly embody the v2.0 architecture.

| New Service Name | Port | What it Replaces/Adds |
| :--- | :--- | :--- |
| `monitoring-service-v2/` (CBME) | 8011 | Multi-task LightGBM MBSV engine (replaces single RSI) |
| `visual-service-v2/` (AVLI) | 8014 | LinUCB + SOVCM + gamification controller |
| `content-service-v2/` (PLCE) | 8012 | Full BKT on 9-node skill graph + IRT 2PL |
| `intervention-service-v2/` (IIGE) | 8013 | Syllable splitter + SM-2 + activity matrix |

---

## 6. Research Validation Summary

| Component | Research Method | Comparator (Baseline) |
| :--- | :--- | :--- |
| C1 CBME | SHAP top-3 feature consistency; synthetic sensitivity test (Cohen's d) | Fixed-threshold RSI scalar |
| C2 AVLI | LinUCB cumulative reward curve | WCAG 2.1 AA/AAA static preset |
| C3 PLCE | BKT mastery curve slope per child | Fixed NIE curriculum order |
| C4 IIGE | SM-2 vs. no-review within-session retention; syllable splitter F1 | Uniform review schedule |

---

*Document version 2.0 — revised per R26-SE-031 Optimization Plan (2026-05-12).*
*Previous version (v1.0) preserved in git history.*
