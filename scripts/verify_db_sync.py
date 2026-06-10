import asyncio
import os
from pathlib import Path
import sys

# Add parent dir to path
sys.path.append(str(Path(__file__).parent.parent))

from shared.database import connect_to_mongo, close_mongo_connection, get_db

async def verify_persistence():
    print("="*50)
    print("--- MONGODB ATLAS PERSISTENCE AUDIT ---")
    print("="*50)
    await connect_to_mongo()
    db = get_db()
    
    # Check if we are using Mock or Real Mongo
    is_mock = "Mock" in str(db.client.__class__.__name__)
    print(f"[STATUS] Database Type: {'MOCK (In-Memory)' if is_mock else 'REAL (MongoDB Atlas)'}")
    
    # Check collections
    collections = await db.list_collection_names()
    print(f"[STATUS] Active Collections: {collections}")
    print("-" * 50)

    # 1. MBSV Events (Monitoring Service)
    if 'mbsv_events' in collections:
        count = await db.mbsv_events.count_documents({})
        print(f"[OK] [C1] mbsv_events count: {count}")
        if count > 0:
            latest = await db.mbsv_events.find_one(sort=[("timestamp_ms", -1)])
            mbsv = latest.get('mbsv_json')
            if isinstance(mbsv, str):
                import json
                mbsv = json.loads(mbsv)
            print(f"   |-- Latest Session: {latest.get('session_id', 'Unknown')}")
            if mbsv:
                print(f"   |-- Visual Strain: {mbsv.get('visual_strain_index', 0):.2f}")
                print(f"   |-- Cognitive Load: {mbsv.get('cognitive_load_index', 0):.2f}")
                print(f"   |-- Phonological: {mbsv.get('phonological_strain_index', 0):.2f}")
    else:
        print("[ERR] [C1] mbsv_events collection NOT FOUND. (Verify Monitoring Service V2 is running)")

    # 2. LinUCB History (Visual Service)
    if 'linucb_history' in collections:
        count = await db.linucb_history.count_documents({})
        print(f"[OK] [C2] linucb_history count: {count}")
    else:
        print("[WARN] [C2] linucb_history collection not found yet.")

    # 3. BKT/Welford States (Learning Models)
    if 'bkt_states' in collections:
        print(f"[OK] [C4] bkt_states found (Persisting student knowledge models)")
    
    print("-" * 50)
    print("Audit Complete.")
    print("="*50)
        
    await close_mongo_connection()

if __name__ == "__main__":
    asyncio.run(verify_persistence())
