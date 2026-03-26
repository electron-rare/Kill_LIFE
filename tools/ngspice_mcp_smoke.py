#!/usr/bin/env python3
"""Smoke checks for the local ngspice MCP server."""

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
SERVER = ROOT / "tools" / "run_ngspice_mcp.sh"

# Minimal RC circuit for smoke test
_SMOKE_NETLIST = """\
Kill_LIFE ngspice smoke test
R1 in out 1k
C1 out 0 100nF
V1 in 0 DC 5V
.op
.end
"""


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
        "server_name": "ngspice",
        "tool_count": 0,
        "checks": [],
        "error": None,
    }

    try:
        init = initialize(proc, args.timeout, "kill-life-ngspice-mcp-smoke")
        tools = list_tools(proc, args.timeout)
        tool_names = {tool.get("name") for tool in tools}
        expected = {"get_runtime_info", "run_simulation", "validate_netlist", "parse_operating_point"}
        if expected - tool_names:
            raise SmokeError(f"ngspice tools missing: {sorted(expected - tool_names)}")

        payload["protocol_version"] = init.get("protocolVersion", PROTOCOL_VERSION)
        payload["server_name"] = (init.get("serverInfo") or {}).get("name", "ngspice")
        payload["tool_count"] = len(tools)
        payload["checks"] = ["initialize", "tools/list"]

        info = call_tool(proc, args.timeout, 3, "get_runtime_info", {})
        if info.get("isError"):
            raise SmokeError("get_runtime_info returned isError=true")
        runtime_text = (info.get("content") or [{}])[0].get("text", "")
        payload["checks"].append("get_runtime_info")

        if args.quick:
            payload["status"] = "ready"
            payload["runtime"] = runtime_text
            return emit_payload(payload, json_output=args.json)

        # Full smoke: validate + OP parse
        validate = call_tool(proc, args.timeout, 4, "validate_netlist", {"netlist": _SMOKE_NETLIST})
        if validate.get("isError"):
            sc = validate.get("structuredContent") or {}
            raise SmokeError(f"validate_netlist failed: {sc.get('errors', sc.get('error', '?'))}")
        payload["checks"].append("validate_netlist")

        op = call_tool(proc, args.timeout, 5, "parse_operating_point", {"netlist": _SMOKE_NETLIST})
        if op.get("isError"):
            sc = op.get("structuredContent") or {}
            raise SmokeError(f"parse_operating_point failed: {sc.get('error', '?')}")

        sc = op.get("structuredContent") or {}
        voltages = sc.get("voltages", {})
        if not voltages:
            raise SmokeError("parse_operating_point returned no voltages")
        # Verify V(in) ≈ 5V
        v_in = voltages.get("in", voltages.get("IN"))
        if v_in is None or abs(v_in - 5.0) > 0.1:
            raise SmokeError(f"Expected V(in)≈5V, got {v_in}")
        payload["checks"].append("parse_operating_point")
        payload["voltages"] = voltages

        payload["status"] = "ready"
        payload["runtime"] = runtime_text
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
