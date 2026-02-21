#!/usr/bin/env python3
"""Minimal evidence-pack validator for CI baseline."""

from __future__ import annotations

import json
from pathlib import Path


def main() -> int:
    repo_root = Path(__file__).resolve().parents[2]
    evidence_dir = repo_root / "docs" / "evidence"

    report = {
        "ok": evidence_dir.exists(),
        "suite": "evidence_pack",
        "checks": [
            {
                "name": "evidence_directory_exists",
                "ok": evidence_dir.exists(),
                "path": str(evidence_dir.relative_to(repo_root)),
            }
        ],
    }

    print(json.dumps(report, indent=2))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
