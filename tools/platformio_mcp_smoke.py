#!/usr/bin/env python3
"""Smoke checks for the local PlatformIO MCP server."""

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
SERVER = ROOT / "tools" / "run_platformio_mcp.sh"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--timeout", type=float, default=60.0)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--quick", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    proc = spawn_server(["bash", str(SERVER)], ROOT)
    payload = {
        "status": "failed",
        "protocol_version": None,
        "server_name": "platformio",
        "tool_count": 0,
        "checks": [],
        "error": None,
        "pio_installed": False,
    }

    try:
        init = initialize(proc, args.timeout, "kill-life-platformio-mcp-smoke")
        tools = list_tools(proc, args.timeout)
        tool_names = {tool.get("name") for tool in tools}
        expected = {"get_runtime_info", "build", "run_tests", "check_code", "get_metadata", "install_platformio"}
        if expected - tool_names:
            raise SmokeError(f"platformio tools missing: {sorted(expected - tool_names)}")

        payload["protocol_version"] = init.get("protocolVersion", PROTOCOL_VERSION)
        payload["server_name"] = (init.get("serverInfo") or {}).get("name", "platformio")
        payload["tool_count"] = len(tools)
        payload["checks"] = ["initialize", "tools/list"]

        info = call_tool(proc, args.timeout, 3, "get_runtime_info", {})
        if info.get("isError"):
            raise SmokeError("get_runtime_info returned isError=true")
        sc = info.get("structuredContent") or {}
        installed = sc.get("installed", False)
        payload["pio_installed"] = installed
        payload["checks"].append("get_runtime_info")

        if args.quick:
            payload["status"] = "ready"
            return emit_payload(payload, json_output=args.json)

        if not installed:
            # Smoke still passes — pio is optional (install_platformio tool available)
            payload["status"] = "ready"
            payload["note"] = "PlatformIO not installed; use install_platformio tool"
            return emit_payload(payload, json_output=args.json)

        # get_metadata on firmware project
        firmware_dir = str(ROOT / "firmware")
        meta = call_tool(proc, args.timeout, 4, "get_metadata", {"project_dir": firmware_dir})
        if meta.get("isError"):
            sc = meta.get("structuredContent") or {}
            raise SmokeError(f"get_metadata failed: {sc.get('error', '?')}")
        sc = meta.get("structuredContent") or {}
        envs = sc.get("environments", [])
        if not envs:
            raise SmokeError("get_metadata returned no environments")
        payload["checks"].append("get_metadata")
        payload["environments"] = envs

        payload["status"] = "ready"
    except SmokeError as exc:
        payload["error"] = str(exc)
        return emit_payload(payload, json_output=args.json, exit_code=1)
    except Exception as exc:
        payload["error"] = f"unexpected: {exc}"
        return emit_payload(payload, json_output=args.json, exit_code=1)
    finally:
        terminate_server(proc)

    return emit_payload(payload, json_output=args.json)


if __name__ == "__main__":
    raise SystemExit(main())
