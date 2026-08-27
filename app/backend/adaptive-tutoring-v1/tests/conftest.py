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
def mock_bkt_collection():
    with patch("database.bkt_states_collection") as mock_coll:
        mock_coll.find_one = AsyncMock(return_value=None)
        mock_coll.update_one = AsyncMock(return_value=None)
        yield mock_coll

from main import app

@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c
