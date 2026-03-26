#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER_SCRIPT="$ROOT_DIR/tools/ngspice_mcp.py"
source "$ROOT_DIR/tools/lib/runtime_home.sh"
kill_life_runtime_home_init "$ROOT_DIR" "ngspice-mcp"

if [[ "${1:-}" == "--doctor" ]]; then
  cat <<EOF
ROOT_DIR=$ROOT_DIR
SERVER_SCRIPT=$SERVER_SCRIPT
HOME=$RUNTIME_HOME
NGSPICE=$(which ngspice 2>/dev/null || echo "NOT FOUND")
EOF
  exit 0
fi

kill_life_runtime_home_ensure
exec python3 "$SERVER_SCRIPT" "$@"
