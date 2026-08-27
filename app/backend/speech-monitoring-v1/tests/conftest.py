import pytest
from fastapi.testclient import TestClient
from mongomock_motor import AsyncMongoMockClient

# Add parent directory to path
import sys
import os

os.environ["MONGODB_URL"] = "mongodb://mock:27017"
os.environ["MONGODB_DB_NAME"] = "test_db"

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from unittest.mock import patch
patch("database.connect_to_mongo").start()
patch("database.close_mongo_connection").start()

from main import app

@pytest.fixture
def mock_db():
    client = AsyncMongoMockClient()
    db = client.get_database("sipsara_db")
    return db

@pytest.fixture
def client(mock_db):
    with TestClient(app) as c:
        yield c
