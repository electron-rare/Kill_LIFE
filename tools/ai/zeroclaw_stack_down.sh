#!/usr/bin/env bash
set -euo pipefail

ART_DIR="${ZEROCLAW_ART_DIR:-/Users/cils/Documents/Lelectron_rare/Kill_LIFE/artifacts/zeroclaw}"
GW_PID_FILE="$ART_DIR/gateway.pid"
FW_PID_FILE="$ART_DIR/follow.pid"

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

stop_pid_file "$GW_PID_FILE"
stop_pid_file "$FW_PID_FILE"
echo "ZeroClaw local stack stopped."
