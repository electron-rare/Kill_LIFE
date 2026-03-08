#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MASCARADE_DIR="${MASCARADE_DIR:-$ROOT_DIR/../mascarade}"
MASCARADE_ENV_FILE="${MASCARADE_ENV_FILE:-$MASCARADE_DIR/.env}"
SERVER_SCRIPT="$ROOT_DIR/tools/knowledge_base_mcp.py"
source "$ROOT_DIR/tools/lib/runtime_home.sh"
kill_life_runtime_home_init "$ROOT_DIR" "knowledge-base-mcp"

load_mascarade_env() {
  [[ -r "$MASCARADE_ENV_FILE" ]] || return 0
  set -a
  # shellcheck disable=SC1090
  source "$MASCARADE_ENV_FILE"
  set +a
}

detect_core_python() {
  local candidate="${MASCARADE_CORE_PYTHON:-}"
  if [[ -n "$candidate" && -x "$candidate" ]]; then
    printf '%s' "$candidate"
    return 0
  fi

  candidate="$MASCARADE_DIR/core/.venv/bin/python"
  if [[ -x "$candidate" ]]; then
    printf '%s' "$candidate"
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    if PYTHONPATH="$MASCARADE_DIR/core${PYTHONPATH:+:$PYTHONPATH}" python3 -c 'import mascarade' >/dev/null 2>&1; then
      printf '%s' "$(command -v python3)"
      return 0
    fi
  fi

  return 1
}

CORE_PYTHON="$(detect_core_python || true)"
load_mascarade_env

if [[ "${1:-}" == "--doctor" ]]; then
  cat <<EOF
ROOT_DIR=$ROOT_DIR
MASCARADE_DIR=$MASCARADE_DIR
MASCARADE_ENV_FILE=$MASCARADE_ENV_FILE
CORE_PYTHON=$CORE_PYTHON
SERVER_SCRIPT=$SERVER_SCRIPT
HOME=$RUNTIME_HOME
XDG_CONFIG_HOME=$XDG_CONFIG_HOME
XDG_CACHE_HOME=$XDG_CACHE_HOME
EOF
  exit 0
fi

[[ -n "$CORE_PYTHON" && -x "$CORE_PYTHON" ]] || {
  echo "Missing Mascarade core python: $CORE_PYTHON" >&2
  exit 1
}

kill_life_runtime_home_ensure
export PYTHONPATH="$MASCARADE_DIR/core${PYTHONPATH:+:$PYTHONPATH}"
exec "$CORE_PYTHON" "$SERVER_SCRIPT" "$@"
