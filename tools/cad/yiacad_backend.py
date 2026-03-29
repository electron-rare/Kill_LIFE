#!/usr/bin/env python3
"""Local YiACAD backend helpers shared by native shells, TUI and CAD utilities."""

from __future__ import annotations

import json
import plistlib
import re
import shutil
import subprocess
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ARTIFACTS_ROOT = ROOT / "artifacts" / "cad-ai-native"
FUSION_STATUS = ROOT / "artifacts" / "cad-fusion" / "yiacad-fusion-last-status.md"
KICAD_APP_CLI = Path("/Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli")
FREECAD_APP_CMD = Path("/Applications/FreeCAD.app/Contents/MacOS/FreeCADCmd")
FREECAD_APP_GUI = Path("/Applications/FreeCAD.app/Contents/MacOS/FreeCAD")
COMMAND_TIMEOUT_SEC = 2.0
ENGINE_BASELINE = {
    "kicad": ">=10.0",
    "freecad": ">=1.1",
    "kibot": "installed",
    "kiauto": "installed",
}


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


def resolve_binary(*candidates: str | Path | None) -> str | None:
    for candidate in candidates:
        if not candidate:
            continue
        if isinstance(candidate, Path):
            if candidate.exists():
                return str(candidate)
            continue
        found = shutil.which(candidate)
        if found:
            return found
    return None


def version_tuple(raw: str | None) -> tuple[int, ...] | None:
    if not raw:
        return None
    match = re.search(r"(\d+(?:\.\d+){0,2})", raw)
    if not match:
        return None
    return tuple(int(part) for part in match.group(1).split("."))


def version_gte(detected: str | None, minimum: str | None) -> bool | None:
    detected_tuple = version_tuple(detected)
    minimum_tuple = version_tuple(minimum)
    if not detected_tuple or not minimum_tuple:
        return None
    padded_detected = detected_tuple + (0,) * (len(minimum_tuple) - len(detected_tuple))
    return padded_detected >= minimum_tuple


def command_output(command: list[str], timeout_sec: float = COMMAND_TIMEOUT_SEC) -> tuple[int, str]:
    try:
        proc = subprocess.run(command, text=True, capture_output=True, timeout=timeout_sec)
    except subprocess.TimeoutExpired:
        rendered = " ".join(command)
        return (124, f"command timed out after {timeout_sec:.1f}s: {rendered}")
    combined = "\n".join(part.strip() for part in (proc.stdout, proc.stderr) if part.strip()).strip()
    return proc.returncode, combined


def bundle_version(binary: str | None) -> str | None:
    if not binary:
        return None
    path = Path(binary)
    for parent in path.parents:
        if parent.suffix != ".app":
            continue
        info_plist = parent / "Contents" / "Info.plist"
        if not info_plist.exists():
            continue
        try:
            with info_plist.open("rb") as handle:
                payload = plistlib.load(handle)
        except Exception:  # noqa: BLE001
            return None
        for key in ("CFBundleShortVersionString", "CFBundleVersion"):
            raw = payload.get(key)
            if isinstance(raw, str):
                match = re.search(r"(\d+(?:\.\d+){0,2})", raw)
                if match:
                    return match.group(1)
    return None


def probe_engine_version(
    probe_binary: str | None,
    probes: list[list[str]],
    *,
    bundle_binary: str | None = None,
) -> str | None:
    if probe_binary:
        for probe in probes:
            rc, text = command_output([probe_binary, *probe])
            if rc == 0 and text:
                match = re.search(r"(\d+(?:\.\d+){0,2})", text)
                if match:
                    return match.group(1)
    return bundle_version(bundle_binary or probe_binary)


def engine_entry(
    *,
    name: str,
    binary: str | None,
    required_version: str | None,
    probes: list[list[str]],
    bundle_binary: str | None = None,
) -> dict:
    reported_binary = binary or bundle_binary
    detected_version = probe_engine_version(binary, probes, bundle_binary=bundle_binary)
    if not reported_binary:
        status = "blocked"
        reason = "missing-binary"
    elif required_version and required_version != "installed":
        meets_baseline = version_gte(detected_version, required_version)
        if meets_baseline is False:
            status = "blocked"
            reason = "version-too-old"
        elif meets_baseline is None:
            status = "degraded"
            reason = "version-unresolved"
        else:
            status = "done"
            reason = "ready" if binary else "bundle-ready"
    elif detected_version is None:
        status = "degraded"
        reason = "version-unresolved"
    else:
        status = "done"
        reason = "ready" if binary else "bundle-ready"
    return {
        "name": name,
        "integrated": True,
        "binary": reported_binary,
        "required_version": required_version,
        "detected_version": detected_version,
        "available": reported_binary is not None,
        "status": status,
        "reason": reason,
    }


def detect_integrated_engines() -> dict:
    kicad_binary = resolve_binary(KICAD_APP_CLI, "kicad-cli")
    freecad_binary = resolve_binary(FREECAD_APP_CMD, "FreeCADCmd", "freecadcmd")
    freecad_bundle_binary = resolve_binary(FREECAD_APP_GUI, "FreeCAD")
    kibot_binary = resolve_binary("kibot")
    kiauto_binary = resolve_binary("pcbnew_do", "eeschema_do", "kicad2step_do", "kiauto")
    return {
        "kicad": engine_entry(
            name="KiCad",
            binary=kicad_binary,
            required_version=ENGINE_BASELINE["kicad"],
            probes=[["version"], ["--version"]],
        ),
        "freecad": engine_entry(
            name="FreeCAD",
            binary=freecad_binary,
            required_version=ENGINE_BASELINE["freecad"],
            probes=[["--version"], ["-v"]],
            bundle_binary=freecad_bundle_binary,
        ),
        "kibot": engine_entry(
            name="KiBot",
            binary=kibot_binary,
            required_version=ENGINE_BASELINE["kibot"],
            probes=[["--version"]],
        ),
        "kiauto": engine_entry(
            name="KiAuto",
            binary=kiauto_binary,
            required_version=ENGINE_BASELINE["kiauto"],
            probes=[["--version"], ["--help"]],
        ),
    }


def collect_engine_reasons(engine_status: dict, relevant: set[str] | None = None) -> list[str]:
    reasons: list[str] = []
    for key, entry in (engine_status or {}).items():
        if relevant and key not in relevant:
            continue
        status = entry.get("status")
        if status not in {"degraded", "blocked"}:
            continue
        reason = entry.get("reason") or status
        reasons.append(f"{key}-{reason}")
    return reasons


def overall_engine_health(engine_status: dict) -> str:
    statuses = {entry.get("status") for entry in engine_status.values()}
    if statuses == {"done"}:
        return "done"
    if "blocked" in statuses:
        return "degraded"
    return "degraded"


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
    integrated_engines: dict | None = None,
) -> dict:
    source = resolve_path(source_path)
    board_path = resolve_path(board)
    schematic_path = resolve_path(schematic)
    freecad_path = resolve_path(freecad_document)
    artifacts_path = resolve_path(artifacts_dir)
    engines = integrated_engines or detect_integrated_engines()
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
            "engine_baseline": ENGINE_BASELINE,
            "integrated_engines": engines,
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
    degraded_reasons: list[str] | None = None,
    engine_status: dict | None = None,
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
        "degraded_reasons": degraded_reasons or [],
        "engine_status": engine_status or {},
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
