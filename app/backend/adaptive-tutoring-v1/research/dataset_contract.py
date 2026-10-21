"""Shared, explicit research-dataset contract for Component 4."""

from __future__ import annotations

from typing import Any, Dict


ORIGINS = {"observed", "synthetic", "public_external"}


def validate_row(row: Dict[str, Any]) -> list[str]:
    """Return provenance and label errors for one research dataset row."""
    errors = []
    if row.get("data_origin") not in ORIGINS:
        errors.append("INVALID_DATA_ORIGIN")
    if not row.get("dataset_id"):
        errors.append("MISSING_DATASET_ID")
    if not row.get("student_id"):
        errors.append("MISSING_STUDENT_ID")
    if not row.get("item_id"):
        errors.append("MISSING_ITEM_ID")
    if not isinstance(row.get("first_attempt_correct"), bool):
        errors.append("MISSING_BINARY_FIRST_ATTEMPT_OUTCOME")
    if row.get("data_origin") != "observed" and row.get("calibration_eligible"):
        errors.append("NON_OBSERVED_CALIBRATION_BLOCKED")
    return errors


def provenance(
    *, data_origin: str, dataset_id: str, validation_status: str
) -> Dict[str, Any]:
    """Build non-calibrating provenance fields for imported/generated data."""
    if data_origin not in ORIGINS:
        raise ValueError(f"Unsupported data origin: {data_origin}")
    return {
        "data_origin": data_origin,
        "dataset_id": dataset_id,
        "validation_status": validation_status,
        "calibration_eligible": False,
    }
