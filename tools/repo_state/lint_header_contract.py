#!/usr/bin/env python3
"""Lint repo-state contract for local/global header generation."""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REQUIRED_MD_KEYS = [
    "Repo",
    "Branch",
    "HEAD",
    "HeadDate",
    "ProjectKind",
    "PivotChanges",
    "ImpactGates",
]
REQUIRED_JSON_KEYS = [
    "schema_version",
    "generated_at_utc",
    "repo",
    "repo_url",
    "branch",
    "head",
    "head_date",
    "head_subject",
    "project_kind",
    "pivot_changes",
    "impact_gates",
]
REQUIRED_REPOS = ["Kill_LIFE", "RTC_BL_PHONE", "le-mystere-professeur-zacus"]


def fail(msg: str) -> None:
    print(f"[fail] {msg}", file=sys.stderr)
    raise SystemExit(1)


def parse_kv_lines(path: Path) -> dict:
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0].strip() != "<!-- REPO_STATE:v1 -->":
        fail(f"missing REPO_STATE marker in {path}")

    data: dict[str, str] = {}
    for line in lines:
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        data[key.strip()] = value.strip()
    return data


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--header-file", default="artifacts/repo_state/header.latest.md")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    md_file = repo_root / "docs/REPO_STATE.md"
    json_file = repo_root / "docs/repo_state.json"
    refresh_script = repo_root / "tools/repo_state/repo_refresh.sh"
    collect_script = repo_root / "tools/repo_state/collect.py"
    header_file = (repo_root / args.header_file).resolve()

    for path in [md_file, json_file, refresh_script, collect_script, header_file]:
        if not path.exists():
            fail(f"missing required file: {path}")

    kv = parse_kv_lines(md_file)
    missing_md = [k for k in REQUIRED_MD_KEYS if k not in kv]
    if missing_md:
        fail(f"missing keys in {md_file}: {', '.join(missing_md)}")

    try:
        json.loads(kv["PivotChanges"])
    except json.JSONDecodeError as exc:
        fail(f"invalid PivotChanges JSON in {md_file}: {exc}")

    state = json.loads(json_file.read_text(encoding="utf-8"))
    missing_json = [k for k in REQUIRED_JSON_KEYS if k not in state]
    if missing_json:
        fail(f"missing keys in {json_file}: {', '.join(missing_json)}")

    header_text = header_file.read_text(encoding="utf-8")
    if "[REPO-STATE UTC:" not in header_text or "[/REPO-STATE]" not in header_text:
        fail(f"invalid header markers in {header_file}")

    for repo in REQUIRED_REPOS:
        pattern = re.compile(rf"^{re.escape(repo)}\s+\| HEAD [0-9a-f]{{7,40}} \| pivots: .+ \| gates: .+$", re.MULTILINE)
        if not pattern.search(header_text):
            fail(f"missing repo line in header for {repo}")

    print("[ok] repo-state header contract is valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
