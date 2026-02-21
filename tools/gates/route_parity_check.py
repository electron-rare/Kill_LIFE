#!/usr/bin/env python3
"""Static frontend/backend API route parity gate.

This helper extracts `/api/...` routes from backend and frontend files and
flags frontend routes that are not exposed by backend sources.
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import re
import sys
from pathlib import Path


ROUTE_RE = re.compile(r"/api/[A-Za-z0-9._~!$&'()*+,;=:@/%-]*")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Check frontend/backend route parity.")
    parser.add_argument(
        "--backend",
        action="append",
        default=[],
        help="Glob for backend source files (repeatable).",
    )
    parser.add_argument(
        "--frontend",
        action="append",
        default=[],
        help="Glob for frontend source files (repeatable).",
    )
    parser.add_argument(
        "--report",
        default="docs/evidence/route_parity_report.json",
        help="JSON report output path.",
    )
    return parser.parse_args()


def expand_files(patterns: list[str]) -> list[Path]:
    files: set[Path] = set()
    for pattern in patterns:
        for item in glob.glob(pattern, recursive=True):
            path = Path(item)
            if path.is_file():
                files.add(path)
    return sorted(files)


def extract_routes(files: list[Path]) -> set[str]:
    routes: set[str] = set()
    for path in files:
        try:
            content = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        for route in ROUTE_RE.findall(content):
            # Normalize accidental trailing slash-only duplicates.
            normalized = route.rstrip() or route
            routes.add(normalized)
    return routes


def main() -> int:
    args = parse_args()
    backend_files = expand_files(args.backend)
    frontend_files = expand_files(args.frontend)

    backend_routes = extract_routes(backend_files)
    frontend_routes = extract_routes(frontend_files)

    frontend_missing_in_backend = sorted(frontend_routes - backend_routes)
    backend_unreferenced_in_frontend = sorted(backend_routes - frontend_routes)

    report = {
        "backend_files_count": len(backend_files),
        "frontend_files_count": len(frontend_files),
        "backend_routes_count": len(backend_routes),
        "frontend_routes_count": len(frontend_routes),
        "frontend_missing_in_backend": frontend_missing_in_backend,
        "backend_unreferenced_in_frontend": backend_unreferenced_in_frontend,
        "backend_routes": sorted(backend_routes),
        "frontend_routes": sorted(frontend_routes),
    }

    report_path = Path(args.report)
    os.makedirs(report_path.parent, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")

    print(f"[route-parity] backend files: {len(backend_files)}")
    print(f"[route-parity] frontend files: {len(frontend_files)}")
    print(f"[route-parity] backend routes: {len(backend_routes)}")
    print(f"[route-parity] frontend routes: {len(frontend_routes)}")
    print(f"[route-parity] report: {report_path}")

    if frontend_missing_in_backend:
        print("[route-parity] FAIL: frontend routes missing in backend:")
        for route in frontend_missing_in_backend:
            print(f"  - {route}")
        return 1

    print("[route-parity] PASS: no frontend-only route detected.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
