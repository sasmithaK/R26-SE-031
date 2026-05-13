# -*- coding: utf-8 -*-
"""
Sinhala word difficulty + error_type (Model1).

This model uses the SAME feature columns as the dataset CSV:
`syllable_count`, `word_length`, `vowel_sign_count`, `consonant_cluster`,
`freq_rank`, `rare_consonant`.

Artifacts written by training to `intervention-service/ml/model1/`:
- `model1.joblib` (difficulty + error_type classifiers)
- `word_csv_features.json` (exact CSV feature row for each known word)
- `training_meta.json` (metrics)
"""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

import joblib
import numpy as np

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
    """
    Lightweight Sinhala tokenization: extract Sinhala letter chunks per whitespace token.
    """

    out: list[str] = []
    for chunk in text.replace("\n", " ").split():
        found = re.findall(r"[\u0D80-\u0DFF\u200C\u200D]+", chunk)
        if found:
            out.append(found[0])
    return out


def infer_error_type_hint(error_type_pred: str) -> str | None:
    """
    Keep API behavior stable: store `none` as NULL in DB/response.
    """

    et = (error_type_pred or "").strip()
    return None if et in ("", "none", "None", "null") else et


class Model1Predictor:
    def __init__(self, artifacts_dir: Path | str) -> None:
        d = Path(artifacts_dir)
        bundle = joblib.load(d / "model1.joblib")
        self.clf_difficulty = bundle["clf_difficulty"]
        self.clf_error_type = bundle["clf_error_type"]
        self.feature_columns: list[str] = list(bundle["feature_columns"])
        self.default_freq_rank: float = float(bundle.get("default_freq_rank", 400.0))

        self.word_snapshot: dict[str, dict[str, float]] = {}
        snap_path = d / WORD_SNAPSHOT_JSON
        if snap_path.is_file():
            with open(snap_path, encoding="utf-8") as f:
                raw = json.load(f)
            for w, feats in raw.items():
                ws = str(w).strip()
                self.word_snapshot[ws] = {c: float(feats[c]) for c in self.feature_columns}

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

        # For OOV words (not in the training CSV), we only have the word text.
        # We keep it simple and still return the expected feature columns.
        wl = float(len(w))
        return {
            "syllable_count": 0.0,
            "word_length": wl,
            "vowel_sign_count": 0.0,
            "consonant_cluster": 0.0,
            "freq_rank": float(self.default_freq_rank),
            "rare_consonant": 0.0,
        }

    def predict_one(self, word: str) -> dict[str, Any]:
        w = word.strip()
        feats = self._feature_row(w)
        X = np.asarray([[feats[c] for c in self.feature_columns]], dtype=np.float64)

        diff_class = int(self.clf_difficulty.predict(X)[0])
        dproba = self.clf_difficulty.predict_proba(X)[0]
        dmap = {int(c): float(p) for c, p in zip(self.clf_difficulty.classes_, dproba)}

        err_class = str(self.clf_error_type.predict(X)[0])
        eproba = self.clf_error_type.predict_proba(X)[0]
        emap = {str(c): float(p) for c, p in zip(self.clf_error_type.classes_, eproba)}

        return {
            "word": w,
            "difficulty_pred": diff_class,
            "p_easy": dmap.get(0),
            "p_hard": dmap.get(1),
            "error_type_pred": err_class,
            "error_type_proba": emap,
            "features": feats,
        }

