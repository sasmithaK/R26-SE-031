"""Idempotently seed the research item bank from the app curriculum."""

from item_bank_builder import build_items, validation_summary


def _quarantine_superseded_activity_evidence(
    db,
    items,
    *,
    activity_id: str,
    include_core: bool = False,
) -> tuple[int, int, int]:
    """Retain observations but exclude evidence for superseded item content."""
    scoped_items = [
        item for item in items
        if item["activity_id"] == activity_id
        and (include_core or not item["is_core"])
    ]
    scoped_item_ids = [item["item_id"] for item in scoped_items]
    expected_version = max(item["item_version"] for item in scoped_items)
    reason = "ITEM_CONTENT_VERSION_SUPERSEDED"

    decision_result = db.adaptive_decisions.update_many(
        {
            "current_item": {"$in": scoped_item_ids},
            "item_version": {"$ne": expected_version},
        },
        {
            "$set": {"research_eligible": False},
            "$addToSet": {"research_validation_errors": reason},
        },
    )
    event_result = db.telemetry_events.update_many(
        {
            "item_id": {"$in": scoped_item_ids},
            "item_version": {"$ne": expected_version},
        },
        {
            "$set": {"research_eligible": False},
            "$addToSet": {"research_validation_errors": reason},
        },
    )
    session_result = db.telemetry_sessions.update_many(
        {
            "events": {
                "$elemMatch": {
                    "item_id": {"$in": scoped_item_ids},
                    "item_version": {"$ne": expected_version},
                }
            }
        },
        {
            "$set": {"events.$[event].research_eligible": False},
            "$addToSet": {
                "events.$[event].research_validation_errors": reason
            },
        },
        array_filters=[{
            "event.item_id": {"$in": scoped_item_ids},
            "event.item_version": {"$ne": expected_version},
        }],
    )
    return (
        decision_result.modified_count,
        event_result.modified_count,
        session_result.modified_count,
    )


def quarantine_superseded_skill_two_activity_one_evidence(db, items) -> dict:
    """Exclude observations collected against pre-version-5 Activity 1 items."""
    decisions, events, sessions = _quarantine_superseded_activity_evidence(
        db,
        items,
        activity_id="2.1",
    )
    return {
        "superseded_adaptive_decisions": decisions,
        "superseded_telemetry_events": events,
        "superseded_telemetry_sessions": sessions,
    }


def quarantine_superseded_skill_two_activity_two_evidence(db, items) -> dict:
    """Exclude observations collected against pre-version-3 Activity 2 items."""
    decisions, events, sessions = _quarantine_superseded_activity_evidence(
        db,
        items,
        activity_id="2.2",
    )
    return {
        "superseded_s2a2_adaptive_decisions": decisions,
        "superseded_s2a2_telemetry_events": events,
        "superseded_s2a2_telemetry_sessions": sessions,
    }


def quarantine_superseded_skill_two_activity_three_evidence(db, items) -> dict:
    """Exclude observations collected against pre-version-3 Activity 3 items."""
    decisions, events, sessions = _quarantine_superseded_activity_evidence(
        db,
        items,
        activity_id="2.3",
        include_core=True,
    )
    return {
        "superseded_s2a3_adaptive_decisions": decisions,
        "superseded_s2a3_telemetry_events": events,
        "superseded_s2a3_telemetry_sessions": sessions,
    }


def quarantine_superseded_skill_two_activity_four_evidence(db, items) -> dict:
    """Exclude observations collected against pre-version-6 Activity 4 items."""
    decisions, events, sessions = _quarantine_superseded_activity_evidence(
        db,
        items,
        activity_id="2.4",
        include_core=True,
    )
    return {
        "superseded_s2a4_adaptive_decisions": decisions,
        "superseded_s2a4_telemetry_events": events,
        "superseded_s2a4_telemetry_sessions": sessions,
    }


def quarantine_superseded_skill_two_activity_five_evidence(db, items) -> dict:
    """Exclude observations collected against pre-version-3 Activity 5 items."""
    decisions, events, sessions = _quarantine_superseded_activity_evidence(
        db,
        items,
        activity_id="2.5",
        include_core=True,
    )
    return {
        "superseded_s2a5_adaptive_decisions": decisions,
        "superseded_s2a5_telemetry_events": events,
        "superseded_s2a5_telemetry_sessions": sessions,
    }


def remove_legacy_skill_two_activity_four_fields(db, items) -> dict:
    """Remove metadata that is not part of the canonical Activity 4 schema."""
    item_ids = [
        item["item_id"] for item in items if item["activity_id"] == "2.4"
    ]
    result = db.item_bank.update_many(
        {"item_id": {"$in": item_ids}},
        {"$unset": {"frontend_item_alias": ""}},
    )
    return {"cleaned_s2a4_legacy_item_records": result.modified_count}


def remove_legacy_skill_two_activities_one_to_three_fields(db, items) -> dict:
    """Remove obsolete aliases without touching Rasch calibration metadata."""
    item_ids = [
        item["item_id"]
        for item in items
        if item["activity_id"] in {"2.1", "2.2", "2.3"}
    ]
    result = db.item_bank.update_many(
        {"item_id": {"$in": item_ids}},
        {"$unset": {
            "frontend_item_alias": "",
            "kc_id": "",
            "target": "",
            "variant": "",
            # These came from the retired prototype item schema. Current BKT
            # parameters live in model_registry and Rasch fields use explicit
            # calibration_* names, so removing them cannot erase calibration.
            "slip_s": "",
            "created_at": "",
            "updated_at": "",
        }},
    )
    return {"cleaned_s2a1_to_s2a3_legacy_item_records": result.modified_count}


def remove_legacy_skill_two_activity_five_fields(db, items) -> dict:
    """Remove pre-canonical Activity 5 aliases and difficulty fields."""
    item_ids = [
        item["item_id"] for item in items if item["activity_id"] == "2.5"
    ]
    result = db.item_bank.update_many(
        {"item_id": {"$in": item_ids}},
        {"$unset": {"difficulty": "", "frontend_item_alias": ""}},
    )
    return {"cleaned_s2a5_legacy_item_records": result.modified_count}


def seed(db) -> dict:
    items = build_items()
    for item in items:
        update = {"$set": item}
        if item["activity_id"] != "2.4":
            update["$unset"] = {"has_floor_remediation": ""}
        db.item_bank.update_one(
            {"item_id": item["item_id"]},
            update,
            upsert=True,
        )
    return {
        **validation_summary(items),
        **remove_legacy_skill_two_activities_one_to_three_fields(db, items),
        **remove_legacy_skill_two_activity_four_fields(db, items),
        **remove_legacy_skill_two_activity_five_fields(db, items),
        **quarantine_superseded_skill_two_activity_one_evidence(db, items),
        **quarantine_superseded_skill_two_activity_two_evidence(db, items),
        **quarantine_superseded_skill_two_activity_three_evidence(db, items),
        **quarantine_superseded_skill_two_activity_four_evidence(db, items),
        **quarantine_superseded_skill_two_activity_five_evidence(db, items),
    }


if __name__ == "__main__":
    import argparse
    import os
    from pymongo import MongoClient

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--apply",
        action="store_true",
        help="write validated item records to MongoDB (default: validate only)",
    )
    args = parser.parse_args()

    items = build_items()
    summary = validation_summary(items)
    if not args.apply:
        print({**summary, "mode": "validation_only"})
    else:
        mongo_url = os.getenv("MONGODB_URI") or os.getenv("MONGODB_URL")
        if not mongo_url:
            raise RuntimeError("Set MONGODB_URI before using --apply")
        database = MongoClient(mongo_url)[
            os.getenv("MONGODB_DB", os.getenv("MONGODB_DB_NAME", "r26_se_031"))
        ]
        print({**seed(database), "mode": "applied"})
