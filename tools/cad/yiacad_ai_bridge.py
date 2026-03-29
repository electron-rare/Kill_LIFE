#!/usr/bin/env python3
"""Compatibility shim that delegates legacy desktop requests to the YiACAD backend client."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path
from typing import Any

from kill_life.yiacad_action_registry import yiacad_action_inputs, yiacad_command_for_alias

ROOT = Path(__file__).resolve().parents[2]
BACKEND_CLIENT = ROOT / "tools" / "cad" / "yiacad_backend_client.py"
YIACAD_STATUS = ROOT / "artifacts" / "cad-fusion" / "yiacad-fusion-last-status.md"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)

    req = sub.add_parser("request")
    req.add_argument("--surface", choices=("kicad", "freecad"), required=True)
    req.add_argument("--intent", required=True)
    req.add_argument("--prompt", default="")
    req.add_argument("--source-path", default="")
    req.add_argument("--selection-json", default="[]")

    sub.add_parser("status")
    return parser.parse_args()


def selection_from_json(raw: str) -> list[Any]:
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        return [raw] if raw else []
    if isinstance(payload, list):
        return payload
    return [payload]


def latest_status_excerpt() -> list[str]:
    if not YIACAD_STATUS.exists():
        return []
    lines = [line.rstrip() for line in YIACAD_STATUS.read_text(encoding="utf-8").splitlines() if line.strip()]
    return lines[:12]


def infer_inputs(source_path: str) -> dict[str, str]:
    if not source_path:
        return {"source_path": "", "board": "", "schematic": "", "freecad_document": ""}
    path = Path(source_path).expanduser()
    stem = path.with_suffix("")
    board = stem.with_suffix(".kicad_pcb")
    schematic = stem.with_suffix(".kicad_sch")
    freecad_document = stem.with_suffix(".FCStd")
    return {
        "source_path": str(path),
        "board": str(board) if board.exists() else "",
        "schematic": str(schematic) if schematic.exists() else "",
        "freecad_document": str(path if path.suffix == ".FCStd" else freecad_document) if (path if path.suffix == ".FCStd" else freecad_document).exists() else "",
    }


def run_backend(command: str, *, source_path: str = "") -> dict:
    args = ["python3", str(BACKEND_CLIENT), "--surface", "yiacad-desktop", "--json-output", command]
    inputs = infer_inputs(source_path)
    for key in yiacad_action_inputs(command):
        value = inputs.get(key, "")
        if value:
            args.extend([f"--{key.replace('_', '-')}", value])
    proc = subprocess.run(
        args,
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
        timeout=30,
    )
    if proc.returncode != 0 and not proc.stdout.strip():
        raise RuntimeError(proc.stderr.strip() or "YiACAD backend client failed")
    return json.loads(proc.stdout.strip() or "{}")


def command_request(args: argparse.Namespace) -> int:
    surface_key = "yiacad-kicad" if args.surface == "kicad" else "yiacad-freecad"
    command = yiacad_command_for_alias(surface_key, args.intent) or "status"
    payload = run_backend(command, source_path=args.source_path)
    compatibility = {
        "status": payload.get("status", "blocked"),
        "surface": args.surface,
        "intent": args.intent,
        "transport_command": command,
        "selection": selection_from_json(args.selection_json),
        "request_path": "",
        "uiux_output": payload.get("uiux_output"),
        "summary": payload.get("summary"),
        "degraded_reasons": payload.get("degraded_reasons", []),
        "next_steps": payload.get("next_steps", []),
        "payload": payload,
    }
    print(json.dumps(compatibility, ensure_ascii=True))
    return 0 if payload.get("status") != "blocked" else 1


def command_status(_: argparse.Namespace) -> int:
    payload = run_backend("status")
    compatibility = {
        "request_dir": "",
        "latest_request": "",
        "yiacad_status": str(YIACAD_STATUS),
        "yiacad_status_exists": YIACAD_STATUS.exists(),
        "yiacad_status_excerpt": latest_status_excerpt(),
        "payload": payload,
    }
    print(json.dumps(compatibility, ensure_ascii=True))
    return 0


def main() -> int:
    args = parse_args()
    if args.command == "request":
        return command_request(args)
    if args.command == "status":
        return command_status(args)
    raise SystemExit(2)


if __name__ == "__main__":
    raise SystemExit(main())
