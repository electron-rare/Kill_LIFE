#!/usr/bin/env python3
from __future__ import annotations

import unittest
from unittest.mock import patch

from fastapi.testclient import TestClient

from kill_life.agent_catalog import canonical_agent_ids, legacy_runtime_aliases
from kill_life.server import app


class DummyResponse:
    def __init__(self, payload: dict):
        self._payload = payload

    def raise_for_status(self) -> None:
        return None

    def json(self) -> dict:
        return self._payload


class DummyAsyncClient:
    last_url: str | None = None
    last_payload: dict | None = None

    def __init__(self, *args, **kwargs) -> None:
        self.timeout = kwargs.get("timeout")

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc, tb):
        return False

    async def post(self, url: str, json: dict) -> DummyResponse:
        DummyAsyncClient.last_url = url
        DummyAsyncClient.last_payload = json
        return DummyResponse({"reply": "ok"})


class KillLifeAgentApiTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = TestClient(app)

    def test_list_agents_uses_canonical_catalog(self) -> None:
        response = self.client.get("/agents")
        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload["count"], 12)
        self.assertEqual(set(payload["agents"].keys()), set(canonical_agent_ids()))

    def test_legacy_agents_return_gone_with_migration_mapping(self) -> None:
        for legacy_id, canonical_id in legacy_runtime_aliases().items():
            with self.subTest(legacy_id=legacy_id):
                response = self.client.post(f"/agents/{legacy_id}/run", json={"input": "hello"})
                self.assertEqual(response.status_code, 410)
                detail = response.json()["detail"]
                self.assertEqual(detail["legacy_agent"], legacy_id)
                self.assertEqual(detail["canonical_agent"], canonical_id)
                self.assertIn("removed from the runtime API", detail["message"])

    def test_canonical_agent_run_routes_through_mascarade(self) -> None:
        with patch("kill_life.server.httpx.AsyncClient", DummyAsyncClient):
            response = self.client.post(
                "/agents/PM-Mesh/run",
                json={"input": "Plan the next lot", "context": {"lot_id": "T-123"}},
            )

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload["agent"], "PM-Mesh")
        self.assertEqual(payload["status"], "ok")
        self.assertEqual(payload["response"], {"reply": "ok"})
        self.assertTrue(DummyAsyncClient.last_url and DummyAsyncClient.last_url.endswith("/v1/send"))
        self.assertIsNotNone(DummyAsyncClient.last_payload)
        assert DummyAsyncClient.last_payload is not None
        self.assertEqual(DummyAsyncClient.last_payload["routing_policy"], "auto")
        self.assertIn("Plan the next lot", DummyAsyncClient.last_payload["messages"][0]["content"])
        self.assertIn('"lot_id": "T-123"', DummyAsyncClient.last_payload["messages"][0]["content"])


if __name__ == "__main__":
    unittest.main()
