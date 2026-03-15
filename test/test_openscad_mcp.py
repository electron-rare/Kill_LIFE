#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "tools" / "run_openscad_mcp.sh"


def write_message(proc: subprocess.Popen[str], payload: dict) -> None:
    body = json.dumps(payload)
    proc.stdin.write(f"Content-Length: {len(body.encode('utf-8'))}\r\n\r\n{body}")
    proc.stdin.flush()


def read_message(proc: subprocess.Popen[str]) -> dict:
    headers = {}
    while True:
        line = proc.stdout.readline()
        if not line:
            raise AssertionError("unexpected EOF while reading MCP headers")
        if line in ("\r\n", "\n"):
            break
        key, _, value = line.partition(":")
        headers[key.strip().lower()] = value.strip()

    length = int(headers["content-length"])
    body = proc.stdout.read(length)
    return json.loads(body)


class OpenScadMcpTests(unittest.TestCase):
    def test_server_supports_initialize_and_tools_list(self):
        proc = subprocess.Popen(
            ["bash", str(SCRIPT)],
            cwd=REPO_ROOT,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        try:
            write_message(proc, {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}})
            initialize = read_message(proc)
            self.assertEqual(initialize["result"]["serverInfo"]["name"], "openscad")
            self.assertEqual(initialize["result"]["protocolVersion"], "2025-03-26")

            write_message(proc, {"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}})
            tools_list = read_message(proc)
            tool_names = {tool["name"] for tool in tools_list["result"]["tools"]}
            self.assertEqual(
                tool_names,
                {"get_runtime_info", "validate_model", "render_model", "export_model"},
            )
        finally:
            proc.terminate()
            proc.wait(timeout=5)
            if proc.stdin:
                proc.stdin.close()
            if proc.stdout:
                proc.stdout.close()
            if proc.stderr:
                proc.stderr.close()


if __name__ == "__main__":
    unittest.main()
