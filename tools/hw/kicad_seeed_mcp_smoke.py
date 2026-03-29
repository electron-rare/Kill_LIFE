#!/usr/bin/env python3
"""Smoke checks for the bridged Seeed KiCad MCP server."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
TOOLS_DIR = ROOT / "tools"
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

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

SERVER = ROOT / "tools" / "hw" / "run_kicad_seeed_mcp.sh"
EXPECTED_TOOLS = {"list_projects", "run_drc", "run_erc", "get_version"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--timeout", type=float, default=45.0)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--quick", action="store_true")
    return parser.parse_args()


def parse_tool_payload(result: dict[str, Any], tool_name: str) -> dict[str, Any]:
    content = result.get("content") or []
    if not content:
        raise SmokeError(f"{tool_name} returned no content")

    text = content[0].get("text") if isinstance(content[0], dict) else None
    if not isinstance(text, str) or not text.strip():
        raise SmokeError(f"{tool_name} returned empty text content")

    try:
        payload = json.loads(text)
    except json.JSONDecodeError as exc:
        raise SmokeError(f"{tool_name} returned invalid JSON content: {exc}") from exc

    if not isinstance(payload, dict):
        raise SmokeError(f"{tool_name} returned unexpected payload type: {type(payload).__name__}")
    if payload.get("error"):
        raise SmokeError(f"{tool_name} returned error: {payload['error']}")
    return payload


def main() -> int:
    args = parse_args()
    proc = spawn_server(["bash", str(SERVER)], ROOT)
    payload = {
        "status": "failed",
        "protocol_version": None,
        "server_name": "kicad-seeed",
        "tool_count": 0,
        "checks": [],
        "error": None,
        "pcbnew_api": None,
        "project_count": None,
        "feature_count": None,
    }

    try:
        init = initialize(proc, args.timeout, "kill-life-kicad-seeed-mcp-smoke")
        tools = list_tools(proc, args.timeout)
        tool_names = {tool.get("name") for tool in tools}
        if EXPECTED_TOOLS - tool_names:
            raise SmokeError(f"kicad seeed tools missing: {sorted(EXPECTED_TOOLS - tool_names)}")

        payload["protocol_version"] = init.get("protocolVersion", PROTOCOL_VERSION)
        payload["server_name"] = (init.get("serverInfo") or {}).get("name", "kicad-seeed")
        payload["tool_count"] = len(tools)
        payload["checks"] = ["initialize", "tools/list"]

        version_payload = parse_tool_payload(call_tool(proc, args.timeout, 3, "get_version", {}), "get_version")
        if "mcp_server" not in version_payload:
            raise SmokeError("get_version missing mcp_server")
        payload["checks"].append("get_version")
        payload["pcbnew_api"] = version_payload.get("pcbnew_api")
        payload["feature_count"] = len(version_payload.get("features") or [])

        projects_payload = parse_tool_payload(
            call_tool(proc, args.timeout, 4, "list_projects", {}),
            "list_projects",
        )
        if "count" not in projects_payload or "projects" not in projects_payload:
            raise SmokeError("list_projects missing count/projects fields")
        payload["checks"].append("list_projects")
        payload["project_count"] = projects_payload.get("count")

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
