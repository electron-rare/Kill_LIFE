#!/usr/bin/env python3
"""Smoke checks for the local GitHub dispatch MCP server."""

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
SERVER = ROOT / "tools" / "run_github_dispatch_mcp.sh"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--timeout", type=float, default=15.0)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--quick", action="store_true")
    parser.add_argument(
        "--live",
        action="store_true",
        help="Dispatch an allowlisted workflow when a GitHub token is configured.",
    )
    parser.add_argument(
        "--workflow-file",
        default="repo_state.yml",
        help="Allowlisted workflow file to use when --live is enabled.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    token_configured = bool(
        os.getenv("KILL_LIFE_GITHUB_TOKEN") or os.getenv("GITHUB_TOKEN")
    )
    proc = spawn_server(["bash", str(SERVER)], ROOT)
    payload = {
        "status": "failed",
        "protocol_version": None,
        "server_name": "github-dispatch",
        "tool_count": 0,
        "checks": [],
        "token_configured": token_configured,
        "live_requested": args.live,
        "live_validation": "skipped" if not args.live else "pending",
        "error": None,
    }

    try:
        init = initialize(proc, args.timeout, "kill-life-github-dispatch-mcp-smoke")
        tools = list_tools(proc, args.timeout)
        tool_names = {tool.get("name") for tool in tools}
        expected = {"list_allowlisted_workflows", "dispatch_workflow", "get_dispatch_status"}
        if expected - tool_names:
            raise SmokeError(f"github-dispatch tools missing: {sorted(expected - tool_names)}")

        payload["protocol_version"] = init.get("protocolVersion", PROTOCOL_VERSION)
        payload["server_name"] = (init.get("serverInfo") or {}).get("name", "github-dispatch")
        payload["tool_count"] = len(tools)
        payload["checks"] = ["initialize", "tools/list"]

        if args.quick:
            if token_configured:
                payload["status"] = "ready"
                payload["live_validation"] = "skipped"
            else:
                payload["status"] = "degraded"
                payload["live_validation"] = "missing_secret"
                payload["error"] = "KILL_LIFE_GITHUB_TOKEN or GITHUB_TOKEN missing"
            return emit_payload(payload, json_output=args.json)

        list_result = call_tool(
            proc,
            args.timeout,
            3,
            "list_allowlisted_workflows",
            {},
        )
        if list_result.get("isError"):
            raise SmokeError("list_allowlisted_workflows returned isError=true")
        structured = list_result.get("structuredContent") or {}
        workflows = (structured.get("workflows") or []) if isinstance(structured, dict) else []
        if not workflows:
            raise SmokeError("list_allowlisted_workflows returned no workflows")
        payload["checks"].append("list_allowlisted_workflows")

        if not token_configured:
            dispatch_result = call_tool(
                proc,
                args.timeout,
                4,
                "dispatch_workflow",
                {"workflow_file": args.workflow_file},
            )
            if not dispatch_result.get("isError"):
                raise SmokeError("dispatch_workflow unexpectedly succeeded without token")
            payload["checks"].append("dispatch_workflow_missing_secret")
            payload["status"] = "degraded"
            payload["live_validation"] = "missing_secret"
            payload["error"] = "KILL_LIFE_GITHUB_TOKEN or GITHUB_TOKEN missing"
            return emit_payload(payload, json_output=args.json)

        if not args.live:
            payload["status"] = "ready"
            payload["live_validation"] = "skipped"
            return emit_payload(payload, json_output=args.json)

        dispatch_result = call_tool(
            proc,
            args.timeout,
            5,
            "dispatch_workflow",
            {"workflow_file": args.workflow_file},
        )
        if dispatch_result.get("isError"):
            structured = dispatch_result.get("structuredContent") or {}
            raise SmokeError(
                ((structured.get("error") or {}).get("message"))
                if isinstance(structured, dict)
                else "dispatch_workflow failed"
            )
        payload["checks"].append("dispatch_workflow")

        dispatch_structured = dispatch_result.get("structuredContent") or {}
        dispatch_id = dispatch_structured.get("dispatch_id") if isinstance(dispatch_structured, dict) else None
        if not isinstance(dispatch_id, str) or not dispatch_id:
            raise SmokeError("dispatch_workflow returned no dispatch_id")

        status_result = call_tool(
            proc,
            args.timeout,
            6,
            "get_dispatch_status",
            {"dispatch_id": dispatch_id},
        )
        if status_result.get("isError"):
            structured = status_result.get("structuredContent") or {}
            raise SmokeError(
                ((structured.get("error") or {}).get("message"))
                if isinstance(structured, dict)
                else "get_dispatch_status failed"
            )
        payload["checks"].append("get_dispatch_status")
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
