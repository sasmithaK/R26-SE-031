import os
from motor.motor_asyncio import AsyncIOMotorClient
from dotenv import load_dotenv

# Load environment variables from the parent directory
current_dir = os.path.dirname(os.path.abspath(__file__))
env_path = os.path.join(current_dir, '..', '.env')
load_dotenv(dotenv_path=env_path)

MONGO_URI = os.getenv("MONGO_URI")
MONGO_DB_NAME = os.getenv("MONGO_DB_NAME", "dyslexia_platform")

class MockMongoCollection:
    """In-memory mock collection for when MongoDB is unavailable."""
    def __init__(self):
        self.data = {}
        self.counter = 0

    async def insert_one(self, doc):
        self.counter += 1
        doc['_id'] = self.counter
        self.data[self.counter] = doc
        return type('obj', (object,), {'inserted_id': self.counter})()

    async def find_one(self, query, sort=None):
        if sort:
            # For sort queries, return most recent
            items = list(self.data.values())
            if items:
                return items[-1]
        for doc in self.data.values():
            match = all(doc.get(k) == v for k, v in query.items())
            if match:
                return doc
        return None

    async def update_one(self, query, update, upsert=False):
        for doc in self.data.values():
            match = all(doc.get(k) == v for k, v in query.items())
            if match:
                if '$set' in update:
                    doc.update(update['$set'])
                return type('obj', (object,), {'modified_count': 1})()
        if upsert:
            new_doc = dict(query)
            if '$set' in update:
                new_doc.update(update['$set'])
            return await self.insert_one(new_doc)
        return type('obj', (object,), {'modified_count': 0})()

class MockMongoDB:
    """In-memory mock database with collection fallback."""
    def __init__(self):
        self.collections = {}

    def __getattr__(self, name):
        if name not in self.collections:
            self.collections[name] = MockMongoCollection()
        return self.collections[name]

class Database:
    client: AsyncIOMotorClient = None
    db = None
    using_mock = False

db_state = Database()

async def connect_to_mongo():
    if not MONGO_URI:
        print("[DB] WARNING: MONGO_URI is not set. Using in-memory storage (data will not persist).")
        return
    try:
        db_state.client = AsyncIOMotorClient(MONGO_URI, serverSelectionTimeoutMS=2000)
        # Verify the connection by getting server info
        await db_state.client.server_info()
        db_state.db = db_state.client[MONGO_DB_NAME]
        print(f"[DB] Connected to MongoDB Atlas: {MONGO_DB_NAME}")
    except Exception as e:
        print(f"[DB] WARNING: Could not connect to MongoDB ({e}). Using in-memory storage.")

async def close_mongo_connection():
    if db_state.client:
        db_state.client.close()
        print("[DB] MongoDB connection closed.")

def get_db():
    if db_state.db is None:
        if not db_state.using_mock:
            print("[DB] Using in-memory mock database (demo mode)")
            db_state.db = MockMongoDB()
            db_state.using_mock = True
        return db_state.db
    return db_state.db
