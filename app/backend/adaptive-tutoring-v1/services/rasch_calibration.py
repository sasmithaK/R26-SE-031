"""Small, auditable Rasch calibrator for Component 4 item difficulties.

This is intentionally not invoked during gameplay. Calibration is an offline
research operation performed only after enough real, consented first-attempt
responses are available. Student ability and item difficulty are estimated
together with regularized stochastic gradient ascent.
"""

from __future__ import annotations

from collections import Counter
from dataclasses import dataclass
from math import exp, log
from random import Random
from typing import Dict, Iterable, List, Mapping


@dataclass(frozen=True)
class RaschCalibrationResult:
    """Offline item, learner, sample, and convergence estimates."""

    item_difficulties: Dict[str, float]
    item_sample_counts: Dict[str, int]
    student_abilities: Dict[str, float]
    observations_used: int
    log_loss: float
    converged: bool
    epochs_run: int


def _sigmoid(value: float) -> float:
    """Evaluate a numerically stable logistic function."""
    if value >= 0:
        inverse = exp(-value)
        return 1.0 / (1.0 + inverse)
    positive = exp(value)
    return positive / (1.0 + positive)


def fit_rasch(
    responses: Iterable[Mapping[str, object]],
    *,
    min_item_responses: int = 30,
    epochs: int = 300,
    learning_rate: float = 0.03,
    regularization: float = 0.02,
    seed: int = 20261006,
) -> RaschCalibrationResult:
    """Fit a 1PL/Rasch model to independent binary item responses.

    Required fields are ``student_id``, ``item_id``, and ``is_correct``.
    Items below ``min_item_responses`` are excluded rather than assigned a
    misleading estimate. Returned logits are clamped to [-3, 3].
    """

    rows: List[tuple[str, str, float]] = []
    for response in responses:
        student_id = str(response.get("student_id", "")).strip()
        item_id = str(response.get("item_id", "")).strip()
        correctness = response.get("is_correct")
        if not student_id or not item_id or not isinstance(correctness, bool):
            continue
        rows.append((student_id, item_id, 1.0 if correctness else 0.0))

    counts = Counter(item_id for _, item_id, _ in rows)
    eligible = {item_id for item_id, count in counts.items()
                if count >= min_item_responses}
    rows = [row for row in rows if row[1] in eligible]
    if not rows:
        return RaschCalibrationResult({}, {}, {}, 0, 0.0, False, 0)

    theta = {student_id: 0.0 for student_id, _, _ in rows}
    difficulty = {item_id: 0.0 for _, item_id, _ in rows}
    rng = Random(seed)
    previous_loss = float("inf")
    converged = False
    epochs_run = 0

    for epoch in range(epochs):
        rng.shuffle(rows)
        for student_id, item_id, observed in rows:
            probability = _sigmoid(theta[student_id] - difficulty[item_id])
            error = observed - probability
            theta[student_id] += learning_rate * (
                error - regularization * theta[student_id]
            )
            difficulty[item_id] += learning_rate * (
                -error - regularization * difficulty[item_id]
            )

        # Resolve Rasch location non-identifiability while preserving theta-b.
        center = sum(theta.values()) / len(theta)
        for student_id in theta:
            theta[student_id] -= center
        for item_id in difficulty:
            difficulty[item_id] -= center

        loss = _log_loss(rows, theta, difficulty)
        epochs_run = epoch + 1
        if abs(previous_loss - loss) < 1e-7:
            converged = True
            break
        previous_loss = loss

    difficulty = {
        item_id: round(max(-3.0, min(3.0, value)), 4)
        for item_id, value in difficulty.items()
    }
    theta = {
        student_id: round(max(-4.0, min(4.0, value)), 4)
        for student_id, value in theta.items()
    }
    return RaschCalibrationResult(
        item_difficulties=difficulty,
        item_sample_counts={item_id: counts[item_id] for item_id in difficulty},
        student_abilities=theta,
        observations_used=len(rows),
        log_loss=round(_log_loss(rows, theta, difficulty), 6),
        converged=converged,
        epochs_run=epochs_run,
    )


def _log_loss(
    rows: Iterable[tuple[str, str, float]],
    theta: Mapping[str, float],
    difficulty: Mapping[str, float],
) -> float:
    """Calculate average binary cross-entropy for Rasch predictions."""
    total = 0.0
    count = 0
    for student_id, item_id, observed in rows:
        probability = min(
            1.0 - 1e-9,
            max(1e-9, _sigmoid(theta[student_id] - difficulty[item_id])),
        )
        total -= observed * log(probability) + (1.0 - observed) * log(
            1.0 - probability
        )
        count += 1
    return total / max(1, count)
