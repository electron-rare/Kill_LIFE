#!/usr/bin/env python3
"""Local MCP server for FreeCAD headless operations."""

from __future__ import annotations

import ast
import json
import re
import time
from pathlib import Path
from typing import Any

from cad_runtime import (  # type: ignore
    CadRuntimeError,
    cleanup_runtime_path,
    coerce_workspace_path,
    create_runtime_temp_dir,
    parse_json_tail,
    require_process_success,
    run_freecad_script,
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
WORKSPACE_ROOT = Path("/workspace")
SAFE_NAME_RE = re.compile(r"^[A-Za-z0-9_.-]{1,80}$")
ALLOWED_SCRIPT_IMPORT_ROOTS = {
    "FreeCAD",
    "App",
    "Part",
    "math",
    "json",
}
BLOCKED_SCRIPT_CALLS = {
    "__import__",
    "eval",
    "exec",
    "compile",
    "getattr",
    "setattr",
    "delattr",
    "open",
    "input",
    "help",
    "globals",
    "locals",
    "vars",
}
BLOCKED_SCRIPT_ATTR_CALLS = {
    "__subclasses__",
    "__globals__",
    "__getattribute__",
    "__setattr__",
    "__delattr__",
    "__reduce__",
    "__reduce_ex__",
    "__mro__",
    "mro",
}
BLOCKED_SCRIPT_MODULE_NAMES = {
    "os",
    "subprocess",
    "socket",
    "pathlib",
    "sys",
    "shutil",
}
BLOCKED_SCRIPT_DUNDER_NAMES = {
    "__builtins__",
    "__loader__",
    "__spec__",
    "__package__",
    "__name__",
    "__file__",
}

TOOLS = [
    {
        "name": "get_runtime_info",
        "description": "Return the resolved FreeCAD headless runtime version and wrapper metadata.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "create_document",
        "description": "Create and save a minimal FreeCAD document in the Kill_LIFE workspace.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "output_path": {"type": "string", "description": "Workspace-relative .FCStd path"},
                "name": {"type": "string", "description": "Document name", "default": "McpDocument"},
                "primitive": {
                    "type": "string",
                    "enum": ["box"],
                    "default": "box",
                    "description": "Primitive to create in the new document",
                },
                "length": {"type": "number", "default": 10},
                "width": {"type": "number", "default": 8},
                "height": {"type": "number", "default": 6},
            },
            "required": ["output_path"],
        },
    },
    {
        "name": "export_document",
        "description": "Export an existing FreeCAD document to STEP from headless FreeCAD.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "document_path": {"type": "string", "description": "Workspace-relative .FCStd path"},
                "output_path": {"type": "string", "description": "Workspace-relative .step path"},
            },
            "required": ["document_path", "output_path"],
        },
    },
    {
        "name": "run_python_script",
        "description": "Execute a constrained FreeCAD Python snippet in headless mode.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "script": {"type": "string", "description": "FreeCAD Python snippet"},
                "output_path": {
                    "type": "string",
                    "description": "Optional workspace-relative .FCStd path to save the active document",
                },
            },
            "required": ["script"],
        },
    },
]


def _tool_error(code: str, message: str, **extra: Any) -> dict[str, Any]:
    payload = {"ok": False, "error": {"code": code, "message": message}}
    payload.update(extra)
    return error_tool_result(message, payload)


def _workspace_runtime_path(path: Path) -> Path:
    return WORKSPACE_ROOT / path.relative_to(ROOT)


def _run_tool(tool_name: str, callback) -> dict[str, Any]:
    started = time.perf_counter()
    try:
        result = callback()
        emit_mcp_span(
            server_name="freecad",
            operation="tools/call",
            tool_name=tool_name,
            status="ok",
            duration_ms=(time.perf_counter() - started) * 1000,
        )
        return result
    except CadRuntimeError as exc:
        emit_mcp_span(
            server_name="freecad",
            operation="tools/call",
            tool_name=tool_name,
            status="error",
            error=str(exc),
            duration_ms=(time.perf_counter() - started) * 1000,
        )
        return _tool_error("runtime_error", str(exc))
    except Exception as exc:
        emit_mcp_span(
            server_name="freecad",
            operation="tools/call",
            tool_name=tool_name,
            status="error",
            error=str(exc),
            duration_ms=(time.perf_counter() - started) * 1000,
        )
        return _tool_error("unexpected_error", str(exc))


def tool_get_runtime_info(_: dict[str, Any]) -> dict[str, Any]:
    proc = require_process_success(
        run_cad_stack(
            "freecad-cmd",
            "-c",
            'import FreeCAD; print(".".join(FreeCAD.Version()[:3]))',
            timeout=45.0,
            env={"PYTHONSTARTUP": "", "PYTHONNOUSERSITE": "1"},
        ),
        context="freecad runtime info",
    )
    version = next(
        (
            line.strip()
            for line in reversed(proc.stdout.splitlines())
            if line.strip() and line.strip() != "(100 %)"
        ),
        "",
    )
    if not version:
        raise CadRuntimeError("freecad runtime info returned no version")
    return ok_tool_result(
        f"FreeCAD runtime {version}",
        {
            "ok": True,
            "runtime": "freecad-headless",
            "version": version,
            "workspace_root": str(ROOT),
        },
    )


def tool_create_document(arguments: dict[str, Any]) -> dict[str, Any]:
    output_path = coerce_workspace_path(arguments.get("output_path", ""), suffix=".FCStd")
    output_runtime_path = _workspace_runtime_path(output_path)
    name = str(arguments.get("name") or "McpDocument").strip() or "McpDocument"
    if not SAFE_NAME_RE.match(name):
        raise CadRuntimeError(f"invalid document name: {name}")

    length = float(arguments.get("length") or 10.0)
    width = float(arguments.get("width") or 8.0)
    height = float(arguments.get("height") or 6.0)
    temp_dir = create_runtime_temp_dir("freecad-mcp")
    script_path = temp_dir / "create_document.py"

    try:
        script_path.write_text(
            "\n".join(
                [
                    "import json",
                    "from pathlib import Path",
                    "import FreeCAD",
                    "",
                    f'name = {name!r}',
                    f'output_path = Path(r"{output_runtime_path.as_posix()}")',
                    "doc = FreeCAD.newDocument(name)",
                    'obj = doc.addObject("Part::Box", "Body")',
                    f"obj.Length = {length!r}",
                    f"obj.Width = {width!r}",
                    f"obj.Height = {height!r}",
                    "doc.recompute()",
                    "doc.saveAs(str(output_path))",
                    "print(json.dumps({",
                    '    "ok": True,',
                    '    "document_name": doc.Name,',
                    '    "document_path": str(output_path),',
                    '    "object_count": len(doc.Objects),',
                    "}))",
                ]
            ),
            encoding="utf-8",
        )
        proc = require_process_success(
            run_freecad_script(
                str(script_path.relative_to(ROOT)),
                timeout=90.0,
            ),
            context="freecad create document",
        )
        payload = parse_json_tail(proc.stdout)
        if not payload.get("ok"):
            raise CadRuntimeError(f"freecad create_document failed: {payload}")
        if not output_path.exists():
            raise CadRuntimeError(f"created document not found: {output_path}")
        return ok_tool_result(
            f"Created FreeCAD document {output_path.name}",
            {
                "ok": True,
                "document_path": str(output_path.relative_to(ROOT)),
                "document_name": payload.get("document_name"),
                "object_count": payload.get("object_count"),
                "size_bytes": output_path.stat().st_size,
            },
        )
    finally:
        cleanup_runtime_path(temp_dir)


def tool_export_document(arguments: dict[str, Any]) -> dict[str, Any]:
    document_path = coerce_workspace_path(arguments.get("document_path", ""), suffix=".FCStd")
    output_path = coerce_workspace_path(arguments.get("output_path", ""), suffix=".step")
    document_runtime_path = _workspace_runtime_path(document_path)
    output_runtime_path = _workspace_runtime_path(output_path)
    if not document_path.exists():
        raise CadRuntimeError(f"document not found: {document_path.relative_to(ROOT)}")

    temp_dir = create_runtime_temp_dir("freecad-mcp")
    script_path = temp_dir / "export_document.py"
    try:
        script_path.write_text(
            "\n".join(
                [
                    "import json",
                    "from pathlib import Path",
                    "import FreeCAD",
                    "import Import",
                    "",
                    f'document_path = Path(r"{document_runtime_path.as_posix()}")',
                    f'output_path = Path(r"{output_runtime_path.as_posix()}")',
                    "doc = FreeCAD.openDocument(str(document_path))",
                    "if not doc.Objects:",
                    '    raise RuntimeError("document contains no objects")',
                    "Import.export(doc.Objects, str(output_path))",
                    "print(json.dumps({",
                    '    "ok": True,',
                    '    "document_path": str(document_path),',
                    '    "output_path": str(output_path),',
                    '    "object_count": len(doc.Objects),',
                    "}))",
                ]
            ),
            encoding="utf-8",
        )
        proc = require_process_success(
            run_freecad_script(
                str(script_path.relative_to(ROOT)),
                timeout=90.0,
            ),
            context="freecad export document",
        )
        payload = parse_json_tail(proc.stdout)
        if not payload.get("ok"):
            raise CadRuntimeError(f"freecad export_document failed: {payload}")
        if not output_path.exists():
            raise CadRuntimeError(f"exported STEP not found: {output_path}")
        return ok_tool_result(
            f"Exported {document_path.name} to {output_path.name}",
            {
                "ok": True,
                "document_path": str(document_path.relative_to(ROOT)),
                "output_path": str(output_path.relative_to(ROOT)),
                "size_bytes": output_path.stat().st_size,
            },
        )
    finally:
        cleanup_runtime_path(temp_dir)


def _validate_freecad_user_script(raw_script: str) -> None:
    if len(raw_script) > 20_000:
        raise CadRuntimeError("script too large (max 20,000 chars)")

    try:
        tree = ast.parse(raw_script, mode="exec")
    except SyntaxError as exc:
        raise CadRuntimeError(f"script syntax error: {exc.msg}") from exc

    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                root = alias.name.split(".", 1)[0]
                if root not in ALLOWED_SCRIPT_IMPORT_ROOTS:
                    raise CadRuntimeError(f"blocked import: {alias.name}")
        elif isinstance(node, ast.ImportFrom):
            module = (node.module or "").strip()
            root = module.split(".", 1)[0] if module else ""
            if node.level != 0 or root not in ALLOWED_SCRIPT_IMPORT_ROOTS:
                raise CadRuntimeError(f"blocked import-from: {module or '<relative>'}")
        elif isinstance(node, ast.Call):
            if isinstance(node.func, ast.Name) and node.func.id in BLOCKED_SCRIPT_CALLS:
                raise CadRuntimeError(f"blocked function call: {node.func.id}")
            if isinstance(node.func, ast.Attribute) and node.func.attr in BLOCKED_SCRIPT_ATTR_CALLS:
                raise CadRuntimeError(f"blocked attribute call: {node.func.attr}")
        elif isinstance(node, ast.Attribute):
            if node.attr.startswith("__"):
                raise CadRuntimeError(f"blocked dunder attribute: {node.attr}")
            if node.attr in BLOCKED_SCRIPT_ATTR_CALLS:
                raise CadRuntimeError(f"blocked attribute access: {node.attr}")
            if isinstance(node.value, ast.Name) and node.value.id in BLOCKED_SCRIPT_MODULE_NAMES:
                raise CadRuntimeError(f"blocked module access: {node.value.id}.{node.attr}")
        elif isinstance(node, ast.Name):
            if isinstance(node.ctx, ast.Load) and (
                node.id in BLOCKED_SCRIPT_MODULE_NAMES
                or node.id in BLOCKED_SCRIPT_DUNDER_NAMES
                or node.id.startswith("__")
            ):
                raise CadRuntimeError(f"blocked module usage: {node.id}")


def tool_run_python_script(arguments: dict[str, Any]) -> dict[str, Any]:
    raw_script = str(arguments.get("script") or "")
    if not raw_script.strip():
        raise CadRuntimeError("script is required")
    _validate_freecad_user_script(raw_script)

    output_path_value = arguments.get("output_path")
    output_path = (
        coerce_workspace_path(output_path_value, suffix=".FCStd")
        if output_path_value
        else None
    )
    output_runtime_path = _workspace_runtime_path(output_path) if output_path is not None else None

    temp_dir = create_runtime_temp_dir("freecad-mcp")
    script_path = temp_dir / "user_script.py"
    quoted_script = json.dumps(raw_script)
    script_path.write_text(
        "\n".join(
                [
                    "import builtins",
                    "import json",
                    "from pathlib import Path",
                    "import FreeCAD",
                    "try:",
                    "    import Part",
                    "except Exception:",
                    "    Part = None",
                    "",
                    f"USER_CODE = {quoted_script}",
                    f'OUTPUT_PATH = Path(r"{output_runtime_path.as_posix()}") if {bool(output_runtime_path)!r} else None',
                    "ALLOWED_IMPORTS = {'FreeCAD', 'App', 'Part', 'math', 'json'}",
                    "def _safe_import(name, globals=None, locals=None, fromlist=(), level=0):",
                    "    root = str(name).split('.', 1)[0]",
                    "    if root not in ALLOWED_IMPORTS:",
                    "        raise ImportError(f'blocked import: {name}')",
                    "    return builtins.__import__(name, globals, locals, fromlist, level)",
                    "SAFE_BUILTINS = {",
                    "    'abs': abs, 'all': all, 'any': any, 'bool': bool, 'dict': dict,",
                    "    'enumerate': enumerate, 'float': float, 'int': int, 'len': len,",
                    "    'list': list, 'max': max, 'min': min, 'range': range, 'round': round,",
                    "    'set': set, 'str': str, 'sum': sum, 'tuple': tuple, 'zip': zip,",
                    "    'print': print, 'Exception': Exception, 'ValueError': ValueError,",
                    "    'RuntimeError': RuntimeError, '__import__': _safe_import,",
                    "}",
                    "globals_dict = {",
                    "    '__builtins__': SAFE_BUILTINS,",
                    "    'FreeCAD': FreeCAD,",
                    "    'App': FreeCAD,",
                    "    'Part': Part,",
                    "    'OUTPUT_PATH': OUTPUT_PATH,",
                    "    'RESULT': {},",
                    "}",
                    'exec(compile(USER_CODE, "<freecad-mcp>", "exec"), globals_dict, globals_dict)',
                "active = FreeCAD.ActiveDocument",
                "if OUTPUT_PATH is not None and active is not None:",
                "    active.saveAs(str(OUTPUT_PATH))",
                "print(json.dumps({",
                '    "ok": True,',
                '    "saved_path": str(OUTPUT_PATH) if OUTPUT_PATH is not None else None,',
                '    "active_document": active.Name if active is not None else None,',
                '    "result": globals_dict.get("RESULT", {}),',
                "}))",
            ]
        ),
        encoding="utf-8",
    )
    try:
        proc = require_process_success(
            run_freecad_script(
                str(script_path.relative_to(ROOT)),
                timeout=120.0,
                prefer_pool=False,
                clean_env=True,
            ),
            context="freecad run python script",
        )
        payload = parse_json_tail(proc.stdout)
        if not payload.get("ok"):
            raise CadRuntimeError(f"freecad run_python_script failed: {payload}")
        response: dict[str, Any] = {
            "ok": True,
            "active_document": payload.get("active_document"),
            "result": payload.get("result") if isinstance(payload.get("result"), dict) else {},
        }
        if output_path is not None:
            if not output_path.exists():
                raise CadRuntimeError(f"requested output file missing: {output_path}")
            response["saved_path"] = str(output_path.relative_to(ROOT))
            response["size_bytes"] = output_path.stat().st_size
        return ok_tool_result("Executed constrained FreeCAD Python snippet", response)
    finally:
        cleanup_runtime_path(temp_dir)


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
                        "serverInfo": {"name": "freecad", "version": "1.0.0"},
                    },
                )
            )
            emit_mcp_span(
                server_name="freecad",
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
                server_name="freecad",
                operation="ping",
                status="ok",
                duration_ms=(time.perf_counter() - started) * 1000,
            )
            continue

        if method == "tools/list":
            write_message(make_response(request_id, {"tools": TOOLS}))
            emit_mcp_span(
                server_name="freecad",
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
            if tool_name == "create_document":
                write_message(make_response(request_id, _run_tool("create_document", lambda: tool_create_document(arguments))))
                continue
            if tool_name == "export_document":
                write_message(make_response(request_id, _run_tool("export_document", lambda: tool_export_document(arguments))))
                continue
            if tool_name == "run_python_script":
                write_message(make_response(request_id, _run_tool("run_python_script", lambda: tool_run_python_script(arguments))))
                continue

            write_message(make_error(request_id, -32602, f"Unknown tool: {tool_name}"))
            emit_mcp_span(
                server_name="freecad",
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
                server_name="freecad",
                operation=str(method),
                status="error",
                error=f"Method not found: {method}",
                duration_ms=(time.perf_counter() - started) * 1000,
            )


if __name__ == "__main__":
    raise SystemExit(serve_mcp())
