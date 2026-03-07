#!/usr/bin/env python3
"""Minimal STDIO smoke test for the supported KiCad MCP launcher."""

from __future__ import annotations

import argparse
import json
import os
import selectors
import signal
import subprocess
import sys
import time
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
PROTOCOL_VERSION = "2025-03-26"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--timeout",
        type=float,
        default=30.0,
        help="Seconds to wait for each MCP response.",
    )
    parser.add_argument(
        "--runtime",
        choices=("auto", "host", "container"),
        default="auto",
        help="Launcher runtime selection to validate.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Emit a machine-readable JSON payload to stdout.",
    )
    parser.add_argument(
        "--quick",
        action="store_true",
        help="Only validate initialize and list methods; skip mutating tool calls.",
    )
    return parser.parse_args()


def read_response(proc: subprocess.Popen[str], timeout: float) -> dict[str, Any]:
    if proc.stdout is None:
        raise RuntimeError("stdout pipe is not available")

    if proc.stdout.closed:
        raise RuntimeError("stdout pipe is closed")

    deadline = time.monotonic() + timeout
    selector = selectors.DefaultSelector()
    selector.register(proc.stdout, selectors.EVENT_READ)
    buffer = ""

    try:
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise RuntimeError(f"Timed out after {timeout:.1f}s waiting for MCP response")

            events = selector.select(remaining)
            if not events:
                raise RuntimeError(f"Timed out after {timeout:.1f}s waiting for MCP response")

            line = proc.stdout.readline()
            if not line:
                raise RuntimeError("MCP process closed stdout before replying")

            buffer += line
            if "\n" not in buffer:
                continue

            message, _, remainder = buffer.partition("\n")
            buffer = remainder
            message = message.strip()
            if not message:
                continue

            return json.loads(message)
    finally:
        selector.close()


def send_message(proc: subprocess.Popen[str], payload: dict[str, Any]) -> None:
    if proc.stdin is None:
        raise RuntimeError("stdin pipe is not available")

    body = json.dumps(payload)
    proc.stdin.write(body + "\n")
    proc.stdin.flush()


def expect_result(message: dict[str, Any], method: str) -> dict[str, Any]:
    if "error" in message:
        raise RuntimeError(f"{method} failed: {message['error']}")
    result = message.get("result")
    if result is None:
        raise RuntimeError(f"{method} returned no result")
    return result


def call_tool(
    proc: subprocess.Popen[str],
    request_id: int,
    name: str,
    arguments: dict[str, Any],
    timeout: float,
) -> dict[str, Any]:
    send_message(
        proc,
        {
            "jsonrpc": "2.0",
            "id": request_id,
            "method": "tools/call",
            "params": {
                "name": name,
                "arguments": arguments,
            },
        },
    )
    response = read_response(proc, timeout)
    result = expect_result(response, f"tools/call {name}")
    raw_text = (result.get("content") or [{}])[0].get("text", "{}")
    try:
        payload = json.loads(raw_text)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"tools/call {name} returned non-JSON content: {raw_text}") from exc
    if not payload.get("success"):
        raise RuntimeError(f"tools/call {name} failed: {payload}")
    return payload


def read_resource(
    proc: subprocess.Popen[str],
    request_id: int,
    uri: str,
    timeout: float,
) -> list[dict[str, Any]]:
    send_message(
        proc,
        {
            "jsonrpc": "2.0",
            "id": request_id,
            "method": "resources/read",
            "params": {"uri": uri},
        },
    )
    result = expect_result(read_response(proc, timeout), f"resources/read {uri}")
    contents = result.get("contents") or []
    if not contents:
        raise RuntimeError(f"resources/read {uri} returned no contents")
    return contents


def read_doctor(runtime: str) -> dict[str, str]:
    launcher = ROOT / "tools" / "hw" / "run_kicad_mcp.sh"
    proc = subprocess.run(
        ["bash", str(launcher), "--runtime", runtime, "--doctor"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    values: dict[str, str] = {}
    for line in proc.stdout.splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key] = value
    return values


def emit_payload(args: argparse.Namespace, payload: dict[str, Any], *, ok: bool) -> int:
    if args.json:
        print(json.dumps(payload, ensure_ascii=True))
    elif ok:
        print(
            "OK: "
            f"server={payload.get('server_name', 'unknown')} "
            f"protocol={payload.get('protocol_version', 'unknown')} "
            f"runtime={payload.get('runtime_mode', 'unknown')} "
            f"tools={payload.get('tool_count', 0)} "
            f"resources={payload.get('resource_count', 0)} "
            f"prompts={payload.get('prompt_count', 0)}"
        )
    else:
        print(f"ERROR: {payload.get('error', 'unknown error')}", file=sys.stderr)
    return 0 if ok else 1


def main() -> int:
    args = parse_args()
    launcher = ROOT / "tools" / "hw" / "run_kicad_mcp.sh"
    doctor = read_doctor(args.runtime)
    selected_runtime = doctor.get("SELECTED_RUNTIME", args.runtime)

    proc = subprocess.Popen(
        ["bash", str(launcher), "--runtime", args.runtime],
        cwd=ROOT,
        env=os.environ.copy(),
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
        start_new_session=True,
    )

    payload: dict[str, Any] = {
        "status": "failed",
        "requested_runtime": args.runtime,
        "runtime_mode": selected_runtime,
        "quick": args.quick,
        "protocol_version": None,
        "server_name": None,
        "tool_count": 0,
        "resource_count": 0,
        "prompt_count": 0,
    }

    try:
        send_message(
            proc,
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {
                    "protocolVersion": PROTOCOL_VERSION,
                    "capabilities": {},
                    "clientInfo": {"name": "kill-life-mcp-smoke", "version": "1.0.0"},
                },
            },
        )
        init = read_response(proc, args.timeout)
        result = expect_result(init, "initialize")
        protocol_version = result.get("protocolVersion")
        server_info = result.get("serverInfo") or {}
        server_name = server_info.get("name", "unknown")
        payload["protocol_version"] = protocol_version
        payload["server_name"] = server_name

        send_message(
            proc,
            {
                "jsonrpc": "2.0",
                "method": "notifications/initialized",
                "params": {},
            },
        )
        send_message(
            proc,
            {"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}},
        )
        tools_resp = read_response(proc, args.timeout)
        tools = expect_result(tools_resp, "tools/list").get("tools") or []
        payload["tool_count"] = len(tools)

        send_message(
            proc,
            {"jsonrpc": "2.0", "id": 3, "method": "resources/list", "params": {}},
        )
        resources_resp = read_response(proc, args.timeout)
        resources = expect_result(resources_resp, "resources/list").get("resources") or []
        payload["resource_count"] = len(resources)

        send_message(
            proc,
            {"jsonrpc": "2.0", "id": 4, "method": "prompts/list", "params": {}},
        )
        prompts_resp = read_response(proc, args.timeout)
        prompts = expect_result(prompts_resp, "prompts/list").get("prompts") or []
        payload["prompt_count"] = len(prompts)

        temp_root = ROOT / ".cad-home" / "kicad-mcp" / "smoke"
        if not protocol_version:
            raise RuntimeError("initialize response missing protocolVersion")
        if protocol_version != PROTOCOL_VERSION:
            raise RuntimeError(
                f"initialize protocolVersion mismatch: expected {PROTOCOL_VERSION}, got {protocol_version}"
            )
        if not tools:
            raise RuntimeError("tools/list returned no tools")
        if not resources:
            raise RuntimeError("resources/list returned no resources")
        if not prompts:
            raise RuntimeError("prompts/list returned no prompts")
        if args.quick:
            payload["status"] = "ready"
            payload["checks"] = ["initialize", "tools/list", "resources/list", "prompts/list"]
            return emit_payload(args, payload, ok=True)

        temp_root.mkdir(parents=True, exist_ok=True)
        temp_project_dir = temp_root / f"mcp-smoke-{int(time.time())}"
        temp_project_dir.mkdir(parents=True, exist_ok=True)

        create_payload = call_tool(
            proc,
            5,
            "create_project",
            {
                "name": "mcp_smoke",
                "path": str(temp_project_dir),
            },
            args.timeout,
        )
        schematic_path = temp_project_dir / "mcp_smoke.kicad_sch"
        netlist_path = temp_project_dir / "mcp_smoke.net"
        position_path = temp_project_dir / "mcp_smoke.pos"

        add_net_class = call_tool(
            proc,
            6,
            "add_net_class",
            {
                "name": "MCPSMOKE",
                "clearance": 0.2,
                "trackWidth": 0.25,
                "viaDiameter": 0.8,
                "viaDrill": 0.4,
                "nets": ["GND"],
            },
            args.timeout,
        )
        add_wire = call_tool(
            proc,
            7,
            "add_wire",
            {
                "schematicPath": str(schematic_path),
                "start": {"x": 25.4, "y": 25.4},
                "end": {"x": 50.8, "y": 25.4},
            },
            args.timeout,
        )
        export_netlist = call_tool(
            proc,
            8,
            "export_netlist",
            {
                "outputPath": str(netlist_path),
                "format": "KiCad",
            },
            args.timeout,
        )
        export_position_file = call_tool(
            proc,
            9,
            "export_position_file",
            {
                "outputPath": str(position_path),
                "format": "ASCII",
                "units": "mm",
                "side": "both",
            },
            args.timeout,
        )

        project_properties = read_resource(
            proc,
            10,
            "kicad://project/properties",
            args.timeout,
        )
        board_3d = read_resource(
            proc,
            11,
            "kicad://board/3d-view/top",
            args.timeout,
        )
        libraries_resource = read_resource(
            proc,
            12,
            "kicad://libraries",
            args.timeout,
        )
        symbol_resource = read_resource(
            proc,
            13,
            "kicad://symbol/Device:R",
            args.timeout,
        )

        send_message(
            proc,
            {
                "jsonrpc": "2.0",
                "id": 14,
                "method": "prompts/get",
                "params": {
                    "name": "component_selection",
                    "arguments": {"requirements": "3.3V regulator for ESP32 dev board"},
                },
            },
        )
        prompt_resp = read_response(proc, args.timeout)
        prompt_messages = expect_result(prompt_resp, "prompts/get component_selection").get("messages") or []

        if not prompt_messages:
            raise RuntimeError("prompts/get returned no messages")
        if not create_payload:
            raise RuntimeError("create_project returned no payload")
        if not add_net_class:
            raise RuntimeError("add_net_class returned no payload")
        if not add_wire:
            raise RuntimeError("add_wire returned no payload")
        if not export_netlist:
            raise RuntimeError("export_netlist returned no payload")
        if not export_position_file:
            raise RuntimeError("export_position_file returned no payload")
        if not project_properties:
            raise RuntimeError("resources/read kicad://project/properties returned no contents")
        if not board_3d:
            raise RuntimeError("resources/read kicad://board/3d-view/top returned no contents")
        if not libraries_resource:
            raise RuntimeError("resources/read kicad://libraries returned no contents")
        if not symbol_resource:
            raise RuntimeError("resources/read kicad://symbol/Device:R returned no contents")
        if not netlist_path.exists():
            raise RuntimeError(f"netlist file was not created: {netlist_path}")
        if not position_path.exists():
            raise RuntimeError(f"position file was not created: {position_path}")

        payload["status"] = "ready"
        payload["checks"] = [
            "initialize",
            "tools/list",
            "resources/list",
            "prompts/list",
            "create_project",
            "add_net_class",
            "add_wire",
            "export_netlist",
            "export_position_file",
            "resources/read",
            "prompts/get",
        ]
        payload["project_path"] = str(temp_project_dir)
        return emit_payload(args, payload, ok=True)
    except Exception as exc:
        payload["status"] = "failed"
        payload["error"] = str(exc)
        return emit_payload(args, payload, ok=False)
    finally:
        if proc.poll() is None:
            os.killpg(proc.pid, signal.SIGTERM)
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(proc.pid, signal.SIGKILL)
                proc.wait(timeout=5)

        stderr_output = ""
        if proc.stderr is not None:
            try:
                stderr_output = proc.stderr.read().strip()
            except Exception:
                stderr_output = ""
        if stderr_output and proc.returncode not in (0, None):
            sys.stderr.write(stderr_output + "\n")


if __name__ == "__main__":
    sys.exit(main())
