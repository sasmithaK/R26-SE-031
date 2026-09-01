import asyncio
import certifi
from motor.motor_asyncio import AsyncIOMotorClient

MONGODB_URL = "mongodb+srv://kavindugunasena_db_user:vsqocmP1Fcu8wgYm@cluster0.ypxuqen.mongodb.net/"

async def inspect():
    client = AsyncIOMotorClient(MONGODB_URL, tlsCAFile=certifi.where())
    
    print("=== MONGODB CLUSTER INSPECTION ===")
    db_names = await client.list_database_names()
    print(f"Databases found ({len(db_names)}): {db_names}\n")
    
    for db_name in db_names:
        if db_name in ['admin', 'local']:
            continue
        db = client[db_name]
        colls = await db.list_collection_names()
        print(f"Database: [{db_name}] ({len(colls)} collections)")
        for coll_name in sorted(colls):
            count = await db[coll_name].count_documents({})
            sample = await db[coll_name].find_one()
            sample_keys = list(sample.keys()) if sample else []
            print(f"  |-- Collection: {coll_name:<30} | Docs: {count:<6} | Sample Keys: {sample_keys}")
        print()

    client.close()

if __name__ == "__main__":
    asyncio.run(inspect())
