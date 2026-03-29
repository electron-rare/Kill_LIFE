#!/usr/bin/env python3
"""Bridge the Seeed KiCad MCP line-delimited JSON server to framed stdio MCP."""

from __future__ import annotations

import json
import os
import shlex
import subprocess
import sys
import threading
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
TOOLS_DIR = ROOT / "tools"
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from mcp_stdio import make_error, make_response, read_message, write_message  # type: ignore

DEFAULT_COMMAND = "uvx kicad-mcp-server"


def _server_command() -> list[str]:
    raw = os.environ.get("KICAD_MCP_SEEED_COMMAND", DEFAULT_COMMAND).strip()
    if not raw:
        raw = DEFAULT_COMMAND
    return shlex.split(raw)


def _pump_stderr(stderr) -> None:
    try:
        for line in stderr:
            if not line:
                break
            sys.stderr.write(line)
            sys.stderr.flush()
    except Exception:
        return


def _spawn_server() -> subprocess.Popen[str]:
    cmd = _server_command()
    env = os.environ.copy()
    return subprocess.Popen(
        cmd,
        cwd=ROOT,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
        env=env,
    )


def _forward_request(proc: subprocess.Popen[str], request: dict[str, Any]) -> None:
    if proc.stdin is None:
        raise RuntimeError("Seeed KiCad MCP stdin is not available")
    proc.stdin.write(json.dumps(request) + "\n")
    proc.stdin.flush()


def _read_response(proc: subprocess.Popen[str]) -> dict[str, Any]:
    if proc.stdout is None:
        raise RuntimeError("Seeed KiCad MCP stdout is not available")

    line = proc.stdout.readline()
    if line:
        return json.loads(line)

    stderr_tail = ""
    if proc.stderr is not None:
        try:
            stderr_tail = proc.stderr.read().strip()
        except Exception:
            stderr_tail = ""
    raise RuntimeError(
        "Seeed KiCad MCP closed stdout before replying"
        + (f": {stderr_tail}" if stderr_tail else "")
    )


def serve() -> int:
    try:
        proc = _spawn_server()
    except FileNotFoundError as exc:
        write_message(
            make_error(
                None,
                -32000,
                f"Unable to launch Seeed KiCad MCP server: {exc}",
            )
        )
        return 1

    stderr_thread = None
    if proc.stderr is not None:
        stderr_thread = threading.Thread(
            target=_pump_stderr,
            args=(proc.stderr,),
            daemon=True,
        )
        stderr_thread.start()

    try:
        while True:
            request = read_message()
            if request is None:
                break

            request_id = request.get("id")
            method = request.get("method")

            if method == "ping" and request_id is not None:
                write_message(make_response(request_id, {}))
                continue

            if method == "resources/list" and request_id is not None:
                write_message(make_response(request_id, {"resources": []}))
                continue

            if method == "prompts/list" and request_id is not None:
                write_message(make_response(request_id, {"prompts": []}))
                continue

            try:
                _forward_request(proc, request)
                if request_id is None:
                    continue
                response = _read_response(proc)
                if method == "initialize":
                    requested_version = (
                        (request.get("params") or {}).get("protocolVersion") or "2025-03-26"
                    )
                    result = response.get("result") or {}
                    result["protocolVersion"] = requested_version
                    result["capabilities"] = {"tools": {"listChanged": False}}
                    response["result"] = result
            except Exception as exc:
                if request_id is None:
                    continue
                response = make_error(request_id, -32000, str(exc))

            write_message(response)
    finally:
        try:
            if proc.stdin is not None:
                proc.stdin.close()
        except Exception:
            pass
        try:
            proc.terminate()
            proc.wait(timeout=3)
        except Exception:
            try:
                proc.kill()
            except Exception:
                pass
        if stderr_thread is not None:
            stderr_thread.join(timeout=1)

    return 0


if __name__ == "__main__":
    raise SystemExit(serve())
