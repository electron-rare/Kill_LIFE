#!/usr/bin/env python3
"""Small diff helper for CAD export text artefacts."""

from __future__ import annotations

import difflib
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 4:
        print(f"usage: {Path(sys.argv[0]).name} <before> <after> <out.md>", file=sys.stderr)
        return 2

    before_path = Path(sys.argv[1])
    after_path = Path(sys.argv[2])
    out_path = Path(sys.argv[3])

    if not before_path.exists():
        print(f"Input file missing: {before_path}", file=sys.stderr)
        return 1
    if not after_path.exists():
        print(f"Input file missing: {after_path}", file=sys.stderr)
        return 1

    before = before_path.read_text(encoding="utf-8", errors="ignore").splitlines()
    after = after_path.read_text(encoding="utf-8", errors="ignore").splitlines()

    diff = difflib.unified_diff(before, after, fromfile=before_path.name, tofile=after_path.name, lineterm="")
    out_path.write_text("\n".join(diff) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
