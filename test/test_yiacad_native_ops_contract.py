#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "tools" / "cad" / "yiacad_native_ops.py"


class YiacadNativeOpsContractTests(unittest.TestCase):
    def run_json(self, *args: str) -> tuple[int, dict]:
        proc = subprocess.run(
            ["python3", str(SCRIPT), *args, "--json-output"],
            cwd=str(REPO_ROOT),
            capture_output=True,
            text=True,
        )
        self.assertTrue(proc.stdout.strip(), proc.stderr)
        return proc.returncode, json.loads(proc.stdout)

    def test_manufacturing_package_without_inputs_is_structured(self) -> None:
        rc, payload = self.run_json("manufacturing-package", "--surface", "yiacad-web")
        self.assertNotEqual(rc, 0)
        self.assertEqual(payload["component"], "yiacad")
        self.assertEqual(payload["surface"], "yiacad-web")
        self.assertEqual(payload["action"], "manufacturing.export")
        self.assertEqual(payload["status"], "blocked")
        self.assertIn("degraded_reasons", payload)
        self.assertIn("engine_status", payload)
        self.assertIn("kibot", payload["engine_status"])

    def test_kiauto_checks_without_board_is_structured(self) -> None:
        rc, payload = self.run_json("kiauto-checks", "--surface", "yiacad-web")
        self.assertNotEqual(rc, 0)
        self.assertEqual(payload["component"], "yiacad")
        self.assertEqual(payload["surface"], "yiacad-web")
        self.assertEqual(payload["action"], "manufacturing.validate")
        self.assertEqual(payload["status"], "blocked")
        self.assertIn("degraded_reasons", payload)
        self.assertIn("engine_status", payload)
        self.assertIn("kiauto", payload["engine_status"])


if __name__ == "__main__":
    unittest.main()
