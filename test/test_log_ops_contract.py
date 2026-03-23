#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "tools" / "cockpit" / "log_ops.sh"


class LogOpsContractTests(unittest.TestCase):
    def run_script(self, target_dirs: list[Path], *args: str) -> dict:
        env = os.environ.copy()
        env["LOG_OPS_TARGET_DIRS"] = ":".join(str(path) for path in target_dirs)
        proc = subprocess.run(
            ["bash", str(SCRIPT), *args],
            cwd=str(REPO_ROOT),
            env=env,
            capture_output=True,
            text=True,
            check=True,
        )
        self.assertTrue(proc.stdout.strip(), proc.stderr)
        return json.loads(proc.stdout)

    def test_summary_is_ok_when_no_logs_are_present(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            artifacts = root / "artifacts"
            logs = root / "logs"
            scratch = root / "tmp"
            for directory in (artifacts, logs, scratch):
                directory.mkdir(parents=True, exist_ok=True)

            payload = self.run_script([artifacts, logs, scratch], "--action", "summary", "--json")
            self.assertEqual(payload["contract_version"], "cockpit-v1")
            self.assertEqual(payload["component"], "log_ops")
            self.assertEqual(payload["status"], "done")
            self.assertEqual(payload["contract_status"], "ok")
            self.assertEqual(payload["count"], 0)
            self.assertEqual(payload["stale"], 0)

    def test_purge_removes_stale_logs_from_overridden_targets(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            artifacts = root / "artifacts"
            logs = root / "logs"
            scratch = root / "tmp"
            for directory in (artifacts, logs, scratch):
                directory.mkdir(parents=True, exist_ok=True)

            stale_file = logs / "stale.log"
            stale_file.write_text("old log\n", encoding="utf-8")
            old_epoch = stale_file.stat().st_mtime - (3 * 24 * 60 * 60)
            os.utime(stale_file, (old_epoch, old_epoch))

            summary = self.run_script(
                [artifacts, logs, scratch],
                "--action",
                "summary",
                "--retention-days",
                "1",
                "--json",
            )
            self.assertEqual(summary["status"], "degraded")
            self.assertEqual(summary["stale"], 1)

            purge = self.run_script(
                [artifacts, logs, scratch],
                "--action",
                "purge",
                "--retention-days",
                "1",
                "--apply",
                "--json",
            )
            self.assertEqual(purge["status"], "done")
            self.assertEqual(purge["purged_count"], 1)
            self.assertFalse(stale_file.exists())

    def test_summary_json_escapes_paths_with_quotes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            artifacts = root / "artifacts"
            logs = root / "logs"
            scratch = root / "tmp"
            for directory in (artifacts, logs, scratch):
                directory.mkdir(parents=True, exist_ok=True)

            quoted_file = logs / 'quoted"log.log'
            quoted_file.write_text("quoted path\n", encoding="utf-8")

            payload = self.run_script([artifacts, logs, scratch], "--action", "summary", "--json")
            self.assertEqual(payload["status"], "done")
            self.assertIn(str(quoted_file), payload["files"])


if __name__ == "__main__":
    unittest.main()
