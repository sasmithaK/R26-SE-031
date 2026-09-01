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
    try:
        import pymongo
        await db.telemetry_sessions.create_index([("session_id", pymongo.ASCENDING)], unique=True)
        await db.telemetry_events.create_index([("session_id", pymongo.ASCENDING)])
        await db.telemetry_events.create_index([("event_id", pymongo.ASCENDING)], unique=True)
        await db.telemetry_events.create_index([("student_id", pymongo.ASCENDING)])
        await db.session_summaries.create_index([("session_id", pymongo.ASCENDING)], unique=True)
        await db.speech_features.create_index([("speech_event_id", pymongo.ASCENDING)], unique=True)
        await db.assessment_submissions.create_index([("student_id", pymongo.ASCENDING), ("version", pymongo.ASCENDING)])
        print("MongoDB indexes verified.")
    except Exception as e:
        print(f"Error creating MongoDB indexes: {e}")

async def close_mongo_connection():
    if db_instance.client:
        db_instance.client.close()
        print("MongoDB connection closed.")

def get_db():
    db_name = os.getenv("MONGODB_DB_NAME", "r26_se_031")
    return db_instance.client[db_name]
