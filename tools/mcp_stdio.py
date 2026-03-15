"""Shared MCP stdio helpers for local Kill_LIFE servers."""

from __future__ import annotations

import json
import sys
from typing import Any

PROTOCOL_VERSION = "2025-03-26"


def make_response(request_id: Any, result: dict[str, Any]) -> dict[str, Any]:
    return {"jsonrpc": "2.0", "id": request_id, "result": result}


def make_error(request_id: Any, code: int, message: str) -> dict[str, Any]:
    return {"jsonrpc": "2.0", "id": request_id, "error": {"code": code, "message": message}}


def ok_tool_result(summary: str, structured_content: dict[str, Any]) -> dict[str, Any]:
    return {
        "content": [{"type": "text", "text": summary}],
        "structuredContent": structured_content,
        "isError": False,
    }


def error_tool_result(summary: str, structured_content: dict[str, Any]) -> dict[str, Any]:
    return {
        "content": [{"type": "text", "text": summary}],
        "structuredContent": structured_content,
        "isError": True,
    }


def read_message() -> dict[str, Any] | None:
    headers: dict[str, str] = {}
    while True:
        line = sys.stdin.buffer.readline()
        if not line:
            return None
        if line in (b"\r\n", b"\n"):
            break
        key, _, value = line.decode("utf-8").partition(":")
        headers[key.strip().lower()] = value.strip()

    content_length = int(headers.get("content-length", "0"))
    if content_length <= 0:
        return None

    body = sys.stdin.buffer.read(content_length)
    if not body:
        return None
    return json.loads(body.decode("utf-8"))


def write_message(message: dict[str, Any]) -> None:
    payload = json.dumps(message).encode("utf-8")
    sys.stdout.buffer.write(f"Content-Length: {len(payload)}\r\n\r\n".encode("utf-8"))
    sys.stdout.buffer.write(payload)
    sys.stdout.buffer.flush()
