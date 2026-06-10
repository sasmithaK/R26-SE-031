"""
scripts/generate_datasets.py
==============================
Synthetic behavioral dataset generator for R26-SE-031-V2 ML model training.

WHY SYNTHETIC?
    No labeled Sinhala dyslexia behavioral dataset exists publicly (2024).
    This generator produces statistically grounded synthetic data using:
    - Published feature ranges from the Dyslexia Screening Test Junior (DST-J)
    - Lokubalasuriya et al. (2019) behavioral profile descriptions
    - Snowling & Hulme (2011) phonological deficit hypothesis feature distributions
    - Scholastic auditory/visual/kinesthetic learning style questionnaire norms

REPRODUCIBILITY:
    All parameters are documented and fixed with RANDOM_SEED=42.
    Generated CSVs are committed to the repository for full reproducibility.

References:
    Fawcett, A. J., & Nicolson, R. I. (2004). The Dyslexia Screening Test-Junior.
    Lokubalasuriya, T. et al. (2019). Early Language Characteristics of Dyslexia.
        8th LLCE Conference.
    Snowling, M. J., & Hulme, C. (2011). Evidence-based interventions for reading
        and language difficulties. Journal of Child Psychology & Psychiatry, 53(4).
"""

from __future__ import annotations
import numpy as np
import pandas as pd
from pathlib import Path

RANDOM_SEED = 42
rng = np.random.default_rng(RANDOM_SEED)

BASE   = Path(__file__).parent.parent
OUTDIR = BASE / "datasets"
OUTDIR.mkdir(exist_ok=True)

# ============================================================================
# Dataset 1 — C1: Behavioral Feature → MBSV Label  (n=1200)
# ============================================================================
# Label: 6 MBSV dimensions (multi-label regression targets, all [0,1])
#   1. cognitive_load_index      (CLI)
#   2. phonological_strain_index (PSI)
#   3. visual_strain_index       (VSI)
#   4. fatigue_index             (FI)
#   5. engagement_score          (ES)   [inverted — higher=more engaged]
#   6. error_rate_index          (ERI)
#
# Profile sampling:
#   50% "at-risk"            → elevated CLI, PSI, ERI; suppressed ES
#   30% "typically-developing" → low stress, high ES
#   20% "mild-difficulty"     → moderate values

N = 1200

def _clip01(x):
    return np.clip(x, 0.0, 1.0)

def generate_c1_dataset():
    profiles = rng.choice(["at_risk", "td", "mild"], size=N, p=[0.5, 0.3, 0.2])

    rows = []
    for profile in profiles:
        if profile == "at_risk":
            # High hesitation, replay, hints; low velocity
            hesitation_ms       = rng.normal(3200, 800)
            correction_rate     = rng.beta(4, 2)          # skewed high
            response_latency    = rng.normal(2800, 600)
            touch_pressure      = rng.normal(0.65, 0.12)
            swipe_velocity      = rng.normal(120, 40)
            replay_count        = rng.poisson(3.5)
            hint_request_count  = rng.poisson(2.8)
            stylus_deviation    = rng.normal(18, 5)
            inter_tap_interval  = rng.normal(950, 200)
            read_aloud_pause_ms = rng.normal(1800, 400)
            syllable_rate       = rng.normal(1.4, 0.3)
            disfluency_count    = rng.poisson(4.2)
            kalman_innovation   = rng.normal(12.5, 3.5)
            # Whisper WER proxy: at-risk → high WER (0.50–0.90)
            # Perera & Sumanathilaka (2025) report 0.66 mean WER for dyslexic Sinhala
            whisper_wer_proxy   = rng.beta(6, 3)  # mean ≈ 0.67

            CLI = _clip01(rng.normal(0.72, 0.12))
            PSI = _clip01(rng.normal(0.68, 0.13))
            VSI = _clip01(rng.normal(0.61, 0.14))
            FI  = _clip01(rng.normal(0.65, 0.13))
            ES  = _clip01(rng.normal(0.28, 0.10))
            ERI = _clip01(rng.normal(0.73, 0.12))

        elif profile == "td":
            hesitation_ms       = rng.normal(900, 250)
            correction_rate     = rng.beta(1.5, 5)        # skewed low
            response_latency    = rng.normal(800, 200)
            touch_pressure      = rng.normal(0.50, 0.10)
            swipe_velocity      = rng.normal(280, 60)
            replay_count        = rng.poisson(0.4)
            hint_request_count  = rng.poisson(0.3)
            stylus_deviation    = rng.normal(5, 2)
            inter_tap_interval  = rng.normal(420, 80)
            read_aloud_pause_ms = rng.normal(450, 120)
            syllable_rate       = rng.normal(3.2, 0.4)
            disfluency_count    = rng.poisson(0.6)
            kalman_innovation   = rng.normal(3.2, 1.0)
            # Whisper WER proxy: typically-developing → low WER (0.10–0.35)
            whisper_wer_proxy   = rng.beta(2, 7)  # mean ≈ 0.22

            CLI = _clip01(rng.normal(0.18, 0.09))
            PSI = _clip01(rng.normal(0.15, 0.08))
            VSI = _clip01(rng.normal(0.14, 0.08))
            FI  = _clip01(rng.normal(0.20, 0.10))
            ES  = _clip01(rng.normal(0.82, 0.09))
            ERI = _clip01(rng.normal(0.14, 0.08))

        else:  # mild
            hesitation_ms       = rng.normal(1800, 450)
            correction_rate     = rng.beta(2.5, 3.5)
            response_latency    = rng.normal(1600, 400)
            touch_pressure      = rng.normal(0.57, 0.11)
            swipe_velocity      = rng.normal(195, 50)
            replay_count        = rng.poisson(1.5)
            hint_request_count  = rng.poisson(1.2)
            stylus_deviation    = rng.normal(11, 3)
            inter_tap_interval  = rng.normal(680, 150)
            read_aloud_pause_ms = rng.normal(1100, 280)
            syllable_rate       = rng.normal(2.1, 0.4)
            disfluency_count    = rng.poisson(2.0)
            kalman_innovation   = rng.normal(7.5, 2.0)
            # Whisper WER proxy: mild difficulty → moderate WER (0.30–0.60)
            whisper_wer_proxy   = rng.beta(3.5, 5)  # mean ≈ 0.41

            CLI = _clip01(rng.normal(0.45, 0.12))
            PSI = _clip01(rng.normal(0.42, 0.13))
            VSI = _clip01(rng.normal(0.38, 0.12))
            FI  = _clip01(rng.normal(0.43, 0.12))
            ES  = _clip01(rng.normal(0.54, 0.12))
            ERI = _clip01(rng.normal(0.44, 0.13))

        rows.append({
            # Raw features (14 — 13 original + whisper_wer_proxy)
            "hesitation_ms":       max(0, hesitation_ms),
            "correction_rate":     _clip01(correction_rate),
            "response_latency":    max(0, response_latency),
            "touch_pressure":      _clip01(touch_pressure),
            "swipe_velocity":      max(0, swipe_velocity),
            "replay_count":        int(max(0, replay_count)),
            "hint_request_count":  int(max(0, hint_request_count)),
            "stylus_deviation":    max(0, stylus_deviation),
            "inter_tap_interval":  max(0, inter_tap_interval),
            "read_aloud_pause_ms": max(0, read_aloud_pause_ms),
            "syllable_rate":       max(0.1, syllable_rate),
            "disfluency_count":    int(max(0, disfluency_count)),
            "kalman_innovation":   max(0, kalman_innovation),
            "whisper_wer_proxy":   round(_clip01(float(whisper_wer_proxy)), 4),
            # MBSV target labels (6)
            "label_CLI": round(CLI, 4),
            "label_PSI": round(PSI, 4),
            "label_VSI": round(VSI, 4),
            "label_FI":  round(FI, 4),
            "label_ES":  round(ES, 4),
            "label_ERI": round(ERI, 4),
            # Metadata
            "profile": profile,
        })

    df = pd.DataFrame(rows)
    path = OUTDIR / "c1_behavioral_features.csv"
    df.to_csv(path, index=False)
    print(f"[datasets] c1_behavioral_features.csv  n={len(df)}  path={path}")
    return df


# ============================================================================
# Dataset 2 — C1: Learner Type Classification  (n=600)
# ============================================================================
# Label: learner_type ∈ {V, A, K}
# Features: subset of behavioral signals that correlate with learning modality
# Reference: VARK questionnaire norms + Dunn & Dunn (1978) learning style inventory

def generate_learner_type_dataset():
    labels = rng.choice(["V", "A", "K"], size=600, p=[0.40, 0.35, 0.25])
    rows = []
    for lt in labels:
        if lt == "V":   # Visual learner: low replay, high stylus precision, fast touch
            replay_count       = rng.poisson(0.6)
            hint_request_count = rng.poisson(0.8)
            stylus_deviation   = rng.normal(6, 2)
            swipe_velocity     = rng.normal(260, 50)
            read_aloud_pause_ms= rng.normal(600, 180)
            disfluency_count   = rng.poisson(1.0)
            inter_tap_interval = rng.normal(450, 90)
        elif lt == "A": # Auditory: high replay, slow stylus, long pauses → listens carefully
            replay_count       = rng.poisson(3.2)
            hint_request_count = rng.poisson(0.5)
            stylus_deviation   = rng.normal(10, 3)
            swipe_velocity     = rng.normal(160, 45)
            read_aloud_pause_ms= rng.normal(1400, 350)
            disfluency_count   = rng.poisson(3.5)
            inter_tap_interval = rng.normal(720, 160)
        else:           # Kinesthetic: many hints, high pressure, erratic velocity
            replay_count       = rng.poisson(1.0)
            hint_request_count = rng.poisson(2.5)
            stylus_deviation   = rng.normal(14, 4)
            swipe_velocity     = rng.normal(210, 80)
            read_aloud_pause_ms= rng.normal(850, 220)
            disfluency_count   = rng.poisson(1.5)
            inter_tap_interval = rng.normal(570, 130)

        rows.append({
            "replay_count":        int(max(0, replay_count)),
            "hint_request_count":  int(max(0, hint_request_count)),
            "stylus_deviation":    max(0, stylus_deviation),
            "swipe_velocity":      max(0, swipe_velocity),
            "read_aloud_pause_ms": max(0, read_aloud_pause_ms),
            "disfluency_count":    int(max(0, disfluency_count)),
            "inter_tap_interval":  max(0, inter_tap_interval),
            "learner_type":        lt,
        })

    df = pd.DataFrame(rows)
    path = OUTDIR / "c1_learner_type_labels.csv"
    df.to_csv(path, index=False)
    print(f"[datasets] c1_learner_type_labels.csv  n={len(df)}  path={path}")
    return df


# ============================================================================
# Dataset 3 — C2: LinUCB Typography Reward Simulation  (n=2000)
# ============================================================================
# Simulates the reward signal for typography arm selection.
# Reward = 1.0 if the arm (font_size, line_spacing, letter_spacing) chosen
#   was appropriate given the child's cognitive load + SOVCM task complexity.
# Rule: harder content + higher load → larger spacing/size required.

def generate_c2_linucb_dataset():
    rows = []
    for _ in range(2000):
        # Context features (same as LinUCB build_context_vector)
        cli           = rng.uniform(0.1, 0.9)    # cognitive_load_index
        psi           = rng.uniform(0.1, 0.9)    # phonological_strain_index
        task_cpx      = rng.uniform(0.2, 0.8)    # SOVCM task_complexity
        session_min   = rng.integers(1, 45)       # minutes into session
        vsi           = rng.uniform(0.1, 0.9)    # visual_strain_index
        fatigue       = rng.uniform(0.1, 0.9)    # fatigue_index
        engagement    = rng.uniform(0.1, 0.9)    # engagement_score

        combined_stress = (cli + psi + vsi + fatigue) / 4.0
        session_frac    = session_min / 45.0

        # Arm features: (font_size_pt, line_spacing, letter_spacing_px)
        # Arms: 0=small-tight, 1=medium, 2=large-loose, 3=adaptive
        arm = rng.integers(0, 4)
        arm_configs = [
            (12, 1.2, 1.0),  # arm 0: small tight  → bad for high stress
            (16, 1.5, 2.0),  # arm 1: medium
            (20, 1.8, 3.5),  # arm 2: large loose  → good for high stress
            (18, 1.6, 2.5),  # arm 3: adaptive mid
        ]
        fs, ls, lsp = arm_configs[arm]

        # Reward function: arms that increase spacing with stress get high reward
        ideal_stress_arm = 2 if combined_stress > 0.6 else (1 if combined_stress > 0.35 else 0)
        arm_distance = abs(arm - ideal_stress_arm)
        reward = max(0.0, 1.0 - arm_distance * 0.4 + rng.normal(0, 0.08))
        reward = float(np.clip(reward, 0.0, 1.0))

        rows.append({
            "cli": round(cli, 4),
            "psi": round(psi, 4),
            "task_complexity_sovcm": round(task_cpx, 4),
            "session_minutes": int(session_min),
            "vsi": round(vsi, 4),
            "fatigue": round(fatigue, 4),
            "engagement": round(engagement, 4),
            "arm_id": arm,
            "font_size_pt": fs,
            "line_spacing": ls,
            "letter_spacing_px": lsp,
            "reward": round(reward, 4),
        })

    df = pd.DataFrame(rows)
    path = OUTDIR / "c2_typography_rewards.csv"
    df.to_csv(path, index=False)
    print(f"[datasets] c2_typography_rewards.csv   n={len(df)}  path={path}")
    return df


# ============================================================================
# Main
# ============================================================================
if __name__ == "__main__":
    print("Generating synthetic research datasets...")
    print("  Seed=42  (fully reproducible)")
    print()
    df1 = generate_c1_dataset()
    df2 = generate_learner_type_dataset()
    df3 = generate_c2_linucb_dataset()
    print()
    print("=== Dataset generation complete ===")
    print(f"  C1 MBSV features  : {len(df1)} rows, {len(df1.columns)} cols")
    print(f"  C1 Learner type   : {len(df2)} rows  (V={sum(df2.learner_type=='V')}, A={sum(df2.learner_type=='A')}, K={sum(df2.learner_type=='K')})")
    print(f"  C2 Typography     : {len(df3)} rows  (arms 0-3)")
