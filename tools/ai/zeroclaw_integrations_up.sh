#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

N8N_CONTAINER="${ZEROCLAW_N8N_CONTAINER:-mascarade-n8n}"
WAIT_SECS="${ZEROCLAW_N8N_WAIT_SECS:-30}"
OUTPUT_JSON=0

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

running_line="$(docker ps --filter "name=^/${N8N_CONTAINER}$" --format '{{.Names}}' | head -n 1)"
existing_line="$(docker ps -a --filter "name=^/${N8N_CONTAINER}$" --format '{{.Names}}' | head -n 1)"

if [[ -n "${running_line}" ]]; then
  :
elif [[ -n "${existing_line}" ]]; then
  docker start "${N8N_CONTAINER}" >/dev/null
else
  echo "n8n container not found: ${N8N_CONTAINER}" >&2
  echo "Expected an already-provisioned companion runtime (for example mascarade-n8n)." >&2
  exit 1
fi

deadline=$((SECONDS + WAIT_SECS))
while (( SECONDS < deadline )); do
  if docker exec "${N8N_CONTAINER}" sh -lc 'which wget >/dev/null 2>&1 && wget -q -O /dev/null http://127.0.0.1:5678/'; then
    if [[ "${OUTPUT_JSON}" == "1" ]]; then
      bash "${ROOT_DIR}/tools/ai/zeroclaw_integrations_status.sh" --json
    else
      bash "${ROOT_DIR}/tools/ai/zeroclaw_integrations_status.sh"
    fi
    exit 0
  fi
  sleep 1
done

echo "n8n container did not become ready within ${WAIT_SECS}s: ${N8N_CONTAINER}" >&2
exit 1
