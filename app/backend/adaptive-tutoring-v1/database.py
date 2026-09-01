import os
from motor.motor_asyncio import AsyncIOMotorClient

import certifi

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

