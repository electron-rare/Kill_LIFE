#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/tools/lib/runtime_home.sh"

USER_HOME="${HOME:-$ROOT_DIR}"
USER_CACHE_HOME="${XDG_CACHE_HOME:-$USER_HOME/.cache}"

if [ -n "${KICAD_SEEED_MCP_HOME:-}" ] && [ -z "${KILL_LIFE_RUNTIME_HOME:-}" ]; then
  export KILL_LIFE_RUNTIME_HOME="$KICAD_SEEED_MCP_HOME"
fi

kill_life_runtime_home_init "$ROOT_DIR" "kicad-seeed-mcp" "$ROOT_DIR/.cad-home"
UV_CACHE_DIR="${UV_CACHE_DIR:-$USER_CACHE_HOME/uv}"
UVX_BIN="${UVX_BIN:-uvx}"
BRIDGE_SCRIPT="$ROOT_DIR/tools/hw/kicad_seeed_mcp_bridge.py"
SEEED_COMMAND="${KICAD_MCP_SEEED_COMMAND:-$UVX_BIN --offline kicad-mcp-server}"
PROJECTS_BASE="${KICAD_MCP_PROJECTS_BASE:-$RUNTIME_HOME/pcb/projects}"
TASKS_DIR="${KICAD_MCP_TASKS_DIR:-$RUNTIME_HOME/pcb/tasks}"

if [[ "${1:-}" == "--doctor" ]]; then
  cat <<EOF
ROOT_DIR=$ROOT_DIR
BRIDGE_SCRIPT=$BRIDGE_SCRIPT
HOME=$RUNTIME_HOME
XDG_CONFIG_HOME=$XDG_CONFIG_HOME
XDG_CACHE_HOME=$XDG_CACHE_HOME
UV_CACHE_DIR=$UV_CACHE_DIR
UVX_BIN=$UVX_BIN
KICAD_MCP_SEEED_COMMAND=$SEEED_COMMAND
KICAD_MCP_PROJECTS_BASE=$PROJECTS_BASE
KICAD_MCP_TASKS_DIR=$TASKS_DIR
EOF
  exit 0
fi

command -v "$UVX_BIN" >/dev/null 2>&1 || {
  echo "Missing uvx executable: $UVX_BIN" >&2
  exit 1
}

kill_life_runtime_home_ensure
mkdir -p "$PROJECTS_BASE" "$TASKS_DIR"
export UV_CACHE_DIR
export KICAD_MCP_SEEED_COMMAND="$SEEED_COMMAND"
export KICAD_MCP_PROJECTS_BASE="$PROJECTS_BASE"
export KICAD_MCP_TASKS_DIR="$TASKS_DIR"
exec python3 "$BRIDGE_SCRIPT" "$@"
