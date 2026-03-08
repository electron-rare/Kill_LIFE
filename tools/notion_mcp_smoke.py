#!/usr/bin/env python3
"""Smoke checks for the local Notion MCP server."""

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
    spawn_server,
    terminate_server,
)

ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT / "tools" / "run_notion_mcp.sh"
PAGE_ID_ENV = "NOTION_MCP_SMOKE_PAGE_ID"


def notion_auth_configured() -> bool:
    auth_mode = os.getenv("NOTION_AUTH_MODE", "api_key").strip().lower()
    if auth_mode == "oauth_oidc":
        return bool(
            os.getenv("NOTION_OAUTH_CLIENT_ID", "").strip()
            and os.getenv("NOTION_OAUTH_CLIENT_SECRET", "").strip()
            and (
                os.getenv("NOTION_OAUTH_ACCESS_TOKEN", "").strip()
                or os.getenv("NOTION_OAUTH_REFRESH_TOKEN", "").strip()
            )
        )
    return bool(os.getenv("NOTION_API_KEY"))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--timeout", type=float, default=15.0)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--quick", action="store_true")
    parser.add_argument("--page-id", default=os.getenv(PAGE_ID_ENV, ""))
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    secret_configured = notion_auth_configured()
    proc = spawn_server(["bash", str(SERVER)], ROOT)
    payload = {
        "status": "failed",
        "protocol_version": None,
        "server_name": "notion",
        "tool_count": 0,
        "checks": [],
        "secret_configured": secret_configured,
        "live_validation": "skipped" if args.quick else "pending",
        "error": None,
    }

    try:
        init = initialize(proc, args.timeout, "kill-life-notion-mcp-smoke")
        tools = list_tools(proc, args.timeout)
        tool_names = {tool.get("name") for tool in tools}
        expected = {"search_pages", "read_page", "append_to_page", "create_page"}
        if expected - tool_names:
            raise SmokeError(f"notion tools missing: {sorted(expected - tool_names)}")

        payload["protocol_version"] = init.get("protocolVersion", PROTOCOL_VERSION)
        payload["server_name"] = (init.get("serverInfo") or {}).get("name", "notion")
        payload["tool_count"] = len(tools)
        payload["checks"] = ["initialize", "tools/list"]

        if args.quick:
            if secret_configured:
                payload["status"] = "ready"
                payload["live_validation"] = "skipped"
            else:
                payload["status"] = "degraded"
                payload["live_validation"] = "missing_secret"
                payload["error"] = "NOTION auth missing"
            return emit_payload(payload, json_output=args.json)

        search_result = call_tool(
            proc,
            args.timeout,
            3,
            "search_pages",
            {"query": "mcp smoke", "limit": 3},
        )
        if search_result.get("isError"):
            structured = search_result.get("structuredContent") or {}
            payload["checks"].append("search_pages_missing_secret")
            payload["status"] = "degraded"
            payload["live_validation"] = "missing_secret"
            payload["error"] = (
                ((structured.get("error") or {}).get("message"))
                if isinstance(structured, dict)
                else "search_pages failed"
            ) or "search_pages failed"
            return emit_payload(payload, json_output=args.json)

        payload["checks"].append("search_pages")
        if args.page_id:
            read_result = call_tool(
                proc,
                args.timeout,
                4,
                "read_page",
                {"page_id": args.page_id},
            )
            if read_result.get("isError"):
                structured = read_result.get("structuredContent") or {}
                raise SmokeError(
                    ((structured.get("error") or {}).get("message"))
                    if isinstance(structured, dict)
                    else "read_page failed"
                )
            payload["checks"].append("read_page")

        payload["status"] = "ready"
        payload["live_validation"] = "passed"
        return emit_payload(payload, json_output=args.json)
    except Exception as exc:
        payload["status"] = "failed"
        payload["error"] = str(exc)
        return emit_payload(payload, json_output=args.json)
    finally:
        terminate_server(proc)


if __name__ == "__main__":
    raise SystemExit(main())
