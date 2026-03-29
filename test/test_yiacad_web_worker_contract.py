#!/usr/bin/env python3
from __future__ import annotations

import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
WORKER = REPO_ROOT / "web" / "workers" / "eda-worker.mjs"


class YiacadWebWorkerContractTests(unittest.TestCase):
    def test_worker_routes_all_yiacad_flows_through_backend_client(self) -> None:
        content = WORKER.read_text(encoding="utf-8")
        self.assertIn('resolve(repoRoot, "tools/cad/yiacad_backend_client.py")', content)
        self.assertIn('"yiacad-web"', content)
        self.assertNotIn('resolve(repoRoot, "tools/cad/yiacad_native_ops.py")', content)
        self.assertNotIn('resolve(repoRoot, "tools/cockpit/fab_package_tui.sh")', content)
        self.assertIn('"manufacturing-package"', content)
        self.assertIn('"kiauto-checks"', content)


if __name__ == "__main__":
    unittest.main()
