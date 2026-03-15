#!/usr/bin/env python3
"""Smoke checks for the local FreeCAD headless runtime."""

from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT / "tools") not in __import__("sys").path:
    __import__("sys").path.insert(0, str(ROOT / "tools"))

from cad_runtime import (  # type: ignore
    CadRuntimeError,
    cleanup_runtime_path,
    create_runtime_temp_dir,
    last_nonempty_line,
    parse_json_tail,
    require_process_success,
    run_cad_stack,
)

WORKSPACE_ROOT = Path("/workspace")


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
            f"runtime=freecad "
            f"version={payload.get('version', 'unknown')} "
            f"checks={len(payload.get('checks', []))}"
        )
    else:
        print(
            f"WARN: runtime=freecad status={payload.get('status')} error={payload.get('error')}",
            file=__import__("sys").stderr,
        )
    return 0 if payload.get("status") == "ready" else 1


def main() -> int:
    args = parse_args()
    temp_dir: Path | None = None
    payload: dict[str, object] = {
        "status": "failed",
        "runtime": "freecad",
        "version": None,
        "checks": [],
        "artifacts": {},
        "error": None,
    }

    try:
        version_proc = require_process_success(
            run_cad_stack(
                "freecad-cmd",
                "-c",
                'import FreeCAD; print(".".join(FreeCAD.Version()[:3]))',
                timeout=args.timeout,
            ),
            context="freecad version probe",
        )
        version = last_nonempty_line(version_proc.stdout) or last_nonempty_line(version_proc.stderr)
        if not version:
            raise CadRuntimeError("freecad version probe returned no version")

        payload["version"] = version
        payload["checks"] = ["version"]

        if args.quick:
            payload["status"] = "ready"
            return emit(payload, json_output=args.json)

        temp_dir = create_runtime_temp_dir("freecad-smoke")
        doc_path = temp_dir / "freecad-smoke.FCStd"
        script_path = temp_dir / "freecad_smoke.py"
        doc_workspace_path = WORKSPACE_ROOT / doc_path.relative_to(ROOT)
        script_path.write_text(
            "\n".join(
                [
                    "import json",
                    "from pathlib import Path",
                    "import FreeCAD",
                    "",
                    f'doc_path = Path(r"{doc_workspace_path.as_posix()}")',
                    'doc = FreeCAD.newDocument("SmokeDoc")',
                    'box = doc.addObject("Part::Box", "SmokeBox")',
                    "box.Length = 10.0",
                    "box.Width = 8.0",
                    "box.Height = 6.0",
                    "doc.recompute()",
                    "doc.saveAs(str(doc_path))",
                    "print(json.dumps({",
                    '    "ok": True,',
                    '    "document_path": str(doc_path),',
                    '    "document_exists": doc_path.exists(),',
                    '    "object_count": len(doc.Objects),',
                    '    "document_name": doc.Name,',
                    "}))",
                ]
            ),
            encoding="utf-8",
        )

        create_proc = require_process_success(
            run_cad_stack(
                "freecad-cmd",
                str(script_path.relative_to(ROOT)),
                timeout=args.timeout,
            ),
            context="freecad create document smoke",
        )
        result = parse_json_tail(create_proc.stdout)
        if not result.get("ok"):
            raise CadRuntimeError(f"freecad document creation failed: {result}")
        if not doc_path.exists():
            raise CadRuntimeError(f"freecad document was not created: {doc_path}")

        payload["checks"] = ["version", "create_document", "save_document"]
        payload["artifacts"] = {
            "document_path": str(doc_path.relative_to(ROOT)),
            "document_size_bytes": doc_path.stat().st_size,
            "object_count": int(result.get("object_count") or 0),
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
