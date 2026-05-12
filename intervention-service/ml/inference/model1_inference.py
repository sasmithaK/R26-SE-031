# -*- coding: utf-8 -*-
"""
Sinhala word difficulty + error_type (Model1).

Uses the same six numeric columns as the CSV. For words in
`word_csv_features.json`, features are copied from training. For new words,
`word_length` and `vowel_sign_count` are computed from the Unicode string; the
other four fields are imputed from training rows with matching length / vowel
signs (see `sinhala_word_features.py`).
"""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

import joblib
import numpy as np

from sinhala_word_features import build_oov_tables, oov_feature_row

# Order must match the dataset columns and training matrix order.
CSV_FEATURE_COLUMNS: list[str] = [
    "syllable_count",
    "word_length",
    "vowel_sign_count",
    "consonant_cluster",
    "freq_rank",
    "rare_consonant",
]

WORD_SNAPSHOT_JSON = "word_csv_features.json"


def tokenize_sinhala_text(text: str) -> list[str]:
    """Split text into Sinhala word-like tokens (whitespace chunks, Sinhala script only)."""
    out: list[str] = []
    for chunk in text.replace("\n", " ").split():
        found = re.findall(r"[\u0D80-\u0DFF\u200C\u200D]+", chunk)
        if found:
            out.append(found[0])
    return out


def infer_error_type_hint(error_type_pred: str) -> str | None:
    """Map model label to API/DB: treat 'none' as empty."""
    et = (error_type_pred or "").strip()
    return None if et in ("", "none", "None", "null") else et


def _rows_to_matrix(rows: list[dict[str, float]], columns: list[str]) -> np.ndarray:
    return np.asarray([[row[c] for c in columns] for row in rows], dtype=np.float64)


def _proba_dict(classes: np.ndarray, probs: np.ndarray) -> dict[Any, float]:
    return {classes[i]: float(probs[i]) for i in range(len(classes))}


class Model1Predictor:
    """Load ml/model1 artifacts and predict difficulty + error_type."""

    def __init__(self, artifacts_dir: Path | str) -> None:
        d = Path(artifacts_dir)
        bundle = joblib.load(d / "model1.joblib")
        self.clf_difficulty = bundle["clf_difficulty"]
        self.clf_error_type = bundle["clf_error_type"]
        self.feature_columns: list[str] = list(bundle["feature_columns"])
        self.default_freq_rank: float = float(bundle.get("default_freq_rank", 400.0))

        self.clf_difficulty.set_params(n_jobs=1)
        self.clf_error_type.set_params(n_jobs=1)

        self.word_snapshot: dict[str, dict[str, float]] = {}
        snap_path = d / WORD_SNAPSHOT_JSON
        if snap_path.is_file():
            with open(snap_path, encoding="utf-8") as f:
                raw = json.load(f)
            for w, feats in raw.items():
                key = str(w).strip()
                self.word_snapshot[key] = {c: float(feats[c]) for c in self.feature_columns}

        if self.word_snapshot:
            self._oov_tables = build_oov_tables(self.word_snapshot)
        else:
            self._oov_tables = {
                "by_len_vs": {},
                "by_len": {},
                "global": {
                    "syllable_count": 1.0,
                    "consonant_cluster": 0.0,
                    "freq_rank": float(self.default_freq_rank),
                    "rare_consonant": 0.0,
                },
            }

        self.meta: dict[str, Any] = {}
        meta_path = d / "training_meta.json"
        if meta_path.is_file():
            with open(meta_path, encoding="utf-8") as f:
                self.meta = json.load(f)

    def _feature_row(self, word: str) -> dict[str, float]:
        w = word.strip()
        snap = self.word_snapshot.get(w)
        if snap is not None:
            return dict(snap)
        return oov_feature_row(w, self._oov_tables, default_freq_rank=self.default_freq_rank)

    def predict_many(self, words: list[str]) -> list[dict[str, Any]]:
        """Predict many words in one batch (faster than repeated predict_one)."""
        clean = [w.strip() for w in words if w.strip()]
        if not clean:
            return []

        rows = [self._feature_row(w) for w in clean]
        X = _rows_to_matrix(rows, self.feature_columns)

        diff_hat = self.clf_difficulty.predict(X)
        diff_P = self.clf_difficulty.predict_proba(X)
        d_classes = self.clf_difficulty.classes_

        err_hat = self.clf_error_type.predict(X)
        err_P = self.clf_error_type.predict_proba(X)
        e_classes = self.clf_error_type.classes_

        out: list[dict[str, Any]] = []
        for i, w in enumerate(clean):
            dmap = {int(k): float(v) for k, v in _proba_dict(d_classes, diff_P[i]).items()}
            emap = {str(k): float(v) for k, v in _proba_dict(e_classes, err_P[i]).items()}
            out.append(
                {
                    "word": w,
                    "difficulty_pred": int(diff_hat[i]),
                    "p_easy": dmap.get(0),
                    "p_hard": dmap.get(1),
                    "error_type_pred": str(err_hat[i]),
                    "error_type_proba": emap,
                    "features": rows[i],
                }
            )
        return out

    def predict_one(self, word: str) -> dict[str, Any]:
        return self.predict_many([word])[0]
