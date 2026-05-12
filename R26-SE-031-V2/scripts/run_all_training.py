"""
scripts/run_all_training.py
============================
Master training pipeline — R26-SE-031-V2.

Runs in sequence:
  1. generate_datasets.py  → datasets/
  2. train_c1_lgbm.py      → models/c1_lgbm_mbsv.pkl
  3. train_c1_learner_type.py → models/c1_learner_type_rf.pkl
  4. train_c2_linucb.py    → models/c2_linucb_agent_warmstart.pkl

Usage:
    python scripts/run_all_training.py
"""

import sys, time
from pathlib import Path
sys.stdout.reconfigure(encoding='utf-8')

BASE = Path(__file__).parent.parent
sys.path.insert(0, str(BASE))
sys.path.insert(0, str(BASE / "scripts"))

def _section(title):
    print()
    print("=" * 60)
    print(f"  {title}")
    print("=" * 60)

def run():
    total_start = time.time()

    _section("Step 1/5 — Synthetic Dataset Generation")
    t = time.time()
    from generate_datasets import generate_c1_dataset, generate_learner_type_dataset, generate_c2_linucb_dataset
    generate_c1_dataset()
    generate_learner_type_dataset()
    generate_c2_linucb_dataset()
    print(f"  Done in {time.time()-t:.1f}s")

    _section("Step 2/5 — C1 LightGBM MBSV Model")
    t = time.time()
    from train_c1_lgbm import train as train_lgbm
    train_lgbm()
    print(f"  Done in {time.time()-t:.1f}s")

    _section("Step 3/5 — C1 Random Forest Learner Type")
    t = time.time()
    from train_c1_learner_type import train as train_rf
    train_rf()
    print(f"  Done in {time.time()-t:.1f}s")

    _section("Step 4/5 — C2 LinUCB Warm-Start")
    t = time.time()
    from train_c2_linucb import train as train_linucb
    train_linucb()
    print(f"  Done in {time.time()-t:.1f}s")

    _section("Step 5/5 — C4 Intervention RF")
    t = time.time()
    from train_c4_intervention_rf import train as train_c4
    train_c4()
    print(f"  Done in {time.time()-t:.1f}s")

    total = time.time() - total_start
    print()
    print("=" * 60)
    print(f"  ALL TRAINING COMPLETE  ({total:.1f}s total)")
    print("=" * 60)
    print()
    print("  Artifacts produced:")
    models_dir = BASE / "models"
    for f in sorted(models_dir.iterdir()):
        size_kb = f.stat().st_size / 1024
        print(f"    {f.name:<45} {size_kb:>7.1f} KB")

if __name__ == "__main__":
    run()
