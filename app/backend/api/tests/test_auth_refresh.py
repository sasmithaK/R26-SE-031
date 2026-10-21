"""Regression tests for access-token renewal."""

import asyncio
import pathlib
import sys
import unittest

from bson import ObjectId
from fastapi import BackgroundTasks, HTTPException, Request


API = pathlib.Path(__file__).resolve().parents[1]
ROOT = API.parents[2]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(API))

from routers import auth
from schemas.auth import TokenRefreshRequest


class _Users:
    def __init__(self, user):
        self.user = user

    async def find_one(self, query):
        if self.user and self.user.get("email") == query.get("email"):
            return self.user
        return None


class _Database:
    def __init__(self, user):
        self.users = _Users(user)


class AuthRefreshTests(unittest.TestCase):
    def setUp(self):
        self.original_get_db = auth.get_db
        self.original_verify_token = auth.verify_token
        self.original_create_access_token = auth.create_access_token
        self.original_create_refresh_token = auth.create_refresh_token

    def tearDown(self):
        auth.get_db = self.original_get_db
        auth.verify_token = self.original_verify_token
        auth.create_access_token = self.original_create_access_token
        auth.create_refresh_token = self.original_create_refresh_token

    def _call(self):
        request = Request(
            {
                "type": "http",
                "method": "POST",
                "path": "/api/v1/auth/refresh",
                "headers": [],
                "query_string": b"",
                "client": ("127.0.0.1", 12345),
                "server": ("testserver", 80),
                "scheme": "http",
            }
        )
        return asyncio.run(
            auth.refresh_token_endpoint(
                request=request,
                token_req=TokenRefreshRequest(refresh_token="valid-refresh"),
                background_tasks=BackgroundTasks(),
            )
        )

    def test_refresh_reloads_account_and_rotates_both_tokens(self):
        user_id = ObjectId("000000000000000000000011")
        auth.get_db = lambda: _Database(
            {"_id": user_id, "email": "parent@example.com", "role": "parent"}
        )
        auth.verify_token = lambda token: {
            "sub": "parent@example.com",
            "role": "stale-role",
            "id": "stale-id",
            "type": "refresh",
        }
        issued_claims = []
        auth.create_access_token = lambda data: issued_claims.append(data) or "new-access"
        auth.create_refresh_token = lambda data: "new-refresh"

        result = self._call()

        self.assertEqual(result.access_token, "new-access")
        self.assertEqual(result.refresh_token, "new-refresh")
        self.assertEqual(
            issued_claims,
            [
                {
                    "sub": "parent@example.com",
                    "role": "parent",
                    "id": str(user_id),
                }
            ],
        )

    def test_refresh_rejects_deleted_account(self):
        auth.get_db = lambda: _Database(None)
        auth.verify_token = lambda token: {
            "sub": "deleted@example.com",
            "type": "refresh",
        }

        with self.assertRaises(HTTPException) as raised:
            self._call()

        self.assertEqual(raised.exception.status_code, 401)
        self.assertEqual(raised.exception.detail, "User not found")


if __name__ == "__main__":
    unittest.main(verbosity=2)
