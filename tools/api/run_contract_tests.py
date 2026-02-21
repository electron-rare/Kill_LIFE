#!/usr/bin/env python3
"""Minimal API contract check used by CI baseline."""

from __future__ import annotations

import json
from pathlib import Path


def main() -> int:
    repo_root = Path(__file__).resolve().parents[2]
    endpoints_file = repo_root / "endpoints.md"

    report = {
        "ok": endpoints_file.exists(),
        "suite": "api_contract",
        "checks": [
            {
                "name": "endpoints_documented",
                "ok": endpoints_file.exists(),
                "path": str(endpoints_file.relative_to(repo_root)),
            }
        ],
    }

    print(json.dumps(report, indent=2))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
