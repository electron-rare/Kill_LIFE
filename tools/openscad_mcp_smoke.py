#!/usr/bin/env python3
"""Smoke checks for the local OpenSCAD MCP server."""

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
SERVER = ROOT / "tools" / "run_openscad_mcp.sh"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--timeout", type=float, default=30.0)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--quick", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    proc = spawn_server(["bash", str(SERVER)], ROOT)
    payload = {
        "status": "failed",
        "protocol_version": None,
        "server_name": "openscad",
        "tool_count": 0,
        "checks": [],
        "error": None,
    }

    try:
        init = initialize(proc, args.timeout, "kill-life-openscad-mcp-smoke")
        tools = list_tools(proc, args.timeout)
        tool_names = {tool.get("name") for tool in tools}
        expected = {"get_runtime_info", "validate_model", "render_model", "export_model"}
        if expected - tool_names:
            raise SmokeError(f"openscad tools missing: {sorted(expected - tool_names)}")

        payload["protocol_version"] = init.get("protocolVersion", PROTOCOL_VERSION)
        payload["server_name"] = (init.get("serverInfo") or {}).get("name", "openscad")
        payload["tool_count"] = len(tools)
        payload["checks"] = ["initialize", "tools/list"]

        info = call_tool(proc, args.timeout, 3, "get_runtime_info", {})
        if info.get("isError"):
            raise SmokeError("get_runtime_info returned isError=true")
        payload["checks"].append("get_runtime_info")

        if args.quick:
            payload["status"] = "ready"
            return emit_payload(payload, json_output=args.json)

        validate = call_tool(
            proc,
            args.timeout,
            4,
            "validate_model",
            {"source": "cube([8, 8, 8], center=true);"},
        )
        if validate.get("isError"):
            structured = validate.get("structuredContent") or {}
            raise SmokeError(
                ((structured.get("error") or {}).get("message"))
                if isinstance(structured, dict)
                else "validate_model failed"
            )
        payload["checks"].append("validate_model")

        render = call_tool(
            proc,
            args.timeout,
            5,
            "render_model",
            {
                "source": "translate([0,0,2]) cylinder(h=4, r=3, center=true);",
                "output_path": ".cad-home/openscad-mcp-smoke/openscad-mcp-smoke.stl",
            },
        )
        if render.get("isError"):
            structured = render.get("structuredContent") or {}
            raise SmokeError(
                ((structured.get("error") or {}).get("message"))
                if isinstance(structured, dict)
                else "render_model failed"
            )
        payload["checks"].append("render_model")

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
