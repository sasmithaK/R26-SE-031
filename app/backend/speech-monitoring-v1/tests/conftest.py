import pytest
from fastapi.testclient import TestClient
from mongomock_motor import AsyncMongoMockClient

# Add parent directory to path
import sys
import os

os.environ["MONGODB_URL"] = "mongodb://mock:27017"
os.environ["MONGODB_DB_NAME"] = "test_db"

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from unittest.mock import patch, AsyncMock
patch("database.connect_to_mongo").start()
patch("database.close_mongo_connection").start()

from main import app
from dependencies import get_current_user, require_owned_student

@pytest.fixture
def mock_db():
    client = AsyncMongoMockClient()
    return client.get_database("sipsara_db")

@pytest.fixture
def mock_db():
    client = AsyncMongoMockClient()
    db = client.get_database("sipsara_db")
    return db

@pytest.fixture
def client(mock_db):
    async def current_user():
        return {"_id": "mock-parent", "role": "parent", "email": "parent@test.local"}

    async def owned_student(_student_id, _user):
        return {"_id": "mock-student", "parent_id": "mock-parent"}

    app.dependency_overrides[get_current_user] = current_user
    app.dependency_overrides[require_owned_student] = owned_student
    with patch("routers.stt.get_db", return_value=mock_db), \
         patch("dependencies.get_db", return_value=mock_db), \
         patch("routers.stt.require_owned_student", new=AsyncMock(return_value={"_id": "mock-student"})):
        with TestClient(app) as c:
            yield c
    app.dependency_overrides.clear()
