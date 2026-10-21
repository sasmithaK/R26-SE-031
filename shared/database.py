import os
from motor.motor_asyncio import AsyncIOMotorClient

class Database:
    client: AsyncIOMotorClient = None

db_instance = Database()

async def connect_to_mongo():
    MONGODB_URL = os.getenv("MONGODB_URL")
    if not MONGODB_URL:
        raise ValueError("MONGODB_URL environment variable is not set!")
    
    import certifi
    db_instance.client = AsyncIOMotorClient(MONGODB_URL, tlsCAFile=certifi.where())
    print("Connected to MongoDB Cloud!")

    # Initialize schema 2.0 indexes
    db = get_db()
    import pymongo

    async def create_index_safely(collection, keys, **options):
        try:
            await collection.create_index(keys, **options)
        except Exception as exc:
            # One legacy collection must not prevent every later index from
            # being created. Report the exact index and continue startup.
            print(f"MongoDB index warning ({collection.name}, {keys}): {exc}")

    await create_index_safely(
        db.telemetry_sessions,
        [("session_id", pymongo.ASCENDING)],
        unique=True,
        name="session_id_unique_string_v2",
        partialFilterExpression={"session_id": {"$type": "string"}},
    )
    await create_index_safely(
        db.telemetry_events,
        [("session_id", pymongo.ASCENDING)],
    )
    await create_index_safely(
        db.telemetry_events,
        [("event_id", pymongo.ASCENDING)],
        name="event_id_lookup_v2",
    )
    # Legacy databases can contain repeated event_id values from releases
    # that inserted retries.  Keep event_id as a lookup index and enforce
    # uniqueness for all new/reconciled writes through ingestion_key instead.
    # This avoids deleting historical research data during normal startup.
    await create_index_safely(
        db.telemetry_events,
        [("ingestion_key", pymongo.ASCENDING)],
        unique=True,
        name="ingestion_key_unique_v2",
        partialFilterExpression={"ingestion_key": {"$type": "string"}},
    )
    await create_index_safely(
        db.telemetry_events,
        [("student_id", pymongo.ASCENDING)],
    )
    await create_index_safely(
        db.session_summaries,
        [("session_id", pymongo.ASCENDING)],
        unique=True,
        name="summary_session_id_unique_string_v2",
        partialFilterExpression={"session_id": {"$type": "string"}},
    )
    await create_index_safely(
        db.speech_features,
        [("speech_event_id", pymongo.ASCENDING)],
        unique=True,
        name="speech_event_id_unique_string_v2",
        partialFilterExpression={"speech_event_id": {"$type": "string"}},
    )
    await create_index_safely(
        db.assessment_submissions,
        [("student_id", pymongo.ASCENDING), ("version", pymongo.ASCENDING)],
    )
    await create_index_safely(
        db.student_baseline_profiles,
        [("student_id", pymongo.ASCENDING), ("baseline_version", pymongo.ASCENDING)],
        unique=True,
        name="student_baseline_version_unique_v1",
    )
    await create_index_safely(
        db.baseline_item_events,
        [
            ("student_id", pymongo.ASCENDING),
            ("baseline_version", pymongo.ASCENDING),
            ("event_id", pymongo.ASCENDING),
        ],
        unique=True,
        name="baseline_student_event_unique_v1",
    )
    print("MongoDB index verification finished.")

async def close_mongo_connection():
    if db_instance.client:
        db_instance.client.close()
        print("MongoDB connection closed.")

def get_db():
    db_name = os.getenv("MONGODB_DB_NAME", "r26_se_031")
    return db_instance.client[db_name]
