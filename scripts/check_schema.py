import asyncio
import os
from pathlib import Path
import sys

# Add parent dir to path
sys.path.append(str(Path(__file__).parent.parent))

from shared.database import connect_to_mongo, close_mongo_connection, get_db

async def check_schema():
    await connect_to_mongo()
    db = get_db()
    doc = await db.mbsv_events.find_one()
    print("Document keys:", doc.keys() if doc else "No document found")
    if doc:
        print("mbsv_json content:", doc.get('mbsv_json'))
    await close_mongo_connection()

if __name__ == "__main__":
    asyncio.run(check_schema())
