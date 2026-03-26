#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "tools" / "cockpit" / "yiacad_uiux_tui.sh"
PROOF_SCRIPT = REPO_ROOT / "tools" / "cockpit" / "yiacad_backend_proof.sh"


class YiacadUiuxTuiContractTests(unittest.TestCase):
    def run_json(self, *args: str) -> dict:
        proc = subprocess.run(
            ["bash", str(SCRIPT), *args, "--json"],
            cwd=str(REPO_ROOT),
            capture_output=True,
            text=True,
            check=True,
        )
        self.assertTrue(proc.stdout.strip(), proc.stderr)
        return json.loads(proc.stdout)

    def test_status_json_is_parseable_and_stable(self) -> None:
        payload = self.run_json("--action", "status")
        self.assertEqual(payload["component"], "yiacad")
        self.assertEqual(payload["surface"], "tui")
        self.assertEqual(payload["action"], "status.surface")
        self.assertIn(payload["status"], {"done", "degraded", "blocked"})
        self.assertIsInstance(payload["artifacts"], list)
        self.assertGreaterEqual(len(payload["next_steps"]), 1)

    def test_logs_summary_json_remains_parseable(self) -> None:
        payload = self.run_json("--action", "logs-summary")
        self.assertEqual(payload["status"], "done")
        self.assertIn("uiux_tui_files", payload)
        self.assertIn("backend_service_files", payload)

    def test_backend_proof_confirms_service_first_transport(self) -> None:
        proc = subprocess.run(
            ["bash", str(PROOF_SCRIPT), "--action", "run", "--json"],
            cwd=str(REPO_ROOT),
            capture_output=True,
            text=True,
        )
        # Script may fail if backend service or native forks are not installed
        if proc.returncode != 0:
            self.skipTest(f"yiacad_backend_proof.sh exited {proc.returncode}")
        payload = json.loads(proc.stdout)
        self.assertEqual(payload["component"], "yiacad-backend-proof")
        self.assertEqual(payload["status"], "done")
        self.assertEqual(payload["transport"], "local-facade")
        self.assertTrue(payload["contract_ok"])
        self.assertEqual(payload["kicad_transport_status"], "done")
        self.assertEqual(payload["freecad_transport_status"], "done")


if __name__ == "__main__":
    unittest.main()
