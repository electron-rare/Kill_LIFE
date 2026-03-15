from __future__ import annotations

import fnmatch
import re

DENY_GLOBS = [
    ".git/**",
    ".github/workflows/**",
    ".github/actions/**",
    "**/.env",
    "**/*.key",
    "**/*secret*",
    "**/*token*",
]

ALLOWED_BY_SCOPE = {
    "ai:spec": [
        "specs/**",
        "docs/**",
        "README.md",
        ".github/copilot-instructions.md",
        ".github/copilot/**",
        ".github/prompts/**",
    ],
    "ai:plan": [
        "specs/**",
        "docs/**",
        "README.md",
    ],
    "ai:tasks": [
        "specs/**",
        "docs/**",
    ],
    "ai:docs": [
        "docs/**",
        "README.md",
        ".github/copilot-instructions.md",
        ".github/copilot/**",
        ".github/prompts/**",
    ],
    "ai:impl": [
        "firmware/**",
        "docs/**",
        "specs/**",
        "tools/**",
    ],
    "ai:qa": [
        "firmware/**",
        "tools/**",
        "docs/**",
        "specs/**",
    ],
}

WINDOWS_DRIVE_RE = re.compile(r"^[A-Za-z]:/")


def normalize_path(path: str) -> str:
    path = path.replace("\\", "/").strip()
    while path.startswith("./"):
        path = path[2:]
    return path


def has_safe_segments(path: str) -> bool:
    if not path or path.startswith("/") or WINDOWS_DRIVE_RE.match(path):
        return False
    return all(part not in ("", ".", "..") for part in path.split("/"))


def matches_any(path: str, patterns: list[str]) -> bool:
    return any(fnmatch.fnmatch(path, pattern) for pattern in patterns)


def is_path_allowed(scope: str, path: str) -> bool:
    path = normalize_path(path)
    if not has_safe_segments(path) or matches_any(path, DENY_GLOBS):
        return False
    allow = ALLOWED_BY_SCOPE.get(scope)
    if not allow:
        return False
    return matches_any(path, allow)


def explain_scope(scope: str) -> str:
    allow = ALLOWED_BY_SCOPE.get(scope, [])
    return f"{scope} allows: " + ", ".join(allow)
