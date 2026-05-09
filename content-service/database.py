import sqlite3
from pymongo import MongoClient
from typing import Optional, List, Dict, Any
import os

DB_PATH = 'content_state.db'

# MongoDB Configuration
MONGO_URL = os.getenv('MONGO_URL', 'mongodb://localhost:27017')
MONGO_DB = os.getenv('MONGO_DB', 'dyslexia_content')

mongo_client: Optional[MongoClient] = None
mongo_db = None


def init_mongo():
    """Initialize MongoDB connection and create indexes"""
    global mongo_client, mongo_db
    try:
        # Fail fast when MongoDB is unavailable so the API can serve fallbacks.
        mongo_client = MongoClient(
            MONGO_URL,
            serverSelectionTimeoutMS=3000,
            connectTimeoutMS=3000,
            socketTimeoutMS=3000,
        )
        mongo_db = mongo_client[MONGO_DB]

        # Force an immediate connectivity check.
        mongo_client.admin.command('ping')
        
        # Create collections and indexes
        if 'questionnaires' not in mongo_db.list_collection_names():
            mongo_db.create_collection('questionnaires')
        
        if 'tasks' not in mongo_db.list_collection_names():
            mongo_db.create_collection('tasks')
        
        # Create indexes
        mongo_db['questionnaires'].create_index('category')
        mongo_db['tasks'].create_index('type')
        
        print("✓ MongoDB connected and initialized")
        return True
    except Exception as e:
        print(f"⚠ MongoDB connection failed: {e}")
        print("  Application will continue with local data fallback")
        return False


def init_db():
    """Initialize all databases - SQLite and MongoDB"""
    # Initialize SQLite for mastery tracking
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS mastery (
            student_id TEXT,
            skill_id TEXT,
            mastery_level REAL,
            last_updated DATETIME DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (student_id, skill_id)
        )
    ''')
    conn.commit()
    conn.close()
    
    # Initialize MongoDB for questions and tasks
    init_mongo()

def update_mastery(student_id: str, skill_id: str, mastery_level: float):
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute('''
        INSERT INTO mastery (student_id, skill_id, mastery_level, last_updated)
        VALUES (?, ?, ?, CURRENT_TIMESTAMP)
        ON CONFLICT(student_id, skill_id) DO UPDATE SET
            mastery_level = excluded.mastery_level,
            last_updated = CURRENT_TIMESTAMP
    ''', (student_id, skill_id, mastery_level))
    conn.commit()
    conn.close()

def get_mastery(student_id: str, skill_id: str):
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute('SELECT mastery_level FROM mastery WHERE student_id = ? AND skill_id = ?', (student_id, skill_id))
    result = cursor.fetchone()
    conn.close()
    return result[0] if result else 0.0

def get_all_mastery(student_id: str):
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute('SELECT skill_id, mastery_level FROM mastery WHERE student_id = ?', (student_id,))
    results = cursor.fetchall()
    conn.close()
    return {skill: level for skill, level in results}


# MongoDB Query Functions
def get_questionnaire_by_category(category: str) -> Optional[Dict[str, Any]]:
    """Fetch questionnaire by category from MongoDB"""
    if mongo_db is None:
        return None
    try:
        return mongo_db['questionnaires'].find_one({'category': category})
    except Exception as e:
        print(f"Error fetching questionnaire: {e}")
        return None


def get_tasks_by_type(task_type: str) -> List[Dict[str, Any]]:
    """Fetch tasks by type from MongoDB"""
    if mongo_db is None:
        return []
    try:
        return list(mongo_db['tasks'].find({'type': task_type}))
    except Exception as e:
        print(f"Error fetching tasks: {e}")
        return []


def get_task_by_id(task_id: str) -> Optional[Dict[str, Any]]:
    """Fetch a single task by ID from MongoDB"""
    if mongo_db is None:
        return None
    try:
        from bson import ObjectId
        return mongo_db['tasks'].find_one({'_id': ObjectId(task_id)})
    except Exception as e:
        print(f"Error fetching task: {e}")
        return None


def insert_questionnaire(questionnaire_data: Dict[str, Any]) -> bool:
    """Insert questionnaire into MongoDB"""
    if mongo_db is None:
        return False
    try:
        mongo_db['questionnaires'].insert_one(questionnaire_data)
        return True
    except Exception as e:
        print(f"Error inserting questionnaire: {e}")
        return False


def insert_task(task_data: Dict[str, Any]) -> bool:
    """Insert task into MongoDB"""
    if mongo_db is None:
        return False
    try:
        mongo_db['tasks'].insert_one(task_data)
        return True
    except Exception as e:
        print(f"Error inserting task: {e}")
        return False


def insert_many_tasks(tasks: List[Dict[str, Any]]) -> bool:
    """Insert multiple tasks into MongoDB"""
    if mongo_db is None:
        return False
    try:
        mongo_db['tasks'].insert_many(tasks)
        return True
    except Exception as e:
        print(f"Error inserting tasks: {e}")
        return False

