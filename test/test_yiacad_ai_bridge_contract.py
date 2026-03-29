#!/usr/bin/env python3
from __future__ import annotations

import argparse
import contextlib
import io
import json
import unittest
from types import SimpleNamespace
from unittest.mock import patch

import tools.cad.yiacad_ai_bridge as bridge


class YiacadAiBridgeContractTests(unittest.TestCase):
    def test_request_delegates_to_backend_without_persisting_local_queue(self) -> None:
        fake_proc = SimpleNamespace(
            returncode=0,
            stdout=json.dumps({"status": "degraded", "summary": "ok", "next_steps": ["step"]}),
            stderr="",
        )
        args = argparse.Namespace(
            surface="freecad",
            intent="ecad-mcad-sync",
            prompt="",
            source_path="/tmp/demo.FCStd",
            selection_json="[]",
        )
        with patch.object(bridge.subprocess, "run", return_value=fake_proc):
            buffer = io.StringIO()
            with contextlib.redirect_stdout(buffer):
                rc = bridge.command_request(args)
        payload = json.loads(buffer.getvalue())
        self.assertEqual(rc, 0)
        self.assertEqual(payload["request_path"], "")
        self.assertEqual(payload["transport_command"], "ecad-mcad-sync")
        self.assertEqual(payload["surface"], "freecad")


if __name__ == "__main__":
    unittest.main()
