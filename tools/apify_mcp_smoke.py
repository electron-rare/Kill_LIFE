#!/usr/bin/env python3
"""Smoke checks for the local Apify MCP server."""

from __future__ import annotations

import argparse
import os
from pathlib import Path

from mcp_smoke_common import (
    PROTOCOL_VERSION,
    SmokeError,
    call_tool,
    emit_payload,
    initialize,
    list_tools,
    load_runtime_env,
    spawn_server,
    terminate_server,
)

ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT / "tools" / "run_apify_mcp.sh"


def apify_key_configured() -> bool:
    return bool(os.getenv("APIFY_API_KEY", "").strip())


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--timeout", type=float, default=30.0)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--quick", action="store_true")
    return parser.parse_args()


def main() -> int:
    load_runtime_env()
    args = parse_args()
    key_configured = apify_key_configured()
    proc = spawn_server(["bash", str(SERVER)], ROOT)
    payload = {
        "status": "failed",
        "protocol_version": None,
        "server_name": "apify",
        "tool_count": 0,
        "checks": [],
        "apify_key_configured": key_configured,
        "error": None,
    }

    try:
        init = initialize(proc, args.timeout, "kill-life-apify-mcp-smoke")
        tools = list_tools(proc, args.timeout)
        tool_names = {tool.get("name") for tool in tools}
        expected = {"get_runtime_info", "fetch_espressif_docs", "fetch_platformio_registry", "fetch_kicad_library_info", "ingest_to_rag"}
        if expected - tool_names:
            raise SmokeError(f"apify tools missing: {sorted(expected - tool_names)}")

        payload["protocol_version"] = init.get("protocolVersion", PROTOCOL_VERSION)
        payload["server_name"] = (init.get("serverInfo") or {}).get("name", "apify")
        payload["tool_count"] = len(tools)
        payload["checks"] = ["initialize", "tools/list"]

        info = call_tool(proc, args.timeout, 3, "get_runtime_info", {})
        if info.get("isError"):
            raise SmokeError("get_runtime_info returned isError=true")
        sc = info.get("structuredContent") or {}
        mode = sc.get("mode", "unknown") if isinstance(sc, dict) else "unknown"
        payload["mode"] = mode
        payload["checks"].append("get_runtime_info")

        if args.quick:
            payload["status"] = "ready"
            return emit_payload(payload, json_output=args.json)

        if not key_configured:
            payload["status"] = "degraded"
            payload["error"] = "APIFY_API_KEY not configured (direct-scrape fallback active)"
            return emit_payload(payload, json_output=args.json)

        payload["status"] = "ready"
        return emit_payload(payload, json_output=args.json)
    except SmokeError as exc:
        payload["status"] = "failed"
        payload["error"] = str(exc)
        return emit_payload(payload, json_output=args.json)
    except Exception as exc:
        payload["status"] = "failed"
        payload["error"] = f"unexpected: {exc}"
        return emit_payload(payload, json_output=args.json)
    finally:
        terminate_server(proc)


if __name__ == "__main__":
    raise SystemExit(main())
