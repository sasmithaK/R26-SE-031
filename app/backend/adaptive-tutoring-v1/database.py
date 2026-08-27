import os
from motor.motor_asyncio import AsyncIOMotorClient

# MongoDB connection settings
MONGO_URL = os.environ.get("MONGO_URL", "mongodb://localhost:27017")
DB_NAME = "sipsara_db"

client = None
db = None
bkt_states_collection = None

async def connect_to_mongo():
    global client, db, bkt_states_collection
    client = AsyncIOMotorClient(MONGO_URL)
    db = client[DB_NAME]
    bkt_states_collection = db["bkt_states"]
    print("Connected to MongoDB (adaptive-tutoring-v1)")

async def close_mongo_connection():
    global client
    if client:
        client.close()
        print("Closed MongoDB connection (adaptive-tutoring-v1)")
