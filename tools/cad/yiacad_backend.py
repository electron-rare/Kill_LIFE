#!/usr/bin/env python3
"""Local YiACAD backend helpers shared by native shells, TUI and CAD utilities."""

from __future__ import annotations

import json
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ARTIFACTS_ROOT = ROOT / "artifacts" / "cad-ai-native"
FUSION_STATUS = ROOT / "artifacts" / "cad-fusion" / "yiacad-fusion-last-status.md"


def utc_timestamp() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def resolve_path(value: str | Path | None) -> Path | None:
    if not value:
        return None
    path = Path(value).expanduser()
    try:
        return path.resolve()
    except FileNotFoundError:
        return path.resolve(strict=False)


def first_existing_path(*candidates: str | Path | None) -> Path | None:
    for candidate in candidates:
        path = resolve_path(candidate)
        if path and path.exists():
            return path
    return None


def infer_surface(
    *,
    board: str | Path | None = None,
    schematic: str | Path | None = None,
    freecad_document: str | Path | None = None,
) -> str:
    has_board = bool(first_existing_path(board))
    has_schematic = bool(first_existing_path(schematic))
    has_freecad = bool(first_existing_path(freecad_document))
    if has_board and not has_schematic and not has_freecad:
        return "kicad-pcb"
    if has_schematic and not has_board and not has_freecad:
        return "kicad-sch"
    if has_freecad and not has_board and not has_schematic:
        return "freecad-workbench"
    return "tui"


def build_context_ref(
    *,
    source_path: str | Path | None = None,
    board: str | Path | None = None,
    schematic: str | Path | None = None,
    freecad_document: str | Path | None = None,
) -> str | None:
    candidate = first_existing_path(board, schematic, freecad_document, source_path)
    if not candidate:
        for fallback in (board, schematic, freecad_document, source_path):
            candidate = resolve_path(fallback)
            if candidate:
                break
    if not candidate:
        return None
    workspace = candidate if candidate.is_dir() else candidate.parent
    leaf = candidate.name if candidate.is_dir() else candidate.stem
    return f"project:{workspace.name}/{leaf}"


def build_context_record(
    surface: str,
    *,
    source_path: str | Path | None = None,
    board: str | Path | None = None,
    schematic: str | Path | None = None,
    freecad_document: str | Path | None = None,
    artifacts_dir: str | Path | None = None,
) -> dict:
    source = resolve_path(source_path)
    board_path = resolve_path(board)
    schematic_path = resolve_path(schematic)
    freecad_path = resolve_path(freecad_document)
    artifacts_path = resolve_path(artifacts_dir)
    return {
        "component": "yiacad-context",
        "generated_at": utc_timestamp(),
        "surface": surface,
        "context_ref": build_context_ref(
            source_path=source,
            board=board_path,
            schematic=schematic_path,
            freecad_document=freecad_path,
        ),
        "paths": {
            "source_path": str(source) if source else None,
            "board": str(board_path) if board_path else None,
            "schematic": str(schematic_path) if schematic_path else None,
            "freecad_document": str(freecad_path) if freecad_path else None,
            "artifacts_dir": str(artifacts_path) if artifacts_path else None,
        },
        "runtime": {
            "root": str(ROOT),
            "artifacts_root": str(ARTIFACTS_ROOT),
            "fusion_status_path": str(FUSION_STATUS) if FUSION_STATUS.exists() else None,
        },
    }


def artifact_entry(path: str | Path, kind: str, label: str | None = None) -> dict:
    resolved = resolve_path(path)
    return {
        "kind": kind,
        "path": str(resolved) if resolved else str(path),
        "label": label,
    }


def output_status_from_returncodes(returncodes: list[int]) -> tuple[str, str]:
    if not returncodes:
        return ("blocked", "error")
    if any(code not in (0, 5) for code in returncodes):
        return ("blocked", "error")
    if any(code == 5 for code in returncodes):
        return ("degraded", "warning")
    return ("done", "info")


def build_uiux_output(
    *,
    surface: str,
    action: str,
    execution_mode: str,
    status: str,
    severity: str,
    summary: str,
    details: str | None,
    context_ref: str | None,
    artifacts: list[dict],
    next_steps: list[str],
    latency_ms: int | None = None,
) -> dict:
    return {
        "component": "yiacad",
        "surface": surface,
        "action": action,
        "execution_mode": execution_mode,
        "status": status,
        "severity": severity,
        "summary": summary,
        "details": details,
        "generated_at": utc_timestamp(),
        "context_ref": context_ref,
        "provider": None,
        "model": None,
        "latency_ms": latency_ms,
        "artifacts": artifacts,
        "next_steps": next_steps,
    }


def write_json(path: str | Path, payload: object) -> Path:
    target = Path(path)
    target.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return target


def write_context_record(path: str | Path, payload: dict) -> Path:
    return write_json(path, payload)


def write_uiux_output(path: str | Path, payload: dict) -> Path:
    return write_json(path, payload)
