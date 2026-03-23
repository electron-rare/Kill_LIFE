#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "tools" / "cockpit" / "machine_registry.sh"


class MachineRegistryContractTests(unittest.TestCase):
    def run_script(self, *args: str) -> dict:
        proc = subprocess.run(
            ["bash", str(SCRIPT), *args],
            cwd=str(REPO_ROOT),
            capture_output=True,
            text=True,
            check=True,
        )
        self.assertTrue(proc.stdout.strip(), proc.stderr)
        return json.loads(proc.stdout)

    def test_summary_uses_cockpit_contract(self) -> None:
        payload = self.run_script("--action", "summary", "--json")
        self.assertEqual(payload["contract_version"], "cockpit-v1")
        self.assertEqual(payload["component"], "machine_registry")
        self.assertEqual(payload["contract_status"], "ok")
        self.assertEqual(payload["status"], "ok")
        self.assertEqual(payload["action"], "summary")
        self.assertIn("tower", payload["priority_order"])
        self.assertIn("root-reserve", payload["reserve_targets"])
        self.assertGreaterEqual(payload["target_count"], 1)
        self.assertTrue(payload["artifacts"])

    def test_show_returns_single_machine(self) -> None:
        payload = self.run_script("--action", "show", "--machine", "tower", "--json")
        self.assertEqual(payload["action"], "show")
        self.assertEqual(len(payload["targets"]), 1)
        self.assertEqual(payload["targets"][0]["id"], "tower")


if __name__ == "__main__":
    unittest.main()
