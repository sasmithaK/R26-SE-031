import os
from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorGridFSBucket
from dotenv import load_dotenv
import certifi

# Load environment variables
load_dotenv()

class Database:
    client: AsyncIOMotorClient = None
    fs: AsyncIOMotorGridFSBucket = None

db_instance = Database()

async def connect_to_mongo():
    MONGODB_URL = os.getenv("MONGODB_URL")
    if not MONGODB_URL:
        raise ValueError("MONGODB_URL environment variable is not set!")
    
    db_instance.client = AsyncIOMotorClient(MONGODB_URL, tlsCAFile=certifi.where())
    
    # Initialize GridFS bucket
    db_name = os.getenv("MONGODB_DB_NAME", "r26_se_031")
    db = db_instance.client[db_name]
    db_instance.fs = AsyncIOMotorGridFSBucket(db)
    
    print("Connected to MongoDB Cloud (GridFS Initialized)!")

async def close_mongo_connection():
    if db_instance.client:
        db_instance.client.close()
        print("MongoDB connection closed.")

def get_fs() -> AsyncIOMotorGridFSBucket:
    return db_instance.fs

def get_db():
    if db_instance.client is None:
        raise RuntimeError("Database not initialized")
    db_name = os.getenv("MONGODB_DB_NAME", "r26_se_031")
    return db_instance.client[db_name]
