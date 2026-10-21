"""End-to-end check, step 1: push simulated sessions through the REAL ingestion.

Simulated learners (round-level simulator, with touch paths) are submitted to
``POST /api/v1/auth/telemetry`` of this service (FastAPI TestClient + an
in-memory MongoDB). The stored collections and the expected numbers, computed
directly from the simulated rounds, are written to a JSON file that the API
dashboard test (api/tests/test_e2e_dashboard_consistency.py) reads.

Usage: python scripts/e2e_ingest_simulated.py OUT.json [learners]
"""
import json
import os
import sys
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
os.environ.setdefault("MONGODB_URL", "mongodb://mock:27017")
os.environ.setdefault("MONGODB_DB_NAME", "e2e")
os.environ.setdefault("JWT_SECRET_KEY", "e2e")

import numpy as np  # noqa: E402
from bson import ObjectId  # noqa: E402
from mongomock_motor import AsyncMongoMockClient  # noqa: E402

patch("database.connect_to_mongo").start()
patch("database.close_mongo_connection").start()

from fastapi.testclient import TestClient  # noqa: E402
from main import app  # noqa: E402
from dependencies import get_current_user  # noqa: E402
from research.c1_simulator import CLASS_NAMES, add_touch_streams, load_config, simulate_learner  # noqa: E402

PARENT = "e2e-parent"
import asyncio  # noqa: E402
LOOP = asyncio.new_event_loop()


def expected_numbers(sessions):
    done = []
    for _, events in sessions:
        seen = set()
        for e in events:
            if e["event_id"] in seen:
                continue
            seen.add(e["event_id"])
            if not e.get("is_abandoned"):
                done.append(e)
    first = [e for e in done if e["first_attempt_correct"]]
    return {"completed_rounds": len(done),
            "first_try_correct": len(first),
            "first_attempt_accuracy": len(first) / len(done) if done else None,
            "sessions": len(sessions)}


def to_payload(student_id, sid, events, when):
    out = []
    for e in events:
        event = {k: v for k, v in e.items() if k not in {"session_id"}}
        event.setdefault("activity_name", "simulated")
        event["first_touch_latency_ms"] = int(event.get("first_touch_latency_ms") or 0)
        event["total_round_latency_ms"] = int(event.get("total_round_latency_ms") or 0)
        event["time_to_correct_ms"] = int(event.get("time_to_correct_ms") or 0)
        event["first_attempt_correct"] = event.get("first_attempt_correct")
        out.append(event)
    return {"student_id": student_id, "session_id": sid, "data_origin": "synthetic",
            "started_at": (when - timedelta(minutes=3)).isoformat(), "completed_at": when.isoformat(),
            "session_duration_seconds": 180, "events": out, "skill_id": out[0]["skill_id"] if out else "unknown",
            "activity_id": out[0]["activity_id"] if out else "unknown"}


def main(out_path, learners=8):
    cfg = load_config()
    rng = np.random.default_rng(2026)
    db = AsyncMongoMockClient().get_database("e2e")
    from database import db_instance
    db_instance.client = db.client

    async def user():
        return {"_id": PARENT, "role": "parent"}
    app.dependency_overrides[get_current_user] = user
    truth = {}
    now = datetime.now(timezone.utc)
    with patch("routers.telemetry.get_db", return_value=db):
        with TestClient(app) as client:
            for i in range(learners):
                pattern = CLASS_NAMES[i % len(CLASS_NAMES)]
                student_id = str(ObjectId())
                LOOP.run_until_complete(
                    db.students.insert_one({"_id": ObjectId(student_id), "parent_id": PARENT}))
                learner, sessions = simulate_learner(rng, pattern, cfg, f"e2e{i}")
                add_touch_streams(np.random.default_rng(i), pattern, learner, sessions, cfg)
                for n, (meta, events) in enumerate(sessions):
                    sid = f"{student_id}-{uuid.uuid4().hex[:8]}"
                    when = now - timedelta(hours=6 * (len(sessions) - n))
                    response = client.post("/api/v1/auth/telemetry", json=to_payload(student_id, sid, events, when))
                    if response.status_code != 201:
                        raise SystemExit(f"ingestion failed: {response.status_code} {response.text[:300]}")
                    if response.json()["c1_processing"].get("status") != "processed":
                        raise SystemExit(f"C1 processing failed: {response.json()['c1_processing']}")
                truth[student_id] = {"pattern": pattern, **expected_numbers(sessions)}

    async def dump():
        out = {}
        for name in ("students", "telemetry_sessions", "telemetry_events", "session_summaries",
                     "behavioral_features", "kinematic_features", "c1_learner_estimates"):
            out[name] = await db[name].find({}).to_list(length=100000)
        return out
    collections = LOOP.run_until_complete(dump())
    Path(out_path).write_text(json.dumps({"truth": truth, "collections": collections}, default=str), encoding="utf-8")
    print(f"ingested {learners} simulated learners -> {out_path}")


if __name__ == "__main__":
    main(sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 8)
