from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path


def _candidate_roots() -> list[Path]:
    candidates: list[Path] = []
    if os.environ.get("KILL_LIFE_ROOT"):
        candidates.append(Path(os.environ["KILL_LIFE_ROOT"]).expanduser())
    here = Path(__file__).resolve()
    candidates.extend(here.parents)
    return candidates


def repo_root() -> Path:
    for candidate in _candidate_roots():
        bridge = candidate / "tools" / "cad" / "yiacad_ai_bridge.py"
        if bridge.exists():
            return candidate
    raise RuntimeError("Unable to locate Kill_LIFE root for YiACAD bridge")


def bridge_script() -> Path:
    return repo_root() / "tools" / "cad" / "yiacad_ai_bridge.py"


def run_bridge(args: list[str]) -> dict:
    proc = subprocess.run(
        ["python3", str(bridge_script()), *args],
        cwd=repo_root(),
        text=True,
        capture_output=True,
        check=False,
        timeout=30,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or proc.stdout.strip() or "YiACAD bridge failed")
    return json.loads(proc.stdout.strip() or "{}")


def queue_request(surface: str, intent: str, prompt: str, source_path: str, selection: list[str]) -> dict:
    return run_bridge(
        [
            "request",
            "--surface",
            surface,
            "--intent",
            intent,
            "--prompt",
            prompt,
            "--source-path",
            source_path,
            "--selection-json",
            json.dumps(selection, ensure_ascii=True),
        ]
    )


def fetch_status_payload() -> dict:
    return run_bridge(["status"])


def open_path(path: Path) -> None:
    subprocess.Popen(["open", str(path)])
