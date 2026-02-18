#!/usr/bin/env python3
"""
Scope guard for AI‑driven pull requests.

This script ensures that files modified in a pull request conform to the
repository's label‑based allowlist and denylist policy. It is intended to
be run in CI to prevent agents (or humans) from modifying files outside
their allocated scope.

Usage: python3 tools/scope_guard.py

Environment variables:
  GITHUB_EVENT_PATH: path to the GitHub event JSON for PR events. Used to
    extract labels attached to the pull request.
  DEFAULT_AI_LABEL: fallback label (default: "ai:impl") if no ai:* label
    is present on the PR.

The script reads the list of changed files from `git diff --name-only` and
compares them against the allowlist for the detected label. If any file
falls outside the allowlist or matches the denylist, the script reports an
error and exits with status 1. Otherwise it prints a success message and
exits with status 0.
"""

import json
import os
import subprocess
import sys
from typing import List


# Mapping of ai:* labels to allowed directory prefixes. The keys should
# correspond exactly to the labels used in your workflow. These prefixes are
# relative to the repository root. If a file's path starts with any of
# these prefixes or matches exactly, it is considered allowed.
ALLOWLIST = {
    "ai:spec": ["specs/", "docs/", "README.md"],
    "ai:plan": ["specs/", "docs/", "README.md"],
    "ai:tasks": ["specs/features/", "docs/", "README.md"],
    "ai:impl": ["firmware/", "tools/", "docs/auto_generated/", "README.md"],
    "ai:qa": ["firmware/test/", "tools/gates/", "docs/", "README.md"],
    "ai:docs": ["docs/", "README.md", "specs/"],
}

# Files or directories that must never be modified by AI automations. If a
# modified file starts with any of these patterns, the guard fails.
DENYLIST = [
    ".github/workflows/",  # workflows are controlled manually
    "openclaw/",            # openclaw configuration is managed separately
    "tools/ai/sanitize_issue.py",  # sanitation logic is security‑sensitive
    "tools/scope_guard.py",        # this script itself
]

def get_labels_from_event() -> List[str]:
    """Return a list of label names from the GitHub event JSON, if present."""
    event_path = os.environ.get("GITHUB_EVENT_PATH")
    if not event_path or not os.path.exists(event_path):
        return []
    try:
        with open(event_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        labels = []
        # Pull request event
        if "pull_request" in data:
            labels = [lbl.get("name", "") for lbl in data["pull_request"].get("labels", [])]
        elif "issue" in data:
            labels = [lbl.get("name", "") for lbl in data["issue"].get("labels", [])]
        return labels
    except Exception:
        return []


def detect_label() -> str:
    """
    Determine which ai:* label applies to the current change set. The first
    ai:* label found on the pull request is used. If none exists, the value
    of the DEFAULT_AI_LABEL environment variable is used (default 'ai:impl').
    """
    labels = get_labels_from_event()
    for lbl in labels:
        if lbl.startswith("ai:"):
            return lbl
    return os.environ.get("DEFAULT_AI_LABEL", "ai:impl")


def get_changed_files() -> List[str]:
    """
    Return a list of files changed relative to the default branch. This uses
    `git diff --name-only` against `origin/main` if available, otherwise
    compares against the previous commit. When run in GitHub Actions with
    fetch‑depth=0, `origin/main` will exist.
    """
    try:
        # Try diffing against origin/main
        result = subprocess.run([
            "git", "diff", "--name-only", "origin/main"
        ], capture_output=True, text=True, check=True)
        files = result.stdout.strip().splitlines()
        if files:
            return files
    except Exception:
        pass
    # Fallback to previous commit
    result = subprocess.run([
        "git", "diff", "--name-only", "HEAD~1"
    ], capture_output=True, text=True, check=True)
    return result.stdout.strip().splitlines()


def is_allowed(file_path: str, label: str) -> bool:
    """Check if a file_path is allowed for the given label."""
    # Denylist check first
    for deny in DENYLIST:
        if file_path.startswith(deny):
            return False
    allowed_prefixes = ALLOWLIST.get(label)
    if not allowed_prefixes:
        # Unknown label uses the default 'ai:impl'
        allowed_prefixes = ALLOWLIST.get("ai:impl", [])
    for prefix in allowed_prefixes:
        if file_path == prefix or file_path.startswith(prefix):
            return True
    return False


def main() -> int:
    label = detect_label()
    changed_files = get_changed_files()
    if not changed_files:
        print(f"No changed files detected. Scope guard passes by default for label {label}.")
        return 0
    disallowed = []
    for file in changed_files:
        if not is_allowed(file, label):
            disallowed.append(file)
    if disallowed:
        print("Error: the following files are outside the allowed scope for label '", label, "':", sep="")
        for f in disallowed:
            print(f"  - {f}")
        print("See tools/scope_guard.py for the policy details.")
        return 1
    print(f"Scope guard passed. Label '{label}' allows changes to: {', '.join(ALLOWLIST.get(label, []))}")
    return 0


if __name__ == "__main__":
    sys.exit(main())