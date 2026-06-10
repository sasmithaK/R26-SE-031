"""
scripts/run_all_training.py
============================
Master training pipeline — R26-SE-031-V2  (v5.0).

Sequence:
  Step 1  fetch_huggingface_datasets.py   → datasets/articulation/, speak_pp/, sitse/
  Step 2  validate_c1_acoustic_features.py → datasets/c1_acoustic_validation_report.csv
  Step 3  generate_datasets.py            → datasets/c1_behavioral_features.csv (14 features)
  Step 4  train_c1_lgbm.py               → models/c1_lgbm_mbsv.pkl
  Step 5  train_c1_learner_type.py        → models/c1_learner_type_rf.pkl
  Step 6  train_c4_sinbert.py            → models/c4_sinbert/
  Step 7  calibrate_irt_from_speak_pp.py → content_repository.json (updated b values)
  Step 8  import_sitse_content.py        → content_repository.json (~400 new items)
  Step 9  train_c2_linucb.py             → models/c2_linucb_agent_warmstart.pkl
  Step 10 train_c4_intervention_rf.py    → models/c4_intervention_rf.pkl (baseline)

Steps 1–2 require internet / FLAC files and may be skipped with --skip-data-fetch.
Step 6 requires GPU/CPU with ≥8 GB RAM and may be skipped with --skip-sinbert.

Usage:
    python scripts/run_all_training.py
    python scripts/run_all_training.py --skip-data-fetch
    python scripts/run_all_training.py --skip-data-fetch --skip-sinbert
"""

import sys, time, argparse
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

def _try_import_run(module_name: str, fn_name: str = "main"):
    """Import a script module and call its entry-point function."""
    import importlib
    mod = importlib.import_module(module_name)
    fn = getattr(mod, fn_name, None) or getattr(mod, "run", None)
    if fn is None:
        raise AttributeError(f"{module_name} has no '{fn_name}' or 'run' function")
    fn()

def run(skip_data_fetch: bool = False, skip_sinbert: bool = False):
    total_start = time.time()

    # ── Data acquisition ────────────────────────────────────────────────────
    if not skip_data_fetch:
        _section("Step 1/10 — Download HuggingFace Datasets")
        t = time.time()
        _try_import_run("fetch_huggingface_datasets")
        print(f"  Done in {time.time()-t:.1f}s")

        _section("Step 2/10 — C1 Acoustic Feature Validation (articulation FLAC)")
        t = time.time()
        _try_import_run("validate_c1_acoustic_features")
        print(f"  Done in {time.time()-t:.1f}s")
    else:
        print("\n  [--skip-data-fetch] Skipping Steps 1–2 (dataset download + acoustic validation)")

    # ── Synthetic dataset generation ────────────────────────────────────────
    _section("Step 3/10 — Synthetic Dataset Generation (14 features + whisper_wer_proxy)")
    t = time.time()
    from generate_datasets import generate_c1_dataset, generate_learner_type_dataset, generate_c2_linucb_dataset
    generate_c1_dataset()
    generate_learner_type_dataset()
    generate_c2_linucb_dataset()
    print(f"  Done in {time.time()-t:.1f}s")

    # ── C1 models ───────────────────────────────────────────────────────────
    _section("Step 4/10 — C1 LightGBM MBSV Model (14 features)")
    t = time.time()
    from train_c1_lgbm import train as train_lgbm
    train_lgbm()
    print(f"  Done in {time.time()-t:.1f}s")

    _section("Step 5/10 — C1 Random Forest Learner Type")
    t = time.time()
    from train_c1_learner_type import train as train_rf
    train_rf()
    print(f"  Done in {time.time()-t:.1f}s")

    # ── C4 SinBERT ──────────────────────────────────────────────────────────
    if not skip_sinbert:
        _section("Step 6/10 — C4 SinBERT Fine-Tuning on SPEAK-PP (arXiv:2510.04750)")
        t = time.time()
        _try_import_run("train_c4_sinbert")
        print(f"  Done in {time.time()-t:.1f}s")
    else:
        print("\n  [--skip-sinbert] Skipping Step 6 (SinBERT fine-tuning)")

    # ── Content calibration ─────────────────────────────────────────────────
    _section("Step 7/10 — IRT Calibration from SPEAK-PP Error Frequency")
    t = time.time()
    _try_import_run("calibrate_irt_from_speak_pp")
    print(f"  Done in {time.time()-t:.1f}s")

    _section("Step 8/10 — Import SiTSE Content (~400 graded sentences)")
    t = time.time()
    _try_import_run("import_sitse_content")
    print(f"  Done in {time.time()-t:.1f}s")

    # ── C2 & C4 baseline ────────────────────────────────────────────────────
    _section("Step 9/10 — C2 LinUCB Warm-Start")
    t = time.time()
    from train_c2_linucb import train as train_linucb
    train_linucb()
    print(f"  Done in {time.time()-t:.1f}s")

    _section("Step 10/10 — C4 Intervention RF (rule-based baseline)")
    t = time.time()
    from train_c4_intervention_rf import train as train_c4
    train_c4()
    print(f"  Done in {time.time()-t:.1f}s")

    # ── Summary ─────────────────────────────────────────────────────────────
    total = time.time() - total_start
    print()
    print("=" * 60)
    print(f"  ALL TRAINING COMPLETE  ({total:.1f}s total)")
    print("=" * 60)
    print()
    print("  Artifacts produced:")
    models_dir = BASE / "models"
    if models_dir.exists():
        for f in sorted(models_dir.rglob("*")):
            if f.is_file():
                size_kb = f.stat().st_size / 1024
                rel = f.relative_to(models_dir)
                print(f"    {str(rel):<45} {size_kb:>7.1f} KB")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--skip-data-fetch", action="store_true",
                        help="Skip HuggingFace download + acoustic validation (Steps 1–2)")
    parser.add_argument("--skip-sinbert", action="store_true",
                        help="Skip SinBERT fine-tuning (Step 6) — uses rule-based fallback")
    args = parser.parse_args()
    run(skip_data_fetch=args.skip_data_fetch, skip_sinbert=args.skip_sinbert)
