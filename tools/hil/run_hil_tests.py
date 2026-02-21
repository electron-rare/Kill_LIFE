#!/usr/bin/env python3
"""HIL placeholder runner for CI baseline."""

from __future__ import annotations

import json


def main() -> int:
    report = {
        "ok": True,
        "suite": "hil",
        "status": "skipped",
        "reason": "No remote hardware executor configured in CI baseline.",
    }
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
