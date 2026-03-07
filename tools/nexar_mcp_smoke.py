#!/usr/bin/env python3
"""Smoke checks for the auxiliary Nexar MCP server."""

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

ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT / "tools" / "run_nexar_mcp.sh"
PROTOCOL_VERSION = "2025-03-26"


class SmokeError(RuntimeError):
    pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--timeout", type=float, default=15.0)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--query", default="STM32")
    parser.add_argument("--limit", type=int, default=2)
    parser.add_argument(
        "--live",
        action="store_true",
        help="Fail if the server remains in demo mode instead of using a configured Nexar token.",
    )
    return parser.parse_args()


def spawn_server() -> subprocess.Popen[str]:
    return subprocess.Popen(
        ["bash", str(SERVER)],
        cwd=ROOT,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
        start_new_session=True,
    )


def terminate_server(proc: subprocess.Popen[str]) -> None:
    if proc.poll() is None:
        try:
            if proc.stdin:
                proc.stdin.close()
        except Exception:
            pass
        try:
            os.killpg(proc.pid, signal.SIGTERM)
        except Exception:
            try:
                proc.kill()
            except Exception:
                pass
        try:
            proc.wait(timeout=3)
        except Exception:
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except Exception:
                try:
                    proc.kill()
                except Exception:
                    pass
    for handle in (proc.stdin, proc.stdout, proc.stderr):
        try:
            if handle:
                handle.close()
        except Exception:
            pass


def send_message(proc: subprocess.Popen[str], payload: dict[str, Any]) -> None:
    if proc.stdin is None:
        raise SmokeError("stdin pipe is not available")
    proc.stdin.write(json.dumps(payload) + "\n")
    proc.stdin.flush()


def read_message(proc: subprocess.Popen[str], timeout: float) -> dict[str, Any]:
    if proc.stdout is None:
        raise SmokeError("stdout pipe is not available")

    selector = selectors.DefaultSelector()
    selector.register(proc.stdout, selectors.EVENT_READ)
    deadline = time.monotonic() + timeout

    try:
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise SmokeError(f"Timed out after {timeout:.1f}s waiting for Nexar MCP reply")
            if not selector.select(remaining):
                raise SmokeError(f"Timed out after {timeout:.1f}s waiting for Nexar MCP reply")
            line = proc.stdout.readline()
            if not line:
                stderr = proc.stderr.read().strip() if proc.stderr else ""
                raise SmokeError(f"Nexar MCP closed stdout before replying: {stderr}")
            line = line.strip()
            if not line:
                continue
            return json.loads(line)
    finally:
        selector.close()


def expect_result(message: dict[str, Any], method: str) -> dict[str, Any]:
    if "error" in message:
        raise SmokeError(f"{method} failed: {message['error']}")
    result = message.get("result")
    if result is None:
        raise SmokeError(f"{method} returned no result")
    return result


def emit_payload(payload: dict[str, Any], *, json_output: bool) -> int:
    status = payload.get("status")
    if json_output:
        print(json.dumps(payload, ensure_ascii=True))
    elif status == "ready":
        print(
            "OK: "
            f"server={payload.get('server_name', 'unknown')} "
            f"protocol={payload.get('protocol_version', 'unknown')} "
            f"tools={payload.get('tool_count', 0)} "
            f"parts={payload.get('parts_found', 0)}"
        )
    else:
        print(
            "WARN: "
            f"server={payload.get('server_name', 'unknown')} "
            f"status={status} "
            f"error={payload.get('error', 'unknown error')}",
            file=sys.stderr,
        )
    return 0 if status == "ready" else 1


def main() -> int:
    args = parse_args()
    token_configured = bool(os.getenv("NEXAR_TOKEN") or os.getenv("NEXAR_API_KEY"))
    proc = spawn_server()
    payload: dict[str, Any] = {
        "status": "failed",
        "protocol_version": None,
        "server_name": "nexar-api",
        "tool_count": 0,
        "checks": [],
        "token_configured": token_configured,
        "parts_found": 0,
        "demo_mode": None,
        "error": None,
    }

    try:
        send_message(
            proc,
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {
                    "protocolVersion": PROTOCOL_VERSION,
                    "capabilities": {},
                    "clientInfo": {"name": "kill-life-nexar-mcp-smoke", "version": "1.0.0"},
                },
            },
        )
        init = expect_result(read_message(proc, args.timeout), "initialize")
        payload["protocol_version"] = init.get("protocolVersion")
        payload["server_name"] = (init.get("serverInfo") or {}).get("name", "nexar-api")
        if payload["protocol_version"] != PROTOCOL_VERSION:
            raise SmokeError(
                f"initialize protocolVersion mismatch: expected {PROTOCOL_VERSION}, got {payload['protocol_version']}"
            )
        payload["checks"].append("initialize")

        send_message(proc, {"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}})
        tools_result = expect_result(read_message(proc, args.timeout), "tools/list")
        tools = tools_result.get("tools") or []
        payload["tool_count"] = len(tools)
        if len(tools) < 4:
            raise SmokeError("nexar tools/list mismatch")
        payload["checks"].append("tools/list")

        send_message(
            proc,
            {
                "jsonrpc": "2.0",
                "id": 3,
                "method": "tools/call",
                "params": {
                    "name": "search_parts",
                    "arguments": {"query": args.query, "limit": args.limit},
                },
            },
        )
        search_result = expect_result(read_message(proc, args.timeout), "tools/call search_parts")
        if search_result.get("isError"):
            structured = search_result.get("structuredContent") or {}
            raise SmokeError(
                ((structured.get("error") or {}).get("message"))
                if isinstance(structured, dict)
                else "search_parts returned isError=true"
            )
        payload["checks"].append("search_parts")

        meta = search_result.get("_meta") or {}
        parts = meta.get("parts") or search_result.get("parts") or []
        if not parts:
            raise SmokeError("nexar search did not expose any parts")

        demo_mode = bool(meta.get("demo_mode", search_result.get("demo_mode", False)))
        payload["parts_found"] = len(parts)
        payload["demo_mode"] = demo_mode

        if demo_mode:
            payload["status"] = "degraded"
            payload["error"] = "NEXAR token missing or server running in demo mode"
            if args.live and token_configured:
                payload["status"] = "failed"
                payload["error"] = "Nexar MCP stayed in demo mode despite configured token"
        else:
            payload["status"] = "ready"

        return emit_payload(payload, json_output=args.json)
    except Exception as exc:
        payload["status"] = "failed"
        payload["error"] = str(exc)
        return emit_payload(payload, json_output=args.json)
    finally:
        terminate_server(proc)


if __name__ == "__main__":
    raise SystemExit(main())
