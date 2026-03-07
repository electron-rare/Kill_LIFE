#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPORT_PATH = ROOT / "docs" / "evidence" / "ci_cd_audit_summary.json"


def run_step(args: list[str]) -> dict:
    proc = subprocess.run(
        [sys.executable, *args],
        cwd=str(ROOT),
        capture_output=True,
        text=True,
    )
    return {
        "command": [sys.executable, *args],
        "returncode": proc.returncode,
        "stdout": proc.stdout.strip(),
        "stderr": proc.stderr.strip(),
    }


def check_all_targets() -> tuple[dict, bool]:
    report = {
        "targets": {},
        "compliance": run_step(["tools/compliance/validate.py", "--strict"]),
    }
    failed = report["compliance"]["returncode"] != 0

    target_steps = {
        "esp": [
            ["tools/build_firmware.py", "esp"],
            ["tools/collect_evidence.py", "esp"],
            ["tools/verify_evidence.py", "esp"],
        ],
        "linux": [
            ["tools/test_firmware.py", "linux"],
            ["tools/collect_evidence.py", "linux"],
            ["tools/verify_evidence.py", "linux"],
        ],
    }

    for target, steps in target_steps.items():
        print(f"\n--- Vérification {target} ---")
        results = []
        for step in steps:
            result = run_step(step)
            results.append(result)
            if result["stdout"]:
                print(result["stdout"])
            if result["stderr"]:
                print(result["stderr"], file=sys.stderr)
        report["targets"][target] = results
        failed = failed or any(item["returncode"] != 0 for item in results)

    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return report, failed


if __name__ == '__main__':
    report, failed = check_all_targets()
    print("\n=== Rapport de vérification ===")
    print(f"compliance: rc={report['compliance']['returncode']}")
    for target, steps in report["targets"].items():
        rc = max(item["returncode"] for item in steps)
        print(f"{target}: rc={rc}")
    print(f"rapport: {REPORT_PATH}")
    raise SystemExit(1 if failed else 0)
