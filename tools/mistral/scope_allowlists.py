"""
Local scope allowlists for applying patches safely.

This is NOT a replacement for CI scope guards; it is a local "pre-flight" safety net.
"""
from __future__ import annotations

from tools.scope_policy import explain_scope, is_path_allowed
