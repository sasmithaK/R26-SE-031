# -*- coding: utf-8 -*-
"""
Train Model1 using the CSV columns directly (no renaming).

Dataset columns required:
word, syllable_count, word_length, vowel_sign_count, consonant_cluster,
freq_rank, rare_consonant, difficulty, error_type

Run from intervention-service:
  python ml/training/train_model1.py --csv "C:\\path\\to\\dataset.csv"
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import (
    accuracy_score,
    balanced_accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
    roc_auc_score,
)
from sklearn.model_selection import train_test_split

ROOT = Path(__file__).resolve().parent.parent
INF = ROOT / "inference"
if str(INF) not in sys.path:
    sys.path.insert(0, str(INF))

from model1_inference import CSV_FEATURE_COLUMNS, WORD_SNAPSHOT_JSON  # noqa: E402


def _sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> None:
    ap = argparse.ArgumentParser(description="Train Model1 difficulty + error_type.")
    ap.add_argument("--csv", type=Path, required=True)
    ap.add_argument("--out-dir", type=Path, default=None)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--train-frac", type=float, default=0.7)
    args = ap.parse_args()

    csv_path = args.csv.resolve()
    out_dir = (args.out_dir or (ROOT / "model1")).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    df = pd.read_csv(csv_path, encoding="utf-8")
    required = ["word", "difficulty", "error_type", *CSV_FEATURE_COLUMNS]
    missing = [c for c in required if c not in df.columns]
    if missing:
        raise SystemExit(f"Missing columns: {missing}. Have: {list(df.columns)}")

    df = df.dropna(subset=["word", "difficulty", "error_type"]).copy()
    df["word"] = df["word"].astype(str).str.strip()
    df = df[df["word"].ne("")].reset_index(drop=True)

    y_diff = pd.to_numeric(df["difficulty"], errors="coerce")
    bad = y_diff.isna() | ~y_diff.isin([0, 1])
    if bad.any():
        raise SystemExit("difficulty must be 0 or 1 for all rows")
    y_diff = y_diff.astype(int)

    y_err = df["error_type"].astype(str).str.strip()

    feat_df = df[CSV_FEATURE_COLUMNS].apply(pd.to_numeric, errors="coerce")
    if feat_df.isna().any().any():
        cols = feat_df.columns[feat_df.isna().any()].tolist()
        raise SystemExit(f"Non-numeric feature values in: {cols}")
    X = feat_df.to_numpy(dtype=np.float64)

    n = len(X)
    if n < 20:
        raise SystemExit(f"Need at least 20 rows; got {n}")

    def split_xy(Xa, yd, ye, test_size, seed):
        strat = yd if yd.value_counts().min() >= 2 else None
        try:
            return train_test_split(
                Xa, yd, ye, test_size=test_size, random_state=seed, stratify=strat
            )
        except ValueError:
            return train_test_split(Xa, yd, ye, test_size=test_size, random_state=seed)

    X_train, X_temp, yd_tr, yd_tmp, ye_tr, ye_tmp = split_xy(
        X, y_diff, y_err, 1.0 - args.train_frac, args.seed
    )
    X_val, X_test, yd_va, yd_te, ye_va, ye_te = split_xy(
        X_temp, yd_tmp, ye_tmp, 0.5, args.seed
    )

    clf_d = RandomForestClassifier(
        n_estimators=200,
        max_depth=None,
        min_samples_leaf=2,
        class_weight="balanced_subsample",
        random_state=args.seed,
        n_jobs=-1,
    )
    clf_d.fit(X_train, yd_tr)

    clf_e = RandomForestClassifier(
        n_estimators=200,
        max_depth=None,
        min_samples_leaf=2,
        class_weight="balanced_subsample",
        random_state=args.seed,
        n_jobs=-1,
    )
    clf_e.fit(X_train, ye_tr)

    def proba_hard(m, Xa: np.ndarray) -> np.ndarray | None:
        p = m.predict_proba(Xa)
        classes = list(m.classes_)
        if 1 in classes:
            j = classes.index(1)
            return p[:, j]
        return None

    def block_diff(yt, yp, ph):
        out = {
            "accuracy": float(accuracy_score(yt, yp)),
            "balanced_accuracy": float(balanced_accuracy_score(yt, yp)),
            "f1_macro": float(f1_score(yt, yp, average="macro", zero_division=0)),
            "confusion_matrix": confusion_matrix(yt, yp, labels=[0, 1]).tolist(),
            "classification_report": classification_report(yt, yp, zero_division=0, output_dict=True),
        }
        try:
            if ph is not None and len(np.unique(yt)) > 1:
                out["roc_auc"] = float(roc_auc_score(yt, ph))
        except ValueError:
            pass
        return out

    def block_err(yt, yp):
        return {
            "accuracy": float(accuracy_score(yt, yp)),
            "balanced_accuracy": float(balanced_accuracy_score(yt, yp)),
            "f1_macro": float(f1_score(yt, yp, average="macro", zero_division=0)),
            "classification_report": classification_report(yt, yp, zero_division=0, output_dict=True),
        }

    pd_tr = clf_d.predict(X_train)
    pd_va = clf_d.predict(X_val)
    pd_te = clf_d.predict(X_test)
    ph_tr = proba_hard(clf_d, X_train)
    ph_va = proba_hard(clf_d, X_val)
    ph_te = proba_hard(clf_d, X_test)

    pe_tr = clf_e.predict(X_train)
    pe_va = clf_e.predict(X_val)
    pe_te = clf_e.predict(X_test)

    default_rank = float(np.median(feat_df["freq_rank"].to_numpy()))

    summary = {
        "dataset_path": str(csv_path),
        "dataset_sha256_16": _sha256_file(csv_path)[:16],
        "n_samples": int(n),
        "splits": {"train": int(len(X_train)), "val": int(len(X_val)), "test": int(len(X_test))},
        "class_balance_difficulty": {str(k): int(v) for k, v in y_diff.value_counts().sort_index().items()},
        "class_balance_error_type": {str(k): int(v) for k, v in y_err.value_counts().sort_index().items()},
        "feature_columns": list(CSV_FEATURE_COLUMNS),
        "default_freq_rank": default_rank,
    }

    meta = {
        "summary": summary,
        "difficulty": {
            "train": block_diff(yd_tr.values, pd_tr, ph_tr),
            "val": block_diff(yd_va.values, pd_va, ph_va),
            "test": block_diff(yd_te.values, pd_te, ph_te),
        },
        "error_type": {
            "train": block_err(ye_tr.values, pe_tr),
            "val": block_err(ye_va.values, pe_va),
            "test": block_err(ye_te.values, pe_te),
        },
    }

    bundle = {
        "clf_difficulty": clf_d,
        "clf_error_type": clf_e,
        "feature_columns": list(CSV_FEATURE_COLUMNS),
        "default_freq_rank": default_rank,
    }
    joblib.dump(bundle, out_dir / "model1.joblib")

    snapshot: dict[str, dict[str, float]] = {}
    for i in range(len(df)):
        w = str(df.iloc[i]["word"]).strip()
        snapshot[w] = {c: float(feat_df.iloc[i][c]) for c in CSV_FEATURE_COLUMNS}

    (out_dir / WORD_SNAPSHOT_JSON).write_text(
        json.dumps(snapshot, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    (out_dir / "training_meta.json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    print(f"Wrote: {out_dir / 'model1.joblib'}")
    print(f"Wrote: {out_dir / WORD_SNAPSHOT_JSON}")
    print(f"Wrote: {out_dir / 'training_meta.json'}")
    print("Difficulty test balanced_accuracy:", meta["difficulty"]["test"]["balanced_accuracy"])
    print("Error_type test accuracy:", meta["error_type"]["test"]["accuracy"])


if __name__ == "__main__":
    main()

