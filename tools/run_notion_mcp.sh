#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MASCARADE_DIR="${MASCARADE_DIR:-$ROOT_DIR/../mascarade}"
CORE_PYTHON="${MASCARADE_CORE_PYTHON:-$MASCARADE_DIR/core/.venv/bin/python}"
SERVER_SCRIPT="$ROOT_DIR/tools/notion_mcp.py"

if [[ "${1:-}" == "--doctor" ]]; then
  cat <<EOF
ROOT_DIR=$ROOT_DIR
MASCARADE_DIR=$MASCARADE_DIR
CORE_PYTHON=$CORE_PYTHON
SERVER_SCRIPT=$SERVER_SCRIPT
EOF
  exit 0
fi

[[ -x "$CORE_PYTHON" ]] || {
  echo "Missing Mascarade core python: $CORE_PYTHON" >&2
  exit 1
}

exec "$CORE_PYTHON" "$SERVER_SCRIPT" "$@"
