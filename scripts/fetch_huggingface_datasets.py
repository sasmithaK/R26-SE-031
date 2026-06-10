"""
scripts/fetch_huggingface_datasets.py
=======================================
Download all HuggingFace datasets used in v5.0 to local datasets/ directory.
Run this FIRST before any other training script.

Downloads:
    peshalaperera/sinhala-dyslexia-assistant-articulation-errors → datasets/articulation/
    SPEAK-PP/sinhala-dyslexia-corrected-id20percent              → datasets/speak_pp/
    NLPC-UOM/SiTSE                                                → datasets/sitse/

Usage:
    pip install datasets huggingface_hub
    python scripts/fetch_huggingface_datasets.py
"""

import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent
DATASETS_DIR = ROOT / "datasets"
DATASETS_DIR.mkdir(parents=True, exist_ok=True)

SOURCES = [
    {
        "hf_id":  "peshalaperera/sinhala-dyslexia-assistant-articulation-errors",
        "subdir": "articulation",
        "splits": ["train", "test"],
        "description": "3k paired correct/dyslexic Sinhala audio + error labels",
    },
    {
        "hf_id":  "SPEAK-PP/sinhala-dyslexia-corrected-id20percent",
        "subdir": "speak_pp",
        "splits": ["train"],
        "description": "27.6k dyslexic sentence pairs with fine-grained error taxonomy",
    },
    {
        "hf_id":  "NLPC-UOM/SiTSE",
        "subdir": "sitse",
        "splits": ["train"],
        "description": "1k Sinhala complex→simplified sentence pairs (3 tiers)",
    },
]


def fetch(source: dict):
    try:
        from datasets import load_dataset
        out_dir = DATASETS_DIR / source["subdir"]
        out_dir.mkdir(parents=True, exist_ok=True)
        print(f"\n[Fetch] {source['hf_id']}")
        print(f"        {source['description']}")
        for split in source["splits"]:
            out_csv = out_dir / f"{split}.csv"
            if out_csv.exists():
                print(f"  [{split}] Already exists → {out_csv}")
                continue
            try:
                ds = load_dataset(source["hf_id"], split=split)
                df = ds.to_pandas()
                df.to_csv(out_csv, index=False, encoding="utf-8")
                print(f"  [{split}] {len(df)} rows → {out_csv}")
            except Exception as e:
                print(f"  [{split}] Failed: {e}")
    except ImportError:
        print("'datasets' not installed. Run: pip install datasets huggingface_hub")
        sys.exit(1)


def main():
    print("=== R26-SE-031 v5.0 Dataset Fetcher ===")
    for source in SOURCES:
        fetch(source)
    print("\nDone. Run scripts in this order:")
    print("  1. python scripts/validate_c1_acoustic_features.py")
    print("  2. python scripts/generate_datasets.py")
    print("  3. python scripts/train_c1_lgbm.py")
    print("  4. python scripts/train_c4_sinbert.py")
    print("  5. python scripts/import_sitse_content.py")
    print("  6. python scripts/calibrate_irt_from_speak_pp.py")


if __name__ == "__main__":
    main()
