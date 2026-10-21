import pytest
from fastapi.testclient import TestClient
import sys
import os

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from unittest.mock import patch, MagicMock, AsyncMock

# Patch MongoDB connection
patch("database.connect_to_mongo").start()
patch("database.close_mongo_connection").start()

@pytest.fixture(autouse=True)
def mock_db_fixture():
    with patch("main.get_db") as mock_get_db:
        mock_db = MagicMock()
        mock_db.command = AsyncMock(return_value={"ok": 1})
        mock_db.students.find_one = AsyncMock(return_value=None)
        mock_db.users.find_one = AsyncMock(return_value={"_id": "mock-parent", "email": "parent@test.local", "role": "parent"})
        mock_db.diagnoses.insert_one = AsyncMock()
        mock_db.learner_profiles.insert_one = AsyncMock()
        mock_db.model_audit_log.insert_one = AsyncMock()
        mock_get_db.return_value = mock_db
        with patch("auth.get_db", return_value=mock_db):
            yield mock_db

from main import app
from auth import get_current_user

@pytest.fixture
def client():
    async def override_current_user():
        return {"_id": "mock-parent", "email": "parent@test.local", "role": "parent"}

    app.dependency_overrides[get_current_user] = override_current_user
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()
