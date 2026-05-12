# -*- coding: utf-8 -*-
"""
Live Sinhala features for words that are not in the training snapshot.

We always compute from the script:
  - word_length       (code-point length after strip)
  - vowel_sign_count  (dependent vowel signs, Sinhala U+0DCF–U+0DDF)

The other four columns (syllable_count, consonant_cluster, freq_rank,
rare_consonant) must match how the CSV was built. Without the original
feature pipeline, we impute them from the training distribution:
  1) median over all training rows with the same (word_length, vowel_sign_count)
  2) else median over the same word_length
  3) else global median over the whole snapshot

That way every prediction still uses a full 6-vector in the same space as training.
"""

from __future__ import annotations

import re
from collections import defaultdict
from typing import Any

# Sinhala dependent vowel signs (same range used to match your CSV in checks).
_VOWEL_SIGN = re.compile(r"[\u0DCF-\u0DDF]")


def count_dependent_vowel_signs(text: str) -> int:
    return len(_VOWEL_SIGN.findall(text.strip()))


def _median(xs: list[float]) -> float:
    if not xs:
        return 0.0
    s = sorted(xs)
    n = len(s)
    m = n // 2
    if n % 2:
        return float(s[m])
    return float((s[m - 1] + s[m]) / 2.0)


def build_oov_tables(
    word_snapshot: dict[str, dict[str, float]],
    impute_keys: tuple[str, ...] = (
        "syllable_count",
        "consonant_cluster",
        "freq_rank",
        "rare_consonant",
    ),
) -> dict[str, Any]:
    rows = list(word_snapshot.values())
    by_lv: dict[tuple[int, int], list[dict[str, float]]] = defaultdict(list)
    by_l: dict[int, list[dict[str, float]]] = defaultdict(list)
    for f in rows:
        wl = int(f["word_length"])
        vs = int(f["vowel_sign_count"])
        by_lv[(wl, vs)].append(f)
        by_l[wl].append(f)

    def pack(group: list[dict[str, float]]) -> dict[str, float]:
        return {k: _median([float(x[k]) for x in group]) for k in impute_keys}

    med_lv = {k: pack(v) for k, v in by_lv.items()}
    med_l = {k: pack(v) for k, v in by_l.items()}
    med_g = pack(rows) if rows else {k: 0.0 for k in impute_keys}

    return {"by_len_vs": med_lv, "by_len": med_l, "global": med_g}


def oov_feature_row(
    word: str,
    tables: dict[str, Any],
    *,
    default_freq_rank: float,
) -> dict[str, float]:
    w = word.strip()
    wl_i = len(w)
    vs_i = count_dependent_vowel_signs(w)
    wl_f = float(wl_i)
    vs_f = float(vs_i)

    key = (wl_i, vs_i)
    if key in tables["by_len_vs"]:
        chosen = dict(tables["by_len_vs"][key])
    elif wl_i in tables["by_len"]:
        chosen = dict(tables["by_len"][wl_i])
    else:
        chosen = dict(tables["global"])

    rare = float(chosen.get("rare_consonant", 0.0))
    rare = 1.0 if rare >= 0.5 else 0.0

    fr = float(chosen.get("freq_rank", default_freq_rank) or default_freq_rank)

    return {
        "syllable_count": float(chosen.get("syllable_count", 0.0)),
        "word_length": wl_f,
        "vowel_sign_count": vs_f,
        "consonant_cluster": float(chosen.get("consonant_cluster", 0.0)),
        "freq_rank": fr,
        "rare_consonant": rare,
    }
