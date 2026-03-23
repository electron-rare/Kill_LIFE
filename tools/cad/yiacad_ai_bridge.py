#!/usr/bin/env python3
"""Shared request bridge for KiCad and FreeCAD AI-native helpers."""

from __future__ import annotations

import argparse
import json
from datetime import datetime
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
REQUEST_DIR = ROOT / "artifacts" / "cad-ai-requests"
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


def ensure_request_dir() -> None:
    REQUEST_DIR.mkdir(parents=True, exist_ok=True)


def selection_from_json(raw: str) -> list[Any]:
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        return [raw] if raw else []
    if isinstance(payload, list):
        return payload
    return [payload]


def latest_request() -> Path | None:
    ensure_request_dir()
    files = sorted(REQUEST_DIR.glob("*.json"), key=lambda item: item.stat().st_mtime, reverse=True)
    return files[0] if files else None


def latest_status_excerpt() -> list[str]:
    if not YIACAD_STATUS.exists():
        return []
    lines = [line.rstrip() for line in YIACAD_STATUS.read_text(encoding="utf-8").splitlines() if line.strip()]
    return lines[:12]


def command_request(args: argparse.Namespace) -> int:
    ensure_request_dir()
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    request_path = REQUEST_DIR / f"{stamp}_{args.surface}_{args.intent}.json"
    payload = {
        "id": request_path.stem,
        "created_at": datetime.now().isoformat(timespec="seconds"),
        "surface": args.surface,
        "intent": args.intent,
        "prompt": args.prompt,
        "source_path": args.source_path,
        "selection": selection_from_json(args.selection_json),
        "status_hint": str(YIACAD_STATUS),
    }
    request_path.write_text(json.dumps(payload, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "status": "queued",
                "request_path": str(request_path),
                "surface": args.surface,
                "intent": args.intent,
            },
            ensure_ascii=True,
        )
    )
    return 0


def command_status(_: argparse.Namespace) -> int:
    last_request = latest_request()
    payload = {
        "request_dir": str(REQUEST_DIR),
        "latest_request": str(last_request) if last_request else "",
        "yiacad_status": str(YIACAD_STATUS),
        "yiacad_status_exists": YIACAD_STATUS.exists(),
        "yiacad_status_excerpt": latest_status_excerpt(),
    }
    print(json.dumps(payload, ensure_ascii=True))
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
