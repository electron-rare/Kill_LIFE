#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ZEROCLAW_ROOT_DIR:-$(cd -- "$SCRIPT_DIR/../.." && pwd)}"
ART_DIR="${ZEROCLAW_ART_DIR:-$ROOT_DIR/artifacts/zeroclaw}"
GW_PID_FILE="$ART_DIR/gateway.pid"
FW_PID_FILE="$ART_DIR/follow.pid"
PROM_PID_FILE="$ART_DIR/prometheus.pid"
PROM_CONTAINER="${ZEROCLAW_PROM_CONTAINER:-zeroclaw-prometheus}"
GW_MANAGED_FILE="$ART_DIR/gateway.managed"
FW_MANAGED_FILE="$ART_DIR/follow.managed"
PROM_MANAGED_FILE="$ART_DIR/prometheus.managed"
WATCHER_SCRIPT="$ROOT_DIR/tools/ai/zeroclaw_watch_1min.sh"

usage() {
  cat <<USAGE
Usage: $(basename "$0")

Stop the local ZeroClaw operator stack started by zeroclaw_stack_up.sh.
Managed logs and artifacts are preserved under:
  $ART_DIR
USAGE
}

if [[ $# -gt 0 ]]; then
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[fail] unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
fi

stop_pid_file() {
  local pid_file="$1"
  [[ -f "$pid_file" ]] || return 0
  local pid
  pid="$(cat "$pid_file" 2>/dev/null || true)"
  if [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1; then
    kill "$pid" >/dev/null 2>&1 || true
    sleep 0.2
    if kill -0 "$pid" >/dev/null 2>&1; then
      kill -9 "$pid" >/dev/null 2>&1 || true
    fi
  fi
  rm -f "$pid_file"
}

if [[ -f "$GW_MANAGED_FILE" ]]; then
  stop_pid_file "$GW_PID_FILE"
fi
if [[ -f "$FW_MANAGED_FILE" ]]; then
  stop_pid_file "$FW_PID_FILE"
fi
if [[ -f "$PROM_MANAGED_FILE" ]]; then
  prom_mode="$(cat "$PROM_MANAGED_FILE" 2>/dev/null || true)"
  if [[ "$prom_mode" == "binary" ]]; then
    stop_pid_file "$PROM_PID_FILE"
  elif [[ "$prom_mode" == "docker" ]] && command -v docker >/dev/null 2>&1; then
    if docker ps -a --filter "name=^/${PROM_CONTAINER}$" --format '{{.ID}}' | grep -q .; then
      docker rm -f "$PROM_CONTAINER" >/dev/null 2>&1 || true
    fi
  fi
fi
rm -f "$GW_MANAGED_FILE" "$FW_MANAGED_FILE" "$PROM_MANAGED_FILE"
if [[ -x "$WATCHER_SCRIPT" ]]; then
  "$WATCHER_SCRIPT" stop >/dev/null 2>&1 || true
fi
echo "ZeroClaw local stack stopped. Logs preserved in artifacts/zeroclaw/."
