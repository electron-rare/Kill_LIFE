#!/usr/bin/env python3
"""Minimal STDIO smoke test for the supported KiCad MCP launcher."""

from __future__ import annotations

import argparse
import json
import os
import selectors
import signal
import subprocess
import sys
import time
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--timeout",
        type=float,
        default=20.0,
        help="Seconds to wait for each MCP response.",
    )
    parser.add_argument(
        "--profile",
        choices=("v1", "v2"),
        default=None,
        help="Optional MCP profile override for the launcher.",
    )
    return parser.parse_args()


def read_response(proc: subprocess.Popen[str], timeout: float) -> dict[str, Any]:
    if proc.stdout is None:
        raise RuntimeError("stdout pipe is not available")

    if proc.stdout.closed:
        raise RuntimeError("stdout pipe is closed")

    deadline = time.monotonic() + timeout
    selector = selectors.DefaultSelector()
    selector.register(proc.stdout, selectors.EVENT_READ)
    buffer = ""

    try:
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise RuntimeError(f"Timed out after {timeout:.1f}s waiting for MCP response")

            events = selector.select(remaining)
            if not events:
                raise RuntimeError(f"Timed out after {timeout:.1f}s waiting for MCP response")

            line = proc.stdout.readline()
            if not line:
                raise RuntimeError("MCP process closed stdout before replying")

            buffer += line
            if "\n" not in buffer:
                continue

            message, _, remainder = buffer.partition("\n")
            buffer = remainder
            message = message.strip()
            if not message:
                continue

            return json.loads(message)
    finally:
        selector.close()


def send_message(proc: subprocess.Popen[str], payload: dict[str, Any]) -> None:
    if proc.stdin is None:
        raise RuntimeError("stdin pipe is not available")

    body = json.dumps(payload)
    proc.stdin.write(body + "\n")
    proc.stdin.flush()


def main() -> int:
    args = parse_args()
    launcher = ROOT / "tools" / "hw" / "run_kicad_mcp.sh"

    env = os.environ.copy()
    if args.profile:
        env["KICAD_MCP_PROFILE"] = args.profile

    proc = subprocess.Popen(
        ["bash", str(launcher)],
        cwd=ROOT,
        env=env,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
        start_new_session=True,
    )

    try:
        send_message(
            proc,
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {
                    "protocolVersion": "2025-03-26",
                    "capabilities": {},
                    "clientInfo": {"name": "kill-life-mcp-smoke", "version": "1.0.0"},
                },
            },
        )
        init = read_response(proc, args.timeout)

        result = init.get("result") or {}
        protocol_version = result.get("protocolVersion")
        server_info = result.get("serverInfo") or {}
        server_name = server_info.get("name", "unknown")

        send_message(
            proc,
            {
                "jsonrpc": "2.0",
                "method": "notifications/initialized",
                "params": {},
            },
        )
        send_message(
            proc,
            {"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}},
        )
        tools_resp = read_response(proc, args.timeout)
        tools = (tools_resp.get("result") or {}).get("tools") or []

        if not protocol_version:
            raise RuntimeError("initialize response missing protocolVersion")
        if not tools:
            raise RuntimeError("tools/list returned no tools")

        print(f"OK: server={server_name} protocol={protocol_version} tools={len(tools)}")
        return 0
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    finally:
        if proc.poll() is None:
            os.killpg(proc.pid, signal.SIGTERM)
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(proc.pid, signal.SIGKILL)
                proc.wait(timeout=5)

        stderr_output = ""
        if proc.stderr is not None:
            try:
                stderr_output = proc.stderr.read().strip()
            except Exception:
                stderr_output = ""
        if stderr_output and proc.returncode not in (0, None):
            sys.stderr.write(stderr_output + "\n")


if __name__ == "__main__":
    sys.exit(main())
