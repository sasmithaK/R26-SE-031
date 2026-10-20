"""Normalize a local ASSISTments/EdNet-style CSV without claiming Sinhala equivalence."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path


ALIASES = {
    "student_id": ("student_id", "user_id", "Anon Student Id"),
    "item_id": ("item_id", "problem_id", "problem_name"),
    "knowledge_component_id": ("skill_id", "skill_name", "KC(Default)"),
    "first_attempt_correct": ("correct", "correctness", "First Attempt"),
    "timestamp": ("timestamp", "start_time", "First Transaction Time"),
}


def value(row, names):
    """Return the first populated value among supported public aliases."""
    return next((row[name] for name in names if row.get(name) not in (None, "")), "")


def main() -> None:
    """Normalize a public KT CSV as external, non-calibrating evidence."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--dataset-id", required=True)
    parser.add_argument("--source-name", required=True)
    args = parser.parse_args()
    with Path(args.input).open(encoding="utf-8-sig", newline="") as source:
        rows = list(csv.DictReader(source))
    normalized = []
    for index, row in enumerate(rows):
        correct = str(value(row, ALIASES["first_attempt_correct"])).strip().lower()
        normalized.append({
            "student_id": value(row, ALIASES["student_id"]),
            "session_id": f"{args.dataset_id}:{index // 20}",
            "item_id": value(row, ALIASES["item_id"]),
            "knowledge_component_id": value(row, ALIASES["knowledge_component_id"]),
            "first_attempt_correct": correct in {"1", "true", "correct"},
            "timestamp": value(row, ALIASES["timestamp"]),
            "data_origin": "public_external",
            "dataset_id": args.dataset_id,
            "source_name": args.source_name,
            "domain_mapping": "external_benchmark_only",
            "validation_status": "public_external_not_sinhala",
            "calibration_eligible": False,
        })
    if not normalized:
        raise RuntimeError("The input CSV contains no data rows.")
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8", newline="") as target:
        writer = csv.DictWriter(target, fieldnames=list(normalized[0]))
        writer.writeheader()
        writer.writerows(normalized)
    print(f"Normalized {len(normalized)} external benchmark rows; calibration remains blocked.")


if __name__ == "__main__":
    main()
