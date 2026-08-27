import os
from motor.motor_asyncio import AsyncIOMotorClient
import certifi
import logging

logger = logging.getLogger(__name__)

class Database:
    client: AsyncIOMotorClient = None

db_instance = Database()

async def connect_to_mongo():
    # Load from environment or use a default local connection for testing
    mongo_url = os.getenv("MONGODB_URL", "mongodb://127.0.0.1:27017")
    
    try:
        db_instance.client = AsyncIOMotorClient(mongo_url, tlsCAFile=certifi.where() if "mongodb+srv" in mongo_url else None)
        logger.info("Connected to MongoDB for Diagnostic Fusion C3!")
    except Exception as e:
        logger.error(f"Could not connect to MongoDB: {e}")

async def close_mongo_connection():
    if db_instance.client:
        db_instance.client.close()
        logger.info("MongoDB connection closed.")

def get_db():
    db_name = os.getenv("MONGODB_DB_NAME", "sipsara_db")
    return db_instance.client[db_name]
