#!/usr/bin/env python3
"""Create a spec folder using .specify templates.

This is a tiny bridge so you can keep a Spec-Kit-ish layout while staying
compatible with the repo's `specs/<name>/` convention.
"""

from __future__ import annotations

import argparse
from pathlib import Path


def sanitize(name: str) -> str:
    name = name.strip().lower()
    out = []
    for ch in name:
        if ch.isalnum() or ch in ("-", "_"):
            out.append(ch)
        elif ch.isspace():
            out.append("-")
    s = "".join(out).strip("-")
    return s or "spec"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--name", required=True, help="feature/epic name")
    args = ap.parse_args()

    repo = Path(__file__).resolve().parents[2]
    templates = repo / ".specify" / "templates"
    if not templates.exists():
        raise SystemExit("missing .specify/templates")

    spec_name = sanitize(args.name)
    dst = repo / "specs" / spec_name
    dst.mkdir(parents=True, exist_ok=True)

    for fname in ("00_prd.md", "01_tech_plan.md", "02_tasks.md"):
        src = templates / fname
        if not src.exists():
            continue
        text = src.read_text(encoding="utf-8").replace("<FEATURE>", spec_name)
        out = dst / fname
        if not out.exists():
            out.write_text(text, encoding="utf-8")

    print(dst)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
