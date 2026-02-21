#!/usr/bin/env python3
"""Minimal model/dataset validation for CI baseline."""

from __future__ import annotations

import json
from pathlib import Path


def main() -> int:
    repo_root = Path(__file__).resolve().parents[2]
    ai_root = repo_root / "tools" / "ai"
    spec_root = repo_root / "specs"

    report = {
        "ok": ai_root.exists() and spec_root.exists(),
        "suite": "model_validation",
        "checks": [
            {"name": "ai_tooling_exists", "ok": ai_root.exists(), "path": str(ai_root.relative_to(repo_root))},
            {"name": "specs_exists", "ok": spec_root.exists(), "path": str(spec_root.relative_to(repo_root))},
        ],
    }
    print(json.dumps(report, indent=2))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
