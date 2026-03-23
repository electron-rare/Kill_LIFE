#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

N8N_CONTAINER="${ZEROCLAW_N8N_CONTAINER:-mascarade-n8n}"
WAIT_SECS="${ZEROCLAW_N8N_WAIT_SECS:-30}"
N8N_IMAGE="${ZEROCLAW_N8N_IMAGE:-docker.n8n.io/n8nio/n8n}"
N8N_VOLUME="${ZEROCLAW_N8N_VOLUME:-${N8N_CONTAINER}-data}"
N8N_PORT="${ZEROCLAW_N8N_PORT:-5678}"
N8N_URL="${ZEROCLAW_N8N_URL:-http://127.0.0.1:${N8N_PORT}/}"
N8N_HEALTH_URL="${ZEROCLAW_N8N_HEALTH_URL:-${N8N_URL%/}/healthz}"
N8N_TIMEZONE="${ZEROCLAW_N8N_TIMEZONE:-${TZ:-Europe/Paris}}"
AUTO_PROVISION="${ZEROCLAW_N8N_AUTOPROVISION:-1}"
DOCKER_TIMEOUT_SECS="${ZEROCLAW_N8N_DOCKER_TIMEOUT_SECS:-20}"
OUTPUT_JSON=0

emit_runtime_json() {
  local status_value="$1"
  local reason_value="$2"
  python3 - <<PY
import json
print(json.dumps({
    "status": ${status_value@Q},
    "reason": ${reason_value@Q},
    "container": ${N8N_CONTAINER@Q},
    "container_state": "unverified",
    "n8n_url": ${N8N_URL@Q},
    "n8n_health_url": ${N8N_HEALTH_URL@Q},
}, ensure_ascii=True))
PY
}

probe_http_ready() {
  curl --max-time 5 -fsSI "${N8N_URL}" >/dev/null 2>&1 || \
    curl --max-time 5 -fsS "${N8N_HEALTH_URL}" >/dev/null 2>&1
}

emit_runtime_error() {
  local reason_value="$1"
  if [[ "${OUTPUT_JSON}" == "1" ]]; then
    emit_runtime_json "blocked" "${reason_value}"
    exit 0
  fi
  echo "${reason_value}" >&2
  exit 1
}

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

usage() {
  cat <<'EOF'
Usage: bash tools/ai/zeroclaw_integrations_up.sh [options]

Ensure the local n8n integration container is running.

Options:
  --json       Emit final status as JSON
  -h, --help   Show this help

Env overrides:
  ZEROCLAW_N8N_CONTAINER
  ZEROCLAW_N8N_WAIT_SECS
  ZEROCLAW_N8N_IMAGE
  ZEROCLAW_N8N_VOLUME
  ZEROCLAW_N8N_PORT
  ZEROCLAW_N8N_URL
  ZEROCLAW_N8N_HEALTH_URL
  ZEROCLAW_N8N_TIMEZONE
  ZEROCLAW_N8N_AUTOPROVISION
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

if ! docker_available; then
  if probe_http_ready; then
    if [[ "${OUTPUT_JSON}" == "1" ]]; then
      bash "${ROOT_DIR}/tools/ai/zeroclaw_integrations_status.sh" --json
    else
      bash "${ROOT_DIR}/tools/ai/zeroclaw_integrations_status.sh"
    fi
    exit 0
  fi
  if [[ "${OUTPUT_JSON}" == "1" ]]; then
    emit_runtime_json "degraded" "docker_unavailable"
    exit 0
  fi

  echo "status=degraded"
  echo "container=${N8N_CONTAINER}"
  echo "container_state=skipped"
  echo "reason=docker_unavailable"
  exit 0
fi

if probe_http_ready; then
  if [[ "${OUTPUT_JSON}" == "1" ]]; then
    bash "${ROOT_DIR}/tools/ai/zeroclaw_integrations_status.sh" --json
  else
    bash "${ROOT_DIR}/tools/ai/zeroclaw_integrations_status.sh"
  fi
  exit 0
fi

if ! running_line="$(docker_cmd_timeout docker ps --filter "name=^/${N8N_CONTAINER}$" --format '{{.Names}}' 2>/dev/null | head -n 1)"; then
  emit_runtime_error "docker_cli_timeout"
fi
if ! existing_line="$(docker_cmd_timeout docker ps -a --filter "name=^/${N8N_CONTAINER}$" --format '{{.Names}}' 2>/dev/null | head -n 1)"; then
  emit_runtime_error "docker_cli_timeout"
fi

if [[ -n "${running_line}" ]]; then
  if ! probe_http_ready; then
    if ! docker_cmd_timeout docker restart "${N8N_CONTAINER}" >/dev/null 2>/dev/null; then
      emit_runtime_error "docker_cli_timeout"
    fi
  fi
elif [[ -n "${existing_line}" ]]; then
  if ! docker_cmd_timeout docker start "${N8N_CONTAINER}" >/dev/null 2>/dev/null; then
    emit_runtime_error "docker_cli_timeout"
  fi
else
  if [[ "${AUTO_PROVISION}" != "1" ]]; then
    echo "n8n container not found: ${N8N_CONTAINER}" >&2
    echo "Expected an already-provisioned companion runtime (for example mascarade-n8n)." >&2
    exit 1
  fi

  if ! docker_cmd_timeout docker volume create "${N8N_VOLUME}" >/dev/null 2>/dev/null; then
    emit_runtime_error "docker_cli_timeout"
  fi
  if ! docker_cmd_timeout docker run -d \
    --name "${N8N_CONTAINER}" \
    -p "${N8N_PORT}:5678" \
    -e GENERIC_TIMEZONE="${N8N_TIMEZONE}" \
    -e TZ="${N8N_TIMEZONE}" \
    -e N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true \
    -v "${N8N_VOLUME}:/home/node/.n8n" \
    "${N8N_IMAGE}" >/dev/null 2>/dev/null; then
    emit_runtime_error "docker_cli_timeout"
  fi
fi

deadline=$((SECONDS + WAIT_SECS))
while (( SECONDS < deadline )); do
  if probe_http_ready; then
    if [[ "${OUTPUT_JSON}" == "1" ]]; then
      bash "${ROOT_DIR}/tools/ai/zeroclaw_integrations_status.sh" --json
    else
      bash "${ROOT_DIR}/tools/ai/zeroclaw_integrations_status.sh"
    fi
    exit 0
  fi
  sleep 1
done

if [[ "${OUTPUT_JSON}" == "1" ]]; then
  bash "${ROOT_DIR}/tools/ai/zeroclaw_integrations_status.sh" --json
  exit 1
fi

echo "n8n container did not become ready within ${WAIT_SECS}s: ${N8N_CONTAINER}" >&2
exit 1
