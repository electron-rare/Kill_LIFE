"""Shared helpers for local MCP smoke scripts."""

from __future__ import annotations

import json
import os
import re
import signal
import subprocess
import sys
from queue import Queue
from pathlib import Path
from threading import Thread
from typing import Any

PROTOCOL_VERSION = "2025-03-26"
ENV_ASSIGN_RE = re.compile(r"^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$")
def resolve_default_mascarade_dir() -> Path:
    env_value = os.environ.get("MASCARADE_DIR", "").strip()
    candidates = []
    if env_value:
        candidates.append(Path(env_value))

    root = Path(__file__).resolve().parents[2]
    candidates.extend([root / "mascarade", root / "mascarade-main"])

    preferred_paths = (
        "core/mascarade/integrations/knowledge_base.py",
        "core/mascarade/integrations/github_dispatch.py",
        "finetune/kicad_mcp_server",
    )

    for candidate in candidates:
        resolved = candidate.resolve()
        if all((resolved / rel).exists() for rel in preferred_paths):
            return resolved

    for candidate in candidates:
        resolved = candidate.resolve()
        if (resolved / "core/mascarade").exists():
            return resolved

    return (root / "mascarade").resolve()


DEFAULT_MASCARADE_DIR = resolve_default_mascarade_dir()


class SmokeError(RuntimeError):
    """Raised when a smoke check fails."""


def _decode_env_value(raw_value: str) -> str:
    value = raw_value.strip()
    if not value:
        return ""
    if len(value) >= 2 and value[0] == value[-1] == '"':
        inner = value[1:-1]
        return inner.replace("\\n", "\n").replace('\\"', '"').replace("\\\\", "\\")
    if len(value) >= 2 and value[0] == value[-1] == "'":
        return value[1:-1]
    return value


def resolve_mascarade_env_file() -> Path:
    return Path(
        os.environ.get("MASCARADE_ENV_FILE", DEFAULT_MASCARADE_DIR / ".env")
    ).resolve()


def load_runtime_env(*, override: bool = False) -> dict[str, str]:
    env_file = resolve_mascarade_env_file()
    loaded: dict[str, str] = {}
    if not env_file.exists():
        return loaded

    for raw_line in env_file.read_text(encoding="utf-8").splitlines():
        stripped = raw_line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        match = ENV_ASSIGN_RE.match(stripped)
        if not match:
            continue
        key = match.group(1)
        value = _decode_env_value(match.group(2))
        if override or key not in os.environ or not os.environ.get(key, "").strip():
            os.environ[key] = value
            loaded[key] = value
    return loaded


def spawn_server(command: list[str], cwd: Path) -> subprocess.Popen[str]:
    return subprocess.Popen(
        command,
        cwd=cwd,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
        start_new_session=True,
    )


def terminate_server(proc: subprocess.Popen[str]) -> None:
    if proc.poll() is None:
        try:
            proc.stdin.close() if proc.stdin else None
        except Exception:
            pass
        try:
            if sys.platform == "win32":
                proc.terminate()
            else:
                os.killpg(proc.pid, signal.SIGTERM)
        except Exception:
            try:
                if sys.platform == "win32":
                    proc.kill()
                else:
                    os.killpg(proc.pid, signal.SIGKILL)
            except Exception:
                try:
                    proc.kill()
                except Exception:
                    pass
        try:
            proc.wait(timeout=3)
        except Exception:
            if sys.platform == "win32":
                proc.kill()
            else:
                try:
                    os.killpg(proc.pid, signal.SIGKILL)
                except Exception:
                    try:
                        proc.kill()
                    except Exception:
                        pass
    for handle in (proc.stdin, proc.stdout, proc.stderr):
        try:
            handle.close() if handle else None
        except Exception:
            pass


def send_message(proc: subprocess.Popen[str], payload: dict[str, Any]) -> None:
    if proc.stdin is None:
        raise SmokeError("stdin pipe is not available")
    body = json.dumps(payload).encode("utf-8")
    proc.stdin.write(f"Content-Length: {len(body)}\r\n\r\n{body.decode('utf-8')}")
    proc.stdin.flush()


def _read_message_blocking(proc: subprocess.Popen[str]) -> dict[str, Any]:
    if proc.stdout is None:
        raise SmokeError("stdout pipe is not available")
    headers: dict[str, str] = {}
    while True:
        line = proc.stdout.readline()
        if not line:
            stderr = proc.stderr.read().strip() if proc.stderr else ""
            raise SmokeError(f"MCP process closed stdout before replying: {stderr}")
        if line in ("\r\n", "\n"):
            break
        key, _, value = line.partition(":")
        headers[key.strip().lower()] = value.strip()

    content_length = int(headers.get("content-length", "0"))
    if content_length <= 0:
        raise SmokeError("MCP response missing Content-Length")
    body = proc.stdout.read(content_length)
    if not body:
        raise SmokeError("MCP response body is empty")
    return json.loads(body)


def read_message(proc: subprocess.Popen[str], timeout: float) -> dict[str, Any]:
    result_queue: Queue[tuple[bool, dict[str, Any] | Exception]] = Queue()

    def _worker() -> None:
        try:
            result_queue.put((True, _read_message_blocking(proc)))
        except Exception as exc:
            result_queue.put((False, exc))

    thread = Thread(target=_worker, daemon=True)
    thread.start()
    thread.join(timeout)
    if thread.is_alive():
        raise SmokeError(f"Timed out after {timeout:.1f}s waiting for MCP response")

    ok, payload = result_queue.get_nowait()
    if ok:
        return payload  # type: ignore[return-value]
    raise payload  # type: ignore[misc]


def initialize(proc: subprocess.Popen[str], timeout: float, client_name: str) -> dict[str, Any]:
    send_message(
        proc,
        {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": PROTOCOL_VERSION,
                "capabilities": {},
                "clientInfo": {"name": client_name, "version": "1.0.0"},
            },
        },
    )
    response = read_message(proc, timeout)
    result = expect_result(response, "initialize")
    if result.get("protocolVersion") != PROTOCOL_VERSION:
        raise SmokeError(
            "initialize protocolVersion mismatch: "
            f"expected {PROTOCOL_VERSION}, got {result.get('protocolVersion')}"
        )
    send_message(
        proc,
        {"jsonrpc": "2.0", "method": "notifications/initialized"},
    )
    return result


def expect_result(message: dict[str, Any], method: str) -> dict[str, Any]:
    if "error" in message:
        raise SmokeError(f"{method} failed: {message['error']}")
    result = message.get("result")
    if result is None:
        raise SmokeError(f"{method} returned no result")
    return result


def list_tools(proc: subprocess.Popen[str], timeout: float, request_id: int = 2) -> list[dict[str, Any]]:
    send_message(
        proc,
        {"jsonrpc": "2.0", "id": request_id, "method": "tools/list", "params": {}},
    )
    result = expect_result(read_message(proc, timeout), "tools/list")
    tools = result.get("tools") or []
    if not tools:
        raise SmokeError("tools/list returned no tools")
    return tools


def call_tool(
    proc: subprocess.Popen[str],
    timeout: float,
    request_id: int,
    name: str,
    arguments: dict[str, Any],
) -> dict[str, Any]:
    send_message(
        proc,
        {
            "jsonrpc": "2.0",
            "id": request_id,
            "method": "tools/call",
            "params": {"name": name, "arguments": arguments},
        },
    )
    return expect_result(read_message(proc, timeout), f"tools/call {name}")


def emit_payload(payload: dict[str, Any], *, json_output: bool) -> int:
    ok = payload.get("status") == "ready"
    if json_output:
        print(json.dumps(payload, ensure_ascii=True))
    elif ok:
        print(
            "OK: "
            f"server={payload.get('server_name', 'unknown')} "
            f"protocol={payload.get('protocol_version', 'unknown')} "
            f"tools={payload.get('tool_count', 0)} "
            f"status={payload.get('status', 'unknown')}"
        )
    else:
        print(
            "WARN: "
            f"server={payload.get('server_name', 'unknown')} "
            f"status={payload.get('status', 'unknown')} "
            f"error={payload.get('error', 'unknown error')}",
            file=sys.stderr,
        )
    return 0 if payload.get("status") == "ready" else 1
