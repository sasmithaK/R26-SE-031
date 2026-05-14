"""
scripts/validate_c1_acoustic_features.py
=========================================
Validate C1 acoustic proxy features against real paired audio from
peshalaperera/sinhala-dyslexia-assistant-articulation-errors dataset.

For each (correct_audio, dyslexic_audio) pair:
  1. Extract read_aloud_pause_ms, syllable_rate, disfluency_count
  2. Paired t-test: do features differ significantly? (target p < 0.05)
  3. Compute Cohen's d
  4. Report which features best separate correct vs dyslexic speech

Expected result: read_aloud_pause_ms and disfluency_count show Cohen's d > 0.5
(validating C1 acoustic proxy approach against real Sinhala dyslexic speech).

Usage:
    python scripts/validate_c1_acoustic_features.py
    python scripts/validate_c1_acoustic_features.py --max-pairs 200
"""

import argparse
import csv
import sys
import os
import math
from pathlib import Path

ROOT = Path(__file__).parent.parent
ARTICULATION_PATH = ROOT / "datasets" / "articulation"
OUTPUT_CSV = ROOT / "datasets" / "c1_acoustic_validation_report.csv"


def extract_acoustic_features(audio_path: str) -> dict:
    """
    Extract C1 acoustic proxy features from audio file.
    Mirrors the energy-thresholding logic in monitoring-service-v2/main.py.
    Returns dict with read_aloud_pause_ms, syllable_rate, disfluency_count.
    """
    try:
        import numpy as np
        try:
            import soundfile as sf
            audio, sr = sf.read(audio_path)
        except Exception:
            try:
                import librosa
                audio, sr = librosa.load(audio_path, sr=16000, mono=True)
            except Exception as e:
                return {"read_aloud_pause_ms": 0.0, "syllable_rate": 0.0, "disfluency_count": 0.0, "error": str(e)}

        if audio.ndim > 1:
            audio = audio.mean(axis=1)
        audio = audio.astype(np.float32)
        sr = int(sr)

        frame_size = int(0.02 * sr)   # 20ms frames
        hop_size   = int(0.01 * sr)   # 10ms hop
        frames = [audio[i:i+frame_size] for i in range(0, len(audio) - frame_size, hop_size)]
        energy = np.array([np.sqrt(np.mean(f**2)) for f in frames])

        # Silence = energy < 0.02 threshold
        voiced = energy > 0.02
        transitions = np.diff(voiced.astype(int))
        silence_starts = np.where(transitions == -1)[0]
        silence_ends   = np.where(transitions ==  1)[0]
        min_len = min(len(silence_starts), len(silence_ends))
        silence_starts = silence_starts[:min_len]
        silence_ends   = silence_ends[:min_len]
        pause_durations_ms = (silence_ends - silence_starts) * 10.0
        read_aloud_pause_ms = float(np.mean(pause_durations_ms)) if len(pause_durations_ms) > 0 else 0.0

        # Syllable rate from energy peaks
        try:
            from scipy.signal import find_peaks
            peaks, _ = find_peaks(energy, height=0.05, distance=max(1, int(0.1 * sr / hop_size)))
        except ImportError:
            # Fallback: count zero crossings as proxy
            peaks = np.where(np.diff(np.sign(energy - 0.05)))[0]
        duration_s = len(audio) / sr
        syllable_rate = len(peaks) / duration_s if duration_s > 0 else 0.0

        # Disfluency: short pauses < 300ms
        short_pauses = pause_durations_ms[pause_durations_ms < 300] if len(pause_durations_ms) else np.array([])
        disfluency_count = float(len(short_pauses))

        return {
            "read_aloud_pause_ms": round(read_aloud_pause_ms, 2),
            "syllable_rate": round(syllable_rate, 4),
            "disfluency_count": disfluency_count,
        }
    except Exception as e:
        return {"read_aloud_pause_ms": 0.0, "syllable_rate": 0.0, "disfluency_count": 0.0, "error": str(e)}


def cohens_d(a, b):
    import numpy as np
    a, b = np.array(a), np.array(b)
    pooled_std = math.sqrt((a.std()**2 + b.std()**2) / 2)
    return float((a.mean() - b.mean()) / (pooled_std + 1e-8))


def run_validation(max_pairs: int = 500):
    import numpy as np
    from scipy import stats

    # Try local CSV first, then HuggingFace
    csv_path = ARTICULATION_PATH / "train.csv"
    if not csv_path.exists():
        print(f"[C1-Acoustic] {csv_path} not found — trying HuggingFace...")
        try:
            from datasets import load_dataset
            ds = load_dataset("peshalaperera/sinhala-dyslexia-assistant-articulation-errors", split="train")
            rows = [{"correct_audio_path": r.get("correct_audio_path",""),
                     "dyslexic_audio_path": r.get("dyslexic_audio_path",""),
                     "error_type": r.get("error_type","")} for r in ds]
        except Exception as e:
            print(f"[C1-Acoustic] Cannot load dataset: {e}")
            print("  Run: python scripts/fetch_huggingface_datasets.py first")
            sys.exit(1)
    else:
        with open(csv_path, encoding="utf-8") as f:
            rows = list(csv.DictReader(f))

    print(f"[C1-Acoustic] Loaded {len(rows)} pairs. Processing up to {max_pairs}...")
    rows = rows[:max_pairs]

    correct_feats  = {"read_aloud_pause_ms": [], "syllable_rate": [], "disfluency_count": []}
    dyslexic_feats = {"read_aloud_pause_ms": [], "syllable_rate": [], "disfluency_count": []}
    processed = 0
    errors = 0

    for row in rows:
        cp = str(row.get("correct_audio_path", "")).strip()
        dp = str(row.get("dyslexic_audio_path", "")).strip()
        if not cp or not dp:
            continue
        # Resolve relative paths against articulation directory
        cp_full = cp if os.path.isabs(cp) else str(ARTICULATION_PATH / cp)
        dp_full = dp if os.path.isabs(dp) else str(ARTICULATION_PATH / dp)
        if not os.path.exists(cp_full) or not os.path.exists(dp_full):
            errors += 1
            continue
        cf = extract_acoustic_features(cp_full)
        df = extract_acoustic_features(dp_full)
        if "error" in cf or "error" in df:
            errors += 1
            continue
        for feat in correct_feats:
            correct_feats[feat].append(cf[feat])
            dyslexic_feats[feat].append(df[feat])
        processed += 1

    if processed == 0:
        print(f"[C1-Acoustic] No pairs processed ({errors} errors). "
              "Check audio file paths in the CSV.")
        sys.exit(1)

    print(f"\n[C1-Acoustic] ===== Validation Report ({processed} pairs) =====")
    print(f"{'Feature':<28} {'Correct μ':>10} {'Dyslexic μ':>11} {'p-value':>10} {'Cohen d':>9} {'Sig?':>6}")
    print("-" * 80)

    results = []
    for feat in ["read_aloud_pause_ms", "syllable_rate", "disfluency_count"]:
        c = np.array(correct_feats[feat])
        d = np.array(dyslexic_feats[feat])
        t_stat, p_val = stats.ttest_rel(c, d)
        d_val = cohens_d(c, d)
        sig = "✅" if p_val < 0.05 and abs(d_val) > 0.5 else ("⚠" if p_val < 0.05 else "❌")
        print(f"{feat:<28} {c.mean():>10.2f} {d.mean():>11.2f} {p_val:>10.4f} {d_val:>9.3f} {sig:>6}")
        results.append({
            "feature": feat, "correct_mean": float(c.mean()),
            "dyslexic_mean": float(d.mean()), "p_value": float(p_val),
            "cohens_d": float(d_val), "significant": p_val < 0.05 and abs(d_val) > 0.5,
        })

    print("\n[C1-Acoustic] Target: p < 0.05 and Cohen's d > 0.5 (✅) for each feature")

    OUTPUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_CSV, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=results[0].keys())
        writer.writeheader()
        writer.writerows(results)
    print(f"[C1-Acoustic] Report saved to {OUTPUT_CSV}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--max-pairs", type=int, default=500)
    args = parser.parse_args()
    run_validation(args.max_pairs)


if __name__ == "__main__":
    main()
