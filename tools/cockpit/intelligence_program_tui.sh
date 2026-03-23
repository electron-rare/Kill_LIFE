#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Compatibility wrapper kept for historical runbooks and aliases.
exec bash "${SCRIPT_DIR}/intelligence_tui.sh" "$@"
