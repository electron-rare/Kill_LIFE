#!/usr/bin/env python3
"""Local MCP server for the existing Mascarade Notion integration."""

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

from mascarade.integrations.notion import (  # noqa: E402
    NotionClient,
    notion_auth_configured,
)


TOOLS = [
    {
        "name": "search_pages",
        "description": "Search pages through the existing Mascarade Notion integration.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Free-text query"},
                "limit": {
                    "type": "integer",
                    "description": "Maximum number of pages to return",
                    "default": 10,
                },
            },
            "required": ["query"],
        },
    },
    {
        "name": "read_page",
        "description": "Read a Notion page and return its plain-text content.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "page_id": {"type": "string", "description": "Notion page identifier"}
            },
            "required": ["page_id"],
        },
    },
    {
        "name": "append_to_page",
        "description": "Append a paragraph block to an existing Notion page.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "page_id": {"type": "string", "description": "Notion page identifier"},
                "content": {"type": "string", "description": "Paragraph content to append"},
            },
            "required": ["page_id", "content"],
        },
    },
    {
        "name": "create_page",
        "description": "Create a page under a parent page using the existing Notion integration.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "parent_id": {"type": "string", "description": "Parent page identifier"},
                "title": {"type": "string", "description": "Page title"},
                "content": {
                    "type": "string",
                    "description": "Optional initial page content",
                    "default": "",
                },
            },
            "required": ["parent_id", "title"],
        },
    },
]


def _missing_secret_payload() -> dict[str, Any]:
    return {
        "ok": False,
        "error": {
            "code": "missing_secret",
            "message": (
                "Notion non configure "
                "(NOTION_API_KEY ou credentials OAuth Notion manquants)"
            ),
        },
    }


async def _with_client(callback):
    if not notion_auth_configured():
        return error_tool_result(
            "Notion non configure (NOTION_API_KEY ou credentials OAuth Notion manquants)",
            _missing_secret_payload(),
        )

    client = NotionClient()
    try:
        return await callback(client)
    finally:
        await client.close()


async def tool_search_pages(arguments: dict[str, Any]) -> dict[str, Any]:
    query = str(arguments.get("query", "")).strip()
    limit = int(arguments.get("limit", 10) or 10)
    limit = max(1, min(limit, 50))
    if not query:
        return error_tool_result(
            "Missing required argument 'query'",
            {"ok": False, "error": {"code": "invalid_arguments", "message": "query is required"}},
        )

    async def _run(client: NotionClient) -> dict[str, Any]:
        results = await client.search(query)
        payload = {"ok": True, "query": query, "results": results[:limit]}
        return ok_tool_result(
            f"Found {len(payload['results'])} Notion page(s) for '{query}'",
            payload,
        )

    return await _with_client(_run)


async def tool_read_page(arguments: dict[str, Any]) -> dict[str, Any]:
    page_id = str(arguments.get("page_id", "")).strip()
    if not page_id:
        return error_tool_result(
            "Missing required argument 'page_id'",
            {
                "ok": False,
                "error": {"code": "invalid_arguments", "message": "page_id is required"},
            },
        )

    async def _run(client: NotionClient) -> dict[str, Any]:
        content = await client.read_page(page_id)
        payload = {"ok": True, "page_id": page_id, "content": content}
        return ok_tool_result(
            f"Read Notion page {page_id}",
            payload,
        )

    return await _with_client(_run)


async def tool_append_to_page(arguments: dict[str, Any]) -> dict[str, Any]:
    page_id = str(arguments.get("page_id", "")).strip()
    content = str(arguments.get("content", "")).strip()
    if not page_id or not content:
        return error_tool_result(
            "Missing required arguments 'page_id' or 'content'",
            {
                "ok": False,
                "error": {
                    "code": "invalid_arguments",
                    "message": "page_id and content are required",
                },
            },
        )

    async def _run(client: NotionClient) -> dict[str, Any]:
        await client.append_to_page(page_id, content)
        payload = {"ok": True, "page_id": page_id, "content_length": len(content)}
        return ok_tool_result(
            f"Appended content to Notion page {page_id}",
            payload,
        )

    return await _with_client(_run)


async def tool_create_page(arguments: dict[str, Any]) -> dict[str, Any]:
    parent_id = str(arguments.get("parent_id", "")).strip()
    title = str(arguments.get("title", "")).strip()
    content = str(arguments.get("content", "") or "")
    if not parent_id or not title:
        return error_tool_result(
            "Missing required arguments 'parent_id' or 'title'",
            {
                "ok": False,
                "error": {
                    "code": "invalid_arguments",
                    "message": "parent_id and title are required",
                },
            },
        )

    async def _run(client: NotionClient) -> dict[str, Any]:
        page_id = await client.create_page(parent_id, title, content)
        payload = {"ok": True, "page_id": page_id, "parent_id": parent_id, "title": title}
        return ok_tool_result(
            f"Created Notion page '{title}'",
            payload,
        )

    return await _with_client(_run)


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
                        "serverInfo": {"name": "notion", "version": "1.0.0"},
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

            if tool_name == "search_pages":
                write_message(make_response(request_id, asyncio.run(tool_search_pages(arguments))))
                continue
            if tool_name == "read_page":
                write_message(make_response(request_id, asyncio.run(tool_read_page(arguments))))
                continue
            if tool_name == "append_to_page":
                write_message(make_response(request_id, asyncio.run(tool_append_to_page(arguments))))
                continue
            if tool_name == "create_page":
                write_message(make_response(request_id, asyncio.run(tool_create_page(arguments))))
                continue

            write_message(make_error(request_id, -32602, f"Unknown tool: {tool_name}"))
            continue

        if request_id is not None:
            write_message(make_error(request_id, -32601, f"Method not found: {method}"))


if __name__ == "__main__":
    raise SystemExit(serve_mcp())
