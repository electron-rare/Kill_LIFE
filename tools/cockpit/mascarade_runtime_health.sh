#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEFAULT_HOST="kxkm@kxkm-ai"
DEFAULT_AGENT="kxkm-fallback-safe"
DEFAULT_LOG_DIR="$ROOT_DIR/artifacts/ops/mascarade_runtime_health"
SSH_CONNECT_TIMEOUT=6

HOST="$DEFAULT_HOST"
AGENT="$DEFAULT_AGENT"
LOG_DIR="$DEFAULT_LOG_DIR"
OUTPUT_MODE="text"

usage() {
  cat <<'EOF'
Usage: mascarade_runtime_health.sh [options]

Options:
  --host <user@host>   Remote host to inspect (default: kxkm@kxkm-ai)
  --agent <name>       Agent used for low-cost smoke (default: kxkm-fallback-safe)
  --log-dir <path>     Artifact directory (default: artifacts/ops/mascarade_runtime_health)
  --json               Emit cockpit-v1 JSON to stdout
  --help               Show this help
EOF
}

mkdir_safe() {
  mkdir -p "$1"
}

timestamp_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

timestamp_slug() {
  date -u +"%Y%m%dT%H%M%SZ"
}

json_from_py() {
  python3 - "$@"
}

copy_latest_artifacts() {
  cp "$RUN_LOG" "$LOG_DIR/latest.log"
  cp "$RUN_JSON" "$LOG_DIR/latest.json"
}

append_reason() {
  DEGRADED_REASONS+=("$1")
}

append_next_step() {
  NEXT_STEPS+=("$1")
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      [[ $# -ge 2 ]] || {
        echo "Missing value for --host" >&2
        exit 2
      }
      HOST="$2"
      shift 2
      ;;
    --agent)
      [[ $# -ge 2 ]] || {
        echo "Missing value for --agent" >&2
        exit 2
      }
      AGENT="$2"
      shift 2
      ;;
    --log-dir)
      [[ $# -ge 2 ]] || {
        echo "Missing value for --log-dir" >&2
        exit 2
      }
      LOG_DIR="$2"
      shift 2
      ;;
    --json)
      OUTPUT_MODE="json"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

mkdir_safe "$LOG_DIR"

RUN_ID="$(timestamp_slug)"
RUN_LOG="$LOG_DIR/$RUN_ID.log"
RUN_JSON="$LOG_DIR/$RUN_ID.json"
SMOKE_CAPTURE="$LOG_DIR/$RUN_ID.smoke.json"
REMOTE_CAPTURE="$LOG_DIR/$RUN_ID.remote.txt"
ROUTING_CAPTURE="$LOG_DIR/$RUN_ID.routing.json"
MEMORY_CAPTURE="$LOG_DIR/$RUN_ID.memory.json"

touch "$RUN_LOG"

log() {
  printf '[%s] %s\n' "$(timestamp_utc)" "$*" | tee -a "$RUN_LOG" >&2
}

SSH_OK="ko"
DOCKER_STATUS="unknown"
API_AGENTS_STATUS="unknown"
OLLAMA_TAGS_STATUS="unknown"
AGENT_SMOKE_STATUS="unknown"
AGENT_SMOKE_PROVIDER=""
AGENT_SMOKE_MODEL=""
ROUTING_STATUS="unknown"
MEMORY_STATUS="unknown"
TRUST_LEVEL="inferred"
RESUME_REF="kill-life:mascarade-runtime-health:${RUN_ID}:${HOST}:${AGENT}"
STATUS="ok"
CONTRACT_STATUS="ready"

declare -A CONTAINERS=(
  ["mascarade-api"]="unknown"
  ["mascarade-core"]="unknown"
  ["mascarade-ollama-runtime"]="unknown"
)

declare -a DEGRADED_REASONS=()
declare -a NEXT_STEPS=()
declare -a ARTIFACTS=()

ARTIFACTS+=("$RUN_LOG")
ARTIFACTS+=("$RUN_JSON")

log "Checking Mascarade runtime on $HOST"

REMOTE_SCRIPT='
set -eu
if command -v docker >/dev/null 2>&1; then
  echo "docker=ok"
  running="$(docker ps --format "{{.Names}}" 2>/dev/null || true)"
  existing="$(docker ps -a --format "{{.Names}}" 2>/dev/null || true)"
else
  echo "docker=missing"
  running=""
  existing=""
fi
for name in mascarade-api mascarade-core mascarade-ollama-runtime; do
  if printf "%s\n" "$running" | grep -Fxq "$name"; then
    echo "container:$name:running"
  elif printf "%s\n" "$existing" | grep -Fxq "$name"; then
    echo "container:$name:stopped"
  else
    echo "container:$name:missing"
  fi
done
api_agents_code="$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://127.0.0.1:3100/api/agents || true)"
if [[ "$api_agents_code" == "200" || "$api_agents_code" == "401" ]] || curl -fsS --max-time 5 http://127.0.0.1:3100/health >/dev/null 2>&1; then
  echo "api_agents=ok"
else
  echo "api_agents=ko"
fi
if curl -fsS --max-time 5 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
  echo "ollama_tags=ok"
else
  echo "ollama_tags=ko"
fi
'

if ssh -o BatchMode=yes -o ConnectTimeout="$SSH_CONNECT_TIMEOUT" "$HOST" "bash -s" >"$REMOTE_CAPTURE" 2>>"$RUN_LOG" <<<"$REMOTE_SCRIPT"; then
  SSH_OK="ok"
  ARTIFACTS+=("$REMOTE_CAPTURE")
  while IFS= read -r line; do
    case "$line" in
      docker=ok)
        DOCKER_STATUS="ok"
        ;;
      docker=missing)
        DOCKER_STATUS="missing"
        append_reason "docker indisponible sur $HOST"
        append_next_step "Installer ou rétablir Docker sur $HOST si Mascarade doit rester containerisé."
        ;;
      container:mascarade-api:*)
        CONTAINERS["mascarade-api"]="${line##*:}"
        ;;
      container:mascarade-core:*)
        CONTAINERS["mascarade-core"]="${line##*:}"
        ;;
      container:mascarade-ollama-runtime:*)
        CONTAINERS["mascarade-ollama-runtime"]="${line##*:}"
        ;;
      api_agents=ok)
        API_AGENTS_STATUS="ok"
        ;;
      api_agents=ko)
        API_AGENTS_STATUS="ko"
        append_reason "l'API agents Mascarade ne répond pas sur $HOST"
        append_next_step "Vérifier mascarade-api/mascarade-core et l'exposition locale 127.0.0.1:3100."
        ;;
      ollama_tags=ok)
        OLLAMA_TAGS_STATUS="ok"
        ;;
      ollama_tags=ko)
        OLLAMA_TAGS_STATUS="ko"
        append_reason "le runtime Ollama ne répond pas sur $HOST"
        append_next_step "Contrôler mascarade-ollama-runtime et l'endpoint 127.0.0.1:11434."
        ;;
    esac
  done <"$REMOTE_CAPTURE"
else
  SSH_OK="ko"
  DOCKER_STATUS="unreachable"
  API_AGENTS_STATUS="unreachable"
  OLLAMA_TAGS_STATUS="unreachable"
  CONTAINERS["mascarade-api"]="unreachable"
  CONTAINERS["mascarade-core"]="unreachable"
  CONTAINERS["mascarade-ollama-runtime"]="unreachable"
  append_reason "SSH indisponible vers $HOST"
  append_next_step "Relancer le health-check SSH mesh avant toute action Mascarade."
fi

if [[ -f "$ROOT_DIR/tools/ops/smoke_mascarade_agents_kxkm.sh" ]]; then
  if bash "$ROOT_DIR/tools/ops/smoke_mascarade_agents_kxkm.sh" --agents "$AGENT" --json >"$SMOKE_CAPTURE" 2>>"$RUN_LOG"; then
    ARTIFACTS+=("$SMOKE_CAPTURE")
    AGENT_SMOKE_STATUS="$(python3 - "$SMOKE_CAPTURE" <<'PY'
import json, sys
path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
except Exception:
    print("invalid")
    raise SystemExit(0)
status = data.get("status") or data.get("contract_status") or "ok"
if isinstance(status, str):
    print(status)
else:
    print("ok")
PY
)"
    AGENT_SMOKE_PROVIDER="$(python3 - "$SMOKE_CAPTURE" <<'PY'
import json, sys
path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
except Exception:
    print("")
    raise SystemExit(0)
provider = ""
model = ""
for key in ("provider", "preferred_provider"):
    if isinstance(data.get(key), str):
        provider = data[key]
        break
checks = data.get("checks")
if isinstance(checks, dict):
    smoke = checks.get("agent_smoke")
    if isinstance(smoke, dict):
        provider = smoke.get("provider") or provider
        model = smoke.get("model") or model
agents = data.get("agents")
if isinstance(agents, list) and agents:
    first = agents[0]
    if isinstance(first, dict):
        provider = first.get("provider") or provider
        model = first.get("model") or model
print(provider or "")
PY
)"
    AGENT_SMOKE_MODEL="$(python3 - "$SMOKE_CAPTURE" <<'PY'
import json, sys
path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
except Exception:
    print("")
    raise SystemExit(0)
model = data.get("model") if isinstance(data.get("model"), str) else ""
checks = data.get("checks")
if isinstance(checks, dict):
    smoke = checks.get("agent_smoke")
    if isinstance(smoke, dict):
        model = smoke.get("model") or model
agents = data.get("agents")
if isinstance(agents, list) and agents:
    first = agents[0]
    if isinstance(first, dict):
        model = first.get("model") or model
print(model or "")
PY
)"
  else
    AGENT_SMOKE_STATUS="ko"
    append_reason "le smoke agent $AGENT a échoué"
    append_next_step "Consulter $(basename "$SMOKE_CAPTURE") ou relancer smoke_mascarade_agents_kxkm.sh pour diagnostic ciblé."
  fi
else
  AGENT_SMOKE_STATUS="missing"
  append_reason "le script smoke_mascarade_agents_kxkm.sh est absent ou non exécutable"
  append_next_step "Rétablir l'outillage tools/ops/smoke_mascarade_agents_kxkm.sh avant l'automatisation complète."
fi

for container_name in "mascarade-api" "mascarade-core" "mascarade-ollama-runtime"; do
  state="${CONTAINERS[$container_name]}"
  case "$state" in
    running)
      ;;
    *)
      append_reason "conteneur $container_name en état $state"
      append_next_step "Contrôler $container_name sur $HOST puis republier si nécessaire."
      ;;
  esac
done

if [[ "$SSH_OK" != "ok" ]] || [[ "$API_AGENTS_STATUS" != "ok" ]] || [[ "$OLLAMA_TAGS_STATUS" != "ok" ]]; then
  STATUS="degraded"
  CONTRACT_STATUS="degraded"
fi

case "$AGENT_SMOKE_STATUS" in
  ok|ready|success)
    ;;
  *)
    STATUS="degraded"
    CONTRACT_STATUS="degraded"
    ;;
esac

if bash "$ROOT_DIR/tools/cockpit/mascarade_dispatch_mesh.sh" --action route --profile "$AGENT" --json >"$ROUTING_CAPTURE" 2>>"$RUN_LOG"; then
  ROUTING_STATUS="$(python3 - "$ROUTING_CAPTURE" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
try:
    data = json.loads(path.read_text(encoding="utf-8"))
except Exception:
    print("invalid")
    raise SystemExit(0)
print(data.get("status", "unknown"))
PY
)"
  ARTIFACTS+=("$ROUTING_CAPTURE")
else
  ROUTING_STATUS="failed"
  append_reason "le dispatch mesh Mascarade n'a pas pu etre calcule pour $AGENT"
  append_next_step "Relancer bash tools/cockpit/mascarade_dispatch_mesh.sh --action route --profile $AGENT --json."
fi

if [[ "$STATUS" == "ok" && "$ROUTING_STATUS" == "ok" ]]; then
  TRUST_LEVEL="verified"
elif [[ "$ROUTING_STATUS" == "ok" ]]; then
  TRUST_LEVEL="bounded"
else
  TRUST_LEVEL="inferred"
fi

if bash "$ROOT_DIR/tools/cockpit/write_kill_life_memory_entry.sh" \
  --component "mascarade_runtime_health" \
  --status "$CONTRACT_STATUS" \
  --owner "Runtime-Companion" \
  --decision-action "mascarade-runtime-health-check" \
  --decision-reason "Mascarade runtime state is checked against the active mesh routing contract." \
  --next-step "Review $RUN_JSON and continue from $RESUME_REF." \
  --resume-ref "$RESUME_REF" \
  --trust-level "$TRUST_LEVEL" \
  --routing-file "$ROUTING_CAPTURE" \
  --artifact "$RUN_LOG" \
  --artifact "$RUN_JSON" \
  --artifact "$SMOKE_CAPTURE" \
  --json >"$MEMORY_CAPTURE" 2>>"$RUN_LOG"; then
  MEMORY_STATUS="$(python3 - "$MEMORY_CAPTURE" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
try:
    data = json.loads(path.read_text(encoding="utf-8"))
except Exception:
    print("invalid")
    raise SystemExit(0)
print(data.get("status", "unknown"))
PY
)"
  ARTIFACTS+=("$MEMORY_CAPTURE")
else
  MEMORY_STATUS="failed"
  append_reason "la memoire kill_life n'a pas pu etre ecrite pour mascarade_runtime_health"
  append_next_step "Relancer bash tools/cockpit/write_kill_life_memory_entry.sh --component mascarade_runtime_health --json."
fi

RUN_AT="$(timestamp_utc)"

json_from_py \
  "$RUN_AT" \
  "$HOST" \
  "$AGENT" \
  "$STATUS" \
  "$CONTRACT_STATUS" \
  "$SSH_OK" \
  "$DOCKER_STATUS" \
  "$API_AGENTS_STATUS" \
  "$OLLAMA_TAGS_STATUS" \
  "$AGENT_SMOKE_STATUS" \
  "$AGENT_SMOKE_PROVIDER" \
  "$AGENT_SMOKE_MODEL" \
  "$RUN_LOG" \
  "$RUN_JSON" \
  "${CONTAINERS[mascarade-api]}" \
  "${CONTAINERS[mascarade-core]}" \
  "${CONTAINERS[mascarade-ollama-runtime]}" \
  "$ROUTING_CAPTURE" \
  "$ROUTING_STATUS" \
  "$MEMORY_CAPTURE" \
  "$MEMORY_STATUS" \
  "$TRUST_LEVEL" \
  "$RESUME_REF" \
  "${ARTIFACTS[@]}" \
  --reasons \
  "${DEGRADED_REASONS[@]}" \
  --next-steps \
  "${NEXT_STEPS[@]}" \
  <<'PY' >"$RUN_JSON"
import json
import sys
from pathlib import Path

run_at, host, agent, status, contract_status, ssh_ok, docker_status, api_agents_status, ollama_tags_status, agent_smoke_status, agent_smoke_provider, agent_smoke_model, run_log, run_json, api_container, core_container, ollama_container, routing_capture, routing_status, memory_capture, memory_status, trust_level, resume_ref, *tail = sys.argv[1:]

def split_sections(values):
    artifacts = []
    reasons = []
    next_steps = []
    mode = "artifacts"
    for value in values:
        if value == "--reasons":
            mode = "reasons"
            continue
        if value == "--next-steps":
            mode = "next_steps"
            continue
        if mode == "artifacts":
            artifacts.append(value)
        elif mode == "reasons":
            reasons.append(value)
        else:
            next_steps.append(value)
    return artifacts, reasons, next_steps

artifacts, degraded_reasons, next_steps = split_sections(tail)

def load_json(path_str):
    path = Path(path_str)
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}

routing = load_json(routing_capture)
memory = load_json(memory_capture)
memory_entry = memory.get("entry", {}) if isinstance(memory.get("entry"), dict) else {}

payload = {
    "contract_version": "cockpit-v1",
    "component": "mascarade-runtime-health",
    "action": "health-check",
    "status": status,
    "contract_status": contract_status,
    "checked_at": run_at,
    "host": host,
    "agent": agent,
    "owner": "Runtime-Companion",
    "decision": {
        "action": "mascarade-runtime-health-check",
        "reason": "Mascarade runtime state checked and projected on the active mesh routing contract."
    },
    "resume_ref": resume_ref,
    "trust_level": trust_level,
    "provider": agent_smoke_provider or "unknown",
    "model": agent_smoke_model or "unknown",
    "runtime_status": status,
    "routing_status": routing_status,
    "routing_artifact": routing_capture,
    "routing": routing,
    "memory_entry_status": memory_status,
    "memory_entry_artifact": memory_capture,
    "memory_entry": memory_entry,
    "checks": {
        "ssh": {"status": ssh_ok},
        "docker": {"status": docker_status},
        "api_agents": {"status": api_agents_status},
        "ollama_tags": {"status": ollama_tags_status},
        "agent_smoke": {
            "status": agent_smoke_status,
            "provider": agent_smoke_provider or "unknown",
            "model": agent_smoke_model or "unknown",
        },
        "containers": {
            "mascarade-api": api_container,
            "mascarade-core": core_container,
            "mascarade-ollama-runtime": ollama_container,
        },
    },
    "artifacts": artifacts,
    "degraded_reasons": degraded_reasons,
    "next_steps": next_steps,
    "log_file": run_log,
    "json_file": run_json,
}

print(json.dumps(payload, ensure_ascii=False, indent=2))
PY

copy_latest_artifacts

if [[ "$OUTPUT_MODE" == "json" ]]; then
  cat "$RUN_JSON"
else
  cat <<EOF
Mascarade runtime health
host: $HOST
status: $STATUS
agent smoke: $AGENT_SMOKE_STATUS (${AGENT_SMOKE_PROVIDER:-unknown}/${AGENT_SMOKE_MODEL:-unknown})
containers: api=${CONTAINERS[mascarade-api]} core=${CONTAINERS[mascarade-core]} ollama=${CONTAINERS[mascarade-ollama-runtime]}
artifacts:
  - $RUN_LOG
  - $RUN_JSON
EOF
  if [[ ${#DEGRADED_REASONS[@]} -gt 0 ]]; then
    printf 'degraded reasons:\n'
    printf '  - %s\n' "${DEGRADED_REASONS[@]}"
  fi
fi
