#!/usr/bin/env python3
from __future__ import annotations

import ast
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPORT_PATH = ROOT / "docs" / "evidence" / "ci_cd_audit_summary.json"
MARKDOWN_REPORT_PATH = ROOT / "docs" / "evidence" / "ci_cd_audit_summary.md"
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


def compact_repo_paths(value: str) -> str:
    text = value.strip()
    if not text:
        return ""
    root_with_sep = f"{ROOT}{os.sep}"
    if root_with_sep in text:
        return text.replace(root_with_sep, "")
    if text == str(ROOT):
        return "."
    return text


def compact_artifact_list_signal(value: str) -> str:
    prefix, separator, suffix = value.partition(": ")
    if not separator or not suffix.startswith("["):
        return value
    try:
        parsed = ast.literal_eval(suffix)
    except (SyntaxError, ValueError):
        return value
    if not isinstance(parsed, list) or not all(isinstance(item, str) for item in parsed):
        return value
    return prefix


def artifact_items_from_signal(value: str) -> list[str]:
    _, separator, suffix = value.partition(": ")
    if not separator or not suffix.startswith("["):
        return []
    try:
        parsed = ast.literal_eval(suffix)
    except (SyntaxError, ValueError):
        return []
    if not isinstance(parsed, list) or not all(isinstance(item, str) for item in parsed):
        return []
    return parsed


def artifact_summary_sample(items: list[str], max_items: int = 2) -> str:
    if not items:
        return "-"
    names = [Path(item).name or item for item in items[:max_items]]
    sample = ", ".join(f"`{name}`" for name in names)
    remaining = len(items) - len(names)
    if remaining > 0:
        sample += f", `+{remaining}`"
    return sample


def evidence_summary_path(target: str) -> Path:
    return ROOT / "docs" / "evidence" / target / "summary.json"


def load_evidence_summary(target: str) -> dict | None:
    path = evidence_summary_path(target)
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None


def required_summary_cell(items: list[str], status: str) -> str:
    if not items:
        return "-"
    if status == "ok":
        label = "file" if len(items) == 1 else "files"
        return f"`{len(items)}` {label}"
    return artifact_summary_sample(items, max_items=3)


def missing_summary_cell(items: list[str]) -> str:
    if not items:
        return "-"
    return artifact_summary_sample(items, max_items=3)


def drift_summary_cell(value: str | None) -> str:
    if not value:
        return "-"
    return value


def artifact_summary_rows(report: dict) -> list[dict]:
    rows: list[dict] = []
    for target, steps in report["targets"].items():
        verify_step = next(
            (result for result in steps if command_label(result) == "verify_evidence"),
            None,
        )
        signal = first_output_line(verify_step or {})
        artifacts = (
            artifact_items_from_signal(signal)
            if signal.startswith(f"Evidence pack trouvé pour {target}")
            else []
        )
        verify_rc = verify_step["returncode"] if verify_step else target_returncode(steps)
        evidence_summary = load_evidence_summary(target) or {}
        summary_status = str(evidence_summary.get("status") or "").strip()
        required_files = [
            item
            for item in evidence_summary.get("required_files", [])
            if isinstance(item, str)
        ]
        missing = [
            item
            for item in evidence_summary.get("missing", [])
            if isinstance(item, str)
        ]
        drift: str | None = None
        if verify_rc != 0 and not missing:
            missing = artifact_items_from_signal(signal)
        if verify_rc != 0 and summary_status == "ok" and missing:
            drift = "summary ok"
        rows.append(
            {
                "lane": target,
                "status": result_status_label(verify_rc),
                "artifacts": artifacts,
                "required_files": required_files,
                "missing": missing,
                "drift": drift,
            }
        )
    return rows


def compact_markdown_signal(value: str, max_length: int = 140) -> str:
    compacted = compact_artifact_list_signal(compact_repo_paths(value))
    if len(compacted) <= max_length:
        return compacted
    return f"{compacted[: max_length - 3].rstrip()}..."


def markdown_signal(value: str) -> str:
    return compact_markdown_signal(value).replace("|", "\\|")


def failing_lane_entries(report: dict) -> list[dict]:
    entries: list[dict] = []

    compliance = report["compliance"]
    if compliance["returncode"] != 0:
        entries.append(
            {
                "lane": "compliance",
                "returncode": compliance["returncode"],
                "failed_steps": [
                    {
                        "label": command_label(compliance),
                        "returncode": compliance["returncode"],
                        "signal": first_output_line(compliance),
                    }
                ],
            }
        )

    for target, steps in report["targets"].items():
        rc = target_returncode(steps)
        if rc == 0:
            continue
        failed_steps = [
            {
                "label": command_label(result),
                "returncode": result["returncode"],
                "signal": first_output_line(result),
            }
            for result in steps
            if result["returncode"] != 0
        ]
        entries.append(
            {
                "lane": target,
                "returncode": rc,
                "failed_steps": failed_steps,
            }
        )

    return entries


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

    failing_lanes = failing_lane_entries(report)
    if failing_lanes:
        lines.extend(
            [
                "",
                "## Focus failures",
                "",
                "| Lane | RC | Failed steps | First signal |",
                "| --- | --- | --- | --- |",
            ]
        )
        for lane in failing_lanes:
            failed_step_labels = ", ".join(
                f"`{step['label']}`" for step in lane["failed_steps"]
            ) or "-"
            first_signal = (
                markdown_signal(lane["failed_steps"][0]["signal"])
                if lane["failed_steps"]
                else "-"
            )
            lines.append(
                f"| {lane['lane']} | `{lane['returncode']}` | {failed_step_labels} | {first_signal or '-'} |"
            )

    artifact_rows = artifact_summary_rows(report)
    if artifact_rows:
        lines.extend(
            [
                "",
                "## Artifact summary",
                "",
                "| Lane | Evidence | Artifacts | Sample | Required | Missing | Drift |",
                "| --- | --- | --- | --- | --- | --- | --- |",
            ]
        )
        for row in artifact_rows:
            lines.append(
                f"| {row['lane']} | {row['status']} | `{len(row['artifacts'])}` | {artifact_summary_sample(row['artifacts'])} | {required_summary_cell(row['required_files'], row['status'])} | {missing_summary_cell(row['missing'])} | {drift_summary_cell(row['drift'])} |"
            )

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
            signal = markdown_signal(first_output_line(result))
            lines.append(
                f"| `{label}` | `{rc}` | `{command}` | {signal or '-'} |"
            )

    return "\n".join(lines) + "\n"


def write_markdown_report(report: dict) -> Path:
    MARKDOWN_REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    MARKDOWN_REPORT_PATH.write_text(render_markdown_summary(report), encoding="utf-8")
    return MARKDOWN_REPORT_PATH


def write_step_summary(report: dict) -> Path | None:
    summary_path = os.environ.get(STEP_SUMMARY_ENV, "").strip()
    if not summary_path:
        return None
    path = Path(summary_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(MARKDOWN_REPORT_PATH.read_text(encoding="utf-8"), encoding="utf-8")
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
    markdown_path = write_markdown_report(report)
    summary_path = write_step_summary(report)
    print("\n=== Rapport de vérification ===")
    print(f"compliance: rc={report['compliance']['returncode']}")
    for target, steps in report["targets"].items():
        rc = target_returncode(steps)
        print(f"{target}: rc={rc}")
    print(f"rapport: {REPORT_PATH}")
    print(f"rapport markdown: {markdown_path}")
    if summary_path is not None:
        print(f"step summary: {summary_path}")
    raise SystemExit(1 if failed else 0)
