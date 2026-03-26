#!/usr/bin/env python3
"""Local MCP server for PlatformIO firmware build and test operations."""

from __future__ import annotations

import os
import subprocess
import time
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
from mcp_telemetry import emit_mcp_span  # type: ignore

ROOT = Path(__file__).resolve().parents[1]
FIRMWARE_DIR = ROOT / "firmware"

# PlatformIO binary: prefer venv in the project, fallback to PATH
_PIO_CANDIDATES = [
    ROOT / ".pio-venv" / "bin" / "pio",
    Path.home() / ".platformio" / "penv" / "bin" / "pio",
    Path("/usr/local/bin/pio"),
    Path("/usr/bin/pio"),
]


def _find_pio() -> str | None:
    for candidate in _PIO_CANDIDATES:
        if candidate.exists():
            return str(candidate)
    # Try PATH
    result = subprocess.run(["which", "pio"], capture_output=True, text=True)
    if result.returncode == 0 and result.stdout.strip():
        return result.stdout.strip()
    return None


PIO_BIN: str | None = _find_pio()

BUILD_TIMEOUT = 300  # seconds
TEST_TIMEOUT = 120


TOOLS = [
    {
        "name": "get_runtime_info",
        "description": "Return PlatformIO version and installation metadata.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "build",
        "description": "Build firmware for the specified PlatformIO environment.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "env": {
                    "type": "string",
                    "description": "PlatformIO environment name (from platformio.ini [env:NAME]). Omit for default.",
                },
                "project_dir": {
                    "type": "string",
                    "description": "Path to the firmware project directory (default: firmware/).",
                },
            },
        },
    },
    {
        "name": "run_tests",
        "description": "Run PlatformIO unit tests (pio test).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "env": {
                    "type": "string",
                    "description": "PlatformIO environment (e.g. 'native' for host-side tests).",
                },
                "filter": {
                    "type": "string",
                    "description": "Test name filter pattern (maps to --filter).",
                },
                "project_dir": {
                    "type": "string",
                    "description": "Path to the firmware project directory.",
                },
            },
        },
    },
    {
        "name": "check_code",
        "description": "Run PlatformIO static analysis (pio check) on the firmware.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "env": {"type": "string", "description": "PlatformIO environment."},
                "project_dir": {"type": "string", "description": "Firmware project directory."},
            },
        },
    },
    {
        "name": "get_metadata",
        "description": "Return project metadata: environments, libs, board, and framework from platformio.ini.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "project_dir": {"type": "string", "description": "Firmware project directory."},
            },
        },
    },
    {
        "name": "install_platformio",
        "description": "Install PlatformIO into a project-local venv (.pio-venv/) if not already available.",
        "inputSchema": {"type": "object", "properties": {}},
    },
]


class PioError(Exception):
    pass


def _resolve_project(project_dir_arg: str | None) -> Path:
    if project_dir_arg:
        p = Path(project_dir_arg)
        if not p.is_absolute():
            p = ROOT / p
        return p.resolve()
    if FIRMWARE_DIR.exists():
        return FIRMWARE_DIR
    return ROOT


def _run_pio(args: list[str], cwd: Path, timeout: int = BUILD_TIMEOUT) -> tuple[str, str, int]:
    pio = PIO_BIN
    if not pio:
        raise PioError(
            "PlatformIO not found. Use install_platformio tool or install manually: pip install platformio"
        )
    env = {**os.environ, "PLATFORMIO_FORCE_ANSI": "false"}
    proc = subprocess.run(
        [pio] + args,
        capture_output=True,
        text=True,
        cwd=str(cwd),
        timeout=timeout,
        env=env,
    )
    return proc.stdout, proc.stderr, proc.returncode


def tool_get_runtime_info(_: dict[str, Any]) -> dict[str, Any]:
    global PIO_BIN
    PIO_BIN = _find_pio()  # Re-probe in case it was just installed
    if not PIO_BIN:
        return ok_tool_result(
            "PlatformIO not installed",
            {
                "ok": True,
                "installed": False,
                "message": "Use install_platformio tool to install",
            },
        )
    try:
        proc = subprocess.run([PIO_BIN, "--version"], capture_output=True, text=True, timeout=15)
        version = (proc.stdout or proc.stderr or "").strip()
        return ok_tool_result(
            version,
            {
                "ok": True,
                "installed": True,
                "binary": PIO_BIN,
                "version": version,
                "firmware_dir": str(FIRMWARE_DIR),
            },
        )
    except Exception as exc:
        return error_tool_result(str(exc), {"ok": False, "error": str(exc)})


def tool_build(arguments: dict[str, Any]) -> dict[str, Any]:
    project_dir = _resolve_project(arguments.get("project_dir"))
    env = arguments.get("env")

    if not (project_dir / "platformio.ini").exists():
        return error_tool_result(
            f"platformio.ini not found in {project_dir}",
            {"ok": False, "error": f"Not a PlatformIO project: {project_dir}"},
        )

    cmd = ["run"]
    if env:
        cmd += ["-e", env]

    try:
        stdout, stderr, rc = _run_pio(cmd, project_dir, timeout=BUILD_TIMEOUT)
        combined = (stdout + "\n" + stderr).strip()
        ok = rc == 0
        summary = f"Build {'succeeded' if ok else 'FAILED'} (exit={rc})"

        # Extract key error lines
        errors = [l for l in (stderr + stdout).splitlines() if "error:" in l.lower()][:5]
        if errors and not ok:
            summary = errors[0].strip()

        payload = {
            "ok": ok,
            "exit_code": rc,
            "stdout": stdout,
            "stderr": stderr,
            "errors": errors,
        }
        return ok_tool_result(summary, payload) if ok else error_tool_result(summary, payload)
    except subprocess.TimeoutExpired:
        return error_tool_result("Build timed out", {"ok": False, "error": f"Timeout after {BUILD_TIMEOUT}s"})
    except PioError as exc:
        return error_tool_result(str(exc), {"ok": False, "error": str(exc)})


def tool_run_tests(arguments: dict[str, Any]) -> dict[str, Any]:
    project_dir = _resolve_project(arguments.get("project_dir"))
    env = arguments.get("env")
    filter_pattern = arguments.get("filter")

    cmd = ["test"]
    if env:
        cmd += ["-e", env]
    if filter_pattern:
        cmd += ["--filter", filter_pattern]

    try:
        stdout, stderr, rc = _run_pio(cmd, project_dir, timeout=TEST_TIMEOUT)
        ok = rc == 0
        combined = (stdout + "\n" + stderr).strip()

        # Extract test summary lines
        summary_lines = [
            l for l in combined.splitlines()
            if any(k in l for k in ("PASSED", "FAILED", "ERROR", "tests", "Tests"))
        ]
        summary = summary_lines[-1].strip() if summary_lines else f"Tests exit={rc}"

        payload = {
            "ok": ok,
            "exit_code": rc,
            "stdout": stdout,
            "stderr": stderr,
        }
        return ok_tool_result(summary, payload) if ok else error_tool_result(summary, payload)
    except subprocess.TimeoutExpired:
        return error_tool_result("Tests timed out", {"ok": False, "error": f"Timeout after {TEST_TIMEOUT}s"})
    except PioError as exc:
        return error_tool_result(str(exc), {"ok": False, "error": str(exc)})


def tool_check_code(arguments: dict[str, Any]) -> dict[str, Any]:
    project_dir = _resolve_project(arguments.get("project_dir"))
    env = arguments.get("env")

    cmd = ["check"]
    if env:
        cmd += ["-e", env]

    try:
        stdout, stderr, rc = _run_pio(cmd, project_dir, timeout=BUILD_TIMEOUT)
        ok = rc == 0
        combined = (stdout + "\n" + stderr).strip()
        defects = [l for l in combined.splitlines() if "defect" in l.lower() or "warning" in l.lower()]
        summary = f"Check {'OK' if ok else 'FAILED'}: {len(defects)} issues"

        payload = {"ok": ok, "exit_code": rc, "stdout": stdout, "stderr": stderr, "issues": defects}
        return ok_tool_result(summary, payload) if ok else error_tool_result(summary, payload)
    except PioError as exc:
        return error_tool_result(str(exc), {"ok": False, "error": str(exc)})


def tool_get_metadata(arguments: dict[str, Any]) -> dict[str, Any]:
    project_dir = _resolve_project(arguments.get("project_dir"))
    ini_path = project_dir / "platformio.ini"

    if not ini_path.exists():
        return error_tool_result(
            f"platformio.ini not found in {project_dir}",
            {"ok": False, "error": f"Not a PlatformIO project: {project_dir}"},
        )

    content = ini_path.read_text(encoding="utf-8")

    # Parse environments
    import configparser
    config = configparser.ConfigParser()
    config.read_string(content)

    envs = [s.replace("env:", "") for s in config.sections() if s.startswith("env:")]
    metadata: dict[str, Any] = {
        "ok": True,
        "project_dir": str(project_dir),
        "environments": envs,
        "platformio_ini": content,
    }

    # Pull board/framework from first env
    if envs:
        first_env = f"env:{envs[0]}"
        if config.has_section(first_env):
            for key in ("board", "framework", "platform", "build_flags"):
                if config.has_option(first_env, key):
                    metadata[key] = config.get(first_env, key)

    return ok_tool_result(
        f"Project: {len(envs)} environments — {', '.join(envs[:5])}",
        metadata,
    )


def tool_install_platformio(_: dict[str, Any]) -> dict[str, Any]:
    global PIO_BIN
    venv_dir = ROOT / ".pio-venv"
    pio_bin = venv_dir / "bin" / "pio"

    if pio_bin.exists():
        PIO_BIN = str(pio_bin)
        return ok_tool_result(
            f"PlatformIO already installed at {pio_bin}",
            {"ok": True, "binary": str(pio_bin), "already_installed": True},
        )

    try:
        # Create venv
        subprocess.run(
            ["python3", "-m", "venv", str(venv_dir)],
            check=True, capture_output=True, timeout=60,
        )
        # Install platformio
        pip = venv_dir / "bin" / "pip"
        proc = subprocess.run(
            [str(pip), "install", "platformio"],
            capture_output=True, text=True, timeout=180,
        )
        if proc.returncode != 0:
            return error_tool_result(
                "pip install platformio failed",
                {"ok": False, "error": proc.stderr[-500:] if proc.stderr else "unknown"},
            )
        if pio_bin.exists():
            PIO_BIN = str(pio_bin)
            return ok_tool_result(
                f"PlatformIO installed at {pio_bin}",
                {"ok": True, "binary": str(pio_bin)},
            )
        return error_tool_result("Install completed but pio binary not found", {"ok": False})
    except Exception as exc:
        return error_tool_result(str(exc), {"ok": False, "error": str(exc)})


def _run_tool(tool_name: str, callback) -> dict[str, Any]:
    started = time.perf_counter()
    try:
        result = callback()
        emit_mcp_span(
            server_name="platformio",
            operation="tools/call",
            tool_name=tool_name,
            status="ok",
            duration_ms=(time.perf_counter() - started) * 1000,
        )
        return result
    except Exception as exc:
        emit_mcp_span(
            server_name="platformio",
            operation="tools/call",
            tool_name=tool_name,
            status="error",
            error=str(exc),
            duration_ms=(time.perf_counter() - started) * 1000,
        )
        return error_tool_result(str(exc), {"ok": False, "error": str(exc)})


TOOL_MAP = {
    "get_runtime_info": tool_get_runtime_info,
    "build": tool_build,
    "run_tests": tool_run_tests,
    "check_code": tool_check_code,
    "get_metadata": tool_get_metadata,
    "install_platformio": tool_install_platformio,
}


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
                        "serverInfo": {"name": "platformio", "version": "1.0.0"},
                    },
                )
            )
            emit_mcp_span(
                server_name="platformio",
                operation="initialize",
                status="ok",
                duration_ms=(time.perf_counter() - started) * 1000,
            )
            continue

        if method == "notifications/initialized":
            continue

        if method == "ping":
            write_message(make_response(request_id, {}))
            continue

        if method == "tools/list":
            write_message(make_response(request_id, {"tools": TOOLS}))
            emit_mcp_span(
                server_name="platformio",
                operation="tools/list",
                status="ok",
                duration_ms=(time.perf_counter() - started) * 1000,
            )
            continue

        if method == "tools/call":
            tool_name = params.get("name")
            arguments = params.get("arguments") or {}
            handler = TOOL_MAP.get(tool_name)
            if handler:
                write_message(
                    make_response(
                        request_id,
                        _run_tool(tool_name, lambda h=handler: h(arguments)),
                    )
                )
            else:
                write_message(make_error(request_id, -32602, f"Unknown tool: {tool_name}"))
                emit_mcp_span(
                    server_name="platformio",
                    operation="tools/call",
                    tool_name=str(tool_name),
                    status="error",
                    error=f"Unknown tool: {tool_name}",
                    duration_ms=(time.perf_counter() - started) * 1000,
                )
            continue

        if request_id is not None:
            write_message(make_error(request_id, -32601, f"Method not found: {method}"))


if __name__ == "__main__":
    raise SystemExit(serve_mcp())
