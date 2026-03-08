#!/usr/bin/env python3
from __future__ import annotations

import unittest

from tools.mcp_runtime_status import classify_overall, derive_blockers


class McpRuntimeStatusTests(unittest.TestCase):
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


if __name__ == "__main__":
    unittest.main()
