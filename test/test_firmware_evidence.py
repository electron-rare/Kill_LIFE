#!/usr/bin/env python3
from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools import ci_runtime
from tools import collect_evidence as collect_evidence_module


class FirmwareEvidenceTests(unittest.TestCase):
    def test_native_pio_command_detects_repo_local_venv_binary(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo_pio = root / ".venv" / "bin" / "pio"
            repo_pio.parent.mkdir(parents=True, exist_ok=True)
            repo_pio.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
            repo_pio.chmod(0o755)

            with patch("tools.ci_runtime.shutil.which", return_value=None):
                self.assertEqual(ci_runtime.native_pio_command(root), [str(repo_pio)])

    def test_collect_evidence_rejects_stale_artifacts_after_failed_step(self):
        with tempfile.TemporaryDirectory() as tmp:
            evidence_dir = Path(tmp) / "docs" / "evidence" / "linux"
            evidence_dir.mkdir(parents=True, exist_ok=True)
            (evidence_dir / "test.result.json").write_text(
                json.dumps({"returncode": 1}), encoding="utf-8"
            )
            (evidence_dir / "test.stdout.txt").write_text("stdout", encoding="utf-8")
            (evidence_dir / "test.stderr.txt").write_text("stderr", encoding="utf-8")

            spec = ci_runtime.TargetSpec(requested="linux", env="native", mode="test")
            captured = {}

            def capture_summary(path: Path, payload: dict) -> None:
                captured["path"] = path
                captured["payload"] = payload

            with patch.object(collect_evidence_module, "resolve_target", return_value=spec), patch.object(
                collect_evidence_module, "ensure_evidence_dir", return_value=evidence_dir
            ), patch.object(
                collect_evidence_module,
                "collect_artifacts",
                return_value=["firmware/.pio/build/native"],
            ), patch.object(
                collect_evidence_module, "now_utc", return_value="2026-03-11T00:00:00Z"
            ), patch.object(
                collect_evidence_module, "write_json", side_effect=capture_summary
            ):
                ok = collect_evidence_module.collect_evidence("linux")

            self.assertFalse(ok)
            self.assertEqual(captured["path"], evidence_dir / "summary.json")
            self.assertEqual(captured["payload"]["status"], "incomplete")
            self.assertEqual(captured["payload"]["step_returncode"], 1)
            self.assertIn("step_returncode=1", captured["payload"]["missing"])


if __name__ == "__main__":
    unittest.main()
