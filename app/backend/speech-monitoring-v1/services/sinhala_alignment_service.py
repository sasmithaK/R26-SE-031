"""Stages 4 and 5 of C2: Sinhala-aware expected-text alignment."""

from __future__ import annotations

import re
import unicodedata
from typing import Any, Dict, Iterable, List, Sequence, Tuple


ALIGNMENT_VERSION = "c2-sinhala-alignment-v1"
_SINHALA_START = "\u0d80"
_SINHALA_END = "\u0dff"
_JOINERS = {"\u200c", "\u200d"}
_VIRAMA = "\u0dca"


def normalize_sinhala(text: str) -> str:
    text = unicodedata.normalize("NFC", text or "")
    kept = []
    for char in text:
        if _SINHALA_START <= char <= _SINHALA_END or char in _JOINERS:
            kept.append(char)
        elif char.isspace() or char in ".,?!;:-–—\n":
            kept.append(" ")
    return re.sub(r"\s+", " ", "".join(kept)).strip()


def grapheme_clusters(text: str) -> List[str]:
    """Return practical Sinhala orthographic clusters without extra packages.

    Sinhala dependent-vowel signs, virama and joiners remain attached to their
    base.  This is preferable to scoring raw Unicode code points.
    """
    clusters: List[str] = []
    current = ""
    previous = ""
    for char in normalize_sinhala(text):
        if char.isspace():
            if current:
                clusters.append(current)
                current = ""
            clusters.append(" ")
            previous = char
            continue
        category = unicodedata.category(char)
        attaches = (
            not current
            or category.startswith("M")
            or char in _JOINERS
            or char == _VIRAMA
            or previous in _JOINERS
            or previous == _VIRAMA
        )
        if attaches:
            current += char
        else:
            clusters.append(current)
            current = char
        previous = char
    if current:
        clusters.append(current)
    return [cluster for cluster in clusters if cluster != " "]


def _align(expected: Sequence[str], observed: Sequence[str]) -> Dict[str, Any]:
    rows, cols = len(expected) + 1, len(observed) + 1
    dp = [[0] * cols for _ in range(rows)]
    back: List[List[Tuple[str, int, int] | None]] = [
        [None] * cols for _ in range(rows)
    ]
    for i in range(1, rows):
        dp[i][0] = i
        back[i][0] = ("deletion", i - 1, 0)
    for j in range(1, cols):
        dp[0][j] = j
        back[0][j] = ("insertion", 0, j - 1)
    for i in range(1, rows):
        for j in range(1, cols):
            same = expected[i - 1] == observed[j - 1]
            choices = [
                (dp[i - 1][j] + 1, "deletion"),
                (dp[i][j - 1] + 1, "insertion"),
                (dp[i - 1][j - 1] + (0 if same else 1), "match" if same else "substitution"),
            ]
            cost, operation = min(choices, key=lambda value: value[0])
            dp[i][j] = cost
            back[i][j] = (operation, i - 1, j - 1)

    i, j = len(expected), len(observed)
    operations: List[Dict[str, Any]] = []
    counts = {"matches": 0, "substitutions": 0, "deletions": 0, "insertions": 0}
    while i > 0 or j > 0:
        operation = back[i][j][0] if back[i][j] else "match"
        if operation in {"match", "substitution"}:
            expected_value, observed_value = expected[i - 1], observed[j - 1]
            i, j = i - 1, j - 1
        elif operation == "deletion":
            expected_value, observed_value = expected[i - 1], None
            i -= 1
        else:
            expected_value, observed_value = None, observed[j - 1]
            j -= 1
        counts[f"{operation}es" if operation == "match" else f"{operation}s"] += 1
        operations.append(
            {"operation": operation, "expected": expected_value, "observed": observed_value}
        )
    operations.reverse()
    reference_count = len(expected)
    errors = counts["substitutions"] + counts["deletions"] + counts["insertions"]
    error_rate = (errors / reference_count) if reference_count else None
    accuracy = max(0.0, 1.0 - error_rate) if error_rate is not None else None
    return {
        **counts,
        "reference_count": reference_count,
        "observed_count": len(observed),
        "error_count": errors,
        "error_rate": error_rate,
        "accuracy": accuracy,
        "operations": operations,
    }


def _adjacent_repetitions(words: Sequence[str]) -> int:
    return sum(1 for left, right in zip(words, words[1:]) if left == right)


class SinhalaAlignmentService:
    def compare(
        self,
        expected_text: str,
        recognized_text: str,
        allowed_variants: Iterable[str] | None = None,
    ) -> Dict[str, Any]:
        references = [expected_text, *(allowed_variants or [])]
        observed_normalized = normalize_sinhala(recognized_text)
        candidates = []
        for reference in references:
            normalized = normalize_sinhala(reference)
            words = normalized.split()
            observed_words = observed_normalized.split()
            word_result = _align(words, observed_words)
            grapheme_result = _align(
                grapheme_clusters(normalized), grapheme_clusters(observed_normalized)
            )
            candidates.append((normalized, word_result, grapheme_result))
        selected = min(
            candidates,
            key=lambda candidate: (
                candidate[2]["error_rate"] if candidate[2]["error_rate"] is not None else 999,
                candidate[1]["error_rate"] if candidate[1]["error_rate"] is not None else 999,
            ),
        )
        selected_reference, word_result, grapheme_result = selected
        observed_words = observed_normalized.split()
        return {
            "expected_normalized": selected_reference,
            "recognized_normalized": observed_normalized,
            "exact_match": bool(selected_reference) and selected_reference == observed_normalized,
            "word": word_result,
            "grapheme": grapheme_result,
            "adjacent_repetitions": _adjacent_repetitions(observed_words),
            "version": ALIGNMENT_VERSION,
        }
