"""Idempotently seed the research item bank from the app curriculum."""

from item_bank_builder import build_items, validation_summary


def _valid_lineage_conditions(
    items,
    *,
    item_field: str,
    version_field: str,
    kc_field: str,
    role_field: str,
    group_field: str,
    difficulty_field: str,
):
    """Describe every active, exact Component 4 item lineage."""
    return [
        {
            item_field: item["item_id"],
            version_field: item["item_version"],
            kc_field: item["knowledge_component_id"],
            role_field: item["item_role"],
            group_field: item["equivalent_group_id"],
            difficulty_field: item["difficulty_b"],
        }
        for item in items
        if item["is_active"]
        and item["skill_id"] in {
            "skill_1", "skill_2", "skill_3", "skill_4"
        }
    ]


def quarantine_invalid_component4_evidence(db, items) -> dict:
    """Preserve, but exclude, non-current Skill 1-4 research evidence.

    This final safety pass requires exact item, version, KC, role, equivalent
    group, and difficulty lineage. It also rejects inactive shared-retry IDs
    and non-canonical IDs without deleting a learner's historical records.
    """
    reason = "ITEM_LINEAGE_NOT_CURRENT"
    decision_conditions = _valid_lineage_conditions(
        items,
        item_field="current_item",
        version_field="item_version",
        kc_field="kc_id",
        role_field="item_role",
        group_field="equivalent_group_id",
        difficulty_field="difficulty_b",
    )
    event_conditions = _valid_lineage_conditions(
        items,
        item_field="item_id",
        version_field="item_version",
        kc_field="knowledge_component_id",
        role_field="item_role",
        group_field="equivalent_group_id",
        difficulty_field="difficulty_b",
    )
    session_conditions = _valid_lineage_conditions(
        items,
        item_field="item_id",
        version_field="item_version",
        kc_field="knowledge_component_id",
        role_field="item_role",
        group_field="equivalent_group_id",
        difficulty_field="difficulty_b",
    )
    array_conditions = _valid_lineage_conditions(
        items,
        item_field="event.item_id",
        version_field="event.item_version",
        kc_field="event.knowledge_component_id",
        role_field="event.item_role",
        group_field="event.equivalent_group_id",
        difficulty_field="event.difficulty_b",
    )

    decision_result = db.adaptive_decisions.update_many(
        {
            "research_eligible": {"$ne": False},
            "current_item": {"$regex": r"^[sS][1-4]"},
            "$nor": decision_conditions,
        },
        {
            "$set": {"research_eligible": False},
            "$addToSet": {"research_validation_errors": reason},
        },
    )
    event_result = db.telemetry_events.update_many(
        {
            "research_eligible": {"$ne": False},
            "item_id": {"$regex": r"^[sS][1-4]"},
            "$nor": event_conditions,
        },
        {
            "$set": {"research_eligible": False},
            "$addToSet": {"research_validation_errors": reason},
        },
    )
    session_result = db.telemetry_sessions.update_many(
        {
            "events": {"$elemMatch": {
                "research_eligible": {"$ne": False},
                "item_id": {"$regex": r"^[sS][1-4]"},
                "$nor": session_conditions,
            }},
        },
        {
            "$set": {"events.$[event].research_eligible": False},
            "$addToSet": {
                "events.$[event].research_validation_errors": reason
            },
        },
        array_filters=[{
            "event.research_eligible": {"$ne": False},
            "event.item_id": {"$regex": r"^[sS][1-4]"},
            "$nor": array_conditions,
        }],
    )
    return {
        "invalid_c4_adaptive_decisions": decision_result.modified_count,
        "invalid_c4_telemetry_events": event_result.modified_count,
        "invalid_c4_telemetry_sessions": session_result.modified_count,
    }


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


def quarantine_superseded_skill_three_evidence(db, items) -> dict:
    """Exclude Skill 3 evidence collected against superseded item content."""
    skill_three_items = [
        item for item in items if item["skill_id"] == "skill_3"
    ]
    canonical_item_ids = [item["item_id"] for item in skill_three_items]
    totals = [0, 0, 0]
    for activity_id in ("3.1", "3.2", "3.3", "3.4", "3.5"):
        activity_totals = _quarantine_superseded_activity_evidence(
            db,
            items,
            activity_id=activity_id,
            include_core=True,
        )
        totals = [
            current + activity
            for current, activity in zip(totals, activity_totals)
        ]

    # Prototype clients used IDs such as S3_A1_R01, which are intentionally
    # absent from the canonical bank. Mark only those non-canonical rows
    # ineligible. Version checks for canonical IDs are handled activity by
    # activity above, allowing independently versioned Skill 3 activities.
    reason = "ITEM_CONTENT_VERSION_SUPERSEDED"
    legacy_decisions = db.adaptive_decisions.update_many(
        {
            "current_item": {
                "$regex": r"^S3",
                "$nin": canonical_item_ids,
            },
            "research_eligible": {"$ne": False},
        },
        {
            "$set": {"research_eligible": False},
            "$addToSet": {"research_validation_errors": reason},
        },
    )
    legacy_events = db.telemetry_events.update_many(
        {
            "skill_id": "skill_3",
            "item_id": {"$nin": canonical_item_ids},
            "research_eligible": {"$ne": False},
        },
        {
            "$set": {"research_eligible": False},
            "$addToSet": {"research_validation_errors": reason},
        },
    )
    legacy_sessions = db.telemetry_sessions.update_many(
        {
            "events": {"$elemMatch": {
                "skill_id": "skill_3",
                "item_id": {"$nin": canonical_item_ids},
                "research_eligible": {"$ne": False},
            }},
        },
        {
            "$set": {"events.$[event].research_eligible": False},
            "$addToSet": {
                "events.$[event].research_validation_errors": reason
            },
        },
        array_filters=[{
            "event.skill_id": "skill_3",
            "event.item_id": {"$nin": canonical_item_ids},
            "event.research_eligible": {"$ne": False},
        }],
    )
    totals = [
        totals[0] + legacy_decisions.modified_count,
        totals[1] + legacy_events.modified_count,
        totals[2] + legacy_sessions.modified_count,
    ]
    return {
        "superseded_s3_adaptive_decisions": totals[0],
        "superseded_s3_telemetry_events": totals[1],
        "superseded_s3_telemetry_sessions": totals[2],
    }


def quarantine_superseded_skill_four_activity_one_evidence(db, items) -> dict:
    """Exclude Activity 4.1 evidence collected against pre-version-5 items."""
    decisions, events, sessions = _quarantine_superseded_activity_evidence(
        db,
        items,
        activity_id="4.1",
        include_core=True,
    )
    return {
        "superseded_s4a1_adaptive_decisions": decisions,
        "superseded_s4a1_telemetry_events": events,
        "superseded_s4a1_telemetry_sessions": sessions,
    }


def quarantine_superseded_skill_four_activity_two_evidence(db, items) -> dict:
    """Exclude Activity 4.2 evidence collected against pre-version-4 items."""
    decisions, events, sessions = _quarantine_superseded_activity_evidence(
        db,
        items,
        activity_id="4.2",
        include_core=True,
    )
    return {
        "superseded_s4a2_adaptive_decisions": decisions,
        "superseded_s4a2_telemetry_events": events,
        "superseded_s4a2_telemetry_sessions": sessions,
    }


def quarantine_superseded_skill_four_activity_three_evidence(db, items) -> dict:
    """Exclude Activity 4.3 evidence collected against pre-version-5 items."""
    decisions, events, sessions = _quarantine_superseded_activity_evidence(
        db,
        items,
        activity_id="4.3",
        include_core=True,
    )
    return {
        "superseded_s4a3_adaptive_decisions": decisions,
        "superseded_s4a3_telemetry_events": events,
        "superseded_s4a3_telemetry_sessions": sessions,
    }


def quarantine_superseded_skill_four_activity_four_evidence(db, items) -> dict:
    """Exclude Activity 4.4 evidence collected against pre-version-4 items."""
    decisions, events, sessions = _quarantine_superseded_activity_evidence(
        db,
        items,
        activity_id="4.4",
        include_core=True,
    )
    return {
        "superseded_s4a4_adaptive_decisions": decisions,
        "superseded_s4a4_telemetry_events": events,
        "superseded_s4a4_telemetry_sessions": sessions,
    }


def retire_removed_skill_four_activity_one_task(db) -> dict:
    """Retain Task 5 history while preventing the retired task being served."""
    retired_ids = ["S4A1R05", "S4A1R05V1", "S4A1R05V2"]
    item_result = db.item_bank.update_many(
        {"item_id": {"$in": retired_ids}},
        {"$set": {
            "is_active": False,
            "research_eligible": False,
            "retired_reason": "REMOVED_FROM_CURRICULUM",
        }},
    )
    decision_result = db.adaptive_decisions.update_many(
        {"current_item": {"$in": retired_ids}},
        {"$set": {"research_eligible": False}, "$addToSet": {
            "research_validation_errors": "ITEM_RETIRED_FROM_CURRICULUM"
        }},
    )
    event_result = db.telemetry_events.update_many(
        {"item_id": {"$in": retired_ids}},
        {"$set": {"research_eligible": False}, "$addToSet": {
            "research_validation_errors": "ITEM_RETIRED_FROM_CURRICULUM"
        }},
    )
    session_result = db.telemetry_sessions.update_many(
        {"events": {"$elemMatch": {"item_id": {"$in": retired_ids}}}},
        {
            "$set": {"events.$[event].research_eligible": False},
            "$addToSet": {
                "events.$[event].research_validation_errors": (
                    "ITEM_RETIRED_FROM_CURRICULUM"
                )
            },
        },
        array_filters=[{"event.item_id": {"$in": retired_ids}}],
    )
    return {
        "retired_s4a1_item_bank_records": item_result.modified_count,
        "retired_s4a1_adaptive_decisions": decision_result.modified_count,
        "retired_s4a1_telemetry_events": event_result.modified_count,
        "retired_s4a1_telemetry_sessions": session_result.modified_count,
    }


def retire_removed_skill_four_activity_two_task(db) -> dict:
    """Retain Activity 4.2 Task 5 history while preventing it being served."""
    retired_ids = ["S4A2R05", "S4A2R05V1", "S4A2R05V2"]
    item_result = db.item_bank.update_many(
        {"item_id": {"$in": retired_ids}},
        {"$set": {
            "is_active": False,
            "research_eligible": False,
            "retired_reason": "REMOVED_FROM_CURRICULUM",
        }},
    )
    decision_result = db.adaptive_decisions.update_many(
        {"current_item": {"$in": retired_ids}},
        {"$set": {"research_eligible": False}, "$addToSet": {
            "research_validation_errors": "ITEM_RETIRED_FROM_CURRICULUM"
        }},
    )
    event_result = db.telemetry_events.update_many(
        {"item_id": {"$in": retired_ids}},
        {"$set": {"research_eligible": False}, "$addToSet": {
            "research_validation_errors": "ITEM_RETIRED_FROM_CURRICULUM"
        }},
    )
    session_result = db.telemetry_sessions.update_many(
        {"events": {"$elemMatch": {"item_id": {"$in": retired_ids}}}},
        {
            "$set": {"events.$[event].research_eligible": False},
            "$addToSet": {
                "events.$[event].research_validation_errors": (
                    "ITEM_RETIRED_FROM_CURRICULUM"
                )
            },
        },
        array_filters=[{"event.item_id": {"$in": retired_ids}}],
    )
    return {
        "retired_s4a2_item_bank_records": item_result.modified_count,
        "retired_s4a2_adaptive_decisions": decision_result.modified_count,
        "retired_s4a2_telemetry_events": event_result.modified_count,
        "retired_s4a2_telemetry_sessions": session_result.modified_count,
    }


def retire_removed_skill_four_activity_three_task(db) -> dict:
    """Retain Activity 4.3 Task 5 history while preventing it being served."""
    retired_ids = ["S4A3R05", "S4A3R05V1", "S4A3R05V2"]
    item_result = db.item_bank.update_many(
        {"item_id": {"$in": retired_ids}},
        {"$set": {
            "is_active": False,
            "research_eligible": False,
            "retired_reason": "REMOVED_FROM_CURRICULUM",
        }},
    )
    decision_result = db.adaptive_decisions.update_many(
        {"current_item": {"$in": retired_ids}},
        {"$set": {"research_eligible": False}, "$addToSet": {
            "research_validation_errors": "ITEM_RETIRED_FROM_CURRICULUM"
        }},
    )
    event_result = db.telemetry_events.update_many(
        {"item_id": {"$in": retired_ids}},
        {"$set": {"research_eligible": False}, "$addToSet": {
            "research_validation_errors": "ITEM_RETIRED_FROM_CURRICULUM"
        }},
    )
    session_result = db.telemetry_sessions.update_many(
        {"events": {"$elemMatch": {"item_id": {"$in": retired_ids}}}},
        {
            "$set": {"events.$[event].research_eligible": False},
            "$addToSet": {
                "events.$[event].research_validation_errors": (
                    "ITEM_RETIRED_FROM_CURRICULUM"
                )
            },
        },
        array_filters=[{"event.item_id": {"$in": retired_ids}}],
    )
    return {
        "retired_s4a3_item_bank_records": item_result.modified_count,
        "retired_s4a3_adaptive_decisions": decision_result.modified_count,
        "retired_s4a3_telemetry_events": event_result.modified_count,
        "retired_s4a3_telemetry_sessions": session_result.modified_count,
    }


def retire_removed_skill_four_activity_four_task(db) -> dict:
    """Retain Activity 4.4 Task 5 history while preventing it being served."""
    retired_ids = ["S4A4R05", "S4A4R05V1", "S4A4R05V2"]
    item_result = db.item_bank.update_many(
        {"item_id": {"$in": retired_ids}},
        {"$set": {
            "is_active": False,
            "research_eligible": False,
            "retired_reason": "REMOVED_FROM_CURRICULUM",
        }},
    )
    decision_result = db.adaptive_decisions.update_many(
        {"current_item": {"$in": retired_ids}},
        {"$set": {"research_eligible": False}, "$addToSet": {
            "research_validation_errors": "ITEM_RETIRED_FROM_CURRICULUM"
        }},
    )
    event_result = db.telemetry_events.update_many(
        {"item_id": {"$in": retired_ids}},
        {"$set": {"research_eligible": False}, "$addToSet": {
            "research_validation_errors": "ITEM_RETIRED_FROM_CURRICULUM"
        }},
    )
    session_result = db.telemetry_sessions.update_many(
        {"events": {"$elemMatch": {"item_id": {"$in": retired_ids}}}},
        {
            "$set": {"events.$[event].research_eligible": False},
            "$addToSet": {
                "events.$[event].research_validation_errors": (
                    "ITEM_RETIRED_FROM_CURRICULUM"
                )
            },
        },
        array_filters=[{"event.item_id": {"$in": retired_ids}}],
    )
    return {
        "retired_s4a4_item_bank_records": item_result.modified_count,
        "retired_s4a4_adaptive_decisions": decision_result.modified_count,
        "retired_s4a4_telemetry_events": event_result.modified_count,
        "retired_s4a4_telemetry_sessions": session_result.modified_count,
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


def remove_legacy_skill_three_fields(db, items) -> dict:
    """Remove aliases from the retired Skill 3 prototype item schema."""
    item_ids = [
        item["item_id"] for item in items if item["skill_id"] == "skill_3"
    ]
    result = db.item_bank.update_many(
        {"item_id": {"$in": item_ids}},
        {"$unset": {"frontend_item_alias": ""}},
    )
    return {"cleaned_s3_legacy_item_records": result.modified_count}


def item_upsert_update(item: dict) -> dict:
    """Build a conflict-free update while clearing obsolete floor metadata."""
    update = {"$set": item}
    if "has_floor_remediation" not in item:
        update["$unset"] = {"has_floor_remediation": ""}
    return update


def seed(db) -> dict:
    """Upsert the canonical bank and quarantine superseded evidence."""
    items = build_items()
    for item in items:
        db.item_bank.update_one(
            {"item_id": item["item_id"]},
            item_upsert_update(item),
            upsert=True,
        )
    return {
        **validation_summary(items),
        **remove_legacy_skill_two_activities_one_to_three_fields(db, items),
        **remove_legacy_skill_two_activity_four_fields(db, items),
        **remove_legacy_skill_two_activity_five_fields(db, items),
        **remove_legacy_skill_three_fields(db, items),
        **quarantine_superseded_skill_two_activity_one_evidence(db, items),
        **quarantine_superseded_skill_two_activity_two_evidence(db, items),
        **quarantine_superseded_skill_two_activity_three_evidence(db, items),
        **quarantine_superseded_skill_two_activity_four_evidence(db, items),
        **quarantine_superseded_skill_two_activity_five_evidence(db, items),
        **quarantine_superseded_skill_three_evidence(db, items),
        **quarantine_superseded_skill_four_activity_one_evidence(db, items),
        **quarantine_superseded_skill_four_activity_two_evidence(db, items),
        **quarantine_superseded_skill_four_activity_three_evidence(db, items),
        **quarantine_superseded_skill_four_activity_four_evidence(db, items),
        **quarantine_invalid_component4_evidence(db, items),
        **retire_removed_skill_four_activity_one_task(db),
        **retire_removed_skill_four_activity_two_task(db),
        **retire_removed_skill_four_activity_three_task(db),
        **retire_removed_skill_four_activity_four_task(db),
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
