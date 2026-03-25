#!/usr/bin/env python3
"""Generate a CHANGELOG section from git history.

Usage:
    python3 tools/ci/generate_changelog.py --version v1.2.0
    python3 tools/ci/generate_changelog.py --version v1.2.0 --output CHANGELOG_DRAFT.md
    python3 tools/ci/generate_changelog.py --version v1.2.0 --full  # prepend to CHANGELOG.md

Features:
- Groups commits by conventional-commit prefix (feat, fix, chore, etc.)
- Lists acceptance criteria (AC) references found in commit messages
- Flags breaking changes
- Outputs Markdown
"""

import argparse
import re
import subprocess
import sys
from collections import defaultdict
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

CATEGORIES = {
    "feat": "Features",
    "fix": "Bug Fixes",
    "perf": "Performance",
    "refactor": "Refactoring",
    "test": "Tests",
    "docs": "Documentation",
    "chore": "Chores",
    "ci": "CI/CD",
    "build": "Build",
    "style": "Style",
}

CC_RE = re.compile(r"^(\w+)(?:\(([^)]*)\))?(!)?:\s*(.*)")
AC_RE = re.compile(r"AC[-_]?\d+|acceptance.criteria", re.IGNORECASE)
BREAKING_RE = re.compile(r"BREAKING[ _-]?CHANGE", re.IGNORECASE)


def git_log(range_spec):
    """Return list of (hash, subject) tuples."""
    cmd = ["git", "log", range_spec, "--pretty=format:%h|||%s", "--no-merges"]
    p = subprocess.run(cmd, text=True, capture_output=True, cwd=str(ROOT))
    if p.returncode != 0:
        return []
    lines = [l.strip() for l in p.stdout.strip().split("\n") if l.strip()]
    results = []
    for line in lines:
        parts = line.split("|||", 1)
        if len(parts) == 2:
            results.append((parts[0], parts[1]))
    return results


def find_prev_tag():
    p = subprocess.run(
        ["git", "describe", "--tags", "--abbrev=0"],
        text=True, capture_output=True, cwd=str(ROOT)
    )
    return p.stdout.strip() if p.returncode == 0 else None


def generate(version, commits):
    """Generate changelog markdown."""
    grouped = defaultdict(list)
    breaking = []
    ac_refs = set()

    for sha, subject in commits:
        m = CC_RE.match(subject)
        if m:
            prefix, scope, bang, desc = m.groups()
            cat = CATEGORIES.get(prefix, "Other")
            scope_str = f"**{scope}:** " if scope else ""
            grouped[cat].append(f"- {scope_str}{desc} ({sha})")
            if bang or BREAKING_RE.search(subject):
                breaking.append(f"- {subject} ({sha})")
        else:
            grouped["Other"].append(f"- {subject} ({sha})")

        if AC_RE.search(subject):
            ac_refs.add(subject)

    lines = [f"## {version} ({date.today().isoformat()})", ""]

    if breaking:
        lines += ["### BREAKING CHANGES", ""]
        lines += breaking
        lines += [""]

    for cat in list(CATEGORIES.values()) + ["Other"]:
        if cat in grouped:
            lines += [f"### {cat}", ""]
            lines += grouped[cat]
            lines += [""]

    if ac_refs:
        lines += ["### Acceptance Criteria Referenced", ""]
        for ref in sorted(ac_refs):
            lines += [f"- {ref}"]
        lines += [""]

    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser(description="Generate CHANGELOG from git history.")
    ap.add_argument("--version", required=True, help="Version tag (e.g. v1.2.0)")
    ap.add_argument("--output", default=None, help="Output file (default: stdout)")
    ap.add_argument("--full", action="store_true",
                    help="Prepend to CHANGELOG.md instead of standalone output")
    args = ap.parse_args()

    prev_tag = find_prev_tag()
    range_spec = f"{prev_tag}..HEAD" if prev_tag else "HEAD~50..HEAD"

    commits = git_log(range_spec)
    if not commits:
        print("No commits found in range.", file=sys.stderr)
        return 1

    md = generate(args.version, commits)

    if args.full:
        changelog = ROOT / "CHANGELOG.md"
        existing = changelog.read_text(encoding="utf-8") if changelog.exists() else ""
        # Insert after the first heading or at top
        if existing.startswith("# "):
            first_nl = existing.index("\n") + 1
            new_content = existing[:first_nl] + "\n" + md + "\n" + existing[first_nl:]
        else:
            new_content = f"# Changelog\n\n{md}\n{existing}"
        changelog.write_text(new_content, encoding="utf-8")
        print(f"Prepended to {changelog}")
    elif args.output:
        Path(args.output).write_text(md, encoding="utf-8")
        print(f"Written to {args.output}")
    else:
        print(md)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
