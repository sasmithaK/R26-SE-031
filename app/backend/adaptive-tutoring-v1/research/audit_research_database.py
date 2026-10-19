"""Read-only Component 4 research database audit."""

from __future__ import annotations

import json
import os
from pathlib import Path

from dotenv import load_dotenv
from pymongo import MongoClient


# Match the service startup behaviour: command-line research utilities should
# work from the repository without requiring users to export the same .env
# values a second time. Explicit shell variables still take precedence.
load_dotenv(Path(__file__).resolve().parents[1] / ".env")


def main() -> None:
    """Print a read-only provenance and Component 4 integrity report."""
    uri = os.getenv("MONGODB_URI") or os.getenv("MONGODB_URL")
    if not uri:
        raise RuntimeError("Set MONGODB_URI or MONGODB_URL.")
    db_name = os.getenv("MONGODB_DB", os.getenv("MONGODB_DB_NAME", "r26_se_031"))
    client = MongoClient(uri, serverSelectionTimeoutMS=10000)
    db = client[db_name]
    try:
        origins = list(db.telemetry_events.aggregate([
            {"$group": {"_id": {"$ifNull": ["$data_origin", "missing"]}, "count": {"$sum": 1}}},
            {"$sort": {"_id": 1}},
        ]))
        active_scope = {
            "skill_id": {
                "$in": ["skill_1", "skill_2", "skill_3", "skill_4"]
            },
            "is_active": {"$ne": False},
        }
        role_counts = list(db.item_bank.aggregate([
            {"$match": active_scope},
            {"$group": {"_id": "$item_role", "count": {"$sum": 1}}},
            {"$sort": {"_id": 1}},
        ]))
        exact_target_counts = list(db.item_bank.aggregate([
            {"$match": {
                **active_scope,
                "response_load_relation": {
                    "$in": ["targeted_reduced", "targeted_equivalent"]
                },
            }},
            {"$group": {"_id": "$skill_id", "count": {"$sum": 1}}},
            {"$sort": {"_id": 1}},
        ]))
        missing_practice_metadata = db.item_bank.count_documents({
            **active_scope,
            "$or": [
                {"micro_kc_id": {"$exists": False}},
                {"micro_skill_tags": {"$exists": False}},
                {"primary_targets": {"$exists": False}},
                {"component_units": {"$exists": False}},
                {"content_review_status": {"$exists": False}},
            ],
        })
        baseline_statuses = list(db.student_baseline_profiles.aggregate([
            {"$match": {"baseline_version": "starter-profile-v1"}},
            {"$group": {"_id": "$status", "count": {"$sum": 1}}},
            {"$sort": {"_id": 1}},
        ]))
        invalid_baseline_events = db.baseline_item_events.count_documents({
            "$or": [
                {"baseline_version": {"$ne": "starter-profile-v1"}},
                {"research_role": {"$ne": "baseline_probe"}},
                {"data_origin": {"$ne": "observed_baseline"}},
                {"scaffold_level_used": {"$ne": 0}},
                {"remediation_used": True},
                {"confirmation_used": True},
                {"calibration_eligible": True},
            ],
        })
        completed_profiles = list(db.student_baseline_profiles.find({
            "baseline_version": "starter-profile-v1",
            "status": "completed",
        }, {"student_id": 1}))
        completed_without_c4_initialization = 0
        for profile in completed_profiles:
            if not db.knowledge_states.find_one({
                "student_id": profile.get("student_id"),
                "starter_baseline.baseline_version": "starter-profile-v1",
                "starter_baseline.profile_status": "completed",
            }):
                completed_without_c4_initialization += 1
        report = {
            "database": db_name,
            "active_skill_1_4_items": db.item_bank.count_documents(
                active_scope
            ),
            "active_item_roles": {
                str(row["_id"]): row["count"] for row in role_counts
            },
            "items_missing_practice_metadata": missing_practice_metadata,
            "exact_target_practice_variants": db.item_bank.count_documents({
                **active_scope,
                "response_load_relation": {
                    "$in": ["targeted_reduced", "targeted_equivalent"]
                },
            }),
            "exact_target_practice_variants_by_skill": {
                str(row["_id"]): row["count"]
                for row in exact_target_counts
            },
            "telemetry_events": db.telemetry_events.count_documents({}),
            "telemetry_origins": {row["_id"]: row["count"] for row in origins},
            "events_missing_dataset_id": db.telemetry_events.count_documents({
                "$or": [{"dataset_id": {"$exists": False}}, {"dataset_id": None}],
            }),
            "approved_calibration_completions": db.telemetry_events.count_documents({
                "data_origin": "observed",
                "calibration_eligible": True,
                "validation_status": {"$in": ["pilot_approved", "validated_observed"]},
                "phase": "COMPLETE",
                "research_eligible": True,
            }),
            "invalid_nonobserved_calibration_rows": db.telemetry_events.count_documents({
                "calibration_eligible": True,
                "data_origin": {"$ne": "observed"},
            }),
            "adaptive_decisions": db.adaptive_decisions.count_documents({}),
            "adaptive_decisions_with_error_profiles": (
                db.adaptive_decisions.count_documents({
                    "error_profile.profile_version": "C4_ERROR_PROFILE_V1",
                })
            ),
            "dynamic_practice_selections": db.adaptive_decisions.count_documents({
                "practice_selection_strategy": "dynamic_targeted_practice_v1",
            }),
            "dynamic_practice_model_controlled_selections": (
                db.adaptive_decisions.count_documents({
                    "practice_selection_strategy": (
                        "dynamic_targeted_practice_v1"
                    ),
                    "practice_model_controls_live_adaptation": True,
                })
            ),
            "policy_decisions": db.policy_decisions.count_documents({}),
            "policy_decisions_with_proximal_outcomes": db.policy_decisions.count_documents({
                "proximal_outcome_observed": True,
            }),
            "policy_decisions_with_linked_outcomes": db.policy_decisions.count_documents({
                "outcome_observed": True,
            }),
            "observed_kinematic_sessions": db.kinematic_features.count_documents({
                "data_origin": "observed",
                "measurement_status": "available",
            }),
            "starter_baseline": {
                "version": "starter-profile-v1",
                "profiles": db.student_baseline_profiles.count_documents({
                    "baseline_version": "starter-profile-v1",
                }),
                "status_counts": {
                    str(row["_id"]): row["count"] for row in baseline_statuses
                },
                "item_events": db.baseline_item_events.count_documents({
                    "baseline_version": "starter-profile-v1",
                }),
                "invalid_contract_events": invalid_baseline_events,
                "completed_without_c4_initialization": (
                    completed_without_c4_initialization
                ),
                "scope": (
                    "cold_start_only; no scaffold, remediation, confirmation, "
                    "diagnostic claim, or calibration eligibility"
                ),
            },
            "active_unapproved_bkt_models": db.model_registry.count_documents({
                "model_type": "BKT",
                "status": "active",
                "$or": [
                    {"data_origin": {"$ne": "observed"}},
                    {"validation_status": {"$nin": ["pilot_approved", "validated_observed"]}},
                ],
            }),
        }
        report["blocking_integrity_errors"] = (
            report["invalid_nonobserved_calibration_rows"]
            + report["items_missing_practice_metadata"]
            + invalid_baseline_events
            + completed_without_c4_initialization
        )
        print(json.dumps(report, indent=2, ensure_ascii=False))
    finally:
        client.close()


if __name__ == "__main__":
    main()
