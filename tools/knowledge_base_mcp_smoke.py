#!/usr/bin/env python3
"""Smoke checks for the local knowledge-base MCP server."""

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
SERVER = ROOT / "tools" / "run_knowledge_base_mcp.sh"
PAGE_ID_ENV = "KNOWLEDGE_BASE_SMOKE_PAGE_ID"


def knowledge_base_auth_configured() -> bool:
    provider = os.getenv("KNOWLEDGE_BASE_PROVIDER", "memos").strip().lower() or "memos"
    if provider == "memos":
        return bool(
            os.getenv("MEMOS_BASE_URL", "").strip()
            and os.getenv("MEMOS_ACCESS_TOKEN", "").strip()
        )
    if provider == "docmost":
        return bool(
            os.getenv("DOCMOST_BASE_URL", "").strip()
            and os.getenv("DOCMOST_EMAIL", "").strip()
            and os.getenv("DOCMOST_PASSWORD", "").strip()
        )
    return False


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--timeout", type=float, default=15.0)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--quick", action="store_true")
    parser.add_argument(
        "--page-id",
        default=os.getenv(PAGE_ID_ENV, "").strip(),
    )
    return parser.parse_args()


def main() -> int:
    load_runtime_env()
    args = parse_args()
    secret_configured = knowledge_base_auth_configured()
    proc = spawn_server(["bash", str(SERVER)], ROOT)
    provider = os.getenv("KNOWLEDGE_BASE_PROVIDER", "memos").strip().lower() or "memos"
    payload = {
        "status": "failed",
        "protocol_version": None,
        "server_name": "knowledge-base",
        "provider": provider,
        "tool_count": 0,
        "checks": [],
        "secret_configured": secret_configured,
        "live_validation": "skipped" if args.quick else "pending",
        "error": None,
    }

    try:
        init = initialize(proc, args.timeout, "kill-life-knowledge-base-mcp-smoke")
        tools = list_tools(proc, args.timeout)
        tool_names = {tool.get("name") for tool in tools}
        expected = {"search_pages", "read_page", "append_to_page", "create_page"}
        if expected - tool_names:
            raise SmokeError(
                f"knowledge-base tools missing: {sorted(expected - tool_names)}"
            )

        payload["protocol_version"] = init.get("protocolVersion", PROTOCOL_VERSION)
        payload["server_name"] = (
            init.get("serverInfo") or {}
        ).get("name", "knowledge-base")
        payload["tool_count"] = len(tools)
        payload["checks"] = ["initialize", "tools/list"]

        if args.quick:
            if secret_configured:
                payload["status"] = "ready"
                payload["live_validation"] = "skipped"
            else:
                payload["status"] = "degraded"
                payload["live_validation"] = "missing_secret"
                payload["error"] = f"{provider} auth missing"
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
