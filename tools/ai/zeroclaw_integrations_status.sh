#!/usr/bin/env bash
set -euo pipefail

N8N_CONTAINER="${ZEROCLAW_N8N_CONTAINER:-mascarade-n8n}"
N8N_URL="${ZEROCLAW_N8N_URL:-http://127.0.0.1:5678/}"
OUTPUT_JSON=0

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

container_line="$(docker ps -a --filter "name=^/${N8N_CONTAINER}$" --format '{{.Names}}|{{.Status}}' | head -n 1)"
running_line="$(docker ps --filter "name=^/${N8N_CONTAINER}$" --format '{{.Names}}|{{.Status}}' | head -n 1)"
container_exists=false
container_running=false
container_status="missing"
internal_http_ok=false
host_http_ok=false
workflow_ids=""
active_ids=""

if [[ -n "${container_line}" ]]; then
  container_exists=true
  container_status="${container_line#*|}"
fi

if [[ -n "${running_line}" ]]; then
  container_running=true
fi

if [[ "${container_running}" == true ]]; then
  if docker exec "${N8N_CONTAINER}" sh -lc 'which wget >/dev/null 2>&1 && wget -q -O /dev/null http://127.0.0.1:5678/'; then
    internal_http_ok=true
  fi

  if curl -fsSI "${N8N_URL}" >/dev/null 2>&1; then
    host_http_ok=true
  fi

  workflow_ids="$(docker exec "${N8N_CONTAINER}" n8n list:workflow --onlyId 2>/dev/null | sed '/^$/d' | paste -sd, - || true)"
  active_ids="$(docker exec "${N8N_CONTAINER}" n8n list:workflow --active=true --onlyId 2>/dev/null | sed '/^$/d' | paste -sd, - || true)"
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
    "container": ${N8N_CONTAINER@Q},
    "container_exists": os.environ["CONTAINER_EXISTS"] == "true",
    "container_running": os.environ["CONTAINER_RUNNING"] == "true",
    "container_status": ${container_status@Q},
    "internal_http_ok": os.environ["INTERNAL_HTTP_OK"] == "true",
    "host_http_ok": os.environ["HOST_HTTP_OK"] == "true",
    "n8n_url": ${N8N_URL@Q},
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
echo "internal_http_ok=${internal_http_ok}"
echo "host_http_ok=${host_http_ok}"
echo "n8n_url=${N8N_URL}"
echo "workflow_ids=${workflow_ids:-"(none)"}"
echo "active_workflow_ids=${active_ids:-"(none)"}"
