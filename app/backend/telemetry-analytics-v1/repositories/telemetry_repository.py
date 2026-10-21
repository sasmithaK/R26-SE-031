from __future__ import annotations
from database import get_db

async def save_session(session_data: dict) -> None:
    """
    Idempotent save of a telemetry session.
    If the session_id already exists, it updates the document.
    """
    db = get_db()
    
    session_id = session_data.get("session_id")
    if not session_id:
        raise ValueError("Missing session_id in session data.")
        
    await db.telemetry_sessions.update_one(
        {"session_id": session_id},
        {"$set": session_data},
        upsert=True
    )

async def save_events(events_list: list[dict]) -> None:
    db = get_db()
    if not events_list:
        return
        
    for event in events_list:
        if "event_id" in event:
            student_id = str(event.get("student_id") or "unknown")
            ingestion_key = f"{student_id}:{event['event_id']}"
            event["ingestion_key"] = ingestion_key
            existing = await db.telemetry_events.find_one(
                {"ingestion_key": ingestion_key}, {"_id": 1}
            )
            if not existing:
                existing = await db.telemetry_events.find_one(
                    {"event_id": event["event_id"]}, {"_id": 1}
                )
            event_filter = {"_id": existing["_id"]} if existing else {
                "ingestion_key": ingestion_key
            }
            await db.telemetry_events.update_one(
                event_filter,
                {"$set": event},
                upsert=existing is None,
            )
        else:
            await db.telemetry_events.insert_one(event)

async def get_session(session_id: str) -> dict | None:
    db = get_db()
    return await db.telemetry_sessions.find_one({"session_id": session_id})

async def get_events_for_session(session_id: str) -> list[dict]:
    db = get_db()
    cursor = db.telemetry_events.find({"session_id": session_id}).sort("round_number", 1)
    return await cursor.to_list(length=1000)
