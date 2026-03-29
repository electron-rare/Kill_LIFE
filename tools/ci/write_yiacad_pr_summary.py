#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path


YIACAD_PR_SUMMARY_MARKER = "<!-- yiacad-pr-summary -->"
DOC_EXTENSIONS = {".md", ".mdx", ".txt", ".rst"}
CAD_EXTENSIONS = {
    ".kicad_pcb",
    ".kicad_sch",
    ".kicad_pro",
    ".fcstd",
    ".step",
    ".stp",
    ".wrl",
    ".kibot.yaml",
    ".kibot.yml",
}
TRACKED_EVIDENCE_WORKFLOWS = {
    "YiACAD Product",
    "KiCad Exports",
    "Evidence Pack Validation",
}
PASSING_STATUSES = {"success", "passed", "pass", "neutral", "skipped", "done"}
RUNNING_STATUSES = {"queued", "requested", "waiting", "pending", "in_progress", "running"}
FAILING_STATUSES = {"failure", "failed", "cancelled", "timed_out", "action_required", "error"}


@dataclass(frozen=True)
class CheckRecord:
    name: str
    status: str
    summary: str
    details_url: str | None


@dataclass(frozen=True)
class EvidenceRecord:
    workflow: str
    status: str
    summary: str
    details_url: str | None


@dataclass(frozen=True)
class DiffProfile:
    scope: str
    touches_docs: bool
    touches_cad: bool
    touches_web: bool
    touches_runtime: bool


@dataclass(frozen=True)
class Assessment:
    risk_level: str
    merge_recommendation: str
    rationale: list[str]
    next_steps: list[str]


def string_value(value: object) -> str | None:
    if isinstance(value, str):
        stripped = value.strip()
        return stripped or None
    return None


def changed_file_extension(file_path: str) -> str | None:
    lower = file_path.lower()
    for extension in CAD_EXTENSIONS:
        if lower.endswith(extension):
            return extension

    suffix = Path(lower).suffix
    return suffix or None


def classify_pull_request_diff(changed_files: list[str]) -> DiffProfile:
    lowered = [file_path.lower() for file_path in changed_files]

    touches_docs = any(
        file_path.startswith("docs/")
        or file_path.startswith("specs/")
        or file_path == "readme.md"
        or (changed_file_extension(file_path) in DOC_EXTENSIONS)
        for file_path in lowered
    )
    touches_cad = any(
        file_path.startswith("hardware/")
        or file_path.startswith("tools/cad/")
        or file_path.startswith("tools/hw/")
        or (changed_file_extension(file_path) in CAD_EXTENSIONS)
        for file_path in lowered
    )
    touches_web = any(file_path.startswith("web/") for file_path in lowered)
    touches_runtime = any(
        file_path.startswith(".github/workflows/")
        or file_path.startswith("tools/ci/")
        or file_path.startswith("tools/cockpit/")
        for file_path in lowered
    )
    active_dimensions = sum((touches_docs, touches_cad, touches_web, touches_runtime))

    if active_dimensions == 0:
        scope = "local-only"
    elif touches_docs and not touches_cad and not touches_web and not touches_runtime:
        scope = "docs-only"
    elif touches_cad and not touches_web and not touches_runtime:
        scope = "cad"
    elif touches_web and not touches_cad and not touches_runtime:
        scope = "web"
    elif touches_runtime and not touches_cad and not touches_web:
        scope = "runtime"
    else:
        scope = "mixed"

    return DiffProfile(
        scope=scope,
        touches_docs=touches_docs,
        touches_cad=touches_cad,
        touches_web=touches_web,
        touches_runtime=touches_runtime,
    )


def normalize_check_status(status: str | None, conclusion: str | None) -> str:
    if (status or "").lower() == "completed":
        return (conclusion or "completed").lower()
    return (status or "queued").lower()


def summarize_check_run(check_run: dict[str, object]) -> str:
    output = check_run.get("output")
    output_dict = output if isinstance(output, dict) else {}
    title = string_value(output_dict.get("title"))
    summary = string_value(output_dict.get("summary"))
    if title:
        return title
    if summary:
        return summary
    return f"{string_value(check_run.get('name')) or 'GitHub check'} {normalize_check_status(string_value(check_run.get('status')), string_value(check_run.get('conclusion')))}"


def load_check_records(path: Path) -> list[CheckRecord]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    records: list[CheckRecord] = []
    for check_run in payload.get("check_runs", []):
        if not isinstance(check_run, dict):
            continue
        records.append(
            CheckRecord(
                name=string_value(check_run.get("name")) or "GitHub check",
                status=normalize_check_status(
                    string_value(check_run.get("status")),
                    string_value(check_run.get("conclusion")),
                ),
                summary=summarize_check_run(check_run),
                details_url=string_value(check_run.get("details_url")),
            )
        )
    return records


def load_evidence_records(path: Path, head_sha: str | None) -> list[EvidenceRecord]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    records: list[EvidenceRecord] = []
    for workflow_run in payload.get("workflow_runs", []):
        if not isinstance(workflow_run, dict):
            continue
        workflow_name = string_value(workflow_run.get("name"))
        if not workflow_name or workflow_name not in TRACKED_EVIDENCE_WORKFLOWS:
            continue
        run_head_sha = string_value(workflow_run.get("head_sha"))
        if head_sha and run_head_sha and run_head_sha != head_sha:
            continue
        status = normalize_check_status(
            string_value(workflow_run.get("status")),
            string_value(workflow_run.get("conclusion")),
        )
        summary = string_value(workflow_run.get("display_title")) or f"{workflow_name} {status}"
        records.append(
            EvidenceRecord(
                workflow=workflow_name,
                status=status,
                summary=summary,
                details_url=string_value(workflow_run.get("html_url")),
            )
        )
    return records


def load_changed_files(path: Path) -> list[str]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    records = payload if isinstance(payload, list) else []
    files: list[str] = []
    for item in records:
        if not isinstance(item, dict):
            continue
        filename = string_value(item.get("filename") or item.get("path"))
        if filename:
            files.append(filename)
    return files


def build_check_summary(checks: list[CheckRecord]) -> str:
    if not checks:
        return "No GitHub checks loaded."

    failed = sum(1 for check in checks if check.status in FAILING_STATUSES)
    running = sum(1 for check in checks if check.status in RUNNING_STATUSES)
    passed = sum(1 for check in checks if check.status in PASSING_STATUSES)
    parts: list[str] = []
    if failed:
        parts.append(f"{failed} failed")
    if running:
        parts.append(f"{running} running")
    if passed:
        parts.append(f"{passed} passed")
    return f"{' · '.join(parts)} GitHub checks" if parts else f"{len(checks)} GitHub checks tracked"


def assess_pull_request(
    profile: DiffProfile, checks: list[CheckRecord], evidence_records: list[EvidenceRecord]
) -> Assessment:
    failed_checks = sum(1 for check in checks if check.status in FAILING_STATUSES)
    running_checks = sum(1 for check in checks if check.status in RUNNING_STATUSES)
    successful_evidence = sum(1 for record in evidence_records if record.status in PASSING_STATUSES)
    rationale: list[str] = []
    next_steps: list[str] = []

    if failed_checks:
        rationale.append(f"{failed_checks} GitHub check(s) failed on the current PR head.")
        next_steps.append("Fix the failing GitHub checks before merge.")
        return Assessment("high", "blocking", rationale, next_steps)

    if running_checks:
        rationale.append(f"{running_checks} GitHub check(s) are still running.")
        next_steps.append("Wait for the remaining GitHub checks to complete.")
        return Assessment("medium", "caution", rationale, next_steps)

    if profile.scope == "docs-only":
        rationale.append("Diff scope is documentation-only.")
        rationale.append("No CAD or product runtime surface is touched.")
        next_steps.append("Do an editorial pass if the content needs final wording validation.")
        return Assessment("low", "favorable", rationale, next_steps)

    if profile.touches_cad:
        rationale.append("CAD-affecting files are part of this PR.")
        if successful_evidence == 0:
            rationale.append("No successful tracked evidence pack was found for the current PR head.")
            next_steps.append("Require a YiACAD/KiCad evidence pack before merge.")
            return Assessment("high", "blocking", rationale, next_steps)
        rationale.append(f"{successful_evidence} tracked evidence pack(s) succeeded on the current PR head.")
        next_steps.append("Perform a final human CAD review on generated outputs before merge.")
        return Assessment("medium", "favorable", rationale, next_steps)

    if profile.scope in {"web", "runtime", "mixed"}:
        rationale.append(f"Diff scope is `{profile.scope}`.")
        if not checks:
            rationale.append("No GitHub checks were loaded for the current PR head.")
            next_steps.append("Run or load the GitHub checks before merge.")
            return Assessment("medium", "caution", rationale, next_steps)
        rationale.append("GitHub checks are green on the current PR head.")
        if profile.touches_runtime and successful_evidence == 0:
            rationale.append("Runtime/CI files changed without a successful tracked evidence pack.")
            next_steps.append("Publish an evidence pack for the changed runtime/CI lane.")
            return Assessment("medium", "caution", rationale, next_steps)
        next_steps.append("Merge is acceptable if the owning surface review is complete.")
        return Assessment("medium", "favorable", rationale, next_steps)

    rationale.append("Diff classification stayed local-only.")
    next_steps.append("Confirm the GitHub diff reflects the intended scope.")
    return Assessment("medium", "caution", rationale, next_steps)


def build_markdown(
    *,
    pr_number: str,
    pr_title: str,
    pr_url: str | None,
    source_branch: str,
    target_branch: str,
    head_sha: str | None,
    changed_files: list[str],
    checks: list[CheckRecord],
    evidence_records: list[EvidenceRecord],
    profile: DiffProfile,
    assessment: Assessment,
) -> str:
    lines = [
        YIACAD_PR_SUMMARY_MARKER,
        "",
        "## YiACAD PR Summary",
        "",
        f"- PR: #{pr_number} {pr_title}",
        f"- Branch: `{source_branch}` -> `{target_branch}`",
        f"- Status: `{'passed' if assessment.merge_recommendation != 'blocking' else 'failed'}`",
        f"- Change scope: `{profile.scope}`",
        f"- Risk level: `{assessment.risk_level}`",
        f"- Merge recommendation: `{assessment.merge_recommendation}`",
        f"- Checks: {build_check_summary(checks)}",
        f"- Evidence packs: {len(evidence_records)}",
        f"- Changed files: {len(changed_files)}",
    ]
    if head_sha:
        lines.append(f"- Head SHA: `{head_sha[:8]}`")
    if pr_url:
        lines.append(f"- PR URL: {pr_url}")
    lines.append("")

    if assessment.rationale:
        lines.extend(["### Assessment", ""])
        lines.extend(f"- {item}" for item in assessment.rationale)
        lines.append("")

    if checks:
        lines.extend(["### GitHub Checks", ""])
        lines.extend(f"- `{check.status}` {check.name}" for check in checks[:12])
        lines.append("")

    if evidence_records:
        lines.extend(["### Evidence Packs", ""])
        for record in evidence_records[:6]:
            suffix = f" ([run]({record.details_url}))" if record.details_url else ""
            lines.append(f"- `{record.status}` {record.workflow}: {record.summary}{suffix}")
        lines.append("")

    if changed_files:
        lines.extend(["### Changed Files", ""])
        lines.extend(f"- `{file_path}`" for file_path in changed_files[:12])
        lines.append("")

    if assessment.next_steps:
        lines.extend(["### Next Steps", ""])
        lines.extend(f"- {step}" for step in assessment.next_steps)
        lines.append("")

    lines.append(
        "_Generated by YiACAD review lane from GitHub checks and tracked workflow evidence._"
    )
    return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Write a normalized YiACAD PR summary JSON and Markdown bundle.")
    parser.add_argument("--output-json", required=True)
    parser.add_argument("--output-md", required=True)
    parser.add_argument("--pr-number", required=True)
    parser.add_argument("--pr-title", required=True)
    parser.add_argument("--pr-url", default=None)
    parser.add_argument("--source-branch", required=True)
    parser.add_argument("--target-branch", required=True)
    parser.add_argument("--head-sha", default=None)
    parser.add_argument("--checks-json", required=True)
    parser.add_argument("--workflow-runs-json", required=True)
    parser.add_argument("--changed-files-json", required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    output_json = Path(args.output_json)
    output_md = Path(args.output_md)
    output_json.parent.mkdir(parents=True, exist_ok=True)
    output_md.parent.mkdir(parents=True, exist_ok=True)

    checks = load_check_records(Path(args.checks_json))
    evidence_records = load_evidence_records(Path(args.workflow_runs_json), args.head_sha)
    changed_files = load_changed_files(Path(args.changed_files_json))
    profile = classify_pull_request_diff(changed_files)
    assessment = assess_pull_request(profile, checks, evidence_records)
    markdown = build_markdown(
        pr_number=args.pr_number,
        pr_title=args.pr_title,
        pr_url=args.pr_url,
        source_branch=args.source_branch,
        target_branch=args.target_branch,
        head_sha=args.head_sha,
        changed_files=changed_files,
        checks=checks,
        evidence_records=evidence_records,
        profile=profile,
        assessment=assessment,
    )
    payload = {
        "pull_request": {
            "number": args.pr_number,
            "title": args.pr_title,
            "url": args.pr_url,
            "source_branch": args.source_branch,
            "target_branch": args.target_branch,
            "head_sha": args.head_sha,
        },
        "change_scope": profile.scope,
        "risk_level": assessment.risk_level,
        "merge_recommendation": assessment.merge_recommendation,
        "check_summary": build_check_summary(checks),
        "changed_files": changed_files,
        "checks": [check.__dict__ for check in checks],
        "evidence_packs": [record.__dict__ for record in evidence_records],
        "rationale": assessment.rationale,
        "next_steps": assessment.next_steps,
    }
    output_json.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    output_md.write_text(markdown + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
