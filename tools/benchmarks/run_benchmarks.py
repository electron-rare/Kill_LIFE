#!/usr/bin/env python3
"""Deterministic benchmark placeholder for CI."""

from __future__ import annotations

import json


def main() -> int:
    report = {
        "ok": True,
        "suite": "performance",
        "benchmarks": [
            {"name": "startup_ms", "value": 0, "unit": "ms"},
            {"name": "smoke_iterations", "value": 1, "unit": "count"},
        ],
        "notes": ["Baseline placeholder; replace with hardware-backed benchmark pipeline."],
    }
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
