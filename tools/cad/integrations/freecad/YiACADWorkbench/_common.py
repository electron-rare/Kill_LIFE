from __future__ import annotations

import json
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path

from kill_life.yiacad_action_registry import (
    yiacad_action_inputs,
    yiacad_actions_for_surface,
    yiacad_command_for_alias,
)

SESSION_VERSION = 1
MAX_SESSION_MESSAGES = 50


def _candidate_roots() -> list[Path]:
    candidates: list[Path] = []
    if os.environ.get("KILL_LIFE_ROOT"):
        candidates.append(Path(os.environ["KILL_LIFE_ROOT"]).expanduser())
    here = Path(__file__).resolve()
    candidates.extend(here.parents)
    return candidates


def repo_root() -> Path:
    for candidate in _candidate_roots():
        backend_client = candidate / "tools" / "cad" / "yiacad_backend_client.py"
        if backend_client.exists():
            return candidate
    raise RuntimeError("Unable to locate Kill_LIFE root for YiACAD backend client")


def backend_client_script() -> Path:
    return repo_root() / "tools" / "cad" / "yiacad_backend_client.py"


def _run_json_command(args: list[str]) -> dict:
    proc = subprocess.run(
        ["python3", str(backend_client_script()), *args],
        cwd=repo_root(),
        text=True,
        capture_output=True,
        check=False,
        timeout=30,
    )
    if proc.returncode != 0 and not proc.stdout.strip():
        raise RuntimeError(proc.stderr.strip() or "YiACAD backend client failed")
    return json.loads(proc.stdout.strip() or "{}")


def _project_inputs(source_path: str) -> dict[str, str]:
    path = Path(source_path).expanduser() if source_path else Path()
    if not source_path:
        return {"source_path": "", "board": "", "schematic": "", "freecad_document": ""}
    suffix = path.suffix
    stem = path.with_suffix("")
    board = stem.with_suffix(".kicad_pcb")
    schematic = stem.with_suffix(".kicad_sch")
    freecad_document = stem.with_suffix(".FCStd")
    return {
        "source_path": str(path),
        "board": str(board) if board.exists() else "",
        "schematic": str(schematic) if schematic.exists() else "",
        "freecad_document": str(path if suffix == ".FCStd" else freecad_document) if (path if suffix == ".FCStd" else freecad_document).exists() else "",
    }


def available_actions(surface: str = "yiacad-freecad") -> list[dict]:
    return list(yiacad_actions_for_surface(surface))


def _now_iso() -> str:
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def _default_session() -> dict:
    return {
        "version": SESSION_VERSION,
        "updated_at": "",
        "last_intent": "ecad-mcad-sync",
        "last_prompt": "",
        "last_source_path": "",
        "messages": [],
    }


def session_dir(root: Path | None = None) -> Path:
    path = (root or repo_root()) / "artifacts" / "cad-ai-native" / "freecad_workbench"
    path.mkdir(parents=True, exist_ok=True)
    return path


def session_path(root: Path | None = None) -> Path:
    return session_dir(root) / "session.json"


def load_session(path: Path | None = None) -> dict:
    target = path or session_path()
    if not target.exists():
        return _default_session()
    try:
        payload = json.loads(target.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return _default_session()
    session = _default_session()
    session.update({key: value for key, value in payload.items() if key in session})
    session["messages"] = payload.get("messages") if isinstance(payload.get("messages"), list) else []
    return session


def save_session(session: dict, path: Path | None = None) -> dict:
    target = path or session_path()
    normalized = _default_session()
    normalized.update({key: value for key, value in session.items() if key in normalized})
    normalized["messages"] = list(session.get("messages") or [])[-MAX_SESSION_MESSAGES:]
    normalized["updated_at"] = _now_iso()
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(normalized, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")
    return normalized


def remember_session_state(intent: str, prompt: str, source_path: str, path: Path | None = None) -> dict:
    session = load_session(path)
    session["last_intent"] = intent
    session["last_prompt"] = prompt
    session["last_source_path"] = source_path
    return save_session(session, path)


def append_session_message(
    role: str,
    content: str,
    *,
    intent: str = "",
    source_path: str = "",
    status: str = "",
    path: Path | None = None,
) -> dict:
    session = load_session(path)
    session["messages"].append(
        {
            "role": role,
            "content": content,
            "intent": intent,
            "source_path": source_path,
            "status": status,
            "created_at": _now_iso(),
        }
    )
    if intent:
        session["last_intent"] = intent
    if source_path:
        session["last_source_path"] = source_path
    return save_session(session, path)


def clear_session(path: Path | None = None) -> dict:
    return save_session(_default_session(), path)


def run_intent(surface: str, intent: str, prompt: str, source_path: str, selection: list[str]) -> dict:
    del prompt
    del selection
    inputs = _project_inputs(source_path)
    command = yiacad_command_for_alias("yiacad-freecad", intent) or yiacad_command_for_alias("yiacad-kicad", intent) or "status"
    args = ["--surface", surface, "--json-output", command]
    for key in yiacad_action_inputs(command):
        value = inputs.get(key, "")
        if value:
            args.extend([f"--{key.replace('_', '-')}", value])
    return _run_json_command(args)


def fetch_status_payload(source_path: str = "") -> dict:
    args = ["--surface", "yiacad-desktop", "--json-output", "status"]
    if source_path:
        args.extend(["--source-path", source_path])
    return _run_json_command(args)


def open_path(path: Path) -> None:
    subprocess.Popen(["open", str(path)])
