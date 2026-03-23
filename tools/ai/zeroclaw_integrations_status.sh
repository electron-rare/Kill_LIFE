#!/usr/bin/env bash
set -euo pipefail

N8N_CONTAINER="${ZEROCLAW_N8N_CONTAINER:-mascarade-n8n}"
N8N_URL="${ZEROCLAW_N8N_URL:-http://127.0.0.1:5678/}"
N8N_HEALTH_URL="${ZEROCLAW_N8N_HEALTH_URL:-${N8N_URL%/}/healthz}"
OUTPUT_JSON=0
TRACKED_WORKFLOW_ID="${ZEROCLAW_N8N_WORKFLOW_ID:-kill-life-n8n-smoke}"
DOCKER_TIMEOUT_SECS="${ZEROCLAW_N8N_DOCKER_TIMEOUT_SECS:-10}"
STATUS_VALUE="blocked"
STATUS_REASON="n8n_http_unreachable"
RUNTIME_ALERTS_CSV=""

docker_available() {
  command -v docker >/dev/null 2>&1 || return 1
  if [[ -n "${DOCKER_HOST:-}" ]]; then
    if [[ "$DOCKER_HOST" == unix://* ]]; then
      local socket_path
      socket_path="${DOCKER_HOST#unix://}"
      [ -S "$socket_path" ] || return 1
    fi
    return 0
  fi

  [ -S "/Users/electron/.docker/run/docker.sock" ] || [ -S "/var/run/docker.sock" ] || [ -S "${HOME}/.docker/run/docker.sock" ] || return 1
}

docker_cmd_timeout() {
  python3 - "${DOCKER_TIMEOUT_SECS}" "$@" <<'PY'
import subprocess
import sys

timeout = float(sys.argv[1])
cmd = sys.argv[2:]
try:
    proc = subprocess.run(cmd, text=True, capture_output=True, timeout=timeout, check=False)
except subprocess.TimeoutExpired:
    sys.stderr.write("docker_timeout\n")
    raise SystemExit(124)

sys.stdout.write(proc.stdout)
sys.stderr.write(proc.stderr)
raise SystemExit(proc.returncode)
PY
}

probe_host_http() {
  curl --max-time 5 -fsSI "${N8N_URL}" >/dev/null 2>&1 || \
    curl --max-time 5 -fsS "${N8N_HEALTH_URL}" >/dev/null 2>&1
}

collect_runtime_alerts() {
  local logs=""
  local -a alerts=()

  if ! logs="$(docker_cmd_timeout docker logs --tail 120 "${N8N_CONTAINER}" 2>&1 || true)"; then
    return 0
  fi

  if grep -Fq "Database connection timed out" <<< "${logs}"; then
    alerts+=("n8n_database_timeout")
  fi
  if grep -Fq "has no node to start the workflow" <<< "${logs}"; then
    alerts+=("workflow_activation_invalid")
  fi

  printf '%s\n' "${alerts[@]}"
}

usage() {
  cat <<'EOF'
Usage: bash tools/ai/zeroclaw_integrations_status.sh [options]

Print the current local n8n integration status.

Options:
  --json       Emit JSON instead of text
  -h, --help   Show this help

Env overrides:
  ZEROCLAW_N8N_CONTAINER
  ZEROCLAW_N8N_URL
  ZEROCLAW_N8N_HEALTH_URL
  ZEROCLAW_N8N_WORKFLOW_ID
  ZEROCLAW_N8N_DOCKER_TIMEOUT_SECS
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      OUTPUT_JSON=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

container_exists=false
container_running=false
container_status="missing"
internal_http_ok=false
host_http_ok=false
workflow_ids=""
active_ids=""
docker_unavailable=0
workflow_probe_status="not_queried"
active_probe_status="not_queried"

if docker_available; then
  if ! container_line="$(docker_cmd_timeout docker ps -a --filter "name=^/${N8N_CONTAINER}$" --format '{{.Names}}|{{.Status}}' 2>/dev/null | head -n 1)"; then
    container_status="docker cli timeout"
    container_line=""
  fi
  if ! running_line="$(docker_cmd_timeout docker ps --filter "name=^/${N8N_CONTAINER}$" --format '{{.Names}}|{{.Status}}' 2>/dev/null | head -n 1)"; then
    container_status="docker cli timeout"
    running_line=""
  fi

  if [[ "${container_status}" != "docker cli timeout" && -n "${container_line}" ]]; then
    container_exists=true
    container_status="${container_line#*|}"
  fi

  if [[ "${container_status}" != "docker cli timeout" && -n "${running_line}" ]]; then
    container_running=true
  fi

else
  container_exists=false
  container_running=false
  container_status="docker unavailable"
  docker_unavailable=1
fi

if probe_host_http; then
  host_http_ok=true
  internal_http_ok=true
  container_exists=true
  container_running=true
  if [[ "${container_status}" == "missing" ]]; then
    container_status="host http ok (container unverified)"
  elif [[ "${container_status}" == "docker cli timeout" ]]; then
    container_status="docker cli timeout (host http ok)"
  elif [[ "${container_status}" == "docker unavailable" ]]; then
    container_status="docker unavailable (host http ok)"
  fi
fi

if [[ "${host_http_ok}" == true ]]; then
  if [[ "${container_status}" == docker\ cli\ timeout* || "${container_status}" == docker\ unavailable* ]]; then
    STATUS_VALUE="degraded"
    STATUS_REASON="runtime_reachable_docker_unavailable"
  else
    STATUS_VALUE="ready"
    STATUS_REASON=""
  fi
elif [[ "${container_status}" == "docker cli timeout" ]]; then
  STATUS_VALUE="blocked"
  STATUS_REASON="docker_cli_timeout"
elif [[ "${docker_unavailable}" == "1" ]]; then
  STATUS_VALUE="degraded"
  STATUS_REASON="docker_unavailable"
fi

if [[ "${host_http_ok}" != true && "${container_running}" == true ]]; then
  RUNTIME_ALERTS_CSV="$(
    collect_runtime_alerts \
      | python3 -c 'import json,sys; items=[line.strip() for line in sys.stdin if line.strip()]; print(",".join(items))'
  )"
  if [[ ",${RUNTIME_ALERTS_CSV}," == *",n8n_database_timeout,"* ]]; then
    STATUS_REASON="n8n_database_timeout"
  elif [[ ",${RUNTIME_ALERTS_CSV}," == *",workflow_activation_invalid,"* ]]; then
    STATUS_REASON="workflow_activation_invalid"
  fi
fi

if [[ "${OUTPUT_JSON}" == "1" ]]; then
  CONTAINER_EXISTS="${container_exists}" \
  CONTAINER_RUNNING="${container_running}" \
  INTERNAL_HTTP_OK="${internal_http_ok}" \
  HOST_HTTP_OK="${host_http_ok}" \
  python3 - <<PY
import json
import os
print(json.dumps({
    "status": ${STATUS_VALUE@Q},
    "reason": ${STATUS_REASON@Q},
    "container": ${N8N_CONTAINER@Q},
    "container_exists": os.environ["CONTAINER_EXISTS"] == "true",
    "container_running": os.environ["CONTAINER_RUNNING"] == "true",
    "container_status": ${container_status@Q},
    "internal_http_ok": os.environ["INTERNAL_HTTP_OK"] == "true",
    "host_http_ok": os.environ["HOST_HTTP_OK"] == "true",
    "n8n_url": ${N8N_URL@Q},
    "n8n_health_url": ${N8N_HEALTH_URL@Q},
    "tracked_workflow_id": ${TRACKED_WORKFLOW_ID@Q},
    "runtime_alerts": [item for item in ${RUNTIME_ALERTS_CSV@Q}.split(",") if item],
    "workflow_probe_status": ${workflow_probe_status@Q},
    "active_probe_status": ${active_probe_status@Q},
    "workflow_ids": [item for item in ${workflow_ids@Q}.split(",") if item],
    "active_workflow_ids": [item for item in ${active_ids@Q}.split(",") if item],
}, ensure_ascii=True))
PY
  exit 0
fi

echo "container=${N8N_CONTAINER}"
echo "exists=${container_exists}"
echo "running=${container_running}"
echo "status=${container_status}"
echo "overall_status=${STATUS_VALUE}"
echo "reason=${STATUS_REASON:-"(none)"}"
echo "internal_http_ok=${internal_http_ok}"
echo "host_http_ok=${host_http_ok}"
echo "n8n_url=${N8N_URL}"
echo "n8n_health_url=${N8N_HEALTH_URL}"
echo "runtime_alerts=${RUNTIME_ALERTS_CSV:-"(none)"}"
echo "tracked_workflow_id=${TRACKED_WORKFLOW_ID}"
echo "workflow_probe_status=${workflow_probe_status}"
echo "active_probe_status=${active_probe_status}"
echo "workflow_ids=${workflow_ids:-"(none)"}"
echo "active_workflow_ids=${active_ids:-"(none)"}"
