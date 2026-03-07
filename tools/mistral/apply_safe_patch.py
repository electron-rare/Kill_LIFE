#!/usr/bin/env python3
"""
Apply a SafePatch JSON to the repo with scope allowlists + deny globs.

This script never runs shell commands. It only writes files.

Example:
  python tools/mistral/apply_safe_patch.py --scope ai:spec --patch /tmp/patch.json
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from jsonschema import Draft202012Validator

from tools.mistral.scope_allowlists import is_path_allowed, explain_scope

SCHEMA_PATH = Path(__file__).parent / "schemas" / "safe_patch.schema.json"
WINDOWS_DRIVE_RE = re.compile(r"^[A-Za-z]:[/\\]")


def safe_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def normalize_relative_path(raw_path: str) -> str:
    rel = raw_path.replace("\\", "/").strip()
    while rel.startswith("./"):
        rel = rel[2:]
    if not rel or rel.startswith("/") or WINDOWS_DRIVE_RE.match(rel):
        raise SystemExit(f"Refusing absolute patch path: {raw_path}")
    parts = rel.split("/")
    if any(part in ("", ".", "..") for part in parts):
        raise SystemExit(f"Refusing unsafe patch path: {raw_path}")
    return "/".join(parts)


def resolve_destination(root: Path, rel: str) -> Path:
    dst = (root / rel).resolve()
    try:
        dst.relative_to(root)
    except ValueError as exc:
        raise SystemExit(f"Refusing out-of-repo path: {rel}") from exc
    return dst


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--scope", required=True, help="ai:spec|ai:plan|ai:tasks|ai:impl|ai:qa|ai:docs")
    ap.add_argument("--patch", required=True)
    ap.add_argument("--allow-delete", action="store_true")
    ap.add_argument("--root", default=".", help="repo root (default: .)")
    args = ap.parse_args()

    root = Path(args.root).resolve()
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))

    patch_path = Path(args.patch)
    patch = json.loads(patch_path.read_text(encoding="utf-8"))

    v = Draft202012Validator(schema)
    errors = sorted(v.iter_errors(patch), key=lambda e: e.path)
    if errors:
        msg = "\n".join([f"- {list(e.path)}: {e.message}" for e in errors])
        raise SystemExit(f"Patch JSON does not match schema:\n{msg}")

    edits = patch.get("edits", [])
    blocked = []
    for e in edits:
        p = normalize_relative_path(e["path"])
        if not is_path_allowed(args.scope, p):
            blocked.append(p)

    if blocked:
        raise SystemExit(
            "Blocked paths for scope "
            + args.scope
            + ":\n  - "
            + "\n  - ".join(blocked)
            + "\n\n"
            + explain_scope(args.scope)
        )

    applied = []
    for e in edits:
        rel = normalize_relative_path(e["path"])
        action = e["action"]
        dst = resolve_destination(root, rel)

        if action in ("create", "update"):
            safe_write(dst, e.get("content", ""))
            applied.append(f"{action}: {rel}")
        elif action == "delete":
            if not args.allow_delete:
                raise SystemExit(f"Refusing to delete {rel} (pass --allow-delete)")
            if dst.is_dir():
                raise SystemExit(f"Refusing to delete directory {rel}")
            if dst.exists():
                dst.unlink()
                applied.append(f"delete: {rel}")
        else:
            raise SystemExit(f"Unknown action: {action}")

    print("Applied edits:")
    for a in applied:
        print(" -", a)

    if patch.get("commands"):
        print("\nSuggested verify commands (NOT executed):")
        for c in patch["commands"]:
            print(" -", c)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
