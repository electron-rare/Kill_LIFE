#!/usr/bin/env python3
"""Generate repo state files (Markdown + JSON) for one repository."""
from __future__ import annotations

import argparse
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Set


REQUIRED_SCHEMA_VERSION = "repo_state.v1"


def run_git(repo_root: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", *args],
        cwd=repo_root,
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def detect_project_kind(repo_root: Path) -> str:
    if (repo_root / "tools" / "ai").exists() and (repo_root / "zeroclaw").exists():
        return "agentic_orchestrator"
    if (repo_root / "platformio.ini").exists():
        return "firmware_embedded"
    if (repo_root / "hardware" / "firmware" / "platformio.ini").exists():
        return "hardware_firmware_hybrid"
    if (repo_root / "kit-maitre-du-jeu").exists():
        return "narrative_hardware_hybrid"
    return "general"


def gates_for_path(path: str) -> Set[str]:
    p = path.strip().lstrip("./")
    gates: Set[str] = set()

    if p.startswith("tools/ai/") or p.startswith("tools/repo_state/") or p.startswith("zeroclaw/"):
        gates.add("agentic_orchestration")
    if p.startswith(".github/workflows/"):
        gates.add("ci_integrity")
    if (
        p == "platformio.ini"
        or p.startswith("firmware/")
        or p.startswith("src/")
        or p.startswith("hardware/firmware/")
    ):
        gates.add("firmware_build_test")
    if p.startswith("hardware/"):
        gates.add("hardware_validation")
    if p == "README.md" or p.startswith("docs/") or p.startswith("specs/"):
        gates.add("docs_specs_sync")
    if p.startswith("compliance/") or p.startswith("security/") or p.startswith("standards/"):
        gates.add("compliance_security")

    if not gates:
        gates.add("general_change")

    return gates


def get_changed_paths(repo_root: Path, limit: int = 5) -> List[str]:
    raw = run_git(repo_root, "show", "--name-only", "--pretty=format:", "HEAD")
    paths = [line.strip() for line in raw.splitlines() if line.strip()]
    return paths[:limit]


def build_state(repo_root: Path, repo_name_override: str | None) -> Dict[str, object]:
    repo_name = repo_name_override or repo_root.name

    head = run_git(repo_root, "rev-parse", "HEAD")
    branch = run_git(repo_root, "rev-parse", "--abbrev-ref", "HEAD")
    head_date = run_git(repo_root, "show", "-s", "--format=%cI", "HEAD")
    head_subject = run_git(repo_root, "show", "-s", "--format=%s", "HEAD")

    try:
        repo_url = run_git(repo_root, "config", "--get", "remote.origin.url")
    except subprocess.CalledProcessError:
        repo_url = ""

    changed_paths = get_changed_paths(repo_root)
    pivot_changes: List[Dict[str, object]] = []
    all_gates: Set[str] = set()

    for path in changed_paths:
        gates = sorted(gates_for_path(path))
        pivot_changes.append({"path": path, "tags": gates})
        all_gates.update(gates)

    if not pivot_changes:
        pivot_changes = [{"path": "(none)", "tags": ["general_change"]}]
        all_gates.add("general_change")

    generated_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")

    return {
        "schema_version": REQUIRED_SCHEMA_VERSION,
        "generated_at_utc": generated_at,
        "repo": repo_name,
        "repo_url": repo_url,
        "branch": branch,
        "head": head,
        "head_date": head_date,
        "head_subject": head_subject,
        "project_kind": detect_project_kind(repo_root),
        "pivot_changes": pivot_changes,
        "impact_gates": sorted(all_gates),
    }


def write_outputs(state: Dict[str, object], out_md: Path, out_json: Path) -> None:
    out_md.parent.mkdir(parents=True, exist_ok=True)
    out_json.parent.mkdir(parents=True, exist_ok=True)

    pivot_changes_inline = json.dumps(state["pivot_changes"], ensure_ascii=False)
    impact_gates_inline = ", ".join(state["impact_gates"])

    md_content = "\n".join(
        [
            "<!-- REPO_STATE:v1 -->",
            f"Repo: {state['repo']}",
            f"Branch: {state['branch']}",
            f"HEAD: {state['head']}",
            f"HeadDate: {state['head_date']}",
            f"HeadSubject: {state['head_subject']}",
            f"RepoURL: {state['repo_url']}",
            f"ProjectKind: {state['project_kind']}",
            f"PivotChanges: {pivot_changes_inline}",
            f"ImpactGates: {impact_gates_inline}",
            f"GeneratedAtUTC: {state['generated_at_utc']}",
            "",
        ]
    )
    out_md.write_text(md_content, encoding="utf-8")
    out_json.write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate docs/REPO_STATE.md and docs/repo_state.json")
    parser.add_argument("--repo-name", default=None, help="Override repo name")
    parser.add_argument("--repo-root", default=".", help="Path to the git repository root (default: .)")
    parser.add_argument("--out-md", default="docs/REPO_STATE.md", help="Output markdown path")
    parser.add_argument("--out-json", default="docs/repo_state.json", help="Output json path")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    if not (repo_root / ".git").exists():
        raise SystemExit(f"[fail] not a git repository: {repo_root}")

    state = build_state(repo_root, args.repo_name)
    out_md = (repo_root / args.out_md).resolve()
    out_json = (repo_root / args.out_json).resolve()
    write_outputs(state, out_md, out_json)

    print(f"[ok] generated {out_md}")
    print(f"[ok] generated {out_json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
