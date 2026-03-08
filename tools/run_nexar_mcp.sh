#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MASCARADE_DIR="${MASCARADE_DIR:-$ROOT_DIR/../mascarade}"
KICAD_KIC_AI_DIR="${KICAD_KIC_AI_DIR:-$MASCARADE_DIR/finetune/kicad_kic_ai}"
PYTHON_BIN="${NEXAR_MCP_PYTHON:-}"
TOKEN_CONFIGURED="no"
source "$ROOT_DIR/tools/lib/runtime_home.sh"
kill_life_runtime_home_init "$ROOT_DIR" "nexar-mcp"

if [ -n "${NEXAR_TOKEN:-${NEXAR_API_KEY:-}}" ]; then
  TOKEN_CONFIGURED="yes"
fi

if [ -z "$PYTHON_BIN" ]; then
  if [ -x "$KICAD_KIC_AI_DIR/venv/bin/python" ]; then
    PYTHON_BIN="$KICAD_KIC_AI_DIR/venv/bin/python"
  else
    PYTHON_BIN="$(command -v python3 || true)"
  fi
fi

if [[ "${1:-}" == "--doctor" ]]; then
  cat <<EOF
ROOT_DIR=$ROOT_DIR
MASCARADE_DIR=$MASCARADE_DIR
KICAD_KIC_AI_DIR=$KICAD_KIC_AI_DIR
NEXAR_MCP_PYTHON=$PYTHON_BIN
SERVER_MODULE=mcp_servers.nexar
NEXAR_TOKEN_CONFIGURED=$TOKEN_CONFIGURED
HOME=$RUNTIME_HOME
XDG_CONFIG_HOME=$XDG_CONFIG_HOME
XDG_CACHE_HOME=$XDG_CACHE_HOME
EOF
  exit 0
fi

[ -d "$KICAD_KIC_AI_DIR/mcp_servers" ] || {
  echo "Missing kicad_kic_ai mcp_servers directory: $KICAD_KIC_AI_DIR/mcp_servers" >&2
  exit 1
}

[ -n "$PYTHON_BIN" ] && [ -x "$PYTHON_BIN" ] || {
  echo "Missing Python runtime for nexar MCP: $PYTHON_BIN" >&2
  exit 1
}

kill_life_runtime_home_ensure
if [ -n "${PYTHONPATH:-}" ]; then
  export PYTHONPATH="$KICAD_KIC_AI_DIR:$PYTHONPATH"
else
  export PYTHONPATH="$KICAD_KIC_AI_DIR"
fi

exec "$PYTHON_BIN" -m mcp_servers.nexar "$@"
