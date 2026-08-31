import os
from pymongo import MongoClient

# Use the same connection string from .env if available, or default to localhost
MONGO_URL = os.getenv("MONGODB_URI", "mongodb://localhost:27017")
client = MongoClient(MONGO_URL)
db = client.adaptive_tutoring

item_bank = db.item_bank

# R1 = -1.2, R2 = -0.8, R3 = -0.4, R4 = 0.0, R5 = 0.4, R6 = 0.8, R7 = 1.2
difficulties = {
    "01": -1.2,
    "02": -0.8,
    "03": -0.4,
    "04": 0.0,
    "05": 0.4,
    "06": 0.8,
    "07": 1.2,
}

items = []
for r_str, diff in difficulties.items():
    # Base item
    items.append({
        "item_id": f"S2A1R{r_str}",
        "activity_id": "2.1",
        "difficulty_b": diff,
        "discrimination_a": 1.0,
        "guessing_c": 0.25 if int(r_str) <= 4 else 0.16, # 4 choices vs 6 choices
        "skill": "skill_2",
        "round": int(r_str)
    })
    
    # Variant 1 (Remediation/Confirmation)
    items.append({
        "item_id": f"S2A1R{r_str}V1",
        "activity_id": "2.1",
        "difficulty_b": diff,
        "discrimination_a": 1.0,
        "guessing_c": 0.25 if int(r_str) <= 4 else 0.16,
        "skill": "skill_2",
        "round": int(r_str)
    })
    
    # Variant 2 (Backup)
    items.append({
        "item_id": f"S2A1R{r_str}V2",
        "activity_id": "2.1",
        "difficulty_b": diff,
        "discrimination_a": 1.0,
        "guessing_c": 0.25 if int(r_str) <= 4 else 0.16,
        "skill": "skill_2",
        "round": int(r_str)
    })

# Delete old S2A1 items if they exist
item_bank.delete_many({"activity_id": "2.1"})

# Insert new ones
result = item_bank.insert_many(items)
print(f"Inserted {len(result.inserted_ids)} items into S2A1.")
