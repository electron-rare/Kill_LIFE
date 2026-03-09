#!/usr/bin/env python3
"""Smoke checks for the validate-specs MCP server."""

from __future__ import annotations

import argparse
from pathlib import Path

from mcp_smoke_common import (
    PROTOCOL_VERSION,
    SmokeError,
    call_tool,
    emit_payload,
    initialize,
    list_tools,
    spawn_server,
    terminate_server,
)

ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT / "tools" / "run_validate_specs_mcp.sh"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--timeout", type=float, default=15.0)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--quick", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    proc = spawn_server(["bash", str(SERVER)], ROOT)
    payload = {
        "status": "failed",
        "protocol_version": None,
        "server_name": "validate-specs",
        "tool_count": 0,
        "checks": [],
        "error": None,
    }

    try:
        init = initialize(proc, args.timeout, "kill-life-validate-specs-mcp-smoke")
        tools = list_tools(proc, args.timeout)
        tool_names = {tool.get("name") for tool in tools}
        expected = {"validate_specs", "scan_rfc2119"}
        if expected - tool_names:
            raise SmokeError(f"validate-specs tools missing: {sorted(expected - tool_names)}")

        payload["protocol_version"] = init.get("protocolVersion", PROTOCOL_VERSION)
        payload["server_name"] = (init.get("serverInfo") or {}).get("name", "validate-specs")
        payload["tool_count"] = len(tools)
        payload["checks"] = ["initialize", "tools/list"]

        if not args.quick:
            result = call_tool(proc, args.timeout, 3, "scan_rfc2119", {})
            if result.get("isError"):
                raise SmokeError("scan_rfc2119 returned isError=true")
            payload["checks"].append("scan_rfc2119")

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
