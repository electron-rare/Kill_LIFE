#!/usr/bin/env bash
set -euo pipefail

load_local_env() {
  local env_file="${ZEROCLAW_ENV_FILE:-$HOME/.zeroclaw/env}"
  [[ -f "$env_file" ]] || return 0
  chmod 600 "$env_file" >/dev/null 2>&1 || true
  set -a
  # shellcheck disable=SC1090
  source "$env_file"
  set +a
}

load_local_env

ROOT_DIR="/Users/cils/Documents/Lelectron_rare/Kill_LIFE"
ART_DIR="${ZEROCLAW_ART_DIR:-$ROOT_DIR/artifacts/zeroclaw}"
ZEROCLAW_BIN="${ZEROCLAW_BIN:-$ROOT_DIR/zeroclaw/target/release/zeroclaw}"
GATEWAY_HOST="${ZEROCLAW_GATEWAY_HOST:-127.0.0.1}"
GATEWAY_PORT="${ZEROCLAW_GATEWAY_PORT:-3000}"
FOLLOW_PORT="${ZEROCLAW_FOLLOW_PORT:-8788}"
PROM_MODE="${ZEROCLAW_PROM_MODE:-auto}"
PROM_HOST="${ZEROCLAW_PROM_HOST:-127.0.0.1}"
PROM_PORT="${ZEROCLAW_PROM_PORT:-9090}"
PROM_RETENTION="${ZEROCLAW_PROM_RETENTION:-24h}"
PROM_SCRAPE_INTERVAL="${ZEROCLAW_PROM_SCRAPE_INTERVAL:-15s}"
PROM_CONTAINER="${ZEROCLAW_PROM_CONTAINER:-zeroclaw-prometheus}"
DOCKER_WAIT_SECS="${ZEROCLAW_DOCKER_WAIT_SECS:-90}"
PROM_READY_WAIT_SECS="${ZEROCLAW_PROM_READY_WAIT_SECS:-15}"
AUTO_REPAIR_ON_INVALID_TOKEN="${ZEROCLAW_AUTO_REPAIR_ON_INVALID_TOKEN:-1}"

GW_PID_FILE="$ART_DIR/gateway.pid"
FW_PID_FILE="$ART_DIR/follow.pid"
GW_LOG="$ART_DIR/gateway.log"
FW_LOG="$ART_DIR/follow.log"
TOKEN_FILE="$ART_DIR/pair_token.txt"
CONVO_FILE="$ART_DIR/conversations.jsonl"
INDEX_FILE="$ART_DIR/index.html"
PROM_PID_FILE="$ART_DIR/prometheus.pid"
PROM_LOG="$ART_DIR/prometheus.log"
PROM_CONFIG_FILE="$ART_DIR/prometheus.yml"
PROM_DATA_DIR="$ART_DIR/prometheus-data"
PROM_STATUS="disabled"
ZEROCLAW_CONFIG_FILE="${ZEROCLAW_CONFIG_FILE:-$HOME/.zeroclaw/config.toml}"
GW_MANAGED_FILE="$ART_DIR/gateway.managed"
FW_MANAGED_FILE="$ART_DIR/follow.managed"
PROM_MANAGED_FILE="$ART_DIR/prometheus.managed"
WATCHER_SCRIPT="$ROOT_DIR/tools/ai/zeroclaw_watch_1min.sh"
RT_LOG="$ART_DIR/realtime_1min.log"

mkdir -p "$ART_DIR"
touch "$CONVO_FILE"
touch "$GW_LOG"
touch "$RT_LOG"

if [[ -f "$HOME/.zeroclaw/config.toml" ]]; then
  chmod 600 "$HOME/.zeroclaw/config.toml" >/dev/null 2>&1 || true
fi

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

listener_pid_on_port() {
  local port="$1"
  lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null | head -n 1
}

ensure_docker_daemon() {
  if ! command -v docker >/dev/null 2>&1; then
    return 1
  fi
  if docker info >/dev/null 2>&1; then
    return 0
  fi

  if [[ "$(uname -s)" == "Darwin" ]]; then
    open -ga Docker >/dev/null 2>&1 || true
  fi

  local waited=0
  while (( waited < DOCKER_WAIT_SECS )); do
    if docker info >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
    waited=$((waited + 2))
  done
  return 1
}

wait_for_prometheus_ready() {
  local waited=0
  while (( waited < PROM_READY_WAIT_SECS )); do
    if curl -fsS "http://$PROM_HOST:$PROM_PORT/-/ready" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
    waited=$((waited + 1))
  done
  return 1
}

write_prometheus_config() {
  mkdir -p "$PROM_DATA_DIR"
  cat >"$PROM_CONFIG_FILE" <<EOF
global:
  scrape_interval: $PROM_SCRAPE_INTERVAL
  evaluation_interval: $PROM_SCRAPE_INTERVAL

scrape_configs:
  - job_name: zeroclaw_gateway
    metrics_path: /metrics
    static_configs:
      - targets: ["$GATEWAY_HOST:$GATEWAY_PORT"]
EOF
}

start_prometheus_binary() {
  if is_running "$PROM_PID_FILE"; then
    PROM_STATUS="binary(existing pid $(cat "$PROM_PID_FILE"))"
    return 0
  fi
  if ! command -v prometheus >/dev/null 2>&1; then
    return 1
  fi
  nohup prometheus \
    --config.file="$PROM_CONFIG_FILE" \
    --storage.tsdb.path="$PROM_DATA_DIR" \
    --storage.tsdb.retention.time="$PROM_RETENTION" \
    --web.listen-address="$PROM_HOST:$PROM_PORT" \
    >"$PROM_LOG" 2>&1 &
  echo "$!" >"$PROM_PID_FILE"
  sleep 0.3
  if is_running "$PROM_PID_FILE"; then
    printf '%s\n' "binary" >"$PROM_MANAGED_FILE"
    if wait_for_prometheus_ready; then
      PROM_STATUS="binary(ready)"
    else
      PROM_STATUS="binary(starting)"
    fi
    return 0
  fi
  rm -f "$PROM_PID_FILE"
  return 1
}

start_prometheus_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    return 1
  fi
  if ! ensure_docker_daemon; then
    return 1
  fi
  local running_id
  running_id="$(docker ps --filter "name=^/${PROM_CONTAINER}$" --format '{{.ID}}' | head -n 1)"
  if [[ -n "$running_id" ]]; then
    printf '%s\n' "docker" >"$PROM_MANAGED_FILE"
    if wait_for_prometheus_ready; then
      PROM_STATUS="docker(existing:$PROM_CONTAINER,ready)"
    else
      PROM_STATUS="docker(existing:$PROM_CONTAINER,starting)"
    fi
    return 0
  fi

  if docker ps -a --filter "name=^/${PROM_CONTAINER}$" --format '{{.ID}}' | grep -q .; then
    docker rm -f "$PROM_CONTAINER" >/dev/null 2>&1 || true
  fi

  local container_id
  container_id="$(docker run -d \
    --name "$PROM_CONTAINER" \
    -p "$PROM_HOST:$PROM_PORT:9090" \
    -v "$PROM_CONFIG_FILE:/etc/prometheus/prometheus.yml:ro" \
    -v "$PROM_DATA_DIR:/prometheus" \
    prom/prometheus:latest \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/prometheus \
    --storage.tsdb.retention.time="$PROM_RETENTION" \
    --web.listen-address=:9090 2>>"$PROM_LOG" || true)"
  if [[ -n "$container_id" ]]; then
    printf '%s\n' "docker" >"$PROM_MANAGED_FILE"
    if wait_for_prometheus_ready; then
      PROM_STATUS="docker($PROM_CONTAINER,ready)"
    else
      PROM_STATUS="docker($PROM_CONTAINER,starting)"
    fi
    return 0
  fi
  return 1
}

gateway_is_paired() {
  curl -fsS "http://$GATEWAY_HOST:$GATEWAY_PORT/health" 2>/dev/null | python3 -c 'import json,sys
raw=sys.stdin.read().strip()
try:
  obj=json.loads(raw) if raw else {}
except Exception:
  sys.exit(1)
sys.exit(0 if obj.get("paired") else 1)' >/dev/null 2>&1
}

read_pair_token() {
  if [[ -f "$TOKEN_FILE" ]]; then
    cat "$TOKEN_FILE" 2>/dev/null
    return 0
  fi

  if [[ -f "$ZEROCLAW_CONFIG_FILE" ]]; then
    local token_from_config
    token_from_config="$(python3 - "$ZEROCLAW_CONFIG_FILE" <<'PY'
import sys
from pathlib import Path

cfg = Path(sys.argv[1])
try:
    import tomllib
except Exception:
    print("", end="")
    raise SystemExit(0)

try:
    obj = tomllib.loads(cfg.read_text(encoding="utf-8"))
except Exception:
    print("", end="")
    raise SystemExit(0)

tokens = obj.get("gateway", {}).get("paired_tokens", [])
if isinstance(tokens, list) and tokens:
    print(str(tokens[0]), end="")
PY
)"
    if [[ -n "$token_from_config" ]]; then
      printf '%s\n' "$token_from_config" >"$TOKEN_FILE"
      chmod 600 "$TOKEN_FILE"
      printf '%s\n' "$token_from_config"
      return 0
    fi
  fi

  return 1
}

token_is_usable() {
  local token="${1:-}"
  [[ -n "$token" ]] || return 1
  local http_status
  http_status="$(curl -sS -o /dev/null -w "%{http_code}" -X POST "http://$GATEWAY_HOST:$GATEWAY_PORT/webhook" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d '{}' || true)"

  # 400/422 typically means auth passed but payload was intentionally malformed.
  if [[ "$http_status" == "401" || "$http_status" == "403" || "$http_status" == "000" ]]; then
    return 1
  fi
  return 0
}

wait_for_gateway_health() {
  local waited=0
  while (( waited < 20 )); do
    if curl -fsS "http://$GATEWAY_HOST:$GATEWAY_PORT/health" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.25
    waited=$((waited + 1))
  done
  return 1
}

clear_config_paired_tokens() {
  [[ -f "$ZEROCLAW_CONFIG_FILE" ]] || return 1
  python3 - "$ZEROCLAW_CONFIG_FILE" <<'PY'
import re
import sys
from pathlib import Path

cfg = Path(sys.argv[1])
text = cfg.read_text(encoding="utf-8")
updated, n = re.subn(r'(?m)^paired_tokens\s*=\s*\[.*\]\s*$', 'paired_tokens = []', text)
if n == 0:
    raise SystemExit(1)
cfg.write_text(updated, encoding="utf-8")
PY
}

extract_pair_code() {
  grep -Eo 'X-Pairing-Code: [0-9]{6}' "$GW_LOG" 2>/dev/null | tail -1 | awk '{print $2}' || true
}

write_pair_token_from_code() {
  local pair_code="$1"
  local pair_json token
  pair_json="$(curl -sS -X POST "http://$GATEWAY_HOST:$GATEWAY_PORT/pair" -H "X-Pairing-Code: $pair_code" || true)"
  token="$(printf '%s' "$pair_json" | python3 -c 'import json,sys
raw=sys.stdin.read().strip()
try:
  obj=json.loads(raw) if raw else {}
except Exception:
  obj={}
print(obj.get("token",""), end="")')"
  if [[ -z "$token" ]]; then
    return 1
  fi
  printf '%s\n' "$token" >"$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE"
  return 0
}

ensure_gateway_pairing() {
  local current_token=""
  current_token="$(read_pair_token || true)"
  if gateway_is_paired && token_is_usable "$current_token"; then
    return 0
  fi

  local pair_code
  pair_code="$(extract_pair_code)"
  if [[ -n "$pair_code" ]]; then
    write_pair_token_from_code "$pair_code" || true
  fi

  current_token="$(read_pair_token || true)"
  if gateway_is_paired && token_is_usable "$current_token"; then
    return 0
  fi

  sleep 0.5
  pair_code="$(extract_pair_code)"
  if [[ -n "$pair_code" ]]; then
    write_pair_token_from_code "$pair_code" || true
  fi

  current_token="$(read_pair_token || true)"
  if ! token_is_usable "$current_token"; then
    rm -f "$TOKEN_FILE"

    if [[ "$AUTO_REPAIR_ON_INVALID_TOKEN" == "1" && -f "$GW_MANAGED_FILE" ]]; then
      if clear_config_paired_tokens; then
        local gw_pid=""
        gw_pid="$(cat "$GW_PID_FILE" 2>/dev/null || true)"
        if [[ -n "$gw_pid" ]] && kill -0 "$gw_pid" >/dev/null 2>&1; then
          kill "$gw_pid" >/dev/null 2>&1 || true
          sleep 0.3
          if kill -0 "$gw_pid" >/dev/null 2>&1; then
            kill -9 "$gw_pid" >/dev/null 2>&1 || true
          fi
        fi

        nohup "$ZEROCLAW_BIN" gateway --port "$GATEWAY_PORT" --host "$GATEWAY_HOST" >"$GW_LOG" 2>&1 &
        echo "$!" >"$GW_PID_FILE"
        wait_for_gateway_health || true

        for _ in $(seq 1 40); do
          pair_code="$(extract_pair_code)"
          if [[ -n "$pair_code" ]]; then
            break
          fi
          sleep 0.25
        done

        if [[ -n "${pair_code:-}" ]]; then
          write_pair_token_from_code "$pair_code" || true
        fi
      fi
    fi
  fi
}

if is_running "$GW_PID_FILE"; then
  echo "[info] gateway already running (pid $(cat "$GW_PID_FILE"))."
elif [[ -n "$(listener_pid_on_port "$GATEWAY_PORT")" ]]; then
  existing_gateway_pid="$(listener_pid_on_port "$GATEWAY_PORT")"
  echo "[info] gateway port $GATEWAY_PORT already listening (pid $existing_gateway_pid). reusing."
  printf '%s\n' "$existing_gateway_pid" >"$GW_PID_FILE"
  rm -f "$GW_MANAGED_FILE"
else
  nohup "$ZEROCLAW_BIN" gateway --port "$GATEWAY_PORT" --host "$GATEWAY_HOST" >"$GW_LOG" 2>&1 &
  echo "$!" >"$GW_PID_FILE"
  printf '%s\n' "1" >"$GW_MANAGED_FILE"
fi

if is_running "$FW_PID_FILE"; then
  echo "[info] follow server already running (pid $(cat "$FW_PID_FILE"))."
elif [[ -n "$(listener_pid_on_port "$FOLLOW_PORT")" ]]; then
  existing_follow_pid="$(listener_pid_on_port "$FOLLOW_PORT")"
  echo "[info] follow port $FOLLOW_PORT already listening (pid $existing_follow_pid). reusing."
  printf '%s\n' "$existing_follow_pid" >"$FW_PID_FILE"
  rm -f "$FW_MANAGED_FILE"
else
  nohup python3 -m http.server "$FOLLOW_PORT" --bind 127.0.0.1 --directory "$ART_DIR" >"$FW_LOG" 2>&1 &
  echo "$!" >"$FW_PID_FILE"
  printf '%s\n' "1" >"$FW_MANAGED_FILE"
fi

for _ in $(seq 1 40); do
  if curl -fsS "http://$GATEWAY_HOST:$GATEWAY_PORT/health" >/dev/null 2>&1; then
    break
  fi
  sleep 0.25
done

ensure_gateway_pairing

write_prometheus_config
case "$PROM_MODE" in
  off)
    rm -f "$PROM_MANAGED_FILE"
    PROM_STATUS="disabled(mode=off)"
    ;;
  auto)
    rm -f "$PROM_MANAGED_FILE"
    if start_prometheus_binary; then
      :
    elif start_prometheus_docker; then
      :
    else
      PROM_STATUS="disabled(no prometheus backend available)"
    fi
    ;;
  binary)
    rm -f "$PROM_MANAGED_FILE"
    if ! start_prometheus_binary; then
      PROM_STATUS="disabled(prometheus binary unavailable)"
    fi
    ;;
  docker)
    rm -f "$PROM_MANAGED_FILE"
    if ! start_prometheus_docker; then
      PROM_STATUS="disabled(docker unavailable or daemon not ready)"
    fi
    ;;
  *)
    rm -f "$PROM_MANAGED_FILE"
    PROM_STATUS="disabled(invalid mode:$PROM_MODE)"
    ;;
esac

cat >"$INDEX_FILE" <<EOF
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>ZeroClaw Live Follow</title>
  <style>
    :root {
      --bg: #f7f8fa;
      --panel: #ffffff;
      --ink: #161b22;
      --muted: #5b6270;
      --line: #d7dbe2;
      --accent: #1a4f8b;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: "SF Pro Text", "Segoe UI", Arial, sans-serif;
      background: radial-gradient(circle at top, #ffffff 0%, #f2f4f8 48%, #eceff5 100%);
      color: var(--ink);
    }
    main {
      max-width: 1280px;
      margin: 0 auto;
      padding: 20px 14px 28px;
    }
    h1 {
      margin: 0 0 10px;
      font-size: 24px;
      letter-spacing: 0.2px;
    }
    .meta {
      color: var(--muted);
      font-size: 13px;
      margin-bottom: 12px;
    }
    .links {
      display: flex;
      gap: 8px;
      flex-wrap: wrap;
      margin-bottom: 14px;
    }
    .links a {
      color: var(--accent);
      text-decoration: none;
      border: 1px solid var(--line);
      background: #fff;
      border-radius: 8px;
      padding: 5px 10px;
      font-size: 13px;
    }
    .grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 12px;
    }
    .panel {
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 12px;
      min-height: 420px;
      box-shadow: 0 2px 10px rgba(17, 26, 41, 0.04);
      display: flex;
      flex-direction: column;
      overflow: hidden;
    }
    .panel h2 {
      margin: 0;
      padding: 12px 14px 10px;
      border-bottom: 1px solid var(--line);
      font-size: 16px;
    }
    .panel pre {
      margin: 0;
      padding: 12px 14px;
      overflow: auto;
      white-space: pre-wrap;
      word-break: break-word;
      font-family: ui-monospace, "SFMono-Regular", Menlo, Consolas, monospace;
      font-size: 12px;
      line-height: 1.4;
      flex: 1;
    }
    .status {
      margin-top: 10px;
      color: var(--muted);
      font-size: 12px;
    }
    @media (max-width: 980px) {
      .grid { grid-template-columns: 1fr; }
      .panel { min-height: 320px; }
    }
  </style>
</head>
<body>
  <main>
    <h1>ZeroClaw Live Follow</h1>
    <div class="meta">
      Follow URL: <code>http://127.0.0.1:$FOLLOW_PORT/</code> |
      Polling interval: <code>1s</code> |
      Display cap: <code>500 lines/panel</code> |
      Prometheus: <code>$PROM_STATUS</code>
    </div>
    <div class="links">
      <a href="/conversations.jsonl">/conversations.jsonl</a>
      <a href="/gateway.log">/gateway.log</a>
      <a href="/realtime_1min.log">/realtime_1min.log</a>
      <a href="/prometheus.yml">/prometheus.yml</a>
      <a href="http://$GATEWAY_HOST:$GATEWAY_PORT/health">/health</a>
      <a href="http://$GATEWAY_HOST:$GATEWAY_PORT/metrics">/metrics</a>
      <a href="http://$PROM_HOST:$PROM_PORT/targets">prometheus /targets</a>
      <a href="http://$PROM_HOST:$PROM_PORT/graph">prometheus /graph</a>
    </div>
    <div class="grid">
      <section class="panel">
        <h2>Conversations (JSONL live)</h2>
        <pre id="conversations">Waiting for data...</pre>
      </section>
      <section class="panel">
        <h2>Gateway log (live)</h2>
        <pre id="gateway">Waiting for data...</pre>
      </section>
    </div>
    <div class="status" id="status">Polling started...</div>
  </main>
  <script>
    const MAX_LINES = 500;
    const POLL_MS = 1000;

    let convoCount = 0;
    let gatewayCount = 0;
    let convoBuf = [];
    let gatewayBuf = [];
    let lastOk = null;

    function trimTail(lines) {
      if (lines.length <= MAX_LINES) return lines;
      return lines.slice(lines.length - MAX_LINES);
    }

    function safeText(input) {
      if (input === null || input === undefined) return "";
      return String(input);
    }

    function renderConvo(line) {
      try {
        const obj = JSON.parse(line);
        const ts = safeText(obj.ts || "");
        const repo = safeText(obj.repo_hint || "unknown");
        const msg = safeText(obj.message || "");
        const status = obj.http_status === undefined ? "-" : safeText(obj.http_status);
        const ok = obj.ok === undefined ? "-" : safeText(obj.ok);
        const raw = safeText(obj.response_raw || "");
        return "[" + ts + "] repo=" + repo + " status=" + status + " ok=" + ok + "\n> " + msg + "\n< " + raw;
      } catch (error) {
        return "[raw] " + line;
      }
    }

    function splitLines(text) {
      if (!text) return [];
      const lines = text.replace(/\r/g, "").split("\n");
      if (lines.length > 0 && lines[lines.length - 1] === "") lines.pop();
      return lines;
    }

    async function pollFile(url, kind) {
      const response = await fetch(url + "?t=" + Date.now(), { cache: "no-store" });
      if (!response.ok) {
        throw new Error(kind + " HTTP " + response.status);
      }
      const content = await response.text();
      const lines = splitLines(content);

      if (kind === "conversations") {
        if (lines.length < convoCount) {
          convoCount = 0;
          convoBuf = [];
        }
        const delta = lines.slice(convoCount).map(renderConvo);
        convoCount = lines.length;
        convoBuf = trimTail(convoBuf.concat(delta));
        document.getElementById("conversations").textContent = convoBuf.length ? convoBuf.join("\n\n") : "(empty)";
      } else {
        if (lines.length < gatewayCount) {
          gatewayCount = 0;
          gatewayBuf = [];
        }
        const delta = lines.slice(gatewayCount);
        gatewayCount = lines.length;
        gatewayBuf = trimTail(gatewayBuf.concat(delta));
        document.getElementById("gateway").textContent = gatewayBuf.length ? gatewayBuf.join("\n") : "(empty)";
      }
    }

    function setStatus(message, isError) {
      const now = new Date().toISOString();
      lastOk = !isError;
      const marker = isError ? "error" : "ok";
      document.getElementById("status").textContent = "[" + marker + "] " + message + " | updated " + now;
    }

    async function tick() {
      try {
        await Promise.all([
          pollFile("/conversations.jsonl", "conversations"),
          pollFile("/gateway.log", "gateway"),
        ]);
        setStatus("polling every " + POLL_MS + "ms", false);
      } catch (error) {
        setStatus(error.message, true);
      }
    }

    tick();
    setInterval(tick, POLL_MS);
  </script>
</body>
</html>
EOF

if [[ -x "$WATCHER_SCRIPT" ]]; then
  "$WATCHER_SCRIPT" start >/dev/null 2>&1 || true
fi

echo "Gateway: http://$GATEWAY_HOST:$GATEWAY_PORT/health"
echo "Follow : http://127.0.0.1:$FOLLOW_PORT/"
echo "Prom   : http://$PROM_HOST:$PROM_PORT/targets ($PROM_STATUS)"
echo "RT 1m  : http://127.0.0.1:$FOLLOW_PORT/realtime_1min.log"
echo "Logs   : $GW_LOG"
echo "Token  : $TOKEN_FILE"
if [[ ! -s "$TOKEN_FILE" ]]; then
  if gateway_is_paired; then
    echo "[warn] gateway is paired but local bearer token is unavailable; webhook_send may require ZEROCLAW_BEARER or gateway re-pair."
  else
    echo "[warn] pair token not found. If gateway is waiting for pairing, restart and pair again."
  fi
fi
