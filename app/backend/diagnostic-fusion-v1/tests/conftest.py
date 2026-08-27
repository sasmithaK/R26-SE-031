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
        mock_db.diagnoses.insert_one = AsyncMock()
        mock_get_db.return_value = mock_db
        yield mock_db

from main import app

@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c
