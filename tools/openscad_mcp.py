#!/usr/bin/env python3
"""Local MCP server for OpenSCAD headless operations."""

from __future__ import annotations

import time
from pathlib import Path
from typing import Any

from cad_runtime import (  # type: ignore
    CadRuntimeError,
    cleanup_runtime_path,
    coerce_workspace_path,
    create_runtime_temp_dir,
    last_nonempty_line,
    require_process_success,
    run_cad_stack,
)
from mcp_stdio import (  # type: ignore
    PROTOCOL_VERSION,
    error_tool_result,
    make_error,
    make_response,
    ok_tool_result,
    read_message,
    write_message,
)
from mcp_telemetry import emit_mcp_span  # type: ignore

ROOT = Path(__file__).resolve().parents[1]

TOOLS = [
    {
        "name": "get_runtime_info",
        "description": "Return the resolved OpenSCAD headless runtime version and wrapper metadata.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "validate_model",
        "description": "Validate an OpenSCAD model by compiling it to a temporary artifact.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "source": {"type": "string", "description": "OpenSCAD source code"},
            },
            "required": ["source"],
        },
    },
    {
        "name": "render_model",
        "description": "Render an OpenSCAD model to a workspace artifact.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "source": {"type": "string", "description": "OpenSCAD source code"},
                "output_path": {"type": "string", "description": "Workspace-relative .stl path"},
            },
            "required": ["source", "output_path"],
        },
    },
    {
        "name": "export_model",
        "description": "Alias of render_model for explicit export workflows.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "source": {"type": "string", "description": "OpenSCAD source code"},
                "output_path": {"type": "string", "description": "Workspace-relative .stl path"},
            },
            "required": ["source", "output_path"],
        },
    },
]


def _tool_error(code: str, message: str, **extra: Any) -> dict[str, Any]:
    payload = {"ok": False, "error": {"code": code, "message": message}}
    payload.update(extra)
    return error_tool_result(message, payload)


def _run_tool(tool_name: str, callback) -> dict[str, Any]:
    started = time.perf_counter()
    try:
        result = callback()
        emit_mcp_span(
            server_name="openscad",
            operation="tools/call",
            tool_name=tool_name,
            status="ok",
            duration_ms=(time.perf_counter() - started) * 1000,
        )
        return result
    except CadRuntimeError as exc:
        emit_mcp_span(
            server_name="openscad",
            operation="tools/call",
            tool_name=tool_name,
            status="error",
            error=str(exc),
            duration_ms=(time.perf_counter() - started) * 1000,
        )
        return _tool_error("runtime_error", str(exc))
    except Exception as exc:
        emit_mcp_span(
            server_name="openscad",
            operation="tools/call",
            tool_name=tool_name,
            status="error",
            error=str(exc),
            duration_ms=(time.perf_counter() - started) * 1000,
        )
        return _tool_error("unexpected_error", str(exc))


def _write_source(temp_dir: Path, source: str) -> Path:
    if not source.strip():
        raise CadRuntimeError("source is required")
    source_path = temp_dir / "model.scad"
    source_path.write_text(source, encoding="utf-8")
    return source_path


def tool_get_runtime_info(_: dict[str, Any]) -> dict[str, Any]:
    proc = require_process_success(
        run_cad_stack("openscad", "--version", timeout=45.0),
        context="openscad runtime info",
    )
    version = last_nonempty_line(proc.stdout) or last_nonempty_line(proc.stderr)
    if not version:
        raise CadRuntimeError("openscad version probe returned no version")
    return ok_tool_result(
        version,
        {
            "ok": True,
            "runtime": "openscad-headless",
            "version": version,
            "workspace_root": str(ROOT),
        },
    )


def tool_validate_model(arguments: dict[str, Any]) -> dict[str, Any]:
    source = str(arguments.get("source") or "")
    temp_dir = create_runtime_temp_dir("openscad-mcp")
    try:
        source_path = _write_source(temp_dir, source)
        output_path = temp_dir / "validate.stl"
        require_process_success(
            run_cad_stack(
                "openscad",
                "-o",
                str(output_path.relative_to(ROOT)),
                str(source_path.relative_to(ROOT)),
                timeout=60.0,
            ),
            context="openscad validate model",
        )
        if not output_path.exists() or output_path.stat().st_size <= 0:
            raise CadRuntimeError("openscad validation produced no artifact")
        return ok_tool_result(
            "Validated OpenSCAD model",
            {
                "ok": True,
                "artifact_size_bytes": output_path.stat().st_size,
            },
        )
    finally:
        cleanup_runtime_path(temp_dir)


def _render_like(source: str, output_path_value: str) -> dict[str, Any]:
    output_path = coerce_workspace_path(output_path_value, suffix=".stl")
    temp_dir = create_runtime_temp_dir("openscad-mcp")
    try:
        source_path = _write_source(temp_dir, source)
        require_process_success(
            run_cad_stack(
                "openscad",
                "-o",
                str(output_path.relative_to(ROOT)),
                str(source_path.relative_to(ROOT)),
                timeout=90.0,
            ),
            context="openscad render model",
        )
        if not output_path.exists() or output_path.stat().st_size <= 0:
            raise CadRuntimeError(f"openscad output missing or empty: {output_path}")
        return {
            "ok": True,
            "output_path": str(output_path.relative_to(ROOT)),
            "size_bytes": output_path.stat().st_size,
        }
    finally:
        cleanup_runtime_path(temp_dir)


def tool_render_model(arguments: dict[str, Any]) -> dict[str, Any]:
    source = str(arguments.get("source") or "")
    output_path_value = str(arguments.get("output_path") or "")
    if not output_path_value:
        raise CadRuntimeError("output_path is required")
    payload = _render_like(source, output_path_value)
    return ok_tool_result("Rendered OpenSCAD model", payload)


def tool_export_model(arguments: dict[str, Any]) -> dict[str, Any]:
    source = str(arguments.get("source") or "")
    output_path_value = str(arguments.get("output_path") or "")
    if not output_path_value:
        raise CadRuntimeError("output_path is required")
    payload = _render_like(source, output_path_value)
    return ok_tool_result("Exported OpenSCAD model", payload)


def serve_mcp() -> int:
    while True:
        started = time.perf_counter()
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
                        "serverInfo": {"name": "openscad", "version": "1.0.0"},
                    },
                )
            )
            emit_mcp_span(
                server_name="openscad",
                operation="initialize",
                status="ok",
                duration_ms=(time.perf_counter() - started) * 1000,
            )
            continue

        if method == "notifications/initialized":
            continue

        if method == "ping":
            write_message(make_response(request_id, {}))
            emit_mcp_span(
                server_name="openscad",
                operation="ping",
                status="ok",
                duration_ms=(time.perf_counter() - started) * 1000,
            )
            continue

        if method == "tools/list":
            write_message(make_response(request_id, {"tools": TOOLS}))
            emit_mcp_span(
                server_name="openscad",
                operation="tools/list",
                status="ok",
                duration_ms=(time.perf_counter() - started) * 1000,
            )
            continue

        if method == "tools/call":
            tool_name = params.get("name")
            arguments = params.get("arguments") or {}
            if tool_name == "get_runtime_info":
                write_message(make_response(request_id, _run_tool("get_runtime_info", lambda: tool_get_runtime_info(arguments))))
                continue
            if tool_name == "validate_model":
                write_message(make_response(request_id, _run_tool("validate_model", lambda: tool_validate_model(arguments))))
                continue
            if tool_name == "render_model":
                write_message(make_response(request_id, _run_tool("render_model", lambda: tool_render_model(arguments))))
                continue
            if tool_name == "export_model":
                write_message(make_response(request_id, _run_tool("export_model", lambda: tool_export_model(arguments))))
                continue

            write_message(make_error(request_id, -32602, f"Unknown tool: {tool_name}"))
            emit_mcp_span(
                server_name="openscad",
                operation="tools/call",
                tool_name=str(tool_name),
                status="error",
                error=f"Unknown tool: {tool_name}",
                duration_ms=(time.perf_counter() - started) * 1000,
            )
            continue

        if request_id is not None:
            write_message(make_error(request_id, -32601, f"Method not found: {method}"))
            emit_mcp_span(
                server_name="openscad",
                operation=str(method),
                status="error",
                error=f"Method not found: {method}",
                duration_ms=(time.perf_counter() - started) * 1000,
            )


if __name__ == "__main__":
    raise SystemExit(serve_mcp())
