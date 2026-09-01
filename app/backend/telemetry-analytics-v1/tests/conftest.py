import pytest
from fastapi.testclient import TestClient
from mongomock_motor import AsyncMongoMockClient

import sys
import os

os.environ["MONGODB_URL"] = "mongodb://mock:27017"
os.environ["MONGODB_DB_NAME"] = "test_db"
os.environ["JWT_SECRET_KEY"] = "mock_secret"

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from unittest.mock import patch
# Patch mongo connection before importing app
patch("database.connect_to_mongo").start()
patch("database.close_mongo_connection").start()

from main import app
from database import get_db
from dependencies import get_current_user

@pytest.fixture
def mock_db():
    client = AsyncMongoMockClient()
    db = client.get_database("test_db")
    return db

@pytest.fixture
def mock_user():
    return {
        "_id": "mock_parent_id",
        "role": "parent",
        "email": "test@example.com"
    }

@pytest.fixture(autouse=True)
def patch_get_db(mock_db):
    from database import db_instance
    db_instance.client = mock_db.client
    with patch("routers.telemetry.get_db", return_value=mock_db):
        yield

@pytest.fixture
def client(mock_db, mock_user):
    async def override_get_current_user():
        return mock_user

    app.dependency_overrides[get_current_user] = override_get_current_user
    
    with TestClient(app) as c:
        yield c
        
    app.dependency_overrides.clear()
