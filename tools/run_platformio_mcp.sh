#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER_SCRIPT="$ROOT_DIR/tools/platformio_mcp.py"
source "$ROOT_DIR/tools/lib/runtime_home.sh"
kill_life_runtime_home_init "$ROOT_DIR" "platformio-mcp"

if [[ "${1:-}" == "--doctor" ]]; then
  PIO_BIN=""
  for candidate in \
    "$ROOT_DIR/.pio-venv/bin/pio" \
    "$HOME/.platformio/penv/bin/pio" \
    "/usr/local/bin/pio" \
    "/usr/bin/pio"; do
    if [[ -x "$candidate" ]]; then
      PIO_BIN="$candidate"
      break
    fi
  done
  cat <<EOF
ROOT_DIR=$ROOT_DIR
SERVER_SCRIPT=$SERVER_SCRIPT
HOME=$RUNTIME_HOME
PIO=${PIO_BIN:-NOT FOUND}
FIRMWARE_DIR=$ROOT_DIR/firmware
EOF
  exit 0
fi

kill_life_runtime_home_ensure
exec python3 "$SERVER_SCRIPT" "$@"
