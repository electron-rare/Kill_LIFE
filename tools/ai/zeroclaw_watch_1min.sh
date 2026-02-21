#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/Users/cils/Documents/Lelectron_rare/Kill_LIFE"
ART_DIR="${ZEROCLAW_ART_DIR:-$ROOT_DIR/artifacts/zeroclaw}"
HOST="${ZEROCLAW_GATEWAY_HOST:-127.0.0.1}"
PORT="${ZEROCLAW_GATEWAY_PORT:-3000}"
PROM_HOST="${ZEROCLAW_PROM_HOST:-127.0.0.1}"
PROM_PORT="${ZEROCLAW_PROM_PORT:-9090}"
INTERVAL_SECS="${ZEROCLAW_RT_INTERVAL_SECS:-60}"

PID_FILE="$ART_DIR/realtime_1min.pid"
LOG_FILE="$ART_DIR/realtime_1min.log"
CONVO_FILE="$ART_DIR/conversations.jsonl"
GW_LOG_FILE="$ART_DIR/gateway.log"

mkdir -p "$ART_DIR"
touch "$LOG_FILE" "$CONVO_FILE" "$GW_LOG_FILE"

is_running() {
  [[ -f "$PID_FILE" ]] || return 1
  local pid
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  [[ -n "$pid" ]] || return 1
  kill -0 "$pid" >/dev/null 2>&1
}

collect_once() {
  local ts health paired uptime prom last_convo last_gw
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  health="$(curl -sS "http://$HOST:$PORT/health" || true)"
  if [[ -n "$health" ]]; then
    paired="$(printf '%s' "$health" | python3 -c 'import json,sys
raw=sys.stdin.read().strip()
try:
  obj=json.loads(raw) if raw else {}
except Exception:
  print("unknown")
  raise SystemExit
print(str(obj.get("paired","unknown")).lower())' 2>/dev/null || echo "unknown")"
    uptime="$(printf '%s' "$health" | python3 -c 'import json,sys
raw=sys.stdin.read().strip()
try:
  obj=json.loads(raw) if raw else {}
except Exception:
  print("unknown")
  raise SystemExit
print(obj.get("runtime",{}).get("uptime_seconds","unknown"))' 2>/dev/null || echo "unknown")"
  else
    paired="down"
    uptime="down"
  fi

  if curl -fsS "http://$PROM_HOST:$PROM_PORT/-/ready" >/dev/null 2>&1; then
    prom="ready"
  else
    prom="down"
  fi

  last_convo="$(tail -n 1 "$CONVO_FILE" 2>/dev/null || true)"
  last_gw="$(tail -n 1 "$GW_LOG_FILE" 2>/dev/null || true)"
  last_convo="${last_convo//$'\t'/ }"
  last_gw="${last_gw//$'\t'/ }"

  printf '%s | paired=%s | uptime=%s | prom=%s | convo=%s | gateway=%s\n' \
    "$ts" "$paired" "$uptime" "$prom" "$last_convo" "$last_gw" >>"$LOG_FILE"
}

run_loop() {
  while true; do
    collect_once
    sleep "$INTERVAL_SECS"
  done
}

start() {
  if is_running; then
    echo "[info] watcher already running (pid $(cat "$PID_FILE"))."
    return 0
  fi
  nohup "$0" run >>"$LOG_FILE" 2>&1 &
  echo "$!" >"$PID_FILE"
  echo "[ok] watcher started (pid $(cat "$PID_FILE"))."
}

stop() {
  if ! is_running; then
    rm -f "$PID_FILE"
    echo "[info] watcher not running."
    return 0
  fi
  local pid
  pid="$(cat "$PID_FILE")"
  kill "$pid" >/dev/null 2>&1 || true
  sleep 0.2
  if kill -0 "$pid" >/dev/null 2>&1; then
    kill -9 "$pid" >/dev/null 2>&1 || true
  fi
  rm -f "$PID_FILE"
  echo "[ok] watcher stopped."
}

status() {
  if is_running; then
    echo "[ok] watcher running (pid $(cat "$PID_FILE"))."
  else
    echo "[info] watcher not running."
  fi
  tail -n 5 "$LOG_FILE" 2>/dev/null || true
}

case "${1:-start}" in
  start) start ;;
  stop) stop ;;
  status) status ;;
  run) run_loop ;;
  once) collect_once ;;
  *)
    echo "Usage: $(basename "$0") [start|stop|status|run|once]" >&2
    exit 1
    ;;
esac
