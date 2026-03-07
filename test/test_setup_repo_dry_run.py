#!/usr/bin/env python3
from __future__ import annotations

import os
import subprocess
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "gh_setup_and_patches" / "setup_repo.sh"


class SetupRepoDryRunTests(unittest.TestCase):
    def test_dry_run_does_not_eval_repo_name(self):
        env = os.environ.copy()
        env["DRY_RUN"] = "1"
        proc = subprocess.run(
            ["bash", str(SCRIPT), "owner/repo$(printf injected)"],
            cwd=str(REPO_ROOT),
            env=env,
            capture_output=True,
            text=True,
        )
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn("owner/repo\\$\\(printf\\ injected\\)", proc.stdout)
        self.assertNotIn("owner/repoinjected", proc.stdout)


if __name__ == "__main__":
    unittest.main()
