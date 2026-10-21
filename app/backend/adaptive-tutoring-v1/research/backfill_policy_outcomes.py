"""Backfill auditable policy outcomes from already stored observed events.

Dry-run is the default. The script never synthesizes an outcome: a proximal
link requires a later response event for the same item, and a distal link
requires a completed independent V2 confirmation in the same session/group.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
import re
from typing import Any, Dict, Iterable, List, Optional

from pymongo import MongoClient


def _timestamp(value: Any) -> Optional[datetime]:
    """Normalize stored datetime or ISO text to a timezone-aware value."""
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    if isinstance(value, str) and value:
        try:
            parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
            return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)
        except ValueError:
            return None
    return None


def _group_id(row: Dict[str, Any]) -> str:
    """Resolve a core equivalent-group ID from a policy or evidence row."""
    value = row.get("equivalent_group_id") or row.get("item_id") or row.get("current_item") or ""
    return re.sub(r"V\d+$", "", str(value), flags=re.IGNORECASE)


def build_backfill_updates(
    policies: Iterable[Dict[str, Any]],
    telemetry: Iterable[Dict[str, Any]],
    decisions: Iterable[Dict[str, Any]],
) -> List[Dict[str, Any]]:
    """Return exact `_id` + `$set` updates supported by stored observations."""
    telemetry_rows = list(telemetry)
    decision_by_event = {
        row.get("event_id"): row for row in decisions if row.get("event_id")
    }
    confirmations: Dict[tuple, Dict[str, Any]] = {}
    for row in decisions:
        item = str(row.get("current_item") or row.get("item_id") or "")
        role = str(row.get("item_role") or "").upper()
        if role != "CONFIRMATION" and not re.search(r"V2$", item, re.IGNORECASE):
            continue
        key = (row.get("student_id"), row.get("session_id"), _group_id(row))
        current = confirmations.get(key)
        if current is None or (_timestamp(row.get("timestamp")) or datetime.min.replace(tzinfo=timezone.utc)) > (
            _timestamp(current.get("timestamp")) or datetime.min.replace(tzinfo=timezone.utc)
        ):
            confirmations[key] = row

    updates = []
    for policy in policies:
        policy_time = _timestamp(policy.get("timestamp"))
        item_id = str(policy.get("item_id") or "")
        group_id = _group_id(policy)
        set_fields: Dict[str, Any] = {}
        if group_id and not policy.get("equivalent_group_id"):
            set_fields["equivalent_group_id"] = group_id
        if not policy.get("item_role"):
            set_fields["item_role"] = "CORE"

        if policy.get("proximal_outcome_observed") is not True and policy_time:
            candidates = []
            for event in telemetry_rows:
                event_time = _timestamp(event.get("timestamp"))
                if (
                    event.get("student_id") == policy.get("student_id")
                    and event.get("session_id") == policy.get("session_id")
                    and str(event.get("item_id") or "") == item_id
                    and event.get("event_id") != policy.get("event_id")
                    and str(event.get("phase") or "").upper() in {"ATTEMPT", "COMPLETE"}
                    and event_time
                    and event_time > policy_time
                ):
                    candidates.append((event_time, event))
            if candidates:
                _, proximal = min(candidates, key=lambda pair: pair[0])
                proximal_decision = decision_by_event.get(proximal.get("event_id"), {})
                proximal_correct = bool(
                    proximal.get("final_correct")
                    if isinstance(proximal.get("final_correct"), bool)
                    else proximal.get("is_correct")
                )
                proximal_phase = str(proximal.get("phase") or "").upper()
                set_fields.update({
                    "proximal_outcome_observed": True,
                    "proximal_next_response_correct": proximal_correct,
                    "proximal_response_phase": proximal_phase,
                    "proximal_response_event_id": proximal.get("event_id"),
                    "proximal_response_quality": (
                        proximal_decision.get("response_quality")
                        or ("INCORRECT_ATTEMPT" if not proximal_correct else "CORRECT_RESPONSE")
                    ),
                    "proximal_outcome_backfill_method": "stored_next_response_v1",
                })

        confirmation = confirmations.get((
            policy.get("student_id"), policy.get("session_id"), group_id
        ))
        if policy.get("outcome_observed") is not True and confirmation:
            first_correct = confirmation.get("learning_observation_correct")
            if not isinstance(first_correct, bool):
                first_correct = confirmation.get("first_attempt_correct")
            final_correct = confirmation.get("is_correct")
            if isinstance(first_correct, bool) and isinstance(final_correct, bool):
                set_fields.update({
                    "outcome_observed": True,
                    "outcome_definition": "equivalent_confirmation_first_attempt_success",
                    "outcome_first_attempt_correct": first_correct,
                    "outcome_final_correct": final_correct,
                    "outcome_response_quality": confirmation.get("response_quality"),
                    "outcome_item_id": confirmation.get("current_item") or confirmation.get("item_id"),
                    "outcome_event_id": confirmation.get("event_id"),
                    "outcome_phase": "CONFIRMATION",
                    "outcome_backfill_method": "stored_equivalent_confirmation_v1",
                })

        if set_fields:
            updates.append({"_id": policy["_id"], "set": set_fields})
    return updates


def main() -> None:
    """Plan or apply evidence-backed policy-outcome links in MongoDB."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--student-id")
    parser.add_argument("--session-id")
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    uri = os.getenv("MONGODB_URI") or os.getenv("MONGODB_URL")
    if not uri:
        raise RuntimeError("Set MONGODB_URI or MONGODB_URL.")
    db_name = os.getenv("MONGODB_DB", os.getenv("MONGODB_DB_NAME", "r26_se_031"))
    query: Dict[str, Any] = {}
    if args.student_id:
        query["student_id"] = args.student_id
    if args.session_id:
        query["session_id"] = args.session_id

    client = MongoClient(uri, serverSelectionTimeoutMS=10000)
    db = client[db_name]
    try:
        policies = list(db.policy_decisions.find(query).sort("_id", 1))
        event_query = {key: value for key, value in query.items() if key in {"student_id", "session_id"}}
        telemetry = list(db.telemetry_events.find({
            **event_query,
            "phase": {"$in": ["ATTEMPT", "COMPLETE"]},
        }).sort("_id", 1))
        decisions = list(db.adaptive_decisions.find(event_query).sort("_id", 1))
        updates = build_backfill_updates(policies, telemetry, decisions)
        applied = 0
        if args.apply:
            now = datetime.now(timezone.utc).isoformat()
            for update in updates:
                result = db.policy_decisions.update_one(
                    {"_id": update["_id"]},
                    {"$set": {**update["set"], "outcome_backfilled_at": now}},
                )
                applied += result.modified_count
        report = {
            "database": db_name,
            "mode": "apply" if args.apply else "dry_run",
            "policy_rows_examined": len(policies),
            "rows_with_evidence_backfill": len(updates),
            "rows_modified": applied,
            "proximal_links_planned": sum(
                1 for row in updates if row["set"].get("proximal_outcome_observed") is True
            ),
            "confirmation_links_planned": sum(
                1 for row in updates if row["set"].get("outcome_observed") is True
            ),
        }
        print(json.dumps(report, ensure_ascii=False, indent=2))
    finally:
        client.close()


if __name__ == "__main__":
    main()
