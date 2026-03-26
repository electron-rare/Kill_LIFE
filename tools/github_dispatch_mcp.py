#!/usr/bin/env python3
"""Local MCP server for GitHub workflow_dispatch operations."""

from __future__ import annotations

import asyncio
import os
import sys
from pathlib import Path
from typing import Any

from mcp_stdio import (  # type: ignore
    PROTOCOL_VERSION,
    error_tool_result,
    make_error,
    make_response,
    ok_tool_result,
    read_message,
    write_message,
)

ROOT = Path(__file__).resolve().parents[1]
MASCARADE_DIR = Path(os.environ.get("MASCARADE_DIR", ROOT.parent / "mascarade")).resolve()
MASCARADE_CORE_DIR = MASCARADE_DIR / "core"

if str(MASCARADE_CORE_DIR) not in sys.path:
    sys.path.insert(0, str(MASCARADE_CORE_DIR))

GITHUB_DISPATCH_IMPORT_ERROR: str | None = None

try:
    from mascarade.integrations.github_dispatch import (  # noqa: E402
        DEFAULT_GITHUB_REPO,
        GitHubDispatchAuthError,
        GitHubDispatchClient,
        GitHubDispatchError,
        list_allowlisted_workflows,
    )
except ModuleNotFoundError as exc:  # pragma: no cover - exercised through smoke flow
    GITHUB_DISPATCH_IMPORT_ERROR = str(exc)
    DEFAULT_GITHUB_REPO = os.getenv("GITHUB_DISPATCH_REPO", "electron-rare/Kill_LIFE")

    class GitHubDispatchError(RuntimeError):
        pass

    class GitHubDispatchAuthError(GitHubDispatchError):
        pass

    class GitHubDispatchClient:
        async def dispatch_workflow(self, workflow_file: str, ref: str | None = None, inputs: dict[str, Any] | None = None) -> dict[str, Any]:
            token = os.getenv("KILL_LIFE_GITHUB_TOKEN") or os.getenv("GITHUB_TOKEN")
            if not token:
                raise GitHubDispatchAuthError(
                    "GitHub token not configured: set KILL_LIFE_GITHUB_TOKEN or GITHUB_TOKEN"
                )
            raise GitHubDispatchError(
                f"Mascarade github_dispatch integration unavailable: {GITHUB_DISPATCH_IMPORT_ERROR}"
            )

        async def get_dispatch_status(self, dispatch_id: str) -> dict[str, Any]:
            raise GitHubDispatchError(
                f"Mascarade github_dispatch integration unavailable: {GITHUB_DISPATCH_IMPORT_ERROR}"
            )

        async def close(self) -> None:
            return None

    def list_allowlisted_workflows() -> list[str]:
        workflows_dir = ROOT / ".github" / "workflows"
        if not workflows_dir.is_dir():
            return ["repo_state.yml"]
        return sorted(path.name for path in workflows_dir.glob("*.yml"))


TOOLS = [
    {
        "name": "list_allowlisted_workflows",
        "description": "List the GitHub Actions workflows allowed for dispatch in this workspace.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "dispatch_workflow",
        "description": "Dispatch an allowlisted GitHub Actions workflow.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "workflow_file": {
                    "type": "string",
                    "description": "Allowlisted workflow file to dispatch",
                },
                "ref": {"type": "string", "description": "Git ref to dispatch against"},
                "inputs": {
                    "type": "object",
                    "description": "Workflow dispatch inputs",
                },
            },
            "required": ["workflow_file"],
        },
    },
    {
        "name": "get_dispatch_status",
        "description": "Resolve the structured status of a previously dispatched workflow.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "dispatch_id": {
                    "type": "string",
                    "description": "Dispatch identifier returned by dispatch_workflow",
                }
            },
            "required": ["dispatch_id"],
        },
    },
]


async def tool_list_allowlisted_workflows(_: dict[str, Any]) -> dict[str, Any]:
    workflows = list_allowlisted_workflows()
    payload = {"ok": True, "repo": DEFAULT_GITHUB_REPO, "workflows": workflows}
    return ok_tool_result(
        f"{len(workflows)} allowlisted GitHub workflow(s)",
        payload,
    )


async def tool_dispatch_workflow(arguments: dict[str, Any]) -> dict[str, Any]:
    workflow_file = str(arguments.get("workflow_file", "")).strip()
    ref = str(arguments.get("ref", "")).strip() or None
    raw_inputs = arguments.get("inputs")
    inputs = raw_inputs if isinstance(raw_inputs, dict) else None
    if not workflow_file:
        return error_tool_result(
            "Missing required argument 'workflow_file'",
            {
                "ok": False,
                "error": {
                    "code": "invalid_arguments",
                    "message": "workflow_file is required",
                },
            },
        )

    client = GitHubDispatchClient()
    try:
        payload = await client.dispatch_workflow(workflow_file, ref=ref, inputs=inputs)
        return ok_tool_result(
            f"Accepted GitHub dispatch for {payload['workflow_file']}",
            {"ok": True, **payload},
        )
    except GitHubDispatchAuthError as exc:
        return error_tool_result(
            str(exc),
            {"ok": False, "error": {"code": "missing_secret", "message": str(exc)}},
        )
    except GitHubDispatchError as exc:
        return error_tool_result(
            str(exc),
            {"ok": False, "error": {"code": "dispatch_failed", "message": str(exc)}},
        )
    finally:
        await client.close()


async def tool_get_dispatch_status(arguments: dict[str, Any]) -> dict[str, Any]:
    dispatch_id = str(arguments.get("dispatch_id", "")).strip()
    if not dispatch_id:
        return error_tool_result(
            "Missing required argument 'dispatch_id'",
            {
                "ok": False,
                "error": {
                    "code": "invalid_arguments",
                    "message": "dispatch_id is required",
                },
            },
        )

    client = GitHubDispatchClient()
    try:
        payload = await client.get_dispatch_status(dispatch_id)
        return ok_tool_result(
            f"Dispatch {dispatch_id} status is {payload['status']}",
            {"ok": True, **payload},
        )
    except GitHubDispatchError as exc:
        return error_tool_result(
            str(exc),
            {"ok": False, "error": {"code": "status_failed", "message": str(exc)}},
        )
    finally:
        await client.close()


def serve_mcp() -> int:
    while True:
        request = read_message()
        if request is None:
            return 0

        method = request.get("method")
        request_id = request.get("id")
        params = request.get("params") or {}

        if method == "initialize":
            write_message(
                make_response(
                    request_id,
                    {
                        "protocolVersion": PROTOCOL_VERSION,
                        "capabilities": {"tools": {"listChanged": False}},
                        "serverInfo": {"name": "github-dispatch", "version": "1.0.0"},
                    },
                )
            )
            continue

        if method == "notifications/initialized":
            continue

        if method == "ping":
            write_message(make_response(request_id, {}))
            continue

        if method == "tools/list":
            write_message(make_response(request_id, {"tools": TOOLS}))
            continue

        if method == "tools/call":
            tool_name = params.get("name")
            arguments = params.get("arguments") or {}

            if tool_name == "list_allowlisted_workflows":
                write_message(
                    make_response(request_id, asyncio.run(tool_list_allowlisted_workflows(arguments)))
                )
                continue
            if tool_name == "dispatch_workflow":
                write_message(
                    make_response(request_id, asyncio.run(tool_dispatch_workflow(arguments)))
                )
                continue
            if tool_name == "get_dispatch_status":
                write_message(
                    make_response(request_id, asyncio.run(tool_get_dispatch_status(arguments)))
                )
                continue

            write_message(make_error(request_id, -32602, f"Unknown tool: {tool_name}"))
            continue

        if request_id is not None:
            write_message(make_error(request_id, -32601, f"Method not found: {method}"))


if __name__ == "__main__":
    raise SystemExit(serve_mcp())
