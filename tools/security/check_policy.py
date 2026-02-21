#!/usr/bin/env python3
"""Security policy baseline checker."""

from __future__ import annotations

import json
from pathlib import Path


def main() -> int:
    repo_root = Path(__file__).resolve().parents[2]
    candidates = [repo_root / "SECURITY.md", repo_root / "docs" / "security", repo_root / "docs" / "security.md"]
    present = [path for path in candidates if path.exists()]

    report = {
        "ok": bool(present),
        "suite": "security_policy",
        "checks": [
            {"name": "security_policy_present", "ok": bool(present), "found": [str(path.relative_to(repo_root)) for path in present]}
        ],
    }
    print(json.dumps(report, indent=2))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
