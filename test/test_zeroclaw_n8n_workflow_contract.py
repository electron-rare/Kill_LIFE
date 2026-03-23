#!/usr/bin/env python3
from __future__ import annotations

import json
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
WORKFLOW_FILE = REPO_ROOT / "tools" / "ai" / "integrations" / "n8n" / "kill_life_smoke_workflow.json"


class ZeroclawN8nWorkflowContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.payload = json.loads(WORKFLOW_FILE.read_text(encoding="utf-8"))

    def test_tracked_workflow_keeps_stable_identity(self) -> None:
        self.assertEqual(self.payload["id"], "kill-life-n8n-smoke")
        self.assertEqual(self.payload["name"], "Kill LIFE n8n smoke")

    def test_smoke_workflow_uses_an_activatable_trigger(self) -> None:
        trigger_nodes = [node for node in self.payload["nodes"] if node["type"] == "n8n-nodes-base.scheduleTrigger"]
        self.assertEqual(len(trigger_nodes), 1)
        trigger = trigger_nodes[0]
        intervals = trigger["parameters"]["rule"]["interval"]
        self.assertEqual(intervals[0]["field"], "cronExpression")
        self.assertTrue(intervals[0]["expression"].strip())
        node_types = {node["type"] for node in self.payload["nodes"]}
        self.assertNotIn("n8n-nodes-base.manualTrigger", node_types)

    def test_trigger_connects_to_the_noop_smoke_node(self) -> None:
        connections = self.payload["connections"]
        self.assertIn("Yearly Trigger", connections)
        first_link = connections["Yearly Trigger"]["main"][0][0]
        self.assertEqual(first_link["node"], "No Op")


if __name__ == "__main__":
    unittest.main()
