#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "tools" / "mistral" / "apply_safe_patch.py"


class ApplySafePatchTests(unittest.TestCase):
    def test_rejects_path_traversal(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir) / "repo"
            outside = Path(tmpdir) / "escape.txt"
            root.mkdir(parents=True)
            patch = Path(tmpdir) / "patch.json"
            patch.write_text(
                json.dumps(
                    {
                        "summary": "attempt traversal",
                        "edits": [
                            {
                                "path": "specs/../../escape.txt",
                                "action": "create",
                                "content": "boom",
                            }
                        ],
                    }
                ),
                encoding="utf-8",
            )
            proc = subprocess.run(
                [sys.executable, str(SCRIPT), "--scope", "ai:spec", "--patch", str(patch), "--root", str(root)],
                cwd=str(REPO_ROOT),
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(proc.returncode, 0)
            self.assertFalse(outside.exists(), proc.stdout + proc.stderr)

    def test_applies_in_scope_edit(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir) / "repo"
            (root / "specs").mkdir(parents=True)
            patch = Path(tmpdir) / "patch.json"
            patch.write_text(
                json.dumps(
                    {
                        "summary": "safe create",
                        "edits": [
                            {
                                "path": "specs/demo.md",
                                "action": "create",
                                "content": "hello",
                            }
                        ],
                    }
                ),
                encoding="utf-8",
            )
            proc = subprocess.run(
                [sys.executable, str(SCRIPT), "--scope", "ai:spec", "--patch", str(patch), "--root", str(root)],
                cwd=str(REPO_ROOT),
                capture_output=True,
                text=True,
            )
            self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
            self.assertEqual((root / "specs" / "demo.md").read_text(encoding="utf-8"), "hello")


if __name__ == "__main__":
    unittest.main()
