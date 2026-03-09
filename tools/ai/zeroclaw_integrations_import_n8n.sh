#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

N8N_CONTAINER="${ZEROCLAW_N8N_CONTAINER:-mascarade-n8n}"
INPUT_FILE="${ZEROCLAW_N8N_WORKFLOW_FILE:-${ROOT_DIR}/tools/ai/integrations/n8n/kill_life_smoke_workflow.json}"
CONTAINER_INPUT_PATH="${ZEROCLAW_N8N_CONTAINER_INPUT:-/home/node/kill-life-import.json}"
PUBLISH=1
OUTPUT_JSON=0

usage() {
  cat <<'EOF'
Usage: bash tools/ai/zeroclaw_integrations_import_n8n.sh [options]

Import the tracked smoke workflow into the local n8n runtime and publish it.

Options:
  --input PATH   Workflow JSON to import
  --no-publish   Import only
  --json         Emit JSON summary
  -h, --help     Show this help

Env overrides:
  ZEROCLAW_N8N_CONTAINER
  ZEROCLAW_N8N_WORKFLOW_FILE
  ZEROCLAW_N8N_CONTAINER_INPUT
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input)
      shift
      [[ $# -gt 0 ]] || { echo "Missing value for --input" >&2; usage >&2; exit 2; }
      INPUT_FILE="$1"
      ;;
    --no-publish)
      PUBLISH=0
      ;;
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

[[ -f "${INPUT_FILE}" ]] || {
  echo "Missing workflow file: ${INPUT_FILE}" >&2
  exit 1
}

workflow_id="$(
  python3 - "${INPUT_FILE}" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
workflow_id = str(data.get("id", "")).strip()
if not workflow_id:
    raise SystemExit("workflow JSON must contain a non-empty id")
print(workflow_id)
PY
)"

bash "${ROOT_DIR}/tools/ai/zeroclaw_integrations_up.sh" >/dev/null

existing_ids="$(docker exec "${N8N_CONTAINER}" n8n list:workflow --onlyId 2>/dev/null || true)"
import_action="skipped"

if ! printf '%s\n' "${existing_ids}" | grep -Fxq "${workflow_id}"; then
  docker exec -i "${N8N_CONTAINER}" sh -lc "cat > '${CONTAINER_INPUT_PATH}'" < "${INPUT_FILE}"
  docker exec "${N8N_CONTAINER}" n8n import:workflow --input="${CONTAINER_INPUT_PATH}" >/dev/null
  import_action="imported"
fi

publish_action="skipped"
if [[ "${PUBLISH}" == "1" ]]; then
  docker exec "${N8N_CONTAINER}" n8n publish:workflow --id="${workflow_id}" >/dev/null
  publish_action="published"
fi

active_ids="$(docker exec "${N8N_CONTAINER}" n8n list:workflow --active=true --onlyId 2>/dev/null || true)"
is_active=false
if printf '%s\n' "${active_ids}" | grep -Fxq "${workflow_id}"; then
  is_active=true
fi

if [[ "${OUTPUT_JSON}" == "1" ]]; then
  ACTIVE="${is_active}" python3 - <<PY
import json
import os
print(json.dumps({
    "workflow_id": ${workflow_id@Q},
    "input_file": ${INPUT_FILE@Q},
    "container": ${N8N_CONTAINER@Q},
    "import_action": ${import_action@Q},
    "publish_action": ${publish_action@Q},
    "active": os.environ["ACTIVE"] == "true",
}, ensure_ascii=True))
PY
  exit 0
fi

echo "workflow_id=${workflow_id}"
echo "input_file=${INPUT_FILE}"
echo "container=${N8N_CONTAINER}"
echo "import_action=${import_action}"
echo "publish_action=${publish_action}"
echo "active=${is_active}"
