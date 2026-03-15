#!/usr/bin/env python3
from __future__ import annotations

import asyncio
import json
import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from tools.mcp_runtime_status import classify_overall, derive_blockers, run_check


class McpRuntimeStatusTests(unittest.TestCase):
    class _FakeProc:
        def __init__(self, stdout: str, stderr: str = "", returncode: int = 0):
            self._stdout = stdout.encode("utf-8")
            self._stderr = stderr.encode("utf-8")
            self.returncode = returncode

        async def communicate(self):
            return self._stdout, self._stderr

    def test_classify_ready(self):
        results = [
            {"status": "ready", "accept_degraded": False},
            {"status": "ready", "accept_degraded": True},
        ]
        self.assertEqual(classify_overall(results, strict=False), "ready")

    def test_classify_degraded_when_only_soft_blockers_exist(self):
        results = [
            {"status": "ready", "accept_degraded": False},
            {"status": "degraded", "accept_degraded": True},
        ]
        self.assertEqual(classify_overall(results, strict=False), "degraded")
        self.assertEqual(classify_overall(results, strict=True), "failed")

    def test_optional_degraded_path_does_not_block_non_strict_runtime(self):
        results = [
            {"status": "ready", "accept_degraded": False},
            {
                "name": "kicad-host",
                "status": "degraded",
                "accept_degraded": True,
                "optional_degraded": True,
                "task": "K-012",
                "blocked_when": "host_pcbnew_import != ok (optional host-native path)",
                "error": "pcbnew not importable on host runtime",
            },
        ]
        self.assertEqual(classify_overall(results, strict=False), "ready")
        self.assertEqual(classify_overall(results, strict=True), "failed")
        self.assertEqual(derive_blockers(results), [])

    def test_classify_failed_when_hard_failure_exists(self):
        results = [
            {"status": "ready", "accept_degraded": False},
            {"status": "failed", "accept_degraded": True},
        ]
        self.assertEqual(classify_overall(results, strict=False), "failed")

    def test_derive_blockers_only_from_degraded_task_checks(self):
        results = [
            {
                "name": "kicad-host",
                "status": "degraded",
                "task": "K-012",
                "blocked_when": "host_pcbnew_import != ok",
                "error": "pcbnew not importable on host runtime",
            },
            {
                "name": "nexar-api",
                "status": "ready",
                "task": "K-014",
                "blocked_when": "token missing or demo mode",
            },
        ]
        self.assertEqual(
            derive_blockers(results),
            [
                {
                    "task": "K-012",
                    "check": "kicad-host",
                    "reason": "pcbnew not importable on host runtime",
                    "condition": "host_pcbnew_import != ok",
                }
            ],
        )

    def test_run_check_marks_external_quota_limit_as_optional_degraded(self):
        spec = {
            "name": "nexar-api",
            "cmd": ["python3", "tools/nexar_mcp_smoke.py", "--json"],
            "accept_degraded": True,
            "task": "K-014",
            "blocked_when": "live Nexar unavailable",
            "optional_degraded_when_live_validation": ("quota_exceeded",),
        }
        stdout = json.dumps(
            {
                "status": "degraded",
                "live_validation": "quota_exceeded",
                "error": "quota exceeded",
            }
        )
        fake_proc = self._FakeProc(stdout=stdout, stderr="", returncode=0)

        async def fake_spawn(*args, **kwargs):
            return fake_proc

        with mock.patch("tools.mcp_runtime_status.asyncio.create_subprocess_exec", side_effect=fake_spawn):
            payload = asyncio.run(run_check(spec))
        self.assertTrue(payload["optional_degraded"])
        self.assertEqual(payload["task"], "K-014")


if __name__ == "__main__":
    unittest.main()
