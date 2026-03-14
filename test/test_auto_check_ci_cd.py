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
                        "stdout": "Evidence pack généré pour esp: /Users/electron/Kill_LIFE/docs/evidence/esp",
                        "stderr": "",
                    },
                    {
                        "command": ["python", "tools/verify_evidence.py", "esp"],
                        "returncode": 0,
                        "stdout": "Evidence pack trouvé pour esp: ['firmware/.pio/build/esp32s3_arduino/firmware.bin', 'firmware/.pio/build/esp32s3_arduino/firmware.elf', 'firmware/.pio/build/esp32s3_arduino/firmware.map', 'firmware/.pio/build/esp32s3_arduino']",
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
        self.assertIn("## Focus failures", summary)
        self.assertIn("| linux | `1` | `test_firmware` | native test failed |", summary)
        self.assertIn("## esp", summary)
        self.assertIn("`build_firmware`", summary)
        self.assertIn("Build terminé pour esp", summary)
        self.assertIn("Evidence pack généré pour esp: docs/evidence/esp", summary)
        self.assertIn("Evidence pack trouvé pour esp: 4 artefacts", summary)
        self.assertNotIn("/Users/electron/Kill_LIFE/docs/evidence/esp", summary)
        self.assertNotIn("firmware.elf', 'firmware.map'", summary)

    def test_render_markdown_summary_omits_focus_failures_when_all_green(self):
        report = self.sample_report()
        report["targets"]["linux"][0]["returncode"] = 0
        report["targets"]["linux"][0]["stderr"] = ""
        report["targets"]["linux"][0]["stdout"] = "Tests terminés pour linux"

        summary = auto_check_ci_cd.render_markdown_summary(report)
        self.assertNotIn("## Focus failures", summary)
        self.assertIn("| linux | `0` | ok |", summary)

    def test_write_step_summary_writes_markdown_when_env_is_set(self):
        report = self.sample_report()
        with tempfile.TemporaryDirectory() as tmp:
            summary_path = Path(tmp) / "summary.md"
            markdown_path = Path(tmp) / "ci_cd_audit_summary.md"
            with patch.object(auto_check_ci_cd, "MARKDOWN_REPORT_PATH", markdown_path), patch.dict(
                os.environ, {auto_check_ci_cd.STEP_SUMMARY_ENV: str(summary_path)}, clear=False
            ):
                auto_check_ci_cd.write_markdown_report(report)
                written = auto_check_ci_cd.write_step_summary(report)

            self.assertEqual(written, summary_path)
            content = summary_path.read_text(encoding="utf-8")
            self.assertIn("Kill_LIFE Evidence Pack Summary", content)
            self.assertIn("Artifact snapshot: `docs/evidence/`", content)
            self.assertEqual(content, markdown_path.read_text(encoding="utf-8"))

    def test_write_markdown_report_writes_sidecar_in_docs_evidence(self):
        report = self.sample_report()
        with tempfile.TemporaryDirectory() as tmp:
            markdown_path = Path(tmp) / "ci_cd_audit_summary.md"
            with patch.object(auto_check_ci_cd, "MARKDOWN_REPORT_PATH", markdown_path):
                written = auto_check_ci_cd.write_markdown_report(report)

            self.assertEqual(written, markdown_path)
            content = markdown_path.read_text(encoding="utf-8")
            self.assertIn("# Kill_LIFE Evidence Pack Summary", content)
            self.assertIn("| linux | `1` | failed (1) |", content)
            self.assertIn("## Focus failures", content)

    def test_compact_repo_paths_keeps_markdown_repo_relative(self):
        signal = "Evidence pack généré: /Users/electron/Kill_LIFE/docs/evidence/linux | prêt"
        compacted = auto_check_ci_cd.markdown_signal(signal)
        self.assertEqual(compacted, "Evidence pack généré: docs/evidence/linux \\| prêt")

    def test_markdown_signal_compacts_artifact_lists(self):
        signal = (
            "Evidence pack trouvé pour linux: "
            "['firmware/.pio/build/native']"
        )
        compacted = auto_check_ci_cd.markdown_signal(signal)
        self.assertEqual(
            compacted,
            "Evidence pack trouvé pour linux: 1 artefact (firmware/.pio/build/native)",
        )


if __name__ == "__main__":
    unittest.main()
