#!/usr/bin/env python3
"""Best-effort OTLP trace emission for local MCP servers."""

from __future__ import annotations

import json
import os
import secrets
import time
import urllib.error
import urllib.request
from typing import Any

DEFAULT_ENDPOINT = "http://127.0.0.1:4318"


def _otel_enabled() -> bool:
    value = (os.getenv("OTEL_ENABLED") or "true").strip().lower()
    return value not in {"0", "false", "no", "off"}


def emit_mcp_span(
    *,
    server_name: str,
    operation: str,
    status: str,
    tool_name: str | None = None,
    error: str | None = None,
    attributes: dict[str, str] | None = None,
    duration_ms: float | None = None,
) -> None:
    if not _otel_enabled():
        return

    endpoint = (
        os.getenv("OTEL_COLLECTOR_HTTP_ENDPOINT")
        or os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
        or DEFAULT_ENDPOINT
    ).rstrip("/")
    timeout_s = float(os.getenv("MCP_OTEL_TIMEOUT_S") or "0.8")
    end_ns = time.time_ns()
    if duration_ms is None or duration_ms <= 0:
        start_ns = end_ns
    else:
        start_ns = end_ns - int(duration_ms * 1_000_000)

    attrs = {
        "mcp.server_name": server_name,
        "mcp.operation": operation,
        "mcp.status": status,
    }
    if tool_name:
        attrs["mcp.tool_name"] = tool_name
    if error:
        attrs["error.message"] = error
    if attributes:
        attrs.update({key: value for key, value in attributes.items() if value})

    payload: dict[str, Any] = {
        "resourceSpans": [
            {
                "resource": {
                    "attributes": [
                        {"key": "service.name", "value": {"stringValue": "kill-life-mcp"}},
                        {"key": "service.namespace", "value": {"stringValue": "kill-life"}},
                    ]
                },
                "scopeSpans": [
                    {
                        "scope": {"name": "kill-life.mcp", "version": "1.0.0"},
                        "spans": [
                            {
                                "traceId": secrets.token_hex(16),
                                "spanId": secrets.token_hex(8),
                                "name": f"{server_name}:{operation}",
                                "kind": 1,
                                "startTimeUnixNano": str(start_ns),
                                "endTimeUnixNano": str(end_ns),
                                "attributes": [
                                    {"key": key, "value": {"stringValue": value}}
                                    for key, value in attrs.items()
                                ],
                                "status": {
                                    "code": 2 if status == "error" else 1,
                                    "message": error or "",
                                },
                            }
                        ],
                    }
                ],
            }
        ]
    }

    request = urllib.request.Request(
        f"{endpoint}/v1/traces",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout_s):
            return
    except (urllib.error.URLError, TimeoutError, OSError, ValueError):
        return
