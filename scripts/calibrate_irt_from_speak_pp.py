"""
scripts/calibrate_irt_from_speak_pp.py
========================================
Update IRT b values in content_repository.json using SPEAK-PP error frequency.

Algorithm:
    For each word in content_repository.json:
        error_frequency = count of rows in SPEAK-PP where word appears in dyslexic_sentence
        b_proxy = 0.4 * norm_syllable_count + 0.3 * sovcm_score + 0.3 * error_freq_norm

This grounds IRT calibration in empirical dyslexic error frequency rather than expert opinion.

Reference: SPEAK-PP/sinhala-dyslexia-corrected-id20percent (27.6k rows)
           Perera & Sumanathilaka (2025) arXiv:2510.04750

Usage:
    python scripts/calibrate_irt_from_speak_pp.py [--dry-run]
"""

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).parent.parent
SPEAK_PP_PATH = ROOT / "datasets" / "speak_pp" / "train.csv"
CONTENT_PATH  = ROOT / "content-service-v1" / "data" / "content_repository.json"

SINHALA_CHAR = re.compile(r'[඀-෿]+')


def count_syllables_simple(text: str) -> int:
    """Approximate syllable count: number of Sinhala Unicode chars (consonants/vowels)."""
    return sum(1 for c in text if 0x0D80 <= ord(c) <= 0x0DFF)


def load_speak_pp_words():
    """Return Counter of Sinhala words appearing in dyslexic sentences."""
    if not SPEAK_PP_PATH.exists():
        print(f"[IRT] {SPEAK_PP_PATH} not found — trying HuggingFace...")
        try:
            from datasets import load_dataset
            ds = load_dataset("SPEAK-PP/sinhala-dyslexia-corrected-id20percent", split="train")
            sentences = [r.get("dyslexic_sentence", "") for r in ds if r.get("dyslexic_sentence")]
        except Exception as e:
            print(f"[IRT] Cannot load SPEAK-PP: {e}")
            sys.exit(1)
    else:
        import csv
        with open(SPEAK_PP_PATH, encoding="utf-8") as f:
            rows = list(csv.DictReader(f))
        col = next((c for c in ["dyslexic_sentence", "sentence", "text"] if c in rows[0]), list(rows[0].keys())[0])
        sentences = [r[col] for r in rows if r.get(col)]

    word_counter: Counter = Counter()
    for sent in sentences:
        words = SINHALA_CHAR.findall(sent)
        word_counter.update(words)
    print(f"[IRT] SPEAK-PP: {len(sentences)} sentences, {len(word_counter)} unique words")
    return word_counter


def run(dry_run: bool = False):
    try:
        # Load SOVCM from visual-service-v1
        sys.path.insert(0, str(ROOT))
        from visual_service_v1.core.sovcm import task_complexity as sovcm_score
    except ImportError:
        try:
            sys.path.insert(0, str(ROOT / "visual-service-v1"))
            from core.sovcm import task_complexity as sovcm_score
        except ImportError:
            print("[IRT] SOVCM not available — using syllable count only")
            def sovcm_score(text): return 0.5  # neutral fallback

    word_freq = load_speak_pp_words()
    if not word_freq:
        print("[IRT] Empty word frequency table — aborting")
        sys.exit(1)

    max_freq = max(word_freq.values()) if word_freq else 1

    if not CONTENT_PATH.exists():
        print(f"[IRT] {CONTENT_PATH} not found — run import_sitse_content.py first")
        sys.exit(1)

    with open(CONTENT_PATH, encoding="utf-8") as f:
        repo = json.load(f)

    repo_items = repo.get("items", repo) if isinstance(repo, dict) else repo
    print(f"[IRT] Processing {len(repo_items)} content items...")
    updated = 0
    for item in repo_items:
        text = item.get("sinhala_text", "")
        if not text:
            continue

        # Extract Sinhala words from the item text
        words = SINHALA_CHAR.findall(text)
        if not words:
            continue

        # Syllable count (normalized 0–1 over 0–10 syllable range)
        syl_count = count_syllables_simple(text)
        norm_syl = min(syl_count / 10.0, 1.0)

        # SOVCM score
        try:
            sovcm = float(sovcm_score(text))
        except Exception:
            sovcm = 0.5

        # Error frequency: mean normalized frequency of words in SPEAK-PP
        freqs = [word_freq.get(w, 0) / max_freq for w in words]
        error_freq_norm = sum(freqs) / len(freqs) if freqs else 0.0

        # Composite IRT proxy (clamped to [-2, 2] IRT range)
        b_proxy = 0.4 * norm_syl + 0.3 * sovcm + 0.3 * error_freq_norm
        # Map [0, 1] → [-2, 2]
        b_irt = round(-2.0 + b_proxy * 4.0, 3)
        b_irt = max(-2.0, min(2.0, b_irt))

        old_b = item.get("irt_difficulty_b", 0.0)
        item["irt_difficulty_b"] = b_irt
        item["irt_calibration_source"] = "speak_pp_error_frequency"
        if abs(old_b - b_irt) > 0.05:
            updated += 1

    print(f"[IRT] Updated {updated}/{len(repo)} IRT b values")

    if not dry_run:
        with open(CONTENT_PATH, "w", encoding="utf-8") as f:
            json.dump(repo, f, ensure_ascii=False, indent=2)
        print(f"[IRT] Saved to {CONTENT_PATH}")
    else:
        print("[IRT] Dry run — no changes written")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    run(args.dry_run)
