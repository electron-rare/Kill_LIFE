#!/usr/bin/env python3
"""Aggregate local MCP runtime readiness across Kill_LIFE smoke helpers."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

try:
    from .mcp_smoke_common import load_runtime_env
except ImportError:  # pragma: no cover - script entrypoint fallback
    from mcp_smoke_common import load_runtime_env

ROOT = Path(__file__).resolve().parents[1]

CHECKS: tuple[dict[str, Any], ...] = (
    {
        "name": "validate-specs",
        "cmd": ["python3", "tools/validate_specs_mcp_smoke.py", "--json", "--quick"],
        "accept_degraded": False,
    },
    {
        "name": "kicad",
        "cmd": ["python3", "tools/hw/mcp_smoke.py", "--json", "--quick", "--timeout", "30"],
        "accept_degraded": False,
    },
    {
        "name": "kicad-host",
        "cmd": ["python3", "tools/hw/kicad_host_mcp_smoke.py", "--json", "--quick"],
        "accept_degraded": True,
        "optional_degraded": True,
        "task": "K-012",
        "blocked_when": "host_pcbnew_import != ok (optional host-native path)",
    },
    {
        "name": "knowledge-base",
        "cmd": ["python3", "tools/knowledge_base_mcp_smoke.py", "--json", "--quick"],
        "accept_degraded": True,
    },
    {
        "name": "github-dispatch",
        "cmd": ["python3", "tools/github_dispatch_mcp_smoke.py", "--json", "--quick"],
        "accept_degraded": True,
    },
    {
        "name": "freecad",
        "cmd": ["python3", "tools/freecad_mcp_smoke.py", "--json", "--quick"],
        "accept_degraded": False,
        "task": "F-101",
    },
    {
        "name": "openscad",
        "cmd": ["python3", "tools/openscad_mcp_smoke.py", "--json", "--quick"],
        "accept_degraded": False,
        "task": "O-101",
    },
    {
        "name": "nexar-api",
        "cmd": ["python3", "tools/nexar_mcp_smoke.py", "--json"],
        "accept_degraded": True,
        "task": "K-014",
        "blocked_when": "live Nexar unavailable (token missing, demo mode, or external account/quota limit)",
        "optional_degraded_when_live_validation": ("quota_exceeded",),
    },
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--strict", action="store_true", help="Treat degraded checks as failures.")
    return parser.parse_args()


def classify_overall(results: list[dict[str, Any]], *, strict: bool) -> str:
    any_failed = False
    any_degraded = False
    for result in results:
        status = result.get("status")
        if status == "failed":
            any_failed = True
            continue
        if status == "degraded" and (strict or not result.get("accept_degraded", False)):
            any_failed = True
            continue
        if status == "degraded" and result.get("optional_degraded", False):
            continue
        if status == "degraded":
            any_degraded = True
    if any_failed:
        return "failed"
    if any_degraded:
        return "degraded"
    return "ready"


def derive_blockers(results: list[dict[str, Any]]) -> list[dict[str, str]]:
    blockers: list[dict[str, str]] = []
    for result in results:
        task = result.get("task")
        if not task or result.get("status") != "degraded" or result.get("optional_degraded", False):
            continue
        name = result.get("name", "unknown")
        error = str(result.get("error") or "blocked by environment")
        blocked_when = str(result.get("blocked_when") or "")
        blockers.append(
            {
                "task": task,
                "check": name,
                "reason": error,
                "condition": blocked_when,
            }
        )
    return blockers


def run_check(spec: dict[str, Any]) -> dict[str, Any]:
    proc = subprocess.run(
        spec["cmd"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    stdout = proc.stdout.strip()
    stderr = proc.stderr.strip()
    try:
        payload = json.loads(stdout) if stdout else {}
    except json.JSONDecodeError as exc:
        payload = {
            "status": "failed",
            "error": f"invalid JSON: {exc}",
            "stdout": stdout,
        }
    payload.setdefault("status", "failed")
    payload.setdefault("error", None)
    payload["name"] = spec["name"]
    payload["accept_degraded"] = spec.get("accept_degraded", False)
    payload["optional_degraded"] = spec.get("optional_degraded", False)
    live_validation = payload.get("live_validation")
    if (
        payload.get("status") == "degraded"
        and live_validation in spec.get("optional_degraded_when_live_validation", ())
    ):
        payload["optional_degraded"] = True
    if "task" in spec:
        payload["task"] = spec["task"]
    if "blocked_when" in spec:
        payload["blocked_when"] = spec["blocked_when"]
    payload["exit_code"] = proc.returncode
    if stderr:
        payload["stderr"] = stderr
    return payload


def emit(payload: dict[str, Any], *, json_output: bool) -> int:
    if json_output:
        print(json.dumps(payload, ensure_ascii=True))
    else:
        print(f"MCP runtime status: {payload['status']}")
        print(f"Checks: {payload['counts']['ready']} ready / {payload['counts']['degraded']} degraded / {payload['counts']['failed']} failed")
        if payload["blockers"]:
            print("Open blocked tasks:")
            for blocker in payload["blockers"]:
                print(f"- {blocker['task']} via {blocker['check']}: {blocker['reason']}")
    return 0 if payload["status"] == "ready" else 1


def main() -> int:
    args = parse_args()
    load_runtime_env()
    results = [run_check(spec) for spec in CHECKS]
    payload = {
        "status": classify_overall(results, strict=args.strict),
        "strict": args.strict,
        "checks": results,
        "counts": {
            "ready": sum(1 for result in results if result.get("status") == "ready"),
            "degraded": sum(1 for result in results if result.get("status") == "degraded"),
            "failed": sum(1 for result in results if result.get("status") == "failed"),
        },
        "blockers": derive_blockers(results),
    }
    return emit(payload, json_output=args.json)


if __name__ == "__main__":
    raise SystemExit(main())
