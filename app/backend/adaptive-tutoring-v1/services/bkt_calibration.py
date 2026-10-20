"""Auditable offline BKT calibration from independent response sequences.

The small constrained grid is intentional: it is deterministic, explainable,
and appropriate for a pilot dataset. Parameters are never fitted during child
play and KCs below the evidence thresholds are omitted.
"""

from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass
from math import log
from typing import Dict, Iterable, Mapping


@dataclass(frozen=True)
class BKTCalibrationResult:
    """Approved per-KC parameters and held-out calibration evidence."""

    parameters: Dict[str, tuple[float, float, float, float]]
    observation_counts: Dict[str, int]
    student_counts: Dict[str, int]
    validation_log_loss: Dict[str, float]


def _next_mastery(
    mastery: float,
    correct: bool,
    transition: float,
    guess: float,
    slip: float,
) -> float:
    """Apply one Bayesian knowledge-tracing observation and transition."""
    likelihood_known = 1.0 - slip if correct else slip
    likelihood_unknown = guess if correct else 1.0 - guess
    denominator = mastery * likelihood_known + (1.0 - mastery) * likelihood_unknown
    posterior = mastery * likelihood_known / denominator if denominator else mastery
    return posterior + (1.0 - posterior) * transition


def _sequence_loss(
    sequences: Iterable[list[bool]],
    params: tuple[float, float, float, float],
) -> tuple[float, int]:
    """Return mean predictive log loss across learner sequences."""
    initial, transition, guess, slip = params
    total = 0.0
    count = 0
    for sequence in sequences:
        mastery = initial
        for correct in sequence:
            probability = mastery * (1.0 - slip) + (1.0 - mastery) * guess
            probability = min(1.0 - 1e-9, max(1e-9, probability))
            total -= log(probability if correct else 1.0 - probability)
            count += 1
            mastery = _next_mastery(
                mastery, correct, transition, guess, slip
            )
    return total / max(1, count), count


def fit_bkt_by_kc(
    responses: Iterable[Mapping[str, object]],
    *,
    min_kc_responses: int = 200,
    min_students: int = 30,
) -> BKTCalibrationResult:
    """Fit P(L0), P(T), P(G), P(S) per KC with learner-level holdout."""
#group correct/incorrect responses by learner and KC#
    grouped: dict[str, dict[str, list[tuple[str, bool]]]] = defaultdict(
        lambda: defaultdict(list)
    )
    for index, response in enumerate(responses):
        student = str(response.get("student_id", "")).strip()
        kc = str(response.get("knowledge_component_id", "")).strip()
        correct = response.get("is_correct")
        if not student or not kc or kc == "KC_UNKNOWN" or not isinstance(correct, bool):
            continue
        order = str(response.get("timestamp", index))
        grouped[kc][student].append((order, correct))

    parameters: Dict[str, tuple[float, float, float, float]] = {}
    observation_counts: Dict[str, int] = {}
    student_counts: Dict[str, int] = {}
    validation_losses: Dict[str, float] = {}
    #Create parameter grid#
    candidates = (
        (initial, transition, guess, slip)
        for initial in (0.1, 0.2, 0.3, 0.4, 0.5, 0.6)
        for transition in (0.03, 0.07, 0.1, 0.15, 0.2)
        for guess in (0.05, 0.1, 0.15, 0.2, 0.25, 0.3)
        for slip in (0.05, 0.1, 0.15, 0.2, 0.25)
        if guess + slip < 0.5
    )
    candidate_grid = tuple(candidates)
#Learner-level training/validation split#
    for kc, by_student in grouped.items():
        ordered_students = sorted(by_student)
        observation_count = sum(len(sequence) for sequence in by_student.values())
        if observation_count < min_kc_responses or len(ordered_students) < min_students:
            continue

        holdout_size = max(1, len(ordered_students) // 5)
        validation_ids = set(ordered_students[::max(1, len(ordered_students) // holdout_size)][:holdout_size])
        train_sequences = [
            [correct for _, correct in sorted(by_student[student])]
            for student in ordered_students
            if student not in validation_ids
        ]
        validation_sequences = [
            [correct for _, correct in sorted(by_student[student])]
            for student in ordered_students
            if student in validation_ids
        ]
        best = min(
            candidate_grid,
            key=lambda params: _sequence_loss(train_sequences, params)[0],
        )
        validation_loss, _ = _sequence_loss(validation_sequences, best)
        parameters[kc] = best
        observation_counts[kc] = observation_count
        student_counts[kc] = len(ordered_students)
        validation_losses[kc] = round(validation_loss, 6)

    return BKTCalibrationResult(
        parameters=parameters,
        observation_counts=observation_counts,
        student_counts=student_counts,
        validation_log_loss=validation_losses,
    )
