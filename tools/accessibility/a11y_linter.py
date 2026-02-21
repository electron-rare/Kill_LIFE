#!/usr/bin/env python3
"""Very small docs accessibility linter."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def main() -> int:
    docs_root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path("docs").resolve()
    markdown_files = list(docs_root.rglob("*.md")) if docs_root.exists() else []

    report = {
        "ok": docs_root.exists(),
        "suite": "accessibility",
        "docs_root": str(docs_root),
        "markdown_file_count": len(markdown_files),
        "notes": ["Baseline linter checks docs presence and markdown discoverability."],
    }

    print(json.dumps(report, indent=2))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
