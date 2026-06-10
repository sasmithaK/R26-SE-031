"""
scripts/train_c2_linucb.py
===========================
LinUCB contextual bandit warm-start training — C2 AVLI Typography Adaptation.

The LinUCB bandit is inherently an online algorithm. This script:
1. WARM-STARTS the LinUCBAgent (A matrices and b vectors) by replaying the
   synthetic typography dataset (offline replay / warm-start).
2. VALIDATES arm selection policy via cumulative regret computation.
3. SERIALIZES the agent state to models/c2_linucb_agent_warmstart.pkl
   so visual-service-v1 loads warm parameters instead of cold identity matrices.

Reference:
    Li, L. et al. (2010). A Contextual-Bandit Approach to Personalized News
    Article Recommendation. WWW 2010.
"""

from __future__ import annotations
import sys, pickle
sys.stdout.reconfigure(encoding='utf-8')
import numpy as np
import pandas as pd
from pathlib import Path

BASE     = Path(__file__).parent.parent
DATASETS = BASE / "datasets"
MODELS   = BASE / "models"
MODELS.mkdir(exist_ok=True)

# ── Import LinUCB from visual-service-v1 ─────────────────────────────────
sys.path.insert(0, str(BASE))
import importlib.util

def _import(name, path):
    spec = importlib.util.spec_from_file_location(name, str(path))
    mod  = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod

linucb_mod = _import("linucb", BASE / "visual-service-v1" / "core" / "linucb.py")
LinUCBAgent          = linucb_mod.LinUCBAgent
LinUCBArm            = linucb_mod.LinUCBArm
build_context_vector = linucb_mod.build_context_vector
NUM_ARMS             = linucb_mod.NUM_ARMS    # 8
CONTEXT_DIM          = linucb_mod.CONTEXT_DIM  # 7

ARM_PRESETS_PATH = str(BASE / "visual-service-v1" / "data" / "arm_presets.json")


def train():
    print("[C2-LinUCB] Loading typography rewards dataset...")
    df = pd.read_csv(DATASETS / "c2_typography_rewards.csv")
    print(f"  Rows: {len(df)}  |  sim arms 0-3 (mapped to 8-arm agent)")

    # Create agent from presets (8 arms)
    agent = LinUCBAgent.load_or_create(
        state_path="__nonexistent__",  # force cold init
        presets_path=ARM_PRESETS_PATH,
    )
    print(f"  Agent initialized with {len(agent.arms)} arms, dim={CONTEXT_DIM}")

    # ── Offline replay warm-start ─────────────────────────────────────────
    print("[C2-LinUCB] Running offline replay warm-start...")
    cumulative_regret = 0.0
    n_updates = 0

    for _, row in df.iterrows():
        # Build 7-dim context using actual API signature
        ctx = build_context_vector(
            visual_strain_index       = float(row["vsi"]),
            engagement_index          = float(row["engagement"]),
            session_number            = int(row["session_minutes"]),   # proxy for session_number
            child_age_years           = None,                          # unknown → default 0.5
            task_complexity_sovcm     = float(row["task_complexity_sovcm"]),
            crowding_load             = float(row["cli"]) * 0.5,      # proxy crowding from CLI
            phonological_strain_index = float(row["psi"]),
        )

        # Map sim arm_id (0-3) to agent arm space (0-7) using modular mapping
        sim_arm = int(row["arm_id"])
        agent_arm = sim_arm % NUM_ARMS

        # Only update the arm that was actually selected in the simulation
        observed_reward = float(row["reward"])
        agent.update(agent_arm, ctx, observed_reward)

        # Compute regret vs. oracle (reward=1.0 for perfect arm)
        oracle_reward = 1.0
        cumulative_regret += max(0.0, oracle_reward - observed_reward)
        n_updates += 1

    print(f"  Updates: {n_updates}  |  Cumulative regret: {cumulative_regret:.4f}")
    print(f"  Avg reward: {agent.cumulative_reward / max(1, agent.total_steps):.4f}")

    # ── Arm update summary ────────────────────────────────────────────────
    counts = agent._arm_counts()
    print("\n  Arm update distribution:")
    for arm_id, cnt in counts.items():
        print(f"    Arm {arm_id}: {cnt} updates")

    # ── Validate: high-stress should prefer arms with larger spacing ──────
    high_stress_ctx = build_context_vector(
        visual_strain_index=0.85, engagement_index=0.20,
        session_number=35, child_age_years=8,
        task_complexity_sovcm=0.75, crowding_load=0.60,
        phonological_strain_index=0.80,
    )
    low_stress_ctx = build_context_vector(
        visual_strain_index=0.15, engagement_index=0.85,
        session_number=5, child_age_years=8,
        task_complexity_sovcm=0.25, crowding_load=0.10,
        phonological_strain_index=0.12,
    )
    arm_high = agent.select_arm(high_stress_ctx)
    arm_low  = agent.select_arm(low_stress_ctx)
    print(f"\n  High-stress context → selected arm {arm_high}")
    print(f"  Low-stress context  → selected arm {arm_low}")

    # ── Serialize agent state ──────────────────────────────────────────────
    out_path = MODELS / "c2_linucb_agent_warmstart.pkl"
    agent.save(str(out_path))
    print(f"\n[C2-LinUCB] Warm-started agent saved → {out_path}")
    return agent


if __name__ == "__main__":
    train()
