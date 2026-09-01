import os
import asyncio
from motor.motor_asyncio import AsyncIOMotorClient

# Setup connection
MONGODB_URL = os.getenv("MONGODB_URL", "mongodb+srv://kavindugunasena_db_user:vsqocmP1Fcu8wgYm@cluster0.ypxuqen.mongodb.net/")
DB_NAME = os.getenv("MONGODB_DB_NAME", "r26_se_031")

async def seed_items():
    client = AsyncIOMotorClient(MONGODB_URL)
    db = client[DB_NAME]
    item_bank = db["item_bank"]

    # Initial mock item bank parameters for Skill 2 (Letter Identity)
    items = [
        {"item_id": "S2A1R01", "kc_id": "KC_LETTER_IDENTITY", "difficulty_b": -1.5, "discrimination_a": 1.0, "guessing_c": 0.2, "target": "අ"},
        {"item_id": "S2A1R02", "kc_id": "KC_LETTER_IDENTITY", "difficulty_b": -1.0, "discrimination_a": 1.0, "guessing_c": 0.2, "target": "ආ"},
        {"item_id": "S2A1R03", "kc_id": "KC_LETTER_IDENTITY", "difficulty_b": -0.5, "discrimination_a": 1.0, "guessing_c": 0.2, "target": "ඇ"},
        {"item_id": "S2A1R04", "kc_id": "KC_LETTER_IDENTITY", "difficulty_b": 0.0, "discrimination_a": 1.0, "guessing_c": 0.2, "target": "ඈ"},
        {"item_id": "S2A1R05", "kc_id": "KC_LETTER_IDENTITY", "difficulty_b": 0.5, "discrimination_a": 1.0, "guessing_c": 0.2, "target": "ඉ"},
        {"item_id": "S2A1R06", "kc_id": "KC_LETTER_IDENTITY", "difficulty_b": 1.0, "discrimination_a": 1.0, "guessing_c": 0.2, "target": "ඊ"},
        
        {"item_id": "S2A2R01", "kc_id": "KC_VISUAL_DISCRIMINATION", "difficulty_b": 0.2, "discrimination_a": 1.2, "guessing_c": 0.25, "target": "උ"},
        {"item_id": "S2A2R02", "kc_id": "KC_VISUAL_DISCRIMINATION", "difficulty_b": 0.8, "discrimination_a": 1.2, "guessing_c": 0.25, "target": "ඌ"},
    ]

    for item in items:
        await item_bank.update_one(
            {"item_id": item["item_id"]},
            {"$set": item},
            upsert=True
        )

    print(f"Successfully seeded {len(items)} items into item_bank.")
    client.close()

if __name__ == "__main__":
    asyncio.run(seed_items())
