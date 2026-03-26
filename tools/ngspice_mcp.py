#!/usr/bin/env python3
"""Local MCP server for ngspice circuit simulation."""

from __future__ import annotations

import re
import subprocess
import tempfile
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
NGSPICE_BIN = "/usr/bin/ngspice"
TIMEOUT_SECONDS = 60


TOOLS = [
    {
        "name": "get_runtime_info",
        "description": "Return ngspice version and runtime metadata.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "run_simulation",
        "description": (
            "Run a SPICE netlist through ngspice and return the raw output. "
            "The netlist must include analysis commands (.op, .ac, .dc, .tran, etc.) "
            "and a .control/.endc block with a 'quit' statement."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "netlist": {
                    "type": "string",
                    "description": "Complete SPICE netlist content",
                },
                "timeout": {
                    "type": "integer",
                    "description": "Timeout in seconds (default 60)",
                    "default": 60,
                },
            },
            "required": ["netlist"],
        },
    },
    {
        "name": "validate_netlist",
        "description": "Validate a SPICE netlist syntax without running a full simulation.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "netlist": {
                    "type": "string",
                    "description": "SPICE netlist to validate",
                },
            },
            "required": ["netlist"],
        },
    },
    {
        "name": "parse_operating_point",
        "description": (
            "Run an operating point (.op) analysis and parse node voltages and currents "
            "from the output into structured data."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "netlist": {
                    "type": "string",
                    "description": "SPICE netlist with .op analysis",
                },
            },
            "required": ["netlist"],
        },
    },
]


class NgspiceError(Exception):
    pass


def _run_ngspice(netlist: str, timeout: int = TIMEOUT_SECONDS) -> tuple[str, str, int]:
    """Write netlist to temp file, run ngspice -b, return (stdout+log, stderr, returncode)."""
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".sp", prefix="ngspice_mcp_", delete=False
    ) as f:
        f.write(netlist)
        netlist_path = f.name

    log_path = netlist_path + ".log"
    try:
        proc = subprocess.run(
            [NGSPICE_BIN, "-b", "-o", log_path, netlist_path],
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        # Merge log file (contains OP results, print output) with stdout
        log_content = ""
        try:
            log_content = Path(log_path).read_text(encoding="utf-8", errors="replace")
        except OSError:
            pass
        combined_stdout = (proc.stdout or "") + "\n" + log_content
        return combined_stdout, proc.stderr, proc.returncode
    except subprocess.TimeoutExpired:
        raise NgspiceError(f"Simulation timed out after {timeout}s")
    finally:
        Path(netlist_path).unlink(missing_ok=True)
        Path(log_path).unlink(missing_ok=True)


def _ensure_control_block(netlist: str, print_all: bool = False) -> str:
    """Ensure netlist has a .control block with quit for batch mode."""
    if ".control" not in netlist.lower():
        lines = netlist.rstrip().splitlines()
        end_idx = next(
            (i for i, l in enumerate(lines) if l.strip().lower() == ".end"), None
        )
        inner = ["run"]
        if print_all:
            inner += ["print all"]
        inner += ["quit"]
        control = [".control"] + inner + [".endc"]
        if end_idx is not None:
            lines = lines[:end_idx] + control + lines[end_idx:]
        else:
            lines += control + [".end"]
        return "\n".join(lines) + "\n"
    # If .control already exists but no print all, inject before quit/endc
    if print_all and "print all" not in netlist.lower():
        netlist = netlist.replace(".endc", "print all\n.endc")
        netlist = netlist.replace(".ENDC", "print all\n.ENDC")
    return netlist


def tool_get_runtime_info(_: dict[str, Any]) -> dict[str, Any]:
    try:
        proc = subprocess.run(
            [NGSPICE_BIN, "--version"],
            capture_output=True,
            text=True,
            timeout=10,
        )
        version_line = (proc.stdout or proc.stderr or "").splitlines()[0] if (proc.stdout or proc.stderr) else "unknown"
        return ok_tool_result(
            version_line,
            {
                "ok": True,
                "runtime": "ngspice",
                "binary": NGSPICE_BIN,
                "version": version_line,
            },
        )
    except Exception as exc:
        return error_tool_result(str(exc), {"ok": False, "error": str(exc)})


def tool_run_simulation(arguments: dict[str, Any]) -> dict[str, Any]:
    netlist = str(arguments.get("netlist") or "").strip()
    if not netlist:
        return error_tool_result("netlist is required", {"ok": False, "error": "netlist is required"})

    timeout = int(arguments.get("timeout") or TIMEOUT_SECONDS)
    netlist = _ensure_control_block(netlist)

    try:
        stdout, stderr, rc = _run_ngspice(netlist, timeout)
        combined = (stdout + "\n" + stderr).strip()
        ok = rc == 0

        summary = f"ngspice exit={rc} | {len(combined.splitlines())} lines output"
        if not ok:
            # Check for fatal errors
            errors = [l for l in (stderr or "").splitlines() if "error" in l.lower()]
            if errors:
                summary = errors[0]

        payload = {
            "ok": ok,
            "exit_code": rc,
            "stdout": stdout,
            "stderr": stderr,
            "output": combined,
        }
        return ok_tool_result(summary, payload) if ok else error_tool_result(summary, payload)
    except NgspiceError as exc:
        return error_tool_result(str(exc), {"ok": False, "error": str(exc)})


def tool_validate_netlist(arguments: dict[str, Any]) -> dict[str, Any]:
    netlist = str(arguments.get("netlist") or "").strip()
    if not netlist:
        return error_tool_result("netlist is required", {"ok": False, "error": "netlist is required"})

    # Build a minimal netlist that just parses without running analysis
    validate_netlist = netlist
    if not any(
        line.strip().lower().startswith((".op", ".ac", ".dc", ".tran", ".noise"))
        for line in netlist.splitlines()
    ):
        # Inject .op so ngspice has something to parse
        lines = netlist.rstrip().splitlines()
        end_idx = next(
            (i for i, l in enumerate(lines) if l.strip().lower() == ".end"), len(lines)
        )
        lines.insert(end_idx, ".op")
        validate_netlist = "\n".join(lines) + "\n"

    validate_netlist = _ensure_control_block(validate_netlist)

    try:
        stdout, stderr, rc = _run_ngspice(validate_netlist, timeout=15)
        combined = (stdout + "\n" + stderr).lower()
        has_error = rc != 0 or "error" in combined or "fatal" in combined

        errors = [
            l for l in (stderr or "").splitlines()
            if any(k in l.lower() for k in ("error", "fatal", "unknown", "couldn't"))
        ]

        if has_error and errors:
            return error_tool_result(
                errors[0],
                {"ok": False, "errors": errors, "stderr": stderr},
            )
        return ok_tool_result(
            "Netlist syntax OK",
            {"ok": True, "warnings": [l for l in (stderr or "").splitlines() if "warning" in l.lower()]},
        )
    except NgspiceError as exc:
        return error_tool_result(str(exc), {"ok": False, "error": str(exc)})


def _parse_op_output(output: str) -> dict[str, Any]:
    """Parse operating point output into node voltages and branch currents.

    ngspice batch 'print all' emits:
      nodename = 1.23456e+00        (node voltage)
      device#branch = -1.23e-03     (branch current, e.g. v1#branch)
    Also handles older v(node) / i(device) formats.
    """
    voltages: dict[str, float] = {}
    currents: dict[str, float] = {}

    for line in output.splitlines():
        line = line.strip()

        # Format: "nodename = 1.234e+00" or "v(node) = 1.234e+00"
        m = re.match(r"^([a-zA-Z_][\w#()]*)\s*=\s*([-+]?\d[\d.eE+\-]+)", line)
        if m:
            name, val_str = m.group(1), m.group(2)
            try:
                val = float(val_str)
            except ValueError:
                continue
            low = name.lower()
            if "#branch" in low or low.startswith("i("):
                # branch current
                key = low.replace("#branch", "").lstrip("i(").rstrip(")")
                currents[key] = val
            else:
                # node voltage — strip v(...) wrapper if present
                key = re.sub(r"^v\((.+)\)$", r"\1", name, flags=re.IGNORECASE)
                voltages[key] = val
            continue

        # Fallback: "v(node)   1.234e+00"
        m = re.match(r"^v\((\S+)\)\s+([-+]?\d[\d.eE+\-]+)", line, re.IGNORECASE)
        if m:
            try:
                voltages[m.group(1)] = float(m.group(2))
            except ValueError:
                pass
            continue

        m = re.match(r"^i\((\S+)\)\s+([-+]?\d[\d.eE+\-]+)", line, re.IGNORECASE)
        if m:
            try:
                currents[m.group(1)] = float(m.group(2))
            except ValueError:
                pass

    return {"voltages": voltages, "currents": currents}


def tool_parse_operating_point(arguments: dict[str, Any]) -> dict[str, Any]:
    netlist = str(arguments.get("netlist") or "").strip()
    if not netlist:
        return error_tool_result("netlist is required", {"ok": False, "error": "netlist is required"})

    # Ensure .op is present
    if not any(l.strip().lower().startswith(".op") for l in netlist.splitlines()):
        lines = netlist.rstrip().splitlines()
        end_idx = next(
            (i for i, l in enumerate(lines) if l.strip().lower() == ".end"), len(lines)
        )
        lines.insert(end_idx, ".op")
        netlist = "\n".join(lines) + "\n"

    netlist = _ensure_control_block(netlist, print_all=True)

    try:
        stdout, stderr, rc = _run_ngspice(netlist)
        if rc != 0:
            errors = [l for l in stderr.splitlines() if "error" in l.lower()]
            msg = errors[0] if errors else f"ngspice exit={rc}"
            return error_tool_result(msg, {"ok": False, "error": msg, "stderr": stderr})

        combined = stdout + "\n" + stderr
        parsed = _parse_op_output(combined)
        n_nodes = len(parsed["voltages"])
        n_branches = len(parsed["currents"])
        summary = f"OP: {n_nodes} node voltages, {n_branches} branch currents"
        return ok_tool_result(summary, {"ok": True, **parsed, "raw_output": combined})
    except NgspiceError as exc:
        return error_tool_result(str(exc), {"ok": False, "error": str(exc)})


def _run_tool(tool_name: str, callback) -> dict[str, Any]:
    started = time.perf_counter()
    try:
        result = callback()
        emit_mcp_span(
            server_name="ngspice",
            operation="tools/call",
            tool_name=tool_name,
            status="ok",
            duration_ms=(time.perf_counter() - started) * 1000,
        )
        return result
    except Exception as exc:
        emit_mcp_span(
            server_name="ngspice",
            operation="tools/call",
            tool_name=tool_name,
            status="error",
            error=str(exc),
            duration_ms=(time.perf_counter() - started) * 1000,
        )
        return error_tool_result(str(exc), {"ok": False, "error": str(exc)})


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
                        "serverInfo": {"name": "ngspice", "version": "1.0.0"},
                    },
                )
            )
            emit_mcp_span(
                server_name="ngspice",
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
                server_name="ngspice",
                operation="ping",
                status="ok",
                duration_ms=(time.perf_counter() - started) * 1000,
            )
            continue

        if method == "tools/list":
            write_message(make_response(request_id, {"tools": TOOLS}))
            emit_mcp_span(
                server_name="ngspice",
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
            elif tool_name == "run_simulation":
                write_message(make_response(request_id, _run_tool("run_simulation", lambda: tool_run_simulation(arguments))))
            elif tool_name == "validate_netlist":
                write_message(make_response(request_id, _run_tool("validate_netlist", lambda: tool_validate_netlist(arguments))))
            elif tool_name == "parse_operating_point":
                write_message(make_response(request_id, _run_tool("parse_operating_point", lambda: tool_parse_operating_point(arguments))))
            else:
                write_message(make_error(request_id, -32602, f"Unknown tool: {tool_name}"))
                emit_mcp_span(
                    server_name="ngspice",
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
                server_name="ngspice",
                operation=str(method),
                status="error",
                error=f"Method not found: {method}",
                duration_ms=(time.perf_counter() - started) * 1000,
            )


if __name__ == "__main__":
    raise SystemExit(serve_mcp())
