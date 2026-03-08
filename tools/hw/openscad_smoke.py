#!/usr/bin/env python3
"""Smoke checks for the local OpenSCAD headless runtime."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT / "tools") not in __import__("sys").path:
    __import__("sys").path.insert(0, str(ROOT / "tools"))

from cad_runtime import (  # type: ignore
    CadRuntimeError,
    cleanup_runtime_path,
    create_runtime_temp_dir,
    last_nonempty_line,
    require_process_success,
    run_cad_stack,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--timeout", type=float, default=60.0)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--quick", action="store_true")
    return parser.parse_args()


def emit(payload: dict[str, object], *, json_output: bool) -> int:
    if json_output:
        print(json.dumps(payload, ensure_ascii=True))
    elif payload.get("status") == "ready":
        print(
            "OK: "
            f"runtime=openscad "
            f"version={payload.get('version', 'unknown')} "
            f"checks={len(payload.get('checks', []))}"
        )
    else:
        print(
            f"WARN: runtime=openscad status={payload.get('status')} error={payload.get('error')}",
            file=__import__("sys").stderr,
        )
    return 0 if payload.get("status") == "ready" else 1


def main() -> int:
    args = parse_args()
    temp_dir: Path | None = None
    payload: dict[str, object] = {
        "status": "failed",
        "runtime": "openscad",
        "version": None,
        "checks": [],
        "artifacts": {},
        "error": None,
    }

    try:
        version_proc = require_process_success(
            run_cad_stack("openscad", "--version", timeout=args.timeout),
            context="openscad version probe",
        )
        version = last_nonempty_line(version_proc.stdout) or last_nonempty_line(version_proc.stderr)
        if not version:
            raise CadRuntimeError("openscad version probe returned no version")
        payload["version"] = version
        payload["checks"] = ["version"]

        if args.quick:
            payload["status"] = "ready"
            return emit(payload, json_output=args.json)

        temp_dir = create_runtime_temp_dir("openscad-smoke")
        source_path = temp_dir / "smoke.scad"
        output_path = temp_dir / "smoke.stl"
        source_path.write_text(
            "difference() { cube([12, 10, 6], center=true); translate([0,0,-1]) cylinder(h=10, r=2, center=true); }\n",
            encoding="utf-8",
        )

        require_process_success(
            run_cad_stack(
                "openscad",
                "-o",
                str(output_path.relative_to(ROOT)),
                str(source_path.relative_to(ROOT)),
                timeout=args.timeout,
            ),
            context="openscad render smoke",
        )
        if not output_path.exists():
            raise CadRuntimeError(f"openscad did not create output artifact: {output_path}")
        if output_path.stat().st_size <= 0:
            raise CadRuntimeError(f"openscad output artifact is empty: {output_path}")

        payload["checks"] = ["version", "render_model", "export_artifact"]
        payload["artifacts"] = {
            "source_path": str(source_path.relative_to(ROOT)),
            "output_path": str(output_path.relative_to(ROOT)),
            "output_size_bytes": output_path.stat().st_size,
        }
        payload["status"] = "ready"
        return emit(payload, json_output=args.json)
    except Exception as exc:
        payload["status"] = "failed"
        payload["error"] = str(exc)
        return emit(payload, json_output=args.json)
    finally:
        if temp_dir is not None:
            cleanup_runtime_path(temp_dir)


if __name__ == "__main__":
    raise SystemExit(main())
