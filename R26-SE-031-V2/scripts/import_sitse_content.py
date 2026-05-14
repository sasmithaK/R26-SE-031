"""
scripts/import_sitse_content.py
================================
Import NLPC-UOM/SiTSE Sinhala text simplification dataset into
content-service-v2/data/content_repository.json.

Maps simplification tiers → IRT difficulty:
    Complex sentence       → S8_sentence_reading,    b ∈ [1.0, 1.5]
    Simplification 1       → S8_sentence_reading,    b ∈ [0.0, 0.5]
    Simplification 2       → S7_word_picture_match,  b ∈ [-0.5, 0.0]
    Simplification 3       → S6_three_syllable_reading, b ∈ [-1.0, -0.5]

Reference: NLPC-UOM (2025) SiTSE dataset. MIT License.
Output: ~400 new items in content_repository.json (filtered: ≤ 15 words)

Usage:
    python scripts/import_sitse_content.py [--dry-run]
"""

import argparse
import json
import sys
import uuid
from pathlib import Path

ROOT = Path(__file__).parent.parent
SITSE_PATH    = ROOT / "datasets" / "sitse"
CONTENT_PATH  = ROOT / "content-service-v2" / "data" / "content_repository.json"

TIER_CONFIG = [
    {"col": "complex",          "skill": "S8_sentence_reading",      "b_range": (1.0, 1.5)},
    {"col": "simplification_1", "skill": "S8_sentence_reading",      "b_range": (0.0, 0.5)},
    {"col": "simplification_2", "skill": "S7_word_picture_match",    "b_range": (-0.5, 0.0)},
    {"col": "simplification_3", "skill": "S6_three_syllable_reading", "b_range": (-1.0, -0.5)},
]
MAX_WORDS = 15


def _irt_b(text: str, b_min: float, b_max: float) -> float:
    """Linearly interpolate b based on word count within the tier range."""
    words = len(text.split())
    words = min(words, MAX_WORDS)
    return round(b_min + (b_max - b_min) * (words / MAX_WORDS), 3)


def load_sitse():
    """Load SiTSE from local CSV or HuggingFace."""
    csv_candidates = list(SITSE_PATH.glob("*.csv"))
    if csv_candidates:
        import pandas as pd
        df = pd.read_csv(csv_candidates[0])
        print(f"[SiTSE] Loaded {len(df)} rows from {csv_candidates[0]}")
        return df
    print("[SiTSE] Local CSV not found — trying HuggingFace...")
    try:
        from datasets import load_dataset
        ds = load_dataset("NLPC-UOM/SiTSE", split="train")
        import pandas as pd
        df = ds.to_pandas()
        print(f"[SiTSE] Loaded {len(df)} rows from HuggingFace")
        return df
    except Exception as e:
        print(f"[SiTSE] Cannot load: {e}")
        print("  Run: python scripts/fetch_huggingface_datasets.py first")
        sys.exit(1)


def run(dry_run: bool = False):
    df = load_sitse()

    # Load existing content repository
    if CONTENT_PATH.exists():
        with open(CONTENT_PATH, encoding="utf-8") as f:
            repo = json.load(f)
    else:
        repo = []
    existing_texts = {item.get("sinhala_text", "") for item in repo}
    print(f"[SiTSE] Existing items: {len(repo)}")

    new_items = []
    for _, row in df.iterrows():
        for cfg in TIER_CONFIG:
            col = cfg["col"]
            # Try alternative column names
            text = None
            for alt in [col, col.replace("_", " "), col.upper(), col.capitalize()]:
                if alt in row and isinstance(row[alt], str) and row[alt].strip():
                    text = row[alt].strip()
                    break
            if not text:
                continue
            if len(text.split()) > MAX_WORDS:
                continue
            if text in existing_texts:
                continue

            item_id = f"SITSE_{uuid.uuid4().hex[:8]}"
            b_val = _irt_b(text, *cfg["b_range"])
            item = {
                "item_id": item_id,
                "skill_id": cfg["skill"],
                "sinhala_text": text,
                "english_gloss": None,
                "irt_difficulty_b": b_val,
                "audio_url": None,
                "image_url": None,
                "modality": "VISUAL",
                "source": "NLPC-UOM/SiTSE",
                "tier": col,
            }
            new_items.append(item)
            existing_texts.add(text)

    print(f"[SiTSE] New items to add: {len(new_items)}")
    skill_counts = {}
    for it in new_items:
        skill_counts[it["skill_id"]] = skill_counts.get(it["skill_id"], 0) + 1
    for sk, cnt in sorted(skill_counts.items()):
        print(f"  {sk}: {cnt} items")

    if not dry_run:
        repo.extend(new_items)
        CONTENT_PATH.parent.mkdir(parents=True, exist_ok=True)
        with open(CONTENT_PATH, "w", encoding="utf-8") as f:
            json.dump(repo, f, ensure_ascii=False, indent=2)
        print(f"[SiTSE] Saved {len(repo)} total items to {CONTENT_PATH}")
    else:
        print("[SiTSE] Dry run — no changes written")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    run(args.dry_run)
