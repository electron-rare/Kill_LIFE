#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
source "${PROJECT_DIR}/tools/cockpit/json_contract.sh"
LOG_DIR="${PROJECT_DIR}/artifacts/cockpit"
STATE_DIR="${PROJECT_DIR}/artifacts/operator_lane"
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="${LOG_DIR}/full_operator_lane_${TIMESTAMP}.log"
SUMMARY_FILE="${STATE_DIR}/full_operator_lane_${TIMESTAMP}.json"
MASCARADE_HEALTH_FILE="${STATE_DIR}/full_operator_lane_mascarade_health_${TIMESTAMP}.json"
MASCARADE_LOGS_FILE="${STATE_DIR}/full_operator_lane_mascarade_logs_${TIMESTAMP}.json"
MASCARADE_QUEUE_FILE="${STATE_DIR}/full_operator_lane_mascarade_queue_${TIMESTAMP}.json"
MASCARADE_WATCH_FILE="${STATE_DIR}/full_operator_lane_mascarade_watch_${TIMESTAMP}.json"
DAILY_OPERATOR_SUMMARY_FILE="${STATE_DIR}/full_operator_lane_daily_operator_summary_${TIMESTAMP}.json"
ROUTING_FILE="${STATE_DIR}/full_operator_lane_routing_${TIMESTAMP}.json"
KILL_LIFE_MEMORY_FILE="${STATE_DIR}/full_operator_lane_kill_life_memory_${TIMESTAMP}.json"
API_BASE="${CRAZY_LIFE_API_BASE:-http://localhost:3100/api/killlife}"
WORKFLOW_ID="${FULL_OPERATOR_LANE_WORKFLOW_ID:-embedded-operator-live}"
WAIT_SECONDS="${FULL_OPERATOR_LANE_POLL_SECONDS:-2}"
WAIT_ATTEMPTS="${FULL_OPERATOR_LANE_POLL_ATTEMPTS:-20}"
JSON_OUTPUT=0
COMMAND="status"
LOGS_ACTION="summary"
MASCARADE_HEALTH_STATUS="unknown"
MASCARADE_PROVIDER="unknown"
MASCARADE_MODEL="unknown"
MASCARADE_LOGS_STATUS="unknown"
MASCARADE_LOGS_STALE="0"
MASCARADE_LOGS_PURGED="0"
MASCARADE_QUEUE_STATUS="unknown"
MASCARADE_QUEUE_MARKDOWN=""
MASCARADE_WATCH_STATUS="unknown"
MASCARADE_WATCH_MARKDOWN=""
DAILY_OPERATOR_SUMMARY_STATUS="unknown"
DAILY_OPERATOR_SUMMARY_MARKDOWN=""
ROUTING_STATUS="unknown"
KILL_LIFE_MEMORY_STATUS="unknown"
COMMAND_EXIT_CODE=0

mkdir -p "${LOG_DIR}" "${STATE_DIR}"

usage() {
  cat <<'USAGE'
Usage: bash tools/cockpit/full_operator_lane.sh <status|dry-run|live|all|logs|purge> [--json] [--logs-action <summary|latest|list|purge>]

Commands:
  status   Fetch workflow detail and latest runs.
  dry-run  Validate then trigger a dry-run on the operator lane.
  live     Validate then trigger the live-provider execution path.
  all      Run dry-run then live in sequence.
  logs     Read or purge Mascarade/Ollama logs through the operator lane.
  purge    Remove generated operator-lane logs and summaries.

Options:
  --json               Print the generated summary JSON to stdout.
  --logs-action <name> summary|latest|list|purge for the `logs` command (default: summary).
USAGE
}

log_line() {
  local level="$1"
  shift
  mkdir -p "${LOG_DIR}" "${STATE_DIR}"
  local msg="${level} $(date '+%Y-%m-%d %H:%M:%S %z') $*"
  printf '%s\n' "${msg}" | tee -a "${LOG_FILE}" >/dev/null
}

curl_json() {
  local method="$1"
  local url="$2"
  local body="$3"
  local output_file="$4"
  local http_file
  local http_code
  http_file="$(mktemp)"
  local -a args=(curl -sS -X "${method}" -H 'Content-Type: application/json' -o "${output_file}" -w '%{http_code}')
  local gateway_api_key="${CRAZY_LIFE_API_KEY:-${MASCARADE_API_KEY:-${KILL_LIFE_API_KEY:-}}}"
  if [[ -n "${gateway_api_key}" ]]; then
    args+=(-H "Authorization: Bearer ${gateway_api_key}")
  fi
  if [[ -n "${body}" ]]; then
    args+=(--data "${body}")
  fi
  args+=("${url}")
  if ! "${args[@]}" > "${http_file}" 2>>"${LOG_FILE}"; then
    rm -f "${http_file}"
    return 1
  fi
  http_code="$(tr -d '\n' < "${http_file}")"
  rm -f "${http_file}"
  if [[ ! "${http_code}" =~ ^2[0-9][0-9]$ ]]; then
    return 1
  fi
}

write_failure_summary() {
  local output_file="$1"
  local error_code="$2"
  local url="$3"
  local hint=""
  local suggested_command=""
  case "${error_code}" in
    status-api-unreachable)
      hint="API locale indisponible pour lire le workflow operateur."
      suggested_command="export CRAZY_LIFE_API_BASE=http://<host>:3100/api/killlife"
      ;;
    validate-api-unreachable)
      hint="Impossible de valider le workflow tant que l'API locale n'est pas joignable."
      suggested_command="bash tools/cockpit/full_operator_lane.sh status --json"
      ;;
    run-api-unreachable)
      hint="Le declenchement dry-run/live ne peut pas partir sans API locale joignable."
      suggested_command="bash tools/cockpit/full_operator_lane.sh status --json"
      ;;
    poll-api-unreachable)
      hint="Le workflow a peut-etre demarre mais le polling ne peut plus joindre l'API."
      suggested_command="bash tools/cockpit/full_operator_lane.sh status --json"
      ;;
  esac
  printf '{"status":"failed","error":"%s","url":"%s","command":"%s","workflow_id":"%s","hint":"%s","suggested_command":"%s"}\n' \
    "${error_code}" "${url}" "${COMMAND}" "${WORKFLOW_ID}" "${hint}" "${suggested_command}" > "${output_file}"
}

json_get() {
  local file="$1"
  local path_expr="$2"
  python3 - "$file" "$path_expr" <<'PY'
import json
import sys
from pathlib import Path

file_path = Path(sys.argv[1])
path = sys.argv[2].split('.') if sys.argv[2] else []
text = file_path.read_text(encoding='utf-8')
try:
    value = json.loads(text)
except json.JSONDecodeError:
    decoder = json.JSONDecoder()
    idx = 0
    last_value = None
    while idx < len(text):
        while idx < len(text) and text[idx].isspace():
            idx += 1
        if idx >= len(text):
            break
        try:
            candidate, end = decoder.raw_decode(text, idx)
        except json.JSONDecodeError:
            break
        last_value = candidate
        idx = end
    if last_value is None:
        print("")
        raise SystemExit(0)
    value = last_value
for key in path:
    if isinstance(value, dict):
        value = value.get(key)
    else:
        value = None
        break
if value is None:
    print("")
elif isinstance(value, (dict, list)):
    print(json.dumps(value, ensure_ascii=True))
else:
    print(value)
PY
}

emit_contract_json() {
  python3 - "${SUMMARY_FILE}" "${COMMAND}" "${LOGS_ACTION}" "${LOG_FILE}" "${WORKFLOW_ID}" "${API_BASE}" "${MASCARADE_HEALTH_FILE}" "${MASCARADE_HEALTH_STATUS}" "${MASCARADE_PROVIDER}" "${MASCARADE_MODEL}" "${MASCARADE_LOGS_FILE}" "${MASCARADE_LOGS_STATUS}" "${MASCARADE_LOGS_STALE}" "${MASCARADE_LOGS_PURGED}" "${MASCARADE_QUEUE_FILE}" "${MASCARADE_QUEUE_STATUS}" "${MASCARADE_QUEUE_MARKDOWN}" "${MASCARADE_WATCH_FILE}" "${MASCARADE_WATCH_STATUS}" "${MASCARADE_WATCH_MARKDOWN}" "${DAILY_OPERATOR_SUMMARY_FILE}" "${DAILY_OPERATOR_SUMMARY_STATUS}" "${DAILY_OPERATOR_SUMMARY_MARKDOWN}" "${ROUTING_FILE}" "${ROUTING_STATUS}" "${KILL_LIFE_MEMORY_FILE}" "${KILL_LIFE_MEMORY_STATUS}" "${PRODUCT_CONTRACT_HANDOFF_FILE:-}" "${PRODUCT_CONTRACT_HANDOFF_STATUS:-unknown}" "${PRODUCT_CONTRACT_HANDOFF_MARKDOWN:-}" <<'PY'
import json
import sys
from pathlib import Path

summary_path = Path(sys.argv[1])
command = sys.argv[2]
logs_action = sys.argv[3]
log_file = sys.argv[4]
workflow_id = sys.argv[5]
api_base = sys.argv[6]
health_path = Path(sys.argv[7])
health_status = sys.argv[8]
health_provider = sys.argv[9]
health_model = sys.argv[10]
logs_path = Path(sys.argv[11])
logs_status = sys.argv[12]
logs_stale = sys.argv[13]
logs_purged = sys.argv[14]
queue_path = Path(sys.argv[15])
queue_status = sys.argv[16]
queue_markdown = sys.argv[17]
watch_path = Path(sys.argv[18])
watch_status = sys.argv[19]
watch_markdown = sys.argv[20]
daily_summary_path = Path(sys.argv[21])
daily_summary_status = sys.argv[22]
daily_summary_markdown = sys.argv[23]
routing_path = Path(sys.argv[24])
routing_status = sys.argv[25]
memory_path = Path(sys.argv[26])
memory_status = sys.argv[27]
handoff_path = Path(sys.argv[28]) if sys.argv[28] else Path("")
handoff_status = sys.argv[29]
handoff_markdown = sys.argv[30]

summary = {}
if summary_path.exists():
    raw = summary_path.read_text(encoding="utf-8")
    try:
        summary = json.loads(raw)
    except json.JSONDecodeError:
        summary = {"raw_summary": raw}

raw_status = ""
error_code = ""
error_url = ""
hint = ""
suggested_command = ""
if isinstance(summary, dict):
    raw_status = str(summary.get("status", ""))
    error_code = str(summary.get("error", ""))
    error_url = str(summary.get("url", ""))
    hint = str(summary.get("hint", ""))
    suggested_command = str(summary.get("suggested_command", ""))

def map_status(value: str) -> str:
    value = (value or "").strip().lower()
    if value in {"done", "ready", "ok", "success"}:
        return "ok"
    if value in {"failed", "error", "cancelled", "cancel_unresolved"}:
        return "error"
    if value in {"", "unknown"}:
        return "degraded"
    return "degraded"

contract_status = map_status(raw_status)
reasons = []
next_steps = []
if contract_status != "ok":
    reasons.append(error_code or f"operator-lane-{raw_status or command}")
    if error_url:
        next_steps.append(f"Restore or reroute the local API endpoint {error_url}")
    if hint:
        next_steps.append(hint)
    if suggested_command:
        next_steps.append(suggested_command)
    next_steps.append(f"Inspect {log_file} and {summary_path}")

health_summary = {}
if health_path.exists():
    raw = health_path.read_text(encoding="utf-8")
    try:
        health_summary = json.loads(raw)
    except json.JSONDecodeError:
        health_summary = {"raw_health_summary": raw}

if (health_status or "").strip().lower() not in {"ok", "ready", "done", "success", "skipped", "n/a"}:
    if contract_status == "ok":
        contract_status = "degraded"
    reasons.append(f"mascarade-runtime-{health_status or 'unknown'}")
    next_steps.append(f"Inspect {health_path}")

logs_summary = {}
if logs_path.exists():
    raw = logs_path.read_text(encoding="utf-8")
    try:
        logs_summary = json.loads(raw)
    except json.JSONDecodeError:
        logs_summary = {"raw_logs_summary": raw}

if (logs_status or "").strip().lower() not in {"ok", "ready", "done", "success", "skipped", "n/a"}:
    if contract_status == "ok":
        contract_status = "degraded"
    reasons.append(f"mascarade-logs-{logs_status or 'unknown'}")
    next_steps.append(f"Inspect {logs_path}")

queue_summary = {}
if queue_path.exists():
    raw = queue_path.read_text(encoding="utf-8")
    try:
        queue_summary = json.loads(raw)
    except json.JSONDecodeError:
        queue_summary = {"raw_queue_summary": raw}

if (queue_status or "").strip().lower() not in {"ok", "ready", "done", "success", "skipped", "n/a"}:
    if contract_status == "ok":
        contract_status = "degraded"
    reasons.append(f"mascarade-queue-{queue_status or 'unknown'}")
    next_steps.append(f"Inspect {queue_path}")

watch_summary = {}
if watch_path.exists():
    raw = watch_path.read_text(encoding="utf-8")
    try:
        watch_summary = json.loads(raw)
    except json.JSONDecodeError:
        watch_summary = {"raw_watch_summary": raw}

if (watch_status or "").strip().lower() not in {"ok", "ready", "done", "success", "skipped", "n/a"}:
    if contract_status == "ok":
        contract_status = "degraded"
    reasons.append(f"mascarade-watch-{watch_status or 'unknown'}")
    next_steps.append(f"Inspect {watch_path}")

daily_summary = {}
if daily_summary_path.exists():
    raw = daily_summary_path.read_text(encoding="utf-8")
    try:
        daily_summary = json.loads(raw)
    except json.JSONDecodeError:
        daily_summary = {"raw_daily_summary": raw}

if (daily_summary_status or "").strip().lower() not in {"ok", "ready", "done", "success", "skipped", "n/a"}:
    if contract_status == "ok":
        contract_status = "degraded"
    reasons.append(f"daily-operator-summary-{daily_summary_status or 'unknown'}")
    next_steps.append(f"Inspect {daily_summary_path}")

routing_summary = {}
if routing_path.exists():
    raw = routing_path.read_text(encoding="utf-8")
    try:
        routing_summary = json.loads(raw)
    except json.JSONDecodeError:
        routing_summary = {"raw_routing_summary": raw}

if (routing_status or "").strip().lower() not in {"ok", "ready", "done", "success", "skipped", "n/a"}:
    if contract_status == "ok":
        contract_status = "degraded"
    reasons.append(f"mascarade-routing-{routing_status or 'unknown'}")
    next_steps.append(f"Inspect {routing_path}")

memory_summary = {}
if memory_path.exists():
    raw = memory_path.read_text(encoding="utf-8")
    try:
        memory_summary = json.loads(raw)
    except json.JSONDecodeError:
        memory_summary = {"raw_memory_summary": raw}

if (memory_status or "").strip().lower() not in {"ok", "ready", "done", "success", "skipped", "n/a"}:
    if contract_status == "ok":
        contract_status = "degraded"
    reasons.append(f"kill-life-memory-{memory_status or 'unknown'}")
    next_steps.append(f"Inspect {memory_path}")

handoff_summary = {}
if handoff_path and handoff_path.exists():
    raw = handoff_path.read_text(encoding="utf-8")
    try:
        handoff_summary = json.loads(raw)
    except json.JSONDecodeError:
        handoff_summary = {"raw_handoff_summary": raw}

if (handoff_status or "").strip().lower() not in {"ok", "ready", "done", "success", "skipped", "n/a"}:
    if contract_status == "ok":
        contract_status = "degraded"
    reasons.append(f"product-contract-handoff-{handoff_status or 'unknown'}")
    next_steps.append(f"Inspect {handoff_path}")

priority_counts = daily_summary.get("priority_counts", {}) if isinstance(daily_summary.get("priority_counts"), dict) else {}
severity_counts = daily_summary.get("severity_counts", {}) if isinstance(daily_summary.get("severity_counts"), dict) else {}
memory_entry = memory_summary.get("entry", {}) if isinstance(memory_summary, dict) else {}
if not isinstance(memory_entry, dict):
    memory_entry = {}
decision = memory_entry.get("decision") if isinstance(memory_entry.get("decision"), dict) else {
    "action": f"operator-lane-{command}",
    "reason": "Operator lane projected into kill_life continuity memory.",
}
owner = memory_entry.get("owner", "SyncOps")
resume_ref = memory_entry.get("resume_ref", f"kill-life:full-operator-lane:{workflow_id}:{command}")
trust_level = memory_entry.get("trust_level", "inferred")

payload = {
    "contract_version": "cockpit-v1",
    "component": "full_operator_lane",
    "action": command,
    "logs_action": logs_action,
    "status": contract_status,
    "contract_status": contract_status,
    "workflow_id": workflow_id,
    "api_base": api_base,
    "log_file": log_file,
    "summary_file": str(summary_path),
    "owner": owner,
    "decision": decision,
    "resume_ref": resume_ref,
    "trust_level": trust_level,
    "mascarade_health_status": health_status or "unknown",
    "mascarade_provider": health_provider or "unknown",
    "mascarade_model": health_model or "unknown",
    "mascarade_health_file": str(health_path),
    "mascarade_logs_status": logs_status or "unknown",
    "mascarade_logs_stale": logs_stale or "0",
    "mascarade_logs_purged": logs_purged or "0",
    "mascarade_logs_file": str(logs_path),
    "mascarade_queue_status": queue_status or "unknown",
    "mascarade_queue_file": str(queue_path),
    "mascarade_queue_markdown": queue_markdown or "",
    "mascarade_watch_status": watch_status or "unknown",
    "mascarade_watch_file": str(watch_path),
    "mascarade_watch_markdown": watch_markdown or "",
    "routing_status": routing_status or "unknown",
    "routing_file": str(routing_path),
    "routing": routing_summary,
    "memory_entry_status": memory_status or "unknown",
    "memory_entry_file": str(memory_path),
    "memory_entry": memory_entry,
    "priority_counts": priority_counts,
    "severity_counts": severity_counts,
    "daily_operator_summary_status": daily_summary_status or "unknown",
    "daily_operator_summary_file": str(daily_summary_path),
    "daily_operator_summary_markdown": daily_summary_markdown or "",
    "product_contract_handoff_status": handoff_status or "unknown",
    "product_contract_handoff_artifact": str(handoff_path) if handoff_path else "",
    "product_contract_handoff_markdown": handoff_markdown or "",
    "artifacts": [log_file, str(summary_path), str(health_path), str(logs_path), str(queue_path), str(watch_path), str(daily_summary_path), str(routing_path), str(memory_path)] + ([str(handoff_path)] if handoff_path else []),
    "degraded_reasons": reasons,
    "next_steps": next_steps,
    "summary": summary,
    "mascarade_health_summary": health_summary,
    "mascarade_logs_summary": logs_summary,
    "mascarade_queue_summary": queue_summary,
    "mascarade_watch_summary": watch_summary,
    "daily_operator_summary": daily_summary,
    "product_contract_handoff": handoff_summary,
}
print(json.dumps(payload, ensure_ascii=False))
PY
}

refresh_mascarade_health() {
  if bash "${PROJECT_DIR}/tools/cockpit/mascarade_runtime_health.sh" --json > "${MASCARADE_HEALTH_FILE}" 2>>"${LOG_FILE}"; then
    MASCARADE_HEALTH_STATUS="$(json_get "${MASCARADE_HEALTH_FILE}" 'status')"
    MASCARADE_PROVIDER="$(json_get "${MASCARADE_HEALTH_FILE}" 'provider')"
    MASCARADE_MODEL="$(json_get "${MASCARADE_HEALTH_FILE}" 'model')"
    log_line INFO "mascarade health status=${MASCARADE_HEALTH_STATUS:-unknown} provider=${MASCARADE_PROVIDER:-unknown} model=${MASCARADE_MODEL:-unknown}"
  else
    MASCARADE_HEALTH_STATUS="failed"
    MASCARADE_PROVIDER="unknown"
    MASCARADE_MODEL="unknown"
    log_line ERROR "mascarade health-check failed"
  fi

  [[ -n "${MASCARADE_HEALTH_STATUS}" ]] || MASCARADE_HEALTH_STATUS="unknown"
  [[ -n "${MASCARADE_PROVIDER}" ]] || MASCARADE_PROVIDER="unknown"
  [[ -n "${MASCARADE_MODEL}" ]] || MASCARADE_MODEL="unknown"
}

refresh_mascarade_logs() {
  local mode="${1:-summary}"
  local -a args=(bash "${PROJECT_DIR}/tools/cockpit/mascarade_logs_tui.sh" --action "${mode}" --json)
  if [[ "${mode}" == "purge" ]]; then
    args+=(--apply)
  fi

  if "${args[@]}" > "${MASCARADE_LOGS_FILE}" 2>>"${LOG_FILE}"; then
    MASCARADE_LOGS_STATUS="$(json_get "${MASCARADE_LOGS_FILE}" 'status')"
    MASCARADE_LOGS_STALE="$(json_get "${MASCARADE_LOGS_FILE}" 'stale_candidate_count')"
    MASCARADE_LOGS_PURGED="$(json_get "${MASCARADE_LOGS_FILE}" 'purged_count')"
    [[ -n "${MASCARADE_LOGS_STALE}" ]] || MASCARADE_LOGS_STALE="0"
    [[ -n "${MASCARADE_LOGS_PURGED}" ]] || MASCARADE_LOGS_PURGED="0"
    log_line INFO "mascarade logs mode=${mode} status=${MASCARADE_LOGS_STATUS:-unknown} stale=${MASCARADE_LOGS_STALE:-0} purged=${MASCARADE_LOGS_PURGED:-0}"
  else
    MASCARADE_LOGS_STATUS="failed"
    MASCARADE_LOGS_STALE="0"
    MASCARADE_LOGS_PURGED="0"
    log_line ERROR "mascarade logs action failed mode=${mode}"
  fi

  [[ -n "${MASCARADE_LOGS_STATUS}" ]] || MASCARADE_LOGS_STATUS="unknown"
}

refresh_mascarade_queue() {
  if bash "${PROJECT_DIR}/tools/cockpit/render_mascarade_incident_queue.sh" --json > "${MASCARADE_QUEUE_FILE}" 2>>"${LOG_FILE}"; then
    MASCARADE_QUEUE_STATUS="$(json_get "${MASCARADE_QUEUE_FILE}" 'status')"
    MASCARADE_QUEUE_MARKDOWN="$(json_get "${MASCARADE_QUEUE_FILE}" 'markdown_file')"
    log_line INFO "mascarade queue status=${MASCARADE_QUEUE_STATUS:-unknown} markdown=${MASCARADE_QUEUE_MARKDOWN:-none}"
  else
    MASCARADE_QUEUE_STATUS="failed"
    MASCARADE_QUEUE_MARKDOWN=""
    log_line ERROR "mascarade queue render failed"
  fi

  [[ -n "${MASCARADE_QUEUE_STATUS}" ]] || MASCARADE_QUEUE_STATUS="unknown"
}

refresh_mascarade_watch() {
  if bash "${PROJECT_DIR}/tools/cockpit/render_mascarade_incident_watch.sh" --json > "${MASCARADE_WATCH_FILE}" 2>>"${LOG_FILE}"; then
    MASCARADE_WATCH_STATUS="$(json_get "${MASCARADE_WATCH_FILE}" 'status')"
    MASCARADE_WATCH_MARKDOWN="$(json_get "${MASCARADE_WATCH_FILE}" 'markdown_file')"
    log_line INFO "mascarade watch status=${MASCARADE_WATCH_STATUS:-unknown} markdown=${MASCARADE_WATCH_MARKDOWN:-none}"
  else
    MASCARADE_WATCH_STATUS="failed"
    MASCARADE_WATCH_MARKDOWN=""
    log_line ERROR "mascarade watch render failed"
  fi

  [[ -n "${MASCARADE_WATCH_STATUS}" ]] || MASCARADE_WATCH_STATUS="unknown"
}

refresh_daily_operator_summary() {
  if bash "${PROJECT_DIR}/tools/cockpit/render_daily_operator_summary.sh" --json > "${DAILY_OPERATOR_SUMMARY_FILE}" 2>>"${LOG_FILE}"; then
    DAILY_OPERATOR_SUMMARY_STATUS="$(json_get "${DAILY_OPERATOR_SUMMARY_FILE}" 'status')"
    DAILY_OPERATOR_SUMMARY_MARKDOWN="$(json_get "${DAILY_OPERATOR_SUMMARY_FILE}" 'markdown_file')"
    log_line INFO "daily operator summary status=${DAILY_OPERATOR_SUMMARY_STATUS:-unknown} markdown=${DAILY_OPERATOR_SUMMARY_MARKDOWN:-none}"
  else
    DAILY_OPERATOR_SUMMARY_STATUS="failed"
    DAILY_OPERATOR_SUMMARY_MARKDOWN=""
    log_line ERROR "daily operator summary render failed"
  fi

  [[ -n "${DAILY_OPERATOR_SUMMARY_STATUS}" ]] || DAILY_OPERATOR_SUMMARY_STATUS="unknown"
}

current_contract_status() {
  local derived="ok"
  local value=""
  if [[ "${COMMAND_EXIT_CODE}" -ne 0 ]]; then
    printf 'error'
    return 0
  fi
  for value in "${MASCARADE_HEALTH_STATUS}" "${MASCARADE_LOGS_STATUS}" "${MASCARADE_QUEUE_STATUS}" "${MASCARADE_WATCH_STATUS}" "${DAILY_OPERATOR_SUMMARY_STATUS}"; do
    case "${value:-unknown}" in
      ok|ready|done|success|skipped|n/a)
        ;;
      blocked|failed|error)
        printf 'error'
        return 0
        ;;
      *)
        derived="degraded"
        ;;
    esac
  done
  printf '%s' "${derived}"
}

current_trust_level() {
  local lane_status=""
  lane_status="$(current_contract_status)"
  if [[ "${lane_status}" == "ok" && "${ROUTING_STATUS}" == "ok" ]]; then
    printf 'verified'
  elif [[ "${ROUTING_STATUS}" == "ok" ]]; then
    printf 'bounded'
  else
    printf 'inferred'
  fi
}

refresh_mascarade_routing() {
  if bash "${PROJECT_DIR}/tools/cockpit/mascarade_dispatch_mesh.sh" --action route --profile "kxkm-ops" --json > "${ROUTING_FILE}" 2>>"${LOG_FILE}"; then
    ROUTING_STATUS="$(json_get "${ROUTING_FILE}" 'status')"
    log_line INFO "mascarade routing status=${ROUTING_STATUS:-unknown} file=${ROUTING_FILE}"
  else
    ROUTING_STATUS="failed"
    log_line ERROR "mascarade routing failed"
  fi
  [[ -n "${ROUTING_STATUS}" ]] || ROUTING_STATUS="unknown"
}

refresh_kill_life_memory() {
  local lane_status=""
  local trust_level=""
  local next_step=""
  local resume_ref=""
  lane_status="$(current_contract_status)"
  trust_level="$(current_trust_level)"
  resume_ref="kill-life:full-operator-lane:${WORKFLOW_ID}:${COMMAND}:${TIMESTAMP}"
  next_step="Review ${SUMMARY_FILE} then continue from ${COMMAND}."
  if [[ "${COMMAND_EXIT_CODE}" -ne 0 ]]; then
    next_step="Inspect ${LOG_FILE} and rerun bash tools/cockpit/full_operator_lane.sh ${COMMAND} --json."
  fi
  if bash "${PROJECT_DIR}/tools/cockpit/write_kill_life_memory_entry.sh" \
    --component "full_operator_lane" \
    --status "${lane_status}" \
    --owner "SyncOps" \
    --decision-action "full-operator-lane-${COMMAND}" \
    --decision-reason "Operator lane state is projected into kill_life with Tower/KXKM mesh routing for trustworthy continuity." \
    --next-step "${next_step}" \
    --resume-ref "${resume_ref}" \
    --trust-level "${trust_level}" \
    --routing-file "${ROUTING_FILE}" \
    --artifact "${SUMMARY_FILE}" \
    --artifact "${LOG_FILE}" \
    --artifact "${MASCARADE_WATCH_FILE}" \
    --artifact "${DAILY_OPERATOR_SUMMARY_FILE}" \
    --json > "${KILL_LIFE_MEMORY_FILE}" 2>>"${LOG_FILE}"; then
    KILL_LIFE_MEMORY_STATUS="$(json_get "${KILL_LIFE_MEMORY_FILE}" 'status')"
    log_line INFO "kill_life memory status=${KILL_LIFE_MEMORY_STATUS:-unknown} file=${KILL_LIFE_MEMORY_FILE}"
  else
    KILL_LIFE_MEMORY_STATUS="failed"
    log_line ERROR "kill_life memory write failed"
  fi
  [[ -n "${KILL_LIFE_MEMORY_STATUS}" ]] || KILL_LIFE_MEMORY_STATUS="unknown"
}

refresh_product_contract_handoff() {
  PRODUCT_CONTRACT_HANDOFF_FILE="${STATE_DIR}/full_operator_lane_product_contract_handoff_${TIMESTAMP}.json"
  if bash "${PROJECT_DIR}/tools/cockpit/render_product_contract_handoff.sh" --no-refresh --json > "${PRODUCT_CONTRACT_HANDOFF_FILE}" 2>>"${LOG_FILE}"; then
    PRODUCT_CONTRACT_HANDOFF_STATUS="$(json_get "${PRODUCT_CONTRACT_HANDOFF_FILE}" 'status')"
    PRODUCT_CONTRACT_HANDOFF_MARKDOWN="$(json_get "${PRODUCT_CONTRACT_HANDOFF_FILE}" 'markdown_file')"
    log_line INFO "product contract handoff status=${PRODUCT_CONTRACT_HANDOFF_STATUS:-unknown} markdown=${PRODUCT_CONTRACT_HANDOFF_MARKDOWN:-none}"
  else
    PRODUCT_CONTRACT_HANDOFF_STATUS="failed"
    PRODUCT_CONTRACT_HANDOFF_MARKDOWN=""
    log_line ERROR "product contract handoff render failed"
  fi

  [[ -n "${PRODUCT_CONTRACT_HANDOFF_STATUS}" ]] || PRODUCT_CONTRACT_HANDOFF_STATUS="unknown"
}

capture_post_run_logs() {
  LOGS_ACTION="latest"
  refresh_mascarade_logs latest
}

write_logs_summary() {
  python3 - "${SUMMARY_FILE}" "${MASCARADE_LOGS_FILE}" "${LOGS_ACTION}" <<'PY'
import json
import sys
from pathlib import Path

summary_path = Path(sys.argv[1])
logs_path = Path(sys.argv[2])
logs_action = sys.argv[3]

payload = {
    "status": "failed",
    "logs_action": logs_action,
    "source": str(logs_path),
}

if logs_path.exists():
    try:
        data = json.loads(logs_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        data = {"status": "failed", "error": "invalid-json", "source": str(logs_path)}
    payload["status"] = data.get("status", "unknown")
    payload["details"] = data
else:
    payload["error"] = "missing-logs-artifact"

summary_path.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
PY
}

validate_workflow() {
  local output_file="${STATE_DIR}/full_operator_lane_validate_${TIMESTAMP}.json"
  if ! curl_json POST "${API_BASE}/workflows/${WORKFLOW_ID}/validate" "" "${output_file}"; then
    write_failure_summary "${output_file}" "validate-api-unreachable" "${API_BASE}/workflows/${WORKFLOW_ID}/validate"
    cp "${output_file}" "${SUMMARY_FILE}"
    log_line ERROR "validate workflow=${WORKFLOW_ID} unreachable api_base=${API_BASE}; try 'bash tools/cockpit/full_operator_lane.sh status --json'"
    return 1
  fi
  local valid
  valid="$(json_get "${output_file}" 'valid')"
  log_line INFO "validate workflow=${WORKFLOW_ID} valid=${valid:-unknown}"
}

start_run() {
  local dry_run_flag="$1"
  local output_file="${STATE_DIR}/full_operator_lane_start_${TIMESTAMP}.json"
  if ! curl_json POST "${API_BASE}/workflows/${WORKFLOW_ID}/run" "{\"mode\":\"local\",\"dry_run\":${dry_run_flag}}" "${output_file}"; then
    write_failure_summary "${output_file}" "run-api-unreachable" "${API_BASE}/workflows/${WORKFLOW_ID}/run"
    cp "${output_file}" "${SUMMARY_FILE}"
    log_line ERROR "run start unreachable workflow=${WORKFLOW_ID} dry_run=${dry_run_flag} api_base=${API_BASE}; verify local API or export CRAZY_LIFE_API_BASE"
    return 1
  fi
  local run_id
  run_id="$(json_get "${output_file}" 'run_id')"
  if [[ -z "${run_id}" ]]; then
    log_line ERROR "run start failed for workflow=${WORKFLOW_ID} dry_run=${dry_run_flag}"
    cp "${output_file}" "${SUMMARY_FILE}"
    return 1
  fi
  local status
  status="$(json_get "${output_file}" 'status')"
  cp "${output_file}" "${STATE_DIR}/full_operator_lane_run_${run_id}.json"
  cp "${output_file}" "${SUMMARY_FILE}"
  log_line INFO "run completed workflow=${WORKFLOW_ID} dry_run=${dry_run_flag} run_id=${run_id} status=${status:-unknown}"
}

poll_run() {
  local run_id="$1"
  local output_file="${STATE_DIR}/full_operator_lane_run_${run_id}.json"
  local attempt="1"
  while [[ "${attempt}" -le "${WAIT_ATTEMPTS}" ]]; do
    if ! curl_json GET "${API_BASE}/workflows/${WORKFLOW_ID}/runs/${run_id}" "" "${output_file}"; then
      write_failure_summary "${output_file}" "poll-api-unreachable" "${API_BASE}/workflows/${WORKFLOW_ID}/runs/${run_id}"
      cp "${output_file}" "${SUMMARY_FILE}"
      log_line ERROR "poll unreachable run_id=${run_id} attempt=${attempt} api_base=${API_BASE}; retry status once API is back"
      return 1
    fi
    local status
    status="$(json_get "${output_file}" 'status')"
    log_line INFO "poll run_id=${run_id} attempt=${attempt} status=${status:-unknown}"
    case "${status}" in
      success|failed|no-op|cancelled|cancel_unresolved)
        cp "${output_file}" "${SUMMARY_FILE}"
        return 0
        ;;
    esac
    sleep "${WAIT_SECONDS}"
    attempt="$((attempt + 1))"
  done
  cp "${output_file}" "${SUMMARY_FILE}"
}

status_command() {
  if curl_json GET "${API_BASE}/workflows/${WORKFLOW_ID}" "" "${SUMMARY_FILE}"; then
    log_line INFO "status workflow=${WORKFLOW_ID} summary=${SUMMARY_FILE}"
    return 0
  fi
  write_failure_summary "${SUMMARY_FILE}" "status-api-unreachable" "${API_BASE}/workflows/${WORKFLOW_ID}"
  log_line ERROR "status workflow=${WORKFLOW_ID} unreachable api_base=${API_BASE}; export CRAZY_LIFE_API_BASE or restart the local API"
  return 1
}

purge_command() {
  mkdir -p "${LOG_DIR}" "${STATE_DIR}"
  rm -f "${LOG_DIR}"/full_operator_lane_*.log "${STATE_DIR}"/full_operator_lane_*.json "${STATE_DIR}"/full_operator_lane_mascarade_health_*.json "${STATE_DIR}"/full_operator_lane_mascarade_logs_*.json "${STATE_DIR}"/full_operator_lane_mascarade_queue_*.json "${STATE_DIR}"/full_operator_lane_mascarade_watch_*.json "${STATE_DIR}"/full_operator_lane_routing_*.json "${STATE_DIR}"/full_operator_lane_kill_life_memory_*.json "${STATE_DIR}"/live_provider_result.json
  printf '{"status":"done","purged":["artifacts/cockpit/full_operator_lane_*.log","artifacts/operator_lane/full_operator_lane_*.json","artifacts/operator_lane/full_operator_lane_mascarade_health_*.json","artifacts/operator_lane/full_operator_lane_mascarade_logs_*.json","artifacts/operator_lane/full_operator_lane_mascarade_queue_*.json","artifacts/operator_lane/full_operator_lane_mascarade_watch_*.json","artifacts/operator_lane/full_operator_lane_routing_*.json","artifacts/operator_lane/full_operator_lane_kill_life_memory_*.json","artifacts/operator_lane/live_provider_result.json"]}\n' > "${SUMMARY_FILE}"
  MASCARADE_HEALTH_STATUS="skipped"
  MASCARADE_QUEUE_STATUS="skipped"
  MASCARADE_QUEUE_MARKDOWN=""
  MASCARADE_WATCH_STATUS="skipped"
  MASCARADE_WATCH_MARKDOWN=""
  refresh_mascarade_logs purge
  log_line INFO "purged full operator lane artifacts"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    status|dry-run|live|all|logs|purge)
      COMMAND="$1"
      ;;
    --json)
      JSON_OUTPUT=1
      ;;
    --logs-action)
      if [[ $# -lt 2 ]]; then
        usage >&2
        exit 2
      fi
      LOGS_ACTION="$2"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [[ ! "${LOGS_ACTION}" =~ ^(summary|latest|list|purge)$ ]]; then
  echo "[error] --logs-action requires summary|latest|list|purge" >&2
  exit 2
fi

case "${COMMAND}" in
  status)
    refresh_mascarade_health
    refresh_mascarade_logs summary
    refresh_mascarade_queue
    refresh_daily_operator_summary
    refresh_mascarade_watch
    status_command || COMMAND_EXIT_CODE=1
    ;;
  dry-run)
    refresh_mascarade_health
    refresh_mascarade_logs summary
    refresh_mascarade_queue
    refresh_daily_operator_summary
    refresh_mascarade_watch
    validate_workflow || COMMAND_EXIT_CODE=1
    if [[ "${COMMAND_EXIT_CODE}" -eq 0 ]]; then
      start_run true || COMMAND_EXIT_CODE=1
    fi
    capture_post_run_logs
    refresh_mascarade_queue
    refresh_daily_operator_summary
    refresh_mascarade_watch
    ;;
  live)
    refresh_mascarade_health
    refresh_mascarade_logs summary
    refresh_mascarade_queue
    refresh_daily_operator_summary
    refresh_mascarade_watch
    validate_workflow || COMMAND_EXIT_CODE=1
    if [[ "${COMMAND_EXIT_CODE}" -eq 0 ]]; then
      start_run false || COMMAND_EXIT_CODE=1
    fi
    capture_post_run_logs
    refresh_mascarade_queue
    refresh_daily_operator_summary
    refresh_mascarade_watch
    ;;
  all)
    refresh_mascarade_health
    refresh_mascarade_logs summary
    refresh_mascarade_queue
    refresh_daily_operator_summary
    refresh_mascarade_watch
    validate_workflow || COMMAND_EXIT_CODE=1
    if [[ "${COMMAND_EXIT_CODE}" -eq 0 ]]; then
      start_run true || COMMAND_EXIT_CODE=1
    fi
    if [[ "${COMMAND_EXIT_CODE}" -eq 0 ]]; then
      start_run false || COMMAND_EXIT_CODE=1
    fi
    capture_post_run_logs
    refresh_mascarade_queue
    refresh_daily_operator_summary
    refresh_mascarade_watch
    ;;
  logs)
    refresh_mascarade_health
    refresh_mascarade_logs "${LOGS_ACTION}"
    refresh_mascarade_queue
    write_logs_summary
    refresh_daily_operator_summary
    refresh_mascarade_watch
    if [[ "${MASCARADE_LOGS_STATUS}" == "failed" || "${MASCARADE_LOGS_STATUS}" == "error" ]]; then
      COMMAND_EXIT_CODE=1
    fi
    ;;
  purge)
    purge_command
    ;;
esac

refresh_mascarade_routing
refresh_kill_life_memory
refresh_product_contract_handoff

if [[ "${JSON_OUTPUT}" -eq 1 && -f "${SUMMARY_FILE}" ]]; then
  emit_contract_json
fi

if [[ "${COMMAND_EXIT_CODE}" -ne 0 ]]; then
  exit "${COMMAND_EXIT_CODE}"
fi
