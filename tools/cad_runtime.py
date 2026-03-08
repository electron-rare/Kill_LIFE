#!/usr/bin/env python3
"""Shared helpers for local CAD runtime wrappers and MCP servers."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
CAD_STACK = ROOT / "tools" / "hw" / "cad_stack.sh"
CAD_HOME = ROOT / ".cad-home"


class CadRuntimeError(RuntimeError):
    """Raised when a CAD runtime command fails or returns invalid output."""


def ensure_cad_home() -> Path:
    CAD_HOME.mkdir(parents=True, exist_ok=True)
    return CAD_HOME


def create_runtime_temp_dir(prefix: str) -> Path:
    ensure_cad_home()
    path = Path(tempfile.mkdtemp(prefix=f"{prefix}-", dir=CAD_HOME))
    os.chmod(path, 0o777)
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
) -> subprocess.CompletedProcess[str]:
    cmd = ["bash", str(CAD_STACK), command, *args]
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


def require_process_success(
    proc: subprocess.CompletedProcess[str],
    *,
    context: str,
) -> subprocess.CompletedProcess[str]:
    if proc.returncode == 0:
        return proc
    error = proc.stderr.strip() or proc.stdout.strip() or f"exit {proc.returncode}"
    raise CadRuntimeError(f"{context} failed: {error}")
