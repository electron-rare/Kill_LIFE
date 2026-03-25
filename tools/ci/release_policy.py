#!/usr/bin/env python3
"""Release policy documentation and enforcement for Kill_LIFE.

Usage:
    python3 tools/ci/release_policy.py --show           # Print policy
    python3 tools/ci/release_policy.py --check          # Verify current state
    python3 tools/ci/release_policy.py --check --strict  # Exit non-zero on violations

This script documents and enforces:
  - Backport policy
  - Hotfix process
  - Version naming conventions
  - Release branch rules
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

POLICY = """
# Kill_LIFE Release & Versioning Policy

## Version Scheme

| Component | Format            | Example  |
|-----------|-------------------|----------|
| Firmware  | SemVer vX.Y.Z     | v1.2.3   |
| Hardware  | HW-V{n}r{rev}     | HW-V1r2  |
| Specs     | Internal rev / tag | rev-5    |

## Branching Model

- `main`            : latest stable, always green CI
- `release/vX.Y.Z`  : release candidate, bugfix-only
- `hotfix/vX.Y.Z`   : emergency fix from a tagged release

## Backport Policy

Backports are applied to the **most recent release branch only**.

1. Fix the issue on `main` first.
2. Cherry-pick to the active `release/vX.Y.Z` branch.
3. If the release is already tagged, create a `hotfix/vX.Y.(Z+1)` branch.
4. Backports to older releases require explicit maintainer approval.

Eligible for backport:
- Security fixes          : ALWAYS
- Data-loss bugs          : ALWAYS
- CI/build regressions    : CASE-BY-CASE
- New features            : NEVER

## Hotfix Process

1. Branch from the release tag:
     git checkout -b hotfix/vX.Y.(Z+1) vX.Y.Z
2. Apply minimal fix (no feature work).
3. Run full test suite:
     bash tools/test_python.sh --suite stable
4. Generate changelog:
     python3 tools/ci/generate_changelog.py --version vX.Y.(Z+1)
5. Tag and push:
     git tag -a vX.Y.(Z+1) -m "Hotfix release"
     git push origin vX.Y.(Z+1)
6. Cherry-pick the fix back to `main`.

## Release Checklist

- [ ] All CI checks green
- [ ] Evidence pack generated
- [ ] CHANGELOG.md updated
- [ ] Tag created (signed if possible)
- [ ] Release notes include AC references and breaking changes
- [ ] Firmware binaries attached to GitHub release
"""


def show_policy():
    print(POLICY.strip())


def check_policy(strict=False):
    """Check current repo state against policy rules."""
    issues = []
    warnings = []

    # Check: are we on a valid branch?
    p = subprocess.run(
        ["git", "branch", "--show-current"],
        text=True, capture_output=True, cwd=str(ROOT)
    )
    branch = p.stdout.strip()
    valid_prefixes = ("main", "release/", "hotfix/", "feat/", "fix/", "chore/", "ci/")
    if branch and not any(branch.startswith(pfx) or branch == pfx.rstrip("/") for pfx in valid_prefixes):
        warnings.append(f"Branch '{branch}' does not follow naming convention.")

    # Check: do we have any tags?
    p = subprocess.run(
        ["git", "tag", "-l", "v*"],
        text=True, capture_output=True, cwd=str(ROOT)
    )
    tags = [t.strip() for t in p.stdout.strip().split("\n") if t.strip()]
    if not tags:
        warnings.append("No version tags found (v*). Consider tagging a release.")
    else:
        # Validate tag format
        for tag in tags:
            if not re.match(r"^v\d+\.\d+\.\d+$", tag):
                warnings.append(f"Tag '{tag}' does not match SemVer vX.Y.Z format.")

    # Check: is CHANGELOG.md present?
    changelog = ROOT / "CHANGELOG.md"
    if not changelog.exists():
        warnings.append("CHANGELOG.md not found at repo root.")

    # Check: dirty working tree on release branch
    if branch and branch.startswith("release/"):
        p = subprocess.run(
            ["git", "status", "--porcelain"],
            text=True, capture_output=True, cwd=str(ROOT)
        )
        if p.stdout.strip():
            issues.append(f"Dirty working tree on release branch '{branch}'.")

    # Report
    print("=== Release Policy Check ===\n")
    print(f"Branch: {branch or '(detached)'}")
    print(f"Tags:   {len(tags)} version tag(s)")
    print("")

    if issues:
        print("ISSUES:")
        for i in issues:
            print(f"  [ERROR] {i}")
        print("")

    if warnings:
        print("WARNINGS:")
        for w in warnings:
            print(f"  [WARN] {w}")
        print("")

    if not issues and not warnings:
        print("All checks passed.")

    if strict and issues:
        return 1
    return 0


def main():
    ap = argparse.ArgumentParser(description="Kill_LIFE release policy.")
    ap.add_argument("--show", action="store_true", help="Print release policy.")
    ap.add_argument("--check", action="store_true", help="Check repo against policy.")
    ap.add_argument("--strict", action="store_true", help="Exit non-zero on violations.")
    args = ap.parse_args()

    if args.show or (not args.check):
        show_policy()
        return 0

    if args.check:
        return check_policy(strict=args.strict)


if __name__ == "__main__":
    raise SystemExit(main())
