"""
Local scope allowlists for applying patches safely.

This is NOT a replacement for CI scope guards; it is a local "pre-flight" safety net.
"""
from __future__ import annotations

import fnmatch
from typing import List


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

def _matches_any(path: str, globs: List[str]) -> bool:
    return any(fnmatch.fnmatch(path, g) for g in globs)

def is_path_allowed(scope: str, path: str) -> bool:
    path = path.replace("\\", "/").lstrip("/")
    if _matches_any(path, DENY_GLOBS):
        return False
    allow = ALLOWED_BY_SCOPE.get(scope)
    if not allow:
        return False
    return _matches_any(path, allow)

def explain_scope(scope: str) -> str:
    allow = ALLOWED_BY_SCOPE.get(scope, [])
    return f"{scope} allows: " + ", ".join(allow)
