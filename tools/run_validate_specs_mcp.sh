#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER_SCRIPT="$ROOT_DIR/tools/validate_specs.py"
VENV_DIR="${KILL_LIFE_VENV_DIR:-$ROOT_DIR/.venv}"

detect_python() {
  local candidate="${KILL_LIFE_PYTHON:-}"
  if [[ -n "$candidate" && -x "$candidate" ]]; then
    printf '%s' "$candidate"
    return 0
  fi

  candidate="$VENV_DIR/bin/python"
  if [[ -x "$candidate" ]]; then
    printf '%s' "$candidate"
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    if python3 -c 'import yaml' >/dev/null 2>&1; then
      printf '%s' "$(command -v python3)"
      return 0
    fi
  fi

  return 1
}

PYTHON_BIN="$(detect_python || true)"

if [[ "${1:-}" == "--doctor" ]]; then
  cat <<EOF
ROOT_DIR=$ROOT_DIR
SERVER_SCRIPT=$SERVER_SCRIPT
VENV_DIR=$VENV_DIR
PYTHON_BIN=$PYTHON_BIN
EOF
  exit 0
fi

[[ -n "$PYTHON_BIN" && -x "$PYTHON_BIN" ]] || {
  echo "Missing validate-specs python runtime. Expected $VENV_DIR/bin/python or a python3 with PyYAML." >&2
  exit 1
}

if [[ "$#" -eq 0 ]]; then
  exec "$PYTHON_BIN" "$SERVER_SCRIPT" --mcp
fi

exec "$PYTHON_BIN" "$SERVER_SCRIPT" "$@"
