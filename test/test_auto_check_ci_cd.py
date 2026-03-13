#!/usr/bin/env python3
from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools import auto_check_ci_cd


class AutoCheckCiCdTests(unittest.TestCase):
    def sample_report(self) -> dict:
        return {
            "compliance": {
                "command": ["python", "tools/compliance/validate.py", "--strict"],
                "returncode": 0,
                "stdout": "OK: compliance profile validated.",
                "stderr": "",
            },
            "targets": {
                "esp": [
                    {
                        "command": ["python", "tools/build_firmware.py", "esp"],
                        "returncode": 0,
                        "stdout": "Build terminé pour esp",
                        "stderr": "",
                    },
                    {
                        "command": ["python", "tools/collect_evidence.py", "esp"],
                        "returncode": 0,
                        "stdout": "Evidence pack généré pour esp",
                        "stderr": "",
                    },
                ],
                "linux": [
                    {
                        "command": ["python", "tools/test_firmware.py", "linux"],
                        "returncode": 1,
                        "stdout": "",
                        "stderr": "native test failed",
                    }
                ],
            },
        }

    def test_render_markdown_summary_contains_lane_table_and_step_details(self):
        summary = auto_check_ci_cd.render_markdown_summary(self.sample_report())
        self.assertIn("# Kill_LIFE Evidence Pack Summary", summary)
        self.assertIn("| compliance | `0` | ok |", summary)
        self.assertIn("| esp | `0` | ok |", summary)
        self.assertIn("| linux | `1` | failed (1) |", summary)
        self.assertIn("## esp", summary)
        self.assertIn("`build_firmware`", summary)
        self.assertIn("Build terminé pour esp", summary)

    def test_write_step_summary_writes_markdown_when_env_is_set(self):
        report = self.sample_report()
        with tempfile.TemporaryDirectory() as tmp:
            summary_path = Path(tmp) / "summary.md"
            with patch.dict(os.environ, {auto_check_ci_cd.STEP_SUMMARY_ENV: str(summary_path)}, clear=False):
                written = auto_check_ci_cd.write_step_summary(report)

            self.assertEqual(written, summary_path)
            content = summary_path.read_text(encoding="utf-8")
            self.assertIn("Kill_LIFE Evidence Pack Summary", content)
            self.assertIn("Artifact snapshot: `docs/evidence/`", content)


if __name__ == "__main__":
    unittest.main()
