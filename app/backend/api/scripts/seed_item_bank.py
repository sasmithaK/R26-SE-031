"""Seed the complete Component 4 item bank without embedded credentials."""

import asyncio
import argparse
import os
import sys
from pathlib import Path

from motor.motor_asyncio import AsyncIOMotorClient


ADAPTIVE_SERVICE = Path(__file__).resolve().parents[2] / "adaptive-tutoring-v1"
sys.path.insert(0, str(ADAPTIVE_SERVICE))

from item_bank_builder import build_items, validation_summary  # noqa: E402


async def seed_items(*, apply: bool = False) -> dict:
    items = build_items()
    summary = validation_summary(items)
    if not apply:
        print(f"Component 4 item bank validated: {summary}")
        return summary

    mongo_url = os.getenv("MONGODB_URI") or os.getenv("MONGODB_URL")
    if not mongo_url:
        raise RuntimeError("Set MONGODB_URI before using --apply.")

    client = AsyncIOMotorClient(mongo_url)
    try:
        db_name = os.getenv("MONGODB_DB", os.getenv("MONGODB_DB_NAME", "r26_se_031"))
        item_bank = client[db_name]["item_bank"]
        for item in items:
            await item_bank.update_one(
                {"item_id": item["item_id"]},
                {"$set": item},
                upsert=True,
            )
        summary = validation_summary(items)
        print(f"Component 4 item bank seeded: {summary}")
        return summary
    finally:
        client.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--apply",
        action="store_true",
        help="write validated item records to MongoDB (default: validate only)",
    )
    args = parser.parse_args()
    asyncio.run(seed_items(apply=args.apply))
