"""Replay labelled events through C4 at a controlled rate for system testing."""

from __future__ import annotations

import argparse
import asyncio
import csv
import json

import httpx


async def main_async(args) -> None:
    """Replay labelled synthetic trigger events through the live API."""
    with open(args.input, encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    async with httpx.AsyncClient(timeout=15.0) as client:
        for index, row in enumerate(rows[:args.limit]):
            payload = {
                "student_id": row["student_id"],
                "session_id": row["session_id"],
                "event_id": f"replay:{row['dataset_id']}:{index}",
                "activity_id": args.activity_id,
                "knowledge_component_id": args.knowledge_component_id,
                "item_id": args.item_id,
                # This endpoint call represents the support-triggering wrong
                # attempt. The simulated later outcome remains in the source
                # dataset and is never mislabeled as an observed completion.
                "is_correct": False,
                "difficulty_b": float(row["difficulty_b"]),
                "current_session_duration_sec": int(float(row["latency_seconds"])),
                "fatigue_score": float(row["fatigue"]),
                "phase": "ATTEMPT",
                "data_origin": "synthetic",
                "dataset_id": row["dataset_id"],
                "validation_status": "synthetic_only",
                "calibration_eligible": False,
                "policy_mode": "simulation",
                "telemetry": {
                    "total_round_latency_ms": int(float(row["latency_seconds"]) * 1000),
                    "attempt_count": int(row["attempt_count"]),
                    "incorrect_attempt_count": int(row["incorrect_attempt_count"]),
                    "hesitation_count": int(row["hesitation_count"]),
                    "misclick_count": int(row["misclick_count"]),
                    "original_options_count": int(row["options_count"]),
                    "supported_actions": ["REMOVE_OPTION", "HIGHLIGHT_OPTION", "REPLAY_INSTRUCTION"],
                },
            }
            response = await client.post(args.url.rstrip("/") + "/update_interaction", json=payload)
            response.raise_for_status()
            print(json.dumps({"index": index, "status": response.status_code, "decision": response.json()["next_action"]["decision"]}))
            if args.interval > 0:
                await asyncio.sleep(args.interval)


def main() -> None:
    """Parse replay controls and run the asynchronous sender."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--url", default="http://127.0.0.1:9017")
    parser.add_argument("--activity-id", default="2.1")
    parser.add_argument("--item-id", default="S2A1R01")
    parser.add_argument("--knowledge-component-id", default="KC_AKSHARA_IDENTITY")
    parser.add_argument("--limit", type=int, default=20)
    parser.add_argument("--interval", type=float, default=0.25)
    args = parser.parse_args()
    asyncio.run(main_async(args))


if __name__ == "__main__":
    main()
