#!/usr/bin/env bash
# gate_scope.sh – Run the Python scope guard in CI

set -euo pipefail

# Expose a default label fallback if none is provided (can be overridden in the environment)
export DEFAULT_AI_LABEL="${DEFAULT_AI_LABEL:-ai:impl}"

# Run the guard script
python3 "$(dirname "$0")/../scope_guard.py"