"""Own the adaptive-tutoring service's MongoDB connection and collections.

The service keeps one asynchronous client and exposes the knowledge-state and
decision collections used by the real-time tutoring endpoint.
"""

import os
from motor.motor_asyncio import AsyncIOMotorClient

import certifi
from dotenv import load_dotenv

load_dotenv()

# MongoDB connection settings
MONGODB_URL = os.environ.get("MONGODB_URL")
DB_NAME = os.environ.get("MONGODB_DB_NAME", "r26_se_031")

class Database:
    client: AsyncIOMotorClient = None

db_instance = Database()
db = None
knowledge_states_collection = None
adaptive_decisions_collection = None

async def connect_to_mongo():
    global db, knowledge_states_collection, adaptive_decisions_collection
    if not MONGODB_URL:
        raise ValueError("MONGODB_URL environment variable is not set!")
    db_instance.client = AsyncIOMotorClient(MONGODB_URL, tlsCAFile=certifi.where())
    db = db_instance.client[DB_NAME]
    knowledge_states_collection = db["knowledge_states"]
    adaptive_decisions_collection = db["adaptive_decisions"]
    import pymongo
    await db["policy_decisions"].create_index(
        [("student_id", pymongo.ASCENDING), ("event_id", pymongo.ASCENDING)],
        name="policy_student_event_lookup_v1",
    )
    await db["policy_decisions"].create_index(
        [
            ("student_id", pymongo.ASCENDING),
            ("session_id", pymongo.ASCENDING),
            ("item_id", pymongo.ASCENDING),
        ],
        name="policy_action_outcome_link_v1",
    )
    await db["adaptive_decisions"].create_index(
        [("student_id", pymongo.ASCENDING), ("timestamp", pymongo.DESCENDING)],
        name="adaptive_student_timeline_v2",
    )
    print("Connected to MongoDB Cloud (adaptive-tutoring-v1)")

async def close_mongo_connection():
    if db_instance.client:
        db_instance.client.close()
        print("Closed MongoDB connection (adaptive-tutoring-v1)")

def get_db():
    """Returns the active Motor database instance. Call connect_to_mongo() first."""
    if db is None:
        raise RuntimeError("Database not initialized. Ensure connect_to_mongo() was called on startup.")
    return db
