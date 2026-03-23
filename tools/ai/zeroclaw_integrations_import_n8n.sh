#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

N8N_CONTAINER="${ZEROCLAW_N8N_CONTAINER:-mascarade-n8n}"
INPUT_FILE="${ZEROCLAW_N8N_WORKFLOW_FILE:-${ROOT_DIR}/tools/ai/integrations/n8n/kill_life_smoke_workflow.json}"
CONTAINER_INPUT_PATH="${ZEROCLAW_N8N_CONTAINER_INPUT:-/home/node/kill-life-import.json}"
PUBLISH=1
N8N_CLI_TIMEOUT_SECS="${ZEROCLAW_N8N_CLI_TIMEOUT_SECS:-45}"
DOCKER_TIMEOUT_SECS="${ZEROCLAW_N8N_DOCKER_TIMEOUT_SECS:-20}"
OUTPUT_JSON=0

emit_result() {
  local import_action="$1"
  local publish_action="$2"
  local active_value="$3"
  local reason_value="${4:-}"
  if [[ "${OUTPUT_JSON}" == "1" ]]; then
    ACTIVE="${active_value}" python3 - <<PY
import json
import os
payload = {
    "workflow_id": ${workflow_id@Q},
    "input_file": ${INPUT_FILE@Q},
    "container": ${N8N_CONTAINER@Q},
    "import_action": ${import_action@Q},
    "publish_action": ${publish_action@Q},
    "active": os.environ["ACTIVE"] == "true",
}
reason = ${reason_value@Q}
if reason:
    payload["reason"] = reason
print(json.dumps(payload, ensure_ascii=True))
PY
    return 0
  fi
  echo "workflow_id=${workflow_id}"
  echo "input_file=${INPUT_FILE}"
  echo "container=${N8N_CONTAINER}"
  echo "import_action=${import_action}"
  echo "publish_action=${publish_action}"
  echo "active=${active_value}"
  if [[ -n "${reason_value}" ]]; then
    echo "reason=${reason_value}"
  fi
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
  ZEROCLAW_N8N_CLI_TIMEOUT_SECS
  ZEROCLAW_N8N_DOCKER_TIMEOUT_SECS
EOF
}

docker_exec_timeout() {
  python3 - "${N8N_CLI_TIMEOUT_SECS}" "$@" <<'PY'
import subprocess
import sys

timeout = float(sys.argv[1])
cmd = sys.argv[2:]
try:
    proc = subprocess.run(cmd, text=True, capture_output=True, timeout=timeout, check=False)
except subprocess.TimeoutExpired:
    sys.stderr.write("cli_timeout\n")
    raise SystemExit(124)

sys.stdout.write(proc.stdout)
sys.stderr.write(proc.stderr)
raise SystemExit(proc.returncode)
PY
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

recent_activation_failure() {
  local logs=""

  if ! logs="$(docker_cmd_timeout docker logs --since 60s "${N8N_CONTAINER}" 2>&1 || true)"; then
    return 1
  fi

  grep -Fq "Activation of workflow \"Kill LIFE n8n smoke\" (${workflow_id}) did fail" <<< "${logs}"
}

inspect_current_workflow_state() {
  local temp_dir=""
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "${temp_dir}"' RETURN

  if ! docker_cmd_timeout docker cp "${N8N_CONTAINER}:/home/node/.n8n/database.sqlite" "${temp_dir}/database.sqlite" >/dev/null 2>/dev/null; then
    return 1
  fi
  docker_cmd_timeout docker cp "${N8N_CONTAINER}:/home/node/.n8n/database.sqlite-wal" "${temp_dir}/database.sqlite-wal" >/dev/null 2>/dev/null || true
  docker_cmd_timeout docker cp "${N8N_CONTAINER}:/home/node/.n8n/database.sqlite-shm" "${temp_dir}/database.sqlite-shm" >/dev/null 2>/dev/null || true

  python3 - "${INPUT_FILE}" "${temp_dir}/database.sqlite" <<'PY'
import json
import sqlite3
import sys
from pathlib import Path

workflow_file = Path(sys.argv[1])
db_path = Path(sys.argv[2])
expected = json.loads(workflow_file.read_text(encoding="utf-8"))
conn = sqlite3.connect(str(db_path))
cur = conn.cursor()
row = cur.execute(
    "select active, nodes, connections from workflow_entity where id = ?",
    (expected["id"],),
).fetchone()
conn.close()

payload = {
    "present": False,
    "active": False,
    "matches": False,
}
if row:
    active, nodes_raw, connections_raw = row
    payload["present"] = True
    payload["active"] = bool(active)
    try:
      nodes = json.loads(nodes_raw or "[]")
      connections = json.loads(connections_raw or "{}")
      payload["matches"] = nodes == expected.get("nodes", []) and connections == expected.get("connections", {})
    except json.JSONDecodeError:
      payload["matches"] = False
print(json.dumps(payload, ensure_ascii=True))
PY
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

if ! docker_available; then
  emit_result "skipped" "skipped" "false" "docker_unavailable"
  exit 0
fi

workflow_state_json="$(inspect_current_workflow_state || true)"
if [[ -n "${workflow_state_json}" ]]; then
  if python3 - "${workflow_state_json}" "${PUBLISH}" <<'PY'
import json
import sys
state = json.loads(sys.argv[1])
publish = sys.argv[2] == "1"
ok = state.get("present") and state.get("matches") and (state.get("active") or not publish)
raise SystemExit(0 if ok else 1)
PY
  then
    active_value="false"
    if python3 - "${workflow_state_json}" <<'PY'
import json
import sys
state = json.loads(sys.argv[1])
raise SystemExit(0 if state.get("active") else 1)
PY
    then
      active_value="true"
    fi
    emit_result "skipped" "skipped" "${active_value}"
    exit 0
  fi
fi

docker_cmd_timeout docker cp "${INPUT_FILE}" "${N8N_CONTAINER}:${CONTAINER_INPUT_PATH}" >/dev/null
import_action="skipped"
publish_action="skipped"
is_active=false

docker_exec_timeout docker exec -u node "${N8N_CONTAINER}" n8n import:workflow --input="${CONTAINER_INPUT_PATH}" >/dev/null
import_action="imported"

if [[ "${PUBLISH}" == "1" ]]; then
  if docker_exec_timeout docker exec -u node "${N8N_CONTAINER}" n8n publish:workflow --id="${workflow_id}" >/dev/null; then
    publish_action="published"
  elif docker_exec_timeout docker exec -u node "${N8N_CONTAINER}" n8n update:workflow --id="${workflow_id}" --active=true >/dev/null; then
    publish_action="activated"
  else
    publish_action="failed"
  fi
fi

if [[ "${PUBLISH}" == "1" ]]; then
  if ! recent_activation_failure; then
    is_active=true
  fi
else
  is_active=true
fi

if [[ "${PUBLISH}" == "1" && "${is_active}" != "true" ]]; then
  if [[ "${publish_action}" == "skipped" ]]; then
    publish_action="failed"
  fi
  emit_result "${import_action}" "${publish_action}" "${is_active}" "workflow_not_active_after_publish"
  exit 1
fi

emit_result "${import_action}" "${publish_action}" "${is_active}"
