#!/usr/bin/env python3
"""Basic community-health checks."""

from __future__ import annotations

import json
from pathlib import Path


def main() -> int:
    repo_root = Path(__file__).resolve().parents[2]
    checks = [
        ("readme_exists", repo_root / "README.md"),
        ("license_exists", repo_root / "LICENSE.md"),
        ("docs_exists", repo_root / "docs"),
    ]

    entries = [{"name": name, "ok": path.exists(), "path": str(path.relative_to(repo_root))} for name, path in checks]
    report = {"ok": all(entry["ok"] for entry in entries), "suite": "community_health", "checks": entries}

    print(json.dumps(report, indent=2))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
