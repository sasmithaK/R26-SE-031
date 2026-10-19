"""Dry-run-first governance gate for making observed rows calibratable."""

from __future__ import annotations

import argparse
import os

from pymongo import MongoClient


def main() -> None:
    """Approve a reviewed observed cohort for later calibration."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset-id", required=True)
    parser.add_argument("--approved-by", required=True)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    uri = os.getenv("MONGODB_URI") or os.getenv("MONGODB_URL")
    if not uri:
        raise RuntimeError("Set MONGODB_URI or MONGODB_URL.")
    db = MongoClient(uri)[
        os.getenv("MONGODB_DB", os.getenv("MONGODB_DB_NAME", "r26_se_031"))
    ]
    query = {
        "dataset_id": args.dataset_id,
        "data_origin": "observed",
        "research_eligible": True,
        "phase": "COMPLETE",
        "is_abandoned": {"$ne": True},
    }
    count = db.telemetry_events.count_documents(query)
    print(f"Eligible observed completion rows found: {count}")
    if not args.apply:
        print("DRY RUN: no rows changed. Add --apply only after ethics/data-quality review.")
        return
    result = db.telemetry_events.update_many(query, {"$set": {
        "calibration_eligible": True,
        "validation_status": "pilot_approved",
        "calibration_approved_by": args.approved_by,
    }})
    print(f"Approved {result.modified_count} rows for calibration.")


if __name__ == "__main__":
    main()
