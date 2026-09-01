import os
import json
import certifi
from pymongo import MongoClient

# Setup connection
MONGODB_URL = os.getenv("MONGODB_URL", "mongodb+srv://kavindugunasena_db_user:vsqocmP1Fcu8wgYm@cluster0.ypxuqen.mongodb.net/")
DB_NAME = os.getenv("MONGODB_DB_NAME", "r26_se_031")

def seed():
    client = MongoClient(MONGODB_URL, tlsCAFile=certifi.where())
    db = client[DB_NAME]
    curriculum_collection = db["curriculum"]

    base_path = "../frontend/assets/data/curriculum"
    
    # 1. Read skill_1.json
    with open(os.path.join(base_path, "skill_1.json"), "r", encoding="utf-8") as f:
        skill_1_data = json.load(f)
    
    if isinstance(skill_1_data, list):
        skill_1_data = skill_1_data[0] # Grab the first dict

    # 2. Iterate through its activities and fetch the details
    enriched_activities = []
    for activity_ref in skill_1_data.get("activities", []):
        file_path = activity_ref.get("file_path")
        if file_path:
            full_path = os.path.join(base_path, file_path)
            try:
                with open(full_path, "r", encoding="utf-8") as act_f:
                    act_data = json.load(act_f)
                    enriched_activities.append(act_data)
            except Exception as e:
                print(f"Failed to read {full_path}: {e}")
                enriched_activities.append(activity_ref)
        else:
            enriched_activities.append(activity_ref)

    skill_1_data["activities"] = enriched_activities

    # 3. Upsert into database
    result = curriculum_collection.update_one(
        {"id": skill_1_data["id"]},
        {"$set": skill_1_data},
        upsert=True
    )
    
    print(f"Successfully seeded {skill_1_data['id']} into MongoDB.")
    if result.upserted_id:
        print(f"Inserted new document with id: {result.upserted_id}")
    else:
        print("Updated existing document.")

if __name__ == "__main__":
    seed()
