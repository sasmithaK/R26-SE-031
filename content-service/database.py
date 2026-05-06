import motor.motor_asyncio
import datetime
import math

MONGO_URI = "mongodb+srv://kavindugunasena_db_user:2Vp8ipkprifuEH8t@cluster0.ypxuqen.mongodb.net/"
client = motor.motor_asyncio.AsyncIOMotorClient(MONGO_URI)
db = client.content_db

async def init_db():
    # Create indexes for fast lookup
    await db.mastery.create_index([("student_id", 1), ("skill_id", 1)], unique=True)
    await db.mastery_history.create_index("student_id")
    print("Content Service: MongoDB indexes initialized.")

async def update_mastery(student_id: str, skill_id: str, mastery_level: float):
    now = datetime.datetime.now(datetime.UTC)
    
    # Update current mastery
    await db.mastery.update_one(
        {"student_id": student_id, "skill_id": skill_id},
        {
            "$set": {
                "mastery_level": mastery_level,
                "last_practiced_at": now
            },
            "$inc": {"attempt_count": 1}
        },
        upsert=True
    )
    
    # Log history for curve analysis
    await db.mastery_history.insert_one({
        "student_id": student_id,
        "skill_id": skill_id,
        "mastery_level": mastery_level,
        "timestamp": now
    })

async def get_mastery(student_id: str, skill_id: str) -> float:
    doc = await db.mastery.find_one({"student_id": student_id, "skill_id": skill_id})
    if not doc:
        return 0.0
    
    # Apply forgetting curve logic (Ebbinghaus)
    return _apply_forgetting(doc["mastery_level"], doc["last_practiced_at"])

async def get_all_mastery(student_id: str) -> dict:
    cursor = db.mastery.find({"student_id": student_id})
    results = {}
    async for doc in cursor:
        results[doc["skill_id"]] = _apply_forgetting(doc["mastery_level"], doc["last_practiced_at"])
    return results

async def get_mastery_history(student_id: str) -> list:
    cursor = db.mastery.find({"student_id": student_id})
    history = []
    async for doc in cursor:
        history.append({
            "skill_id": doc["skill_id"],
            "mastery_level": _apply_forgetting(doc["mastery_level"], doc["last_practiced_at"]),
            "attempt_count": doc.get("attempt_count", 0),
            "last_practiced": doc["last_practiced_at"].isoformat()
        })
    return history

def _apply_forgetting(base_mastery: float, last_at: datetime.datetime) -> float:
    """
    Implements a simple exponential decay forgetting curve.
    Formula: M = B * e^(-t/S)
    Where t is hours since last practice, S is stability factor.
    """
    if base_mastery <= 0:
        return 0.0
    
    now = datetime.datetime.now(datetime.UTC)
    diff = now - last_at
    hours_passed = diff.total_seconds() / 3600.0
    
    # Stability factor: higher mastery decays slower
    stability = 24.0 * (1.0 + base_mastery * 2) 
    decayed = base_mastery * math.exp(-hours_passed / stability)
    
    return round(max(0.0, decayed), 4)
