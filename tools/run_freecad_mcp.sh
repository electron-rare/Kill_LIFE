#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER_SCRIPT="$ROOT_DIR/tools/freecad_mcp.py"
source "$ROOT_DIR/tools/lib/runtime_home.sh"
kill_life_runtime_home_init "$ROOT_DIR" "freecad-mcp"

if [[ "${1:-}" == "--doctor" ]]; then
  cat <<EOF
ROOT_DIR=$ROOT_DIR
SERVER_SCRIPT=$SERVER_SCRIPT
HOME=$RUNTIME_HOME
XDG_CONFIG_HOME=$XDG_CONFIG_HOME
XDG_CACHE_HOME=$XDG_CACHE_HOME
CAD_STACK=$ROOT_DIR/tools/hw/cad_stack.sh
EOF
  exit 0
fi

kill_life_runtime_home_ensure
exec python3 "$SERVER_SCRIPT" "$@"
