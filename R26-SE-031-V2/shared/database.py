import os
from motor.motor_asyncio import AsyncIOMotorClient
from dotenv import load_dotenv

# Load environment variables from the parent directory
current_dir = os.path.dirname(os.path.abspath(__file__))
env_path = os.path.join(current_dir, '..', '.env')
load_dotenv(dotenv_path=env_path)

MONGO_URI = os.getenv("MONGO_URI")
MONGO_DB_NAME = os.getenv("MONGO_DB_NAME", "dyslexia_platform")

class Database:
    client: AsyncIOMotorClient = None
    db = None

db_state = Database()

async def connect_to_mongo():
    if not MONGO_URI:
        print("WARNING: MONGO_URI is not set. MongoDB will not connect.")
        return
    try:
        db_state.client = AsyncIOMotorClient(MONGO_URI, serverSelectionTimeoutMS=5000)
        # Verify the connection by getting server info
        await db_state.client.server_info()
        db_state.db = db_state.client[MONGO_DB_NAME]
        print(f"Connected to MongoDB Atlas: {MONGO_DB_NAME}")
    except Exception as e:
        print(f"Error connecting to MongoDB: {e}")

async def close_mongo_connection():
    if db_state.client:
        db_state.client.close()
        print("MongoDB connection closed.")

def get_db():
    if db_state.db is None:
        raise Exception("Database not connected. Call connect_to_mongo() first.")
    return db_state.db
