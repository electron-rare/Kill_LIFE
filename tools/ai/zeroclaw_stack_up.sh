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
OPENAI_CODEX_MODEL="${ZEROCLAW_OPENAI_CODEX_MODEL:-gpt-5.3-codex}"
OPENROUTER_MODEL="${ZEROCLAW_OPENROUTER_MODEL:-openrouter/auto}"
PREFER_LOCAL_AI="${ZEROCLAW_PREFER_LOCAL_AI:-0}"
OLLAMA_MODEL="${ZEROCLAW_OLLAMA_MODEL:-llama3.2:1b}"
OLLAMA_AUTO_PULL="${ZEROCLAW_OLLAMA_AUTO_PULL:-0}"
OLLAMA_WARMUP="${ZEROCLAW_OLLAMA_WARMUP:-1}"
LMSTUDIO_BASE_URL="${ZEROCLAW_LMSTUDIO_BASE_URL:-http://127.0.0.1:1234/v1}"
LMSTUDIO_MODEL="${ZEROCLAW_LMSTUDIO_MODEL:-}"
LOCAL_PROVIDER_ORDER="${ZEROCLAW_LOCAL_PROVIDER_ORDER:-ollama,lmstudio}"

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
ORCHESTRATOR_SERVER="$ROOT_DIR/tools/ai/zeroclaw_orchestrator_server.py"
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

ensure_preferred_provider_config() {
  [[ -f "$ZEROCLAW_CONFIG_FILE" ]] || return 0

  local preferred_provider=""
  local preferred_model=""
  local fallback_csv=""
  local fallback_models_csv=""

  ollama_model_available() {
    command -v ollama >/dev/null 2>&1 || return 1
    ollama list 2>/dev/null | awk 'NR>1 {print $1}' | rg -qx "$OLLAMA_MODEL"
  }

  ensure_ollama_ready() {
    [[ "$PREFER_LOCAL_AI" == "1" ]] || return 1
    command -v ollama >/dev/null 2>&1 || return 1

    if ! ollama list >/dev/null 2>&1; then
      if [[ "$(uname -s)" == "Darwin" ]] && command -v brew >/dev/null 2>&1; then
        brew services start ollama >/dev/null 2>&1 || true
        sleep 1
      fi
      if ! ollama list >/dev/null 2>&1; then
        nohup ollama serve >"$ART_DIR/ollama.log" 2>&1 &
        sleep 1
      fi
    fi

    if ollama_model_available; then
      if [[ "$OLLAMA_WARMUP" == "1" ]]; then
        python3 - "$OLLAMA_MODEL" >>"$ART_DIR/ollama.log" 2>&1 <<'PY'
import json
import sys
import urllib.request

model = sys.argv[1]
payload = json.dumps({
    "model": model,
    "prompt": "Reply with exactly: ready",
    "stream": False,
}).encode("utf-8")
req = urllib.request.Request(
    "http://127.0.0.1:11434/api/generate",
    data=payload,
    headers={"Content-Type": "application/json"},
    method="POST",
)
try:
    with urllib.request.urlopen(req, timeout=60) as resp:
        resp.read()
except Exception:
    pass
PY
      fi
      return 0
    fi

    if [[ "$OLLAMA_AUTO_PULL" == "1" ]]; then
      ollama pull "$OLLAMA_MODEL" >>"$ART_DIR/ollama.log" 2>&1 || true
      if ollama_model_available; then
        if [[ "$OLLAMA_WARMUP" == "1" ]]; then
          python3 - "$OLLAMA_MODEL" >>"$ART_DIR/ollama.log" 2>&1 <<'PY'
import json
import sys
import urllib.request

model = sys.argv[1]
payload = json.dumps({
    "model": model,
    "prompt": "Reply with exactly: ready",
    "stream": False,
}).encode("utf-8")
req = urllib.request.Request(
    "http://127.0.0.1:11434/api/generate",
    data=payload,
    headers={"Content-Type": "application/json"},
    method="POST",
)
try:
    with urllib.request.urlopen(req, timeout=60) as resp:
        resp.read()
except Exception:
    pass
PY
        fi
        return 0
      fi
    fi

    return 1
  }

  lmstudio_first_model() {
    python3 - "$LMSTUDIO_BASE_URL" <<'PY'
import json
import sys
import urllib.request

base = sys.argv[1].rstrip("/")
url = f"{base}/models"
try:
    req = urllib.request.Request(url, headers={"Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=3) as resp:
        payload = json.loads(resp.read().decode("utf-8", "replace"))
    models = payload.get("data", [])
    if isinstance(models, list):
        for item in models:
            if isinstance(item, dict):
                model_id = str(item.get("id", "")).strip()
                if model_id:
                    print(model_id)
                    raise SystemExit(0)
except Exception:
    pass
raise SystemExit(1)
PY
  }

  ensure_lmstudio_ready() {
    [[ "$PREFER_LOCAL_AI" == "1" ]] || return 1
    local discovered
    discovered="$(lmstudio_first_model 2>/dev/null || true)"
    [[ -n "$discovered" ]] || return 1
    LMSTUDIO_MODEL="$discovered"
    export LMSTUDIO_BASE_URL
    export LMSTUDIO_API_KEY="${LMSTUDIO_API_KEY:-lm-studio}"
    return 0
  }

  if [[ "$PREFER_LOCAL_AI" == "1" ]]; then
    IFS=',' read -r -a local_provider_order <<<"$LOCAL_PROVIDER_ORDER"
    for local_provider in "${local_provider_order[@]}"; do
      case "${local_provider// /}" in
        ollama)
          if ensure_ollama_ready; then
            preferred_provider="ollama"
            preferred_model="$OLLAMA_MODEL"
            break
          fi
          ;;
        lmstudio)
          if ensure_lmstudio_ready; then
            preferred_provider="lmstudio"
            preferred_model="$LMSTUDIO_MODEL"
            break
          fi
          ;;
      esac
    done
  fi

  if [[ -n "$preferred_provider" ]]; then
    :
  elif env -u ZEROCLAW_WORKSPACE "$ZEROCLAW_BIN" auth status 2>/dev/null | rg -q "openai-codex:"; then
    preferred_provider="openai-codex"
    preferred_model="$OPENAI_CODEX_MODEL"
  elif [[ -n "${OPENROUTER_API_KEY:-}" ]]; then
    preferred_provider="openrouter"
    preferred_model="$OPENROUTER_MODEL"
  else
    return 0
  fi

  if [[ "$preferred_provider" == "ollama" || "$preferred_provider" == "lmstudio" ]]; then
    if env -u ZEROCLAW_WORKSPACE "$ZEROCLAW_BIN" auth status 2>/dev/null | rg -q "openai-codex:"; then
      fallback_csv="openai-codex"
      fallback_models_csv="$OPENAI_CODEX_MODEL"
    fi
    if [[ -n "${OPENROUTER_API_KEY:-}" ]]; then
      if [[ -n "$fallback_csv" ]]; then
        fallback_csv+=",openrouter"
      else
        fallback_csv="openrouter"
      fi
      if [[ -n "$fallback_models_csv" ]]; then
        fallback_models_csv+=",$OPENROUTER_MODEL"
      else
        fallback_models_csv="$OPENROUTER_MODEL"
      fi
    fi
  elif [[ "$preferred_provider" == "openai-codex" && -n "${OPENROUTER_API_KEY:-}" ]]; then
    fallback_csv="openrouter"
    fallback_models_csv="$OPENROUTER_MODEL"
  elif [[ "$preferred_provider" == "openrouter" ]] && env -u ZEROCLAW_WORKSPACE "$ZEROCLAW_BIN" auth status 2>/dev/null | rg -q "openai-codex:"; then
    fallback_csv="openai-codex"
    fallback_models_csv="$OPENAI_CODEX_MODEL"
  fi

  python3 - "$ZEROCLAW_CONFIG_FILE" "$preferred_provider" "$preferred_model" "$fallback_csv" "$fallback_models_csv" <<'PY'
import re
import sys
from pathlib import Path

cfg = Path(sys.argv[1])
provider = sys.argv[2]
model = sys.argv[3]
fallback_csv = sys.argv[4]
fallback_models_csv = sys.argv[5]
fallbacks = [p for p in fallback_csv.split(",") if p]
model_fallbacks = [m for m in fallback_models_csv.split(",") if m]
text = cfg.read_text(encoding="utf-8")

if re.search(r"(?m)^default_provider\s*=", text):
    text = re.sub(r'(?m)^default_provider\s*=.*$', f'default_provider = "{provider}"', text, count=1)
else:
    text = f'default_provider = "{provider}"\n' + text

if re.search(r"(?m)^default_model\s*=", text):
    text = re.sub(r'(?m)^default_model\s*=.*$', f'default_model = "{model}"', text, count=1)
else:
    text = f'default_model = "{model}"\n' + text

fallback_value = "[]" if not fallbacks else "[" + ", ".join(f'"{p}"' for p in fallbacks) + "]"
if re.search(r"(?m)^fallback_providers\s*=", text):
    text = re.sub(r'(?m)^fallback_providers\s*=\s*\[.*\]\s*$', f"fallback_providers = {fallback_value}", text, count=1)
else:
    if re.search(r"(?m)^\[reliability\]\s*$", text):
        text = re.sub(r"(?m)^\[reliability\]\s*$", f"[reliability]\nfallback_providers = {fallback_value}", text, count=1)
    else:
        text += f"\n[reliability]\nfallback_providers = {fallback_value}\n"

# Normalize model fallback section for the currently selected model.
text = re.sub(
    r"(?ms)^\[reliability\.model_fallbacks\]\n.*?(?=^\[|\Z)",
    "",
    text,
)

section_lines = ["[reliability.model_fallbacks]"]
if model_fallbacks:
    fallbacks_value = "[" + ", ".join(f'"{m}"' for m in model_fallbacks) + "]"
    section_lines.append(f'"{model}" = {fallbacks_value}')
text = text.rstrip() + "\n\n" + "\n".join(section_lines) + "\n"

cfg.write_text(text, encoding="utf-8")
PY
}

ensure_preferred_provider_config

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
  if [[ -f "$ORCHESTRATOR_SERVER" ]]; then
    nohup python3 "$ORCHESTRATOR_SERVER" \
      --host 127.0.0.1 \
      --port "$FOLLOW_PORT" \
      --directory "$ART_DIR" \
      --root-dir "$ROOT_DIR" \
      --gateway-url "http://$GATEWAY_HOST:$GATEWAY_PORT" \
      --prom-url "http://$PROM_HOST:$PROM_PORT" \
      >"$FW_LOG" 2>&1 &
  else
    nohup python3 -m http.server "$FOLLOW_PORT" --bind 127.0.0.1 --directory "$ART_DIR" >"$FW_LOG" 2>&1 &
  fi
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
  <title>ZeroClaw Orchestrator</title>
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
    .alert-banner {
      border: 1px solid #d97706;
      background: #fff7ed;
      color: #9a3412;
      border-radius: 10px;
      padding: 8px 10px;
      margin-bottom: 12px;
      font-size: 13px;
      display: none;
    }
    .alert-banner.show {
      display: block;
    }
    .ops-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 12px;
      margin-bottom: 12px;
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
    .panel .body {
      padding: 12px 14px;
      display: flex;
      flex-direction: column;
      gap: 10px;
      flex: 1;
    }
    .panel pre {
      margin: 0;
      padding: 10px 12px;
      overflow: auto;
      white-space: pre-wrap;
      word-break: break-word;
      font-family: ui-monospace, "SFMono-Regular", Menlo, Consolas, monospace;
      font-size: 12px;
      line-height: 1.4;
      flex: 1;
      background: #fafbfd;
      border: 1px solid var(--line);
      border-radius: 8px;
    }
    textarea {
      width: 100%;
      min-height: 64px;
      resize: vertical;
      padding: 8px;
      font-size: 13px;
      border: 1px solid var(--line);
      border-radius: 8px;
      font-family: "SF Pro Text", "Segoe UI", Arial, sans-serif;
    }
    .btn-row {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
    }
    button {
      border: 1px solid var(--line);
      background: #fdfefe;
      color: var(--ink);
      border-radius: 8px;
      padding: 8px 10px;
      cursor: pointer;
      font-size: 12px;
    }
    button.primary {
      border-color: #245fa1;
      color: #fff;
      background: #245fa1;
    }
    button:disabled {
      opacity: 0.5;
      cursor: not-allowed;
    }
    .hint {
      color: var(--muted);
      font-size: 12px;
      margin: 0;
    }
    .status-block {
      color: var(--muted);
      font-size: 12px;
      border: 1px dashed var(--line);
      border-radius: 8px;
      padding: 8px 10px;
    }
    .questions-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 12px;
      margin-bottom: 12px;
    }
    .question-item {
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 8px;
      background: #fcfdff;
      margin-bottom: 8px;
    }
    .question-item.blocking {
      border-color: #f59e0b;
      background: #fffaf0;
    }
    .question-title {
      font-size: 13px;
      font-weight: 600;
      margin-bottom: 4px;
    }
    .question-meta {
      font-size: 11px;
      color: var(--muted);
      margin-bottom: 6px;
    }
    .question-context {
      font-size: 12px;
      white-space: pre-wrap;
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 6px;
      background: #fff;
      margin-bottom: 8px;
    }
    .question-answer {
      min-height: 52px;
      margin-bottom: 6px;
    }
    .modal {
      position: fixed;
      inset: 0;
      background: rgba(15, 23, 42, 0.5);
      display: none;
      align-items: center;
      justify-content: center;
      z-index: 9999;
      padding: 16px;
    }
    .modal.open {
      display: flex;
    }
    .modal-card {
      width: min(760px, 100%);
      background: #fff;
      border: 1px solid var(--line);
      border-radius: 12px;
      box-shadow: 0 12px 40px rgba(17, 26, 41, 0.25);
      padding: 14px;
    }
    .modal-card h3 {
      margin: 0 0 8px;
      font-size: 18px;
    }
    .modal-card .small {
      margin: 0 0 8px;
      font-size: 12px;
      color: var(--muted);
    }
    .status {
      margin-top: 10px;
      color: var(--muted);
      font-size: 12px;
    }
    @media (max-width: 980px) {
      .ops-grid { grid-template-columns: 1fr; }
      .questions-grid { grid-template-columns: 1fr; }
      .grid { grid-template-columns: 1fr; }
      .panel { min-height: 320px; }
    }
  </style>
</head>
<body>
  <main>
    <h1>ZeroClaw Orchestrator</h1>
    <div class="meta">
      Follow URL: <code>http://127.0.0.1:$FOLLOW_PORT/</code> |
      Polling interval: <code>1s</code> |
      Display cap: <code>500 lines/panel</code> |
      Prometheus: <code>$PROM_STATUS</code> |
      API: <code>/api/status</code> <code>/api/run</code>
    </div>
    <div id="questionAlert" class="alert-banner"></div>
    <div class="links">
      <a href="/conversations.jsonl">/conversations.jsonl</a>
      <a href="/gateway.log">/gateway.log</a>
      <a href="/realtime_1min.log">/realtime_1min.log</a>
      <a href="/orchestrator.log">/orchestrator.log</a>
      <a href="/prometheus.yml">/prometheus.yml</a>
      <a href="http://$GATEWAY_HOST:$GATEWAY_PORT/health">/health</a>
      <a href="http://$GATEWAY_HOST:$GATEWAY_PORT/metrics">/metrics</a>
      <a href="http://$PROM_HOST:$PROM_PORT/targets">prometheus /targets</a>
      <a href="http://$PROM_HOST:$PROM_PORT/graph">prometheus /graph</a>
    </div>
    <div class="ops-grid">
      <section class="panel">
        <h2>Orchestration Controls</h2>
        <div class="body">
          <p class="hint">Prompt general (source)</p>
          <textarea id="generalPromptInput">Autonomy heartbeat: return concise status and blockers</textarea>
          <div class="btn-row">
            <button onclick="setGeneralPrompt('RTC post-flash check: verify audio wifi status and recent errors')">General RTC Quick</button>
            <button onclick="setGeneralPrompt('Zacus post-flash check: verify network ui audio story state and recent errors')">General Zacus Quick</button>
            <button onclick="setGeneralPrompt('Autonomy heartbeat: return concise status and blockers')">General Heartbeat</button>
            <button onclick="deriveRepoPrompts()">Generate RTC+Zacus Prompts</button>
            <button class="primary" onclick="runAction('general_prompt_fanout', true)">Send General -> RTC+Zacus</button>
          </div>
          <p class="hint">Prompt RTC</p>
          <textarea id="rtcPromptInput">RTC post-flash check: verify audio wifi status and recent errors</textarea>
          <p class="hint">Prompt Zacus</p>
          <textarea id="zacusPromptInput">Zacus post-flash check: verify network ui audio story state and recent errors</textarea>
          <div class="btn-row">
            <button onclick="runAction('rtc_webhook', true)">Send RTC Prompt</button>
            <button onclick="runAction('zacus_webhook', true)">Send Zacus Prompt</button>
          </div>
          <p class="hint">Operator presets (one-click chains with progress in Job panel)</p>
          <div class="btn-row">
            <button class="primary" onclick="runPreset('rtc_operator_chain', 'RTC post-flash check: verify audio wifi status and recent errors', true)">Run RTC Operator Chain</button>
            <button class="primary" onclick="runPreset('zacus_operator_chain', 'Zacus post-flash check: verify network ui audio story state and recent errors', true)">Run Zacus Operator Chain</button>
            <button class="primary" onclick="runPreset('daily_chain', '', false)">Run Daily Chain</button>
          </div>
          <div class="btn-row">
            <button onclick="runAction('provider_scan', false)">Provider Scan</button>
            <button onclick="runAction('rtc_provider_check', false)">RTC Provider Check</button>
            <button onclick="runAction('zacus_provider_check', false)">Zacus Provider Check</button>
            <button onclick="runAction('rtc_firmware_loop', false)">RTC Build/Flash/Monitor</button>
            <button onclick="runAction('zacus_firmware_loop', false)">Zacus Build/Flash/Monitor</button>
            <button onclick="stopJob()">Stop Current Job</button>
          </div>
          <div class="status-block" id="opsStatus">Waiting for API status...</div>
        </div>
      </section>
      <section class="panel">
        <h2>Job Progress</h2>
        <div class="body">
          <pre id="jobInfo">No job yet.</pre>
          <pre id="jobTail">(job output)</pre>
        </div>
      </section>
    </div>
    <div class="questions-grid">
      <section class="panel">
        <h2>Questions / Decisions</h2>
        <div class="body">
          <p class="hint">Create a blocking question when a decision is needed.</p>
          <textarea id="questionTitleInput">Decision needed</textarea>
          <textarea id="questionContextInput">Context and current blocker...</textarea>
          <textarea id="questionOptionsInput">A | B | C</textarea>
          <textarea id="questionRecommendationInput">Recommended: B</textarea>
          <div class="btn-row">
            <label class="hint"><input type="checkbox" id="questionBlockingInput" checked> blocking</label>
            <button class="primary" onclick="raiseQuestion()">Raise Question</button>
            <button onclick="refreshQuestions()">Refresh Questions</button>
          </div>
          <div class="status-block" id="questionsSummary">No questions loaded.</div>
        </div>
      </section>
      <section class="panel">
        <h2>Open Questions</h2>
        <div class="body">
          <div id="openQuestions">(no open questions)</div>
        </div>
      </section>
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
  <div id="questionPopup" class="modal">
    <div class="modal-card">
      <h3>Blocking Question</h3>
      <p class="small" id="popupMeta"></p>
      <pre id="popupBody"></pre>
      <div class="btn-row">
        <button onclick="closeQuestionPopup()">Close</button>
      </div>
    </div>
  </div>
  <script>
    const MAX_LINES = 500;
    const POLL_MS = 1000;
    const API_POLL_MS = 1500;

    let convoCount = 0;
    let gatewayCount = 0;
    let convoBuf = [];
    let gatewayBuf = [];
    let lastOk = null;
    let runInFlight = false;
    let lastPopupQuestionId = Number(localStorage.getItem("zc_last_popup_question_id") || "0");

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

    async function fetchJson(url) {
      const response = await fetch(url + "?t=" + Date.now(), { cache: "no-store" });
      const body = await response.text();
      let parsed = {};
      try {
        parsed = body ? JSON.parse(body) : {};
      } catch (error) {
        parsed = { raw: body };
      }
      if (!response.ok) {
        const msg = parsed.error || ("HTTP " + response.status);
        throw new Error(msg);
      }
      return parsed;
    }

    function boolText(value) {
      if (value === true) return "yes";
      if (value === false) return "no";
      return "unknown";
    }

    function closeQuestionPopup() {
      document.getElementById("questionPopup").classList.remove("open");
    }

    function showQuestionPopup(question) {
      if (!question) return;
      const meta =
        "id=" + safeText(question.id) +
        " blocking=" + boolText(question.blocking) +
        " created=" + safeText(question.created_at);
      let body = safeText(question.title);
      if (question.context) body += "\n\n" + safeText(question.context);
      const options = Array.isArray(question.options) ? question.options : [];
      if (options.length) body += "\n\nOptions: " + options.join(" | ");
      if (question.recommendation) body += "\nRecommendation: " + safeText(question.recommendation);
      document.getElementById("popupMeta").textContent = meta;
      document.getElementById("popupBody").textContent = body;
      document.getElementById("questionPopup").classList.add("open");
    }

    function renderOpenQuestions(openItems) {
      const root = document.getElementById("openQuestions");
      root.innerHTML = "";
      if (!openItems.length) {
        root.textContent = "(no open questions)";
        return;
      }
      for (const q of openItems) {
        const box = document.createElement("div");
        box.className = "question-item" + (q.blocking ? " blocking" : "");

        const title = document.createElement("div");
        title.className = "question-title";
        title.textContent = "#" + safeText(q.id) + " " + safeText(q.title);
        box.appendChild(title);

        const meta = document.createElement("div");
        meta.className = "question-meta";
        meta.textContent = "blocking=" + boolText(q.blocking) + " created=" + safeText(q.created_at);
        box.appendChild(meta);

        const ctx = document.createElement("div");
        ctx.className = "question-context";
        let ctxText = safeText(q.context || "");
        const options = Array.isArray(q.options) ? q.options : [];
        if (options.length) ctxText += (ctxText ? "\n" : "") + "Options: " + options.join(" | ");
        if (q.recommendation) ctxText += (ctxText ? "\n" : "") + "Recommendation: " + safeText(q.recommendation);
        ctx.textContent = ctxText || "(no context)";
        box.appendChild(ctx);

        const answer = document.createElement("textarea");
        answer.className = "question-answer";
        answer.id = "q-answer-" + safeText(q.id);
        answer.placeholder = "Decision / answer...";
        box.appendChild(answer);

        const row = document.createElement("div");
        row.className = "btn-row";
        const resolveBtn = document.createElement("button");
        resolveBtn.textContent = "Resolve";
        resolveBtn.onclick = function () {
          resolveQuestion(q.id);
        };
        const popupBtn = document.createElement("button");
        popupBtn.textContent = "Popup";
        popupBtn.onclick = function () {
          showQuestionPopup(q);
        };
        row.appendChild(resolveBtn);
        row.appendChild(popupBtn);
        box.appendChild(row);

        root.appendChild(box);
      }
    }

    async function refreshQuestions() {
      try {
        const data = await fetchJson("/api/questions");
        const openItems = Array.isArray(data.open_items) ? data.open_items : [];
        const summary =
          "open=" + safeText(data.open_count) +
          " blocking_open=" + safeText(data.blocking_open_count) +
          " total=" + safeText(Array.isArray(data.items) ? data.items.length : 0);
        document.getElementById("questionsSummary").textContent = summary;
        renderOpenQuestions(openItems);

        const alertBox = document.getElementById("questionAlert");
        if ((data.blocking_open_count || 0) > 0) {
          alertBox.classList.add("show");
          alertBox.textContent = "Blocking question open: " + safeText(data.blocking_open_count) + " (see Questions / Decisions)";
        } else {
          alertBox.classList.remove("show");
          alertBox.textContent = "";
        }

        const latest = data.latest_open;
        if (latest && latest.blocking && Number(latest.id) > lastPopupQuestionId) {
          lastPopupQuestionId = Number(latest.id);
          localStorage.setItem("zc_last_popup_question_id", String(lastPopupQuestionId));
          showQuestionPopup(latest);
          window.alert("New blocking question #" + safeText(latest.id) + ": " + safeText(latest.title));
        }
      } catch (error) {
        document.getElementById("questionsSummary").textContent = "questions api error: " + error.message;
      }
    }

    async function raiseQuestion() {
      const payload = {
        title: document.getElementById("questionTitleInput").value.trim(),
        context: document.getElementById("questionContextInput").value.trim(),
        options: document.getElementById("questionOptionsInput").value.trim(),
        recommendation: document.getElementById("questionRecommendationInput").value.trim(),
        blocking: document.getElementById("questionBlockingInput").checked,
      };
      try {
        const response = await fetch("/api/questions", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        });
        const body = await response.text();
        let parsed = {};
        try {
          parsed = body ? JSON.parse(body) : {};
        } catch (error) {
          parsed = { raw: body };
        }
        if (!response.ok) {
          throw new Error(parsed.error || ("HTTP " + response.status));
        }
        setStatus("question raised", false);
        await refreshQuestions();
      } catch (error) {
        setStatus("raise question failed: " + error.message, true);
      }
    }

    async function resolveQuestion(id) {
      const input = document.getElementById("q-answer-" + safeText(id));
      const responseText = input ? input.value.trim() : "";
      try {
        const response = await fetch("/api/questions/resolve", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ id: id, response: responseText }),
        });
        const body = await response.text();
        let parsed = {};
        try {
          parsed = body ? JSON.parse(body) : {};
        } catch (error) {
          parsed = { raw: body };
        }
        if (!response.ok) {
          throw new Error(parsed.error || ("HTTP " + response.status));
        }
        setStatus("question resolved #" + safeText(id), false);
        await refreshQuestions();
      } catch (error) {
        setStatus("resolve question failed: " + error.message, true);
      }
    }

    async function refreshOps() {
      try {
        const status = await fetchJson("/api/status");
        const health = status.health || {};
        const last = status.last || {};
        const job = status.job || {};
        const ops =
          "gateway_ok=" + boolText(health.gateway_ok) +
          " status=" + safeText(health.gateway_status) +
          " paired=" + boolText(health.paired) +
          " prom_ok=" + boolText(health.prometheus_ok) +
          " prom_status=" + safeText(health.prometheus_status) +
          "\nlast_convo: " + safeText(last.conversation || "(none)") +
          "\nlast_rt1m: " + safeText(last.realtime_1min || "(none)");
        document.getElementById("opsStatus").textContent = ops;

        const jobInfo =
          "job_id=" + safeText(job.job_id) +
          " running=" + boolText(job.running) +
          " action=" + safeText(job.action) +
          "\nstarted_at=" + safeText(job.started_at) +
          " ended_at=" + safeText(job.ended_at) +
          " returncode=" + safeText(job.returncode);
        document.getElementById("jobInfo").textContent = jobInfo;
        const tail = Array.isArray(job.tail) ? job.tail : [];
        document.getElementById("jobTail").textContent = tail.length ? tail.join("\n") : "(job output)";
      } catch (error) {
        document.getElementById("opsStatus").textContent = "api status error: " + error.message;
      }
    }

    function setButtonsDisabled(disabled) {
      const buttons = document.querySelectorAll("button");
      for (const btn of buttons) {
        btn.disabled = disabled;
      }
    }

    function setGeneralPrompt(text) {
      document.getElementById("generalPromptInput").value = text;
      setStatus("general prompt template loaded", false);
    }

    function deriveRepoPrompts() {
      const general = document.getElementById("generalPromptInput").value.trim();
      if (!general) {
        setStatus("general prompt is required", true);
        return;
      }
      const rtcPrompt =
        general +
        "\\nContexte cible: RTC_BL_PHONE sur ESP32 Audio Kit." +
        "\\nAttendu: diagnostic audio/Bluetooth/WiFi/WebServer + erreurs recentes + prochaine action concise.";
      const zacusPrompt =
        general +
        "\\nContexte cible: le-mystere-professeur-zacus sur Freenove ESP32-S3 (usbmodem)." +
        "\\nAttendu: diagnostic UI/story/audio/network + erreurs recentes + prochaine action concise.";
      document.getElementById("rtcPromptInput").value = rtcPrompt;
      document.getElementById("zacusPromptInput").value = zacusPrompt;
      setStatus("rtc/zacus prompts generated from general prompt", false);
    }

    function getPromptForAction(action) {
      if (action === "rtc_webhook" || action === "rtc_operator_chain") {
        return document.getElementById("rtcPromptInput").value.trim();
      }
      if (action === "zacus_webhook" || action === "zacus_operator_chain") {
        return document.getElementById("zacusPromptInput").value.trim();
      }
      if (action === "general_prompt_fanout") {
        return document.getElementById("generalPromptInput").value.trim();
      }
      return document.getElementById("generalPromptInput").value.trim();
    }

    async function runPreset(action, defaultPrompt, needsMessage) {
      if (needsMessage) {
        let input = null;
        if (action === "rtc_operator_chain") input = document.getElementById("rtcPromptInput");
        if (action === "zacus_operator_chain") input = document.getElementById("zacusPromptInput");
        if (!input) input = document.getElementById("generalPromptInput");
        if (!input.value.trim() && defaultPrompt) {
          input.value = defaultPrompt;
        }
      }
      await runAction(action, needsMessage);
    }

    async function runAction(action, needsMessage) {
      if (runInFlight) return;
      const payload = { action: action };
      if (needsMessage) {
        const message = getPromptForAction(action);
        if (!message) {
          setStatus("prompt is required for " + action, true);
          return;
        }
        payload.message = message;
      }
      runInFlight = true;
      setButtonsDisabled(true);
      try {
        const response = await fetch("/api/run", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        });
        const body = await response.text();
        let parsed = {};
        try {
          parsed = body ? JSON.parse(body) : {};
        } catch (error) {
          parsed = { raw: body };
        }
        if (!response.ok) {
          throw new Error(parsed.error || ("HTTP " + response.status));
        }
        setStatus("action started: " + action, false);
      } catch (error) {
        setStatus("action failed: " + action + " -> " + error.message, true);
      } finally {
        runInFlight = false;
        setButtonsDisabled(false);
        await refreshOps();
      }
    }

    async function stopJob() {
      try {
        const response = await fetch("/api/stop", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: "{}",
        });
        const body = await response.text();
        let parsed = {};
        try {
          parsed = body ? JSON.parse(body) : {};
        } catch (error) {
          parsed = { raw: body };
        }
        if (!response.ok) {
          throw new Error(parsed.error || ("HTTP " + response.status));
        }
        setStatus("job stop requested", false);
      } catch (error) {
        setStatus("stop failed: " + error.message, true);
      } finally {
        await refreshOps();
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
    refreshOps();
    setInterval(refreshOps, API_POLL_MS);
    refreshQuestions();
    setInterval(refreshQuestions, API_POLL_MS);
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
