# -*- coding: utf-8 -*-
"""
Quick test for Model1: loads artifacts and evaluates on a labelled CSV.

Run from intervention-service:
  python ml/training/test_model1.py --csv "C:\\path\\to\\dataset.csv" --artifacts ml/model1
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
INF = ROOT / "inference"
if str(INF) not in sys.path:
    sys.path.insert(0, str(INF))

from model1_inference import Model1Predictor  # noqa: E402


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", type=Path, required=True)
    ap.add_argument("--artifacts", type=Path, default=ROOT / "model1")
    ap.add_argument("--limit", type=int, default=0)
    args = ap.parse_args()

    p = Model1Predictor(args.artifacts.resolve())
    df = pd.read_csv(args.csv.resolve(), encoding="utf-8")
    if args.limit:
        df = df.head(args.limit)

    ok_d = 0
    ok_e = 0
    n = 0

    for _, row in df.iterrows():
        w = str(row.get("word", "")).strip()
        if not w:
            continue
        r = p.predict_one(w)
        td = int(row["difficulty"])
        te = str(row["error_type"]).strip()
        if r["difficulty_pred"] == td:
            ok_d += 1
        if r["error_type_pred"] == te:
            ok_e += 1
        n += 1

    print(f"Rows evaluated: {n}")
    print(f"Difficulty accuracy: {ok_d / max(1, n):.4f}")
    print(f"Error_type accuracy: {ok_e / max(1, n):.4f}")


if __name__ == "__main__":
    main()

