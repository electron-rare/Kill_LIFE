#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPORT_PATH = ROOT / "docs" / "evidence" / "ci_cd_audit_summary.json"
STEP_SUMMARY_ENV = "GITHUB_STEP_SUMMARY"


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


def command_label(result: dict) -> str:
    command = result.get("command", [])
    if len(command) >= 2:
        return Path(command[1]).stem
    return "step"


def result_status_label(returncode: int) -> str:
    return "ok" if returncode == 0 else f"failed ({returncode})"


def target_returncode(steps: list[dict]) -> int:
    return max((item.get("returncode", 1) for item in steps), default=1)


def first_output_line(result: dict) -> str:
    for key in ("stdout", "stderr"):
        value = (result.get(key) or "").strip()
        if value:
            return value.splitlines()[0]
    return ""


def render_markdown_summary(report: dict) -> str:
    compliance_rc = report["compliance"]["returncode"]

    lines = [
        "# Kill_LIFE Evidence Pack Summary",
        "",
        f"- JSON report: `{REPORT_PATH.relative_to(ROOT)}`",
        "- Artifact snapshot: `docs/evidence/`",
        "",
        "| Lane | RC | Status |",
        "| --- | --- | --- |",
        f"| compliance | `{compliance_rc}` | {result_status_label(compliance_rc)} |",
    ]

    for target, steps in report["targets"].items():
        rc = target_returncode(steps)
        lines.append(f"| {target} | `{rc}` | {result_status_label(rc)} |")

    for target, steps in report["targets"].items():
        lines.extend(
            [
                "",
                f"## {target}",
                "",
                "| Step | RC | Command | Signal |",
                "| --- | --- | --- | --- |",
            ]
        )
        for result in steps:
            label = command_label(result)
            rc = result["returncode"]
            command = " ".join(result.get("command", [])[1:])
            signal = first_output_line(result).replace("|", "\\|")
            lines.append(
                f"| `{label}` | `{rc}` | `{command}` | {signal or '-'} |"
            )

    return "\n".join(lines) + "\n"


def write_step_summary(report: dict) -> Path | None:
    summary_path = os.environ.get(STEP_SUMMARY_ENV, "").strip()
    if not summary_path:
        return None
    path = Path(summary_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(render_markdown_summary(report), encoding="utf-8")
    return path


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
    summary_path = write_step_summary(report)
    print("\n=== Rapport de vérification ===")
    print(f"compliance: rc={report['compliance']['returncode']}")
    for target, steps in report["targets"].items():
        rc = target_returncode(steps)
        print(f"{target}: rc={rc}")
    print(f"rapport: {REPORT_PATH}")
    if summary_path is not None:
        print(f"step summary: {summary_path}")
    raise SystemExit(1 if failed else 0)
