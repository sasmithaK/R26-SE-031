import datetime
import math
import os
import sqlite3
from typing import Any, Dict, List, Optional

from pymongo import MongoClient

DB_PATH = os.getenv('SQLITE_DB_PATH', 'student_mastery.db')

# async def init_db():
#     # Create indexes for fast lookup
#     await db.mastery.create_index([("student_id", 1), ("skill_id", 1)], unique=True)
#     await db.mastery_history.create_index("student_id")
#     print("Content Service: MongoDB indexes initialized.")
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


async def init_db():
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
            last_practiced_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            attempt_count INTEGER DEFAULT 0,
            PRIMARY KEY (student_id, skill_id)
        )
    ''')
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS mastery_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            student_id TEXT,
            skill_id TEXT,
            mastery_level REAL,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ''')

    # Lightweight migration for older local DBs.
    cursor.execute("PRAGMA table_info(mastery)")
    existing_cols = {row[1] for row in cursor.fetchall()}
    if 'last_practiced_at' not in existing_cols:
        cursor.execute('ALTER TABLE mastery ADD COLUMN last_practiced_at DATETIME DEFAULT CURRENT_TIMESTAMP')
    if 'attempt_count' not in existing_cols:
        cursor.execute('ALTER TABLE mastery ADD COLUMN attempt_count INTEGER DEFAULT 0')
    conn.commit()
    conn.close()
    
    # Initialize MongoDB for questions and tasks
    init_mongo()

def _apply_forgetting(mastery_level: float, last_practiced_at_iso: str) -> float:
    """Apply a simple Ebbinghaus-style decay on mastery over elapsed days."""
    try:
        last_practiced = datetime.datetime.fromisoformat(last_practiced_at_iso)
    except Exception:
        return float(mastery_level)

    if last_practiced.tzinfo is None:
        last_practiced = last_practiced.replace(tzinfo=datetime.timezone.utc)

    now = datetime.datetime.now(datetime.timezone.utc)
    elapsed_days = max(0.0, (now - last_practiced).total_seconds() / 86400.0)
    decay_lambda = 0.02
    decayed = float(mastery_level) * math.exp(-decay_lambda * elapsed_days)
    return round(max(0.0, min(1.0, decayed)), 4)


async def update_mastery(student_id: str, skill_id: str, mastery_level: float):
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    cursor.execute(
        'SELECT attempt_count FROM mastery WHERE student_id = ? AND skill_id = ?',
        (student_id, skill_id),
    )
    row = cursor.fetchone()
    attempt_count = (row[0] + 1) if row else 1

    cursor.execute(
        '''
        INSERT OR REPLACE INTO mastery (student_id, skill_id, mastery_level, last_updated, last_practiced_at, attempt_count)
        VALUES (?, ?, ?, ?, ?, ?)
        ''',
        (student_id, skill_id, float(mastery_level), now, now, attempt_count),
    )
    cursor.execute(
        '''
        INSERT INTO mastery_history (student_id, skill_id, mastery_level, timestamp)
        VALUES (?, ?, ?, ?)
        ''',
        (student_id, skill_id, float(mastery_level), now),
    )
    conn.commit()
    conn.close()

async def get_mastery(student_id: str, skill_id: str) -> float:
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute(
        'SELECT mastery_level, last_practiced_at FROM mastery WHERE student_id = ? AND skill_id = ?',
        (student_id, skill_id),
    )
    row = cursor.fetchone()
    conn.close()

    if not row:
        return 0.0

    mastery_level, last_practiced_at = row
    if last_practiced_at is None:
        return float(mastery_level)

    return _apply_forgetting(float(mastery_level), last_practiced_at)

async def get_all_mastery(student_id: str):
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute(
        'SELECT skill_id, mastery_level, last_practiced_at FROM mastery WHERE student_id = ?',
        (student_id,),
    )
    results = cursor.fetchall()
    conn.close()
    output: Dict[str, float] = {}
    for skill, level, last_practiced_at in results:
        if last_practiced_at:
            output[skill] = _apply_forgetting(float(level), last_practiced_at)
        else:
            output[skill] = float(level)
    return output


async def get_mastery_history(student_id: str) -> List[Dict[str, Any]]:
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute(
        '''
        SELECT m.skill_id, m.mastery_level, m.attempt_count, m.last_practiced_at
        FROM mastery m
        WHERE m.student_id = ?
        ORDER BY m.last_updated DESC
        ''',
        (student_id,),
    )
    rows = cursor.fetchall()
    conn.close()

    history: List[Dict[str, Any]] = []
    for skill_id, mastery_level, attempt_count, last_practiced_at in rows:
        decayed = (
            _apply_forgetting(float(mastery_level), last_practiced_at)
            if last_practiced_at
            else float(mastery_level)
        )
        history.append(
            {
                'skill_id': skill_id,
                'mastery_level': decayed,
                'attempt_count': int(attempt_count or 0),
                'last_practiced_at': last_practiced_at,
            }
        )
    return history


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

