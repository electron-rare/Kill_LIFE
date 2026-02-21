#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/Users/cils/Documents/Lelectron_rare/Kill_LIFE"
ART_DIR="${ZEROCLAW_ART_DIR:-$ROOT_DIR/artifacts/zeroclaw}"
ZEROCLAW_BIN="${ZEROCLAW_BIN:-$ROOT_DIR/zeroclaw/target/release/zeroclaw}"
GATEWAY_HOST="${ZEROCLAW_GATEWAY_HOST:-127.0.0.1}"
GATEWAY_PORT="${ZEROCLAW_GATEWAY_PORT:-3000}"
FOLLOW_PORT="${ZEROCLAW_FOLLOW_PORT:-8788}"

GW_PID_FILE="$ART_DIR/gateway.pid"
FW_PID_FILE="$ART_DIR/follow.pid"
GW_LOG="$ART_DIR/gateway.log"
FW_LOG="$ART_DIR/follow.log"
TOKEN_FILE="$ART_DIR/pair_token.txt"
CONVO_FILE="$ART_DIR/conversations.jsonl"
INDEX_FILE="$ART_DIR/index.html"

mkdir -p "$ART_DIR"
touch "$CONVO_FILE"

if [[ ! -x "$ZEROCLAW_BIN" ]]; then
  if command -v zeroclaw >/dev/null 2>&1; then
    ZEROCLAW_BIN="$(command -v zeroclaw)"
  else
    echo "[fail] zeroclaw binary not found." >&2
    exit 1
  fi
fi

is_running() {
  local pid_file="$1"
  [[ -f "$pid_file" ]] || return 1
  local pid
  pid="$(cat "$pid_file" 2>/dev/null || true)"
  [[ -n "$pid" ]] || return 1
  kill -0 "$pid" >/dev/null 2>&1
}

if is_running "$GW_PID_FILE"; then
  echo "[info] gateway already running (pid $(cat "$GW_PID_FILE"))."
else
  nohup "$ZEROCLAW_BIN" gateway --port "$GATEWAY_PORT" --host "$GATEWAY_HOST" >"$GW_LOG" 2>&1 &
  echo "$!" >"$GW_PID_FILE"
fi

if is_running "$FW_PID_FILE"; then
  echo "[info] follow server already running (pid $(cat "$FW_PID_FILE"))."
else
  nohup python3 -m http.server "$FOLLOW_PORT" --bind 127.0.0.1 --directory "$ART_DIR" >"$FW_LOG" 2>&1 &
  echo "$!" >"$FW_PID_FILE"
fi

for _ in $(seq 1 40); do
  if curl -fsS "http://$GATEWAY_HOST:$GATEWAY_PORT/health" >/dev/null 2>&1; then
    break
  fi
  sleep 0.25
done

PAIR_CODE="$(grep -Eo 'X-Pairing-Code: [0-9]{6}' "$GW_LOG" 2>/dev/null | tail -1 | awk '{print $2}' || true)"
if [[ -n "$PAIR_CODE" ]]; then
  PAIR_JSON="$(curl -sS -X POST "http://$GATEWAY_HOST:$GATEWAY_PORT/pair" -H "X-Pairing-Code: $PAIR_CODE" || true)"
  TOKEN="$(printf '%s' "$PAIR_JSON" | python3 -c 'import json,sys
raw=sys.stdin.read().strip()
try:
  obj=json.loads(raw) if raw else {}
except Exception:
  obj={}
print(obj.get("token",""), end="")')"
  if [[ -n "$TOKEN" ]]; then
    printf '%s\n' "$TOKEN" >"$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
  fi
fi

cat >"$INDEX_FILE" <<EOF
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta http-equiv="refresh" content="5" />
  <title>ZeroClaw Local Follow</title>
  <style>body{font-family:ui-sans-serif,system-ui;margin:20px}code{background:#f4f4f4;padding:2px 4px}</style>
</head>
<body>
  <h1>ZeroClaw Local Follow</h1>
  <ul>
    <li>Health: <a href="http://$GATEWAY_HOST:$GATEWAY_PORT/health">http://$GATEWAY_HOST:$GATEWAY_PORT/health</a></li>
    <li>Metrics: <a href="http://$GATEWAY_HOST:$GATEWAY_PORT/metrics">http://$GATEWAY_HOST:$GATEWAY_PORT/metrics</a></li>
    <li>Gateway log: <a href="/gateway.log">/gateway.log</a></li>
    <li>Conversation log: <a href="/conversations.jsonl">/conversations.jsonl</a></li>
  </ul>
  <p>Follow URL: <code>http://127.0.0.1:$FOLLOW_PORT/</code></p>
</body>
</html>
EOF

echo "Gateway: http://$GATEWAY_HOST:$GATEWAY_PORT/health"
echo "Follow : http://127.0.0.1:$FOLLOW_PORT/"
echo "Logs   : $GW_LOG"
echo "Token  : $TOKEN_FILE"
