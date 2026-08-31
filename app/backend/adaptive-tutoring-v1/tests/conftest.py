import pytest
from fastapi.testclient import TestClient
import sys
import os

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from mongomock_motor import AsyncMongoMockClient
import database

# Mock the Database initialization
mock_client = AsyncMongoMockClient()
mock_db = mock_client["test_db"]

# Replace db globals
database.db_instance.client = mock_client
database.db = mock_db
database.knowledge_states_collection = mock_db["knowledge_states"]
database.adaptive_decisions_collection = mock_db["adaptive_decisions"]

@pytest.fixture(autouse=True)
async def reset_db():
    # Clear collections between tests
    await mock_db["knowledge_states"].delete_many({})
    await mock_db["adaptive_decisions"].delete_many({})
    await mock_db["item_bank"].delete_many({})
    yield

from main import app

@pytest.fixture
def client():
    # Clear events so real connection isn't attempted
    app.router.on_startup.clear()
    app.router.on_shutdown.clear()
    with TestClient(app) as c:
        yield c
