#!/usr/bin/env python3
"""Shared helpers for local CAD runtime wrappers and MCP servers."""

from __future__ import annotations

import json
import os
import shutil
import socket
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
CAD_STACK = ROOT / "tools" / "hw" / "cad_stack.sh"
CAD_HOME = ROOT / ".cad-home"
FREECAD_POOL_SOCKET = CAD_HOME / "freecad_pool.sock"
FREECAD_POOL_PID = CAD_HOME / "freecad_pool.pid"
FREECAD_POOL_LOG = CAD_HOME / "freecad_pool.log"
FREECAD_POOL_DAEMON = CAD_HOME / "freecad_pool_daemon.py"
FREECAD_POOL_SOCKET_REL = ".cad-home/freecad_pool.sock"


class CadRuntimeError(RuntimeError):
    """Raised when a CAD runtime command fails or returns invalid output."""


def ensure_cad_home() -> Path:
    CAD_HOME.mkdir(parents=True, exist_ok=True)
    return CAD_HOME


def create_runtime_temp_dir(prefix: str) -> Path:
    ensure_cad_home()
    path = Path(tempfile.mkdtemp(prefix=f"{prefix}-", dir=CAD_HOME))
    os.chmod(path, 0o700)
    return path


def cleanup_runtime_path(path: Path | None) -> None:
    if path is None:
        return
    try:
        if path.is_dir():
            shutil.rmtree(path, ignore_errors=True)
        elif path.exists():
            path.unlink()
    except Exception:
        pass


def coerce_workspace_path(raw_path: str | Path, *, suffix: str | None = None) -> Path:
    raw = Path(str(raw_path)).expanduser()
    if raw.is_absolute():
        resolved = raw.resolve()
    else:
        resolved = (ROOT / raw).resolve()
    try:
        resolved.relative_to(ROOT)
    except ValueError as exc:
        raise CadRuntimeError(f"path escapes Kill_LIFE workspace: {raw_path}") from exc
    if suffix and resolved.suffix.lower() != suffix.lower():
        raise CadRuntimeError(f"path must end with {suffix}: {raw_path}")
    resolved.parent.mkdir(parents=True, exist_ok=True)
    return resolved


def last_nonempty_line(text: str) -> str:
    for line in reversed(text.splitlines()):
        candidate = line.strip()
        if candidate:
            return candidate
    return ""


def parse_json_tail(text: str) -> dict[str, Any]:
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    if not lines:
        raise CadRuntimeError("expected JSON output, got empty stdout")
    for line in reversed(lines):
        try:
            payload = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(payload, dict):
            return payload
        raise CadRuntimeError(f"expected JSON object, got: {payload!r}")
    raise CadRuntimeError(f"expected JSON output, got: {last_nonempty_line(text)}")


def run_cad_stack(
    command: str,
    *args: str,
    timeout: float = 120.0,
    env: dict[str, str] | None = None,
    clean_env: bool = False,
) -> subprocess.CompletedProcess[str]:
    cmd = ["bash", str(CAD_STACK), command, *args]
    if clean_env:
        merged_env = {}
        for key in ("PATH", "HOME", "TMPDIR", "TMP", "TEMP", "LANG", "LC_ALL", "LC_CTYPE", "USER", "LOGNAME", "SHELL"):
            value = os.environ.get(key)
            if value:
                merged_env[key] = value
    else:
        merged_env = os.environ.copy()
    if env:
        merged_env.update(env)
    return subprocess.run(
        cmd,
        cwd=ROOT,
        env=merged_env,
        capture_output=True,
        text=True,
        check=False,
        timeout=timeout,
    )


def run_cad_stack_background(
    command: str,
    *args: str,
    env: dict[str, str] | None = None,
    log_path: Path | None = None,
) -> subprocess.Popen[str]:
    cmd = ["bash", str(CAD_STACK), command, *args]
    merged_env = os.environ.copy()
    if env:
        merged_env.update(env)
    stdout_target: Any = subprocess.DEVNULL
    stderr_target: Any = subprocess.DEVNULL
    log_handle = None
    if log_path is not None:
        log_path.parent.mkdir(parents=True, exist_ok=True)
        log_handle = open(log_path, "a", encoding="utf-8")
        stdout_target = log_handle
        stderr_target = log_handle
    proc = subprocess.Popen(
        cmd,
        cwd=ROOT,
        env=merged_env,
        stdin=subprocess.DEVNULL,
        stdout=stdout_target,
        stderr=stderr_target,
        text=True,
    )
    if log_handle is not None:
        log_handle.close()
    return proc


def _freecad_pool_enabled() -> bool:
    return str(os.getenv("FREECAD_POOL_ENABLED", "1")).strip().lower() not in {"0", "false", "no"}


def _freecad_pool_start_timeout() -> float:
    raw = str(os.getenv("FREECAD_POOL_START_TIMEOUT", "8")).strip()
    try:
        value = float(raw)
    except ValueError:
        value = 8.0
    return max(1.0, min(value, 30.0))


def _freecad_pool_daemon_source() -> str:
    return """#!/usr/bin/env python3
from __future__ import annotations

import io
import json
import os
import socket
import traceback
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

import FreeCAD

ROOT = Path.cwd().resolve()
SOCKET_PATH = Path(os.getenv("FREECAD_POOL_SOCKET", ".cad-home/freecad_pool.sock"))
if not SOCKET_PATH.is_absolute():
    SOCKET_PATH = (ROOT / SOCKET_PATH).resolve()
SOCKET_PATH.parent.mkdir(parents=True, exist_ok=True)
try:
    SOCKET_PATH.unlink()
except FileNotFoundError:
    pass

server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
server.bind(str(SOCKET_PATH))
os.chmod(SOCKET_PATH, 0o600)
server.listen(16)

def _jsonl(conn: socket.socket, payload: dict):
    conn.sendall((json.dumps(payload, ensure_ascii=False) + "\\n").encode("utf-8"))

def _safe_script_path(rel: str) -> Path | None:
    try:
        candidate = (ROOT / rel).resolve()
        candidate.relative_to(ROOT)
        return candidate
    except Exception:
        return None

def _runtime_info() -> dict:
    try:
        version = ".".join(FreeCAD.Version()[:3])
    except Exception:
        version = ""
    return {"ok": True, "version": version}

def _run_script(rel: str) -> dict:
    script_path = _safe_script_path(rel)
    if script_path is None or not script_path.exists():
        return {"ok": False, "error": f"script not found: {rel}"}
    code = script_path.read_text(encoding="utf-8")
    buf_out = io.StringIO()
    buf_err = io.StringIO()
    scope = {"__name__": "__main__"}
    try:
        with redirect_stdout(buf_out), redirect_stderr(buf_err):
            exec(compile(code, str(script_path), "exec"), scope, scope)
        return {"ok": True, "stdout": buf_out.getvalue(), "stderr": buf_err.getvalue()}
    except Exception as exc:
        return {
            "ok": False,
            "error": str(exc),
            "stdout": buf_out.getvalue(),
            "stderr": buf_err.getvalue(),
            "traceback": traceback.format_exc(limit=8),
        }

while True:
    conn, _ = server.accept()
    try:
        data = b""
        while b"\\n" not in data and len(data) < 4_000_000:
            chunk = conn.recv(65536)
            if not chunk:
                break
            data += chunk
        if not data:
            continue
        line = data.split(b"\\n", 1)[0]
        req = json.loads(line.decode("utf-8"))
        action = str(req.get("action") or "")
        if action == "ping":
            _jsonl(conn, {"ok": True, "status": "ready"})
            continue
        if action == "runtime_info":
            _jsonl(conn, _runtime_info())
            continue
        if action == "run_script":
            _jsonl(conn, _run_script(str(req.get("script_rel") or "")))
            continue
        _jsonl(conn, {"ok": False, "error": f"unknown action: {action}"})
    except Exception as exc:
        _jsonl(conn, {"ok": False, "error": str(exc)})
    finally:
        try:
            conn.close()
        except Exception:
            pass
"""


def _freecad_pool_request(payload: dict[str, Any], *, timeout: float) -> dict[str, Any]:
    if not FREECAD_POOL_SOCKET.exists():
        raise CadRuntimeError("freecad pool socket not available")
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(timeout)
        client.connect(str(FREECAD_POOL_SOCKET))
        client.sendall((json.dumps(payload, ensure_ascii=True) + "\n").encode("utf-8"))
        chunks: list[bytes] = []
        started = time.monotonic()
        while True:
            if time.monotonic() - started > timeout:
                raise CadRuntimeError("freecad pool request timed out")
            chunk = client.recv(65536)
            if not chunk:
                break
            chunks.append(chunk)
            if b"\n" in chunk:
                break
    raw = b"".join(chunks).split(b"\n", 1)[0].decode("utf-8", errors="replace").strip()
    if not raw:
        raise CadRuntimeError("freecad pool returned empty payload")
    try:
        payload_out = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise CadRuntimeError(f"freecad pool invalid JSON: {raw}") from exc
    if not isinstance(payload_out, dict):
        raise CadRuntimeError("freecad pool response is not an object")
    return payload_out


def _freecad_pool_ping(*, timeout: float = 1.0) -> bool:
    try:
        response = _freecad_pool_request({"action": "ping"}, timeout=timeout)
        return bool(response.get("ok"))
    except Exception:
        return False


def _ensure_freecad_pool() -> bool:
    if not _freecad_pool_enabled():
        return False
    ensure_cad_home()
    if _freecad_pool_ping(timeout=0.5):
        return True

    daemon_source = _freecad_pool_daemon_source()
    FREECAD_POOL_DAEMON.write_text(daemon_source, encoding="utf-8")
    os.chmod(FREECAD_POOL_DAEMON, 0o700)

    if FREECAD_POOL_SOCKET.exists():
        cleanup_runtime_path(FREECAD_POOL_SOCKET)

    proc = run_cad_stack_background(
        "freecad-cmd",
        str(FREECAD_POOL_DAEMON.relative_to(ROOT)),
        env={"FREECAD_POOL_SOCKET": FREECAD_POOL_SOCKET_REL},
        log_path=FREECAD_POOL_LOG,
    )
    try:
        FREECAD_POOL_PID.write_text(str(proc.pid), encoding="utf-8")
    except Exception:
        pass

    deadline = time.monotonic() + _freecad_pool_start_timeout()
    while time.monotonic() < deadline:
        if proc.poll() is not None:
            break
        if _freecad_pool_ping(timeout=0.5):
            return True
        time.sleep(0.1)

    try:
        if FREECAD_POOL_LOG.exists():
            excerpt = FREECAD_POOL_LOG.read_text(encoding="utf-8", errors="replace")[-4000:]
            if excerpt.strip():
                FREECAD_POOL_LOG.write_text(excerpt, encoding="utf-8")
    except Exception:
        pass
    return False


def run_freecad_script(
    script_rel_path: str,
    *,
    timeout: float = 120.0,
    prefer_pool: bool = True,
    clean_env: bool = False,
) -> subprocess.CompletedProcess[str]:
    if prefer_pool and _ensure_freecad_pool():
        try:
            response = _freecad_pool_request(
                {"action": "run_script", "script_rel": script_rel_path},
                timeout=max(5.0, timeout + 5.0),
            )
            ok = bool(response.get("ok"))
            return subprocess.CompletedProcess(
                args=["freecad-pool", script_rel_path],
                returncode=0 if ok else 1,
                stdout=str(response.get("stdout") or ""),
                stderr=str(response.get("stderr") or response.get("error") or ""),
            )
        except Exception:
            pass

    return run_cad_stack("freecad-cmd", script_rel_path, timeout=timeout, clean_env=clean_env)


def require_process_success(
    proc: subprocess.CompletedProcess[str],
    *,
    context: str,
) -> subprocess.CompletedProcess[str]:
    if proc.returncode == 0:
        return proc
    error = proc.stderr.strip() or proc.stdout.strip() or f"exit {proc.returncode}"
    raise CadRuntimeError(f"{context} failed: {error}")
