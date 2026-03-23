#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-${SCRIPT_DIR%/tools/cockpit}}"
source "${ROOT_DIR}/tools/cockpit/json_contract.sh"
LOG_DIR="$ROOT_DIR/artifacts/cockpit"
PERSIST_DAYS=14
REGISTRY_FILE="${ROOT_DIR}/specs/contracts/machine_registry.mesh.json"

usage() {
  cat <<'USAGE'
Usage:
  bash tools/cockpit/run_alignment_daily.sh [options]

Runbook de vérification quotidienne de l'alignement SSH + état repo.

Options:
  --json         Affiche un résumé JSON (en plus du log console)
  --skip-healthcheck  Exécute uniquement le rafraîchissement repo (utile hors machine de pilotage).
 --skip-mesh         Exécute uniquement health-check + refresh repo sans préflight mesh.
  --skip-mascarade-health
                    Ignore volontairement le health-check live Mascarade/Ollama.
  --mesh-load-profile <tower-first|photon-safe>
                     Active la stratégie de charge pour le préflight mesh.
                     - tower-first (défaut): clems -> kxkm -> cils -> local -> root (réserve)
                     - photon-safe: idem, avec non-essentiel désactivé sur CILS et pas de précheck applicatif CILS.
                     Le plan P2P priorise systématiquement Tower puis KXKM avant CILS (quota) puis local.
  --purge-days N Conserve les logs de ce script sur N jours (défaut: 14)
 --no-purge     Désactive la purge automatique des logs
  --skip-log-ops         Ignore volontairement le résumé purgatif log_ops (JSON).
  -h, --help     Affiche cette aide
USAGE
}

json_output=false
skip_healthcheck=false
skip_mesh=false
do_purge=true
MESH_LOAD_PROFILE="tower-first"
SKIP_MASCARADE_HEALTH=false
MASCARADE_HEALTH_FILE=""
MASCARADE_HEALTH_STATUS="n/a"
MASCARADE_RUNTIME_STATUS="unknown"
MASCARADE_PROVIDER="unknown"
MASCARADE_MODEL="unknown"
MASCARADE_LOGS_FILE=""
MASCARADE_LOGS_STATUS="n/a"
MASCARADE_BRIEF_FILE=""
MASCARADE_BRIEF_STATUS="n/a"
MASCARADE_BRIEF_MARKDOWN=""
MASCARADE_REGISTRY_FILE=""
MASCARADE_REGISTRY_STATUS="n/a"
MASCARADE_REGISTRY_MARKDOWN=""
MASCARADE_QUEUE_FILE=""
MASCARADE_QUEUE_STATUS="n/a"
MASCARADE_QUEUE_MARKDOWN=""
MASCARADE_WATCH_FILE=""
MASCARADE_WATCH_STATUS="n/a"
MASCARADE_WATCH_MARKDOWN=""
MASCARADE_WATCH_HISTORY_FILE=""
MASCARADE_WATCH_HISTORY_STATUS="n/a"
MASCARADE_WATCH_HISTORY_MARKDOWN=""
MASCARADE_ROUTING_FILE=""
MASCARADE_ROUTING_STATUS="n/a"
DAILY_OPERATOR_SUMMARY_FILE=""
DAILY_OPERATOR_SUMMARY_STATUS="n/a"
DAILY_OPERATOR_SUMMARY_MARKDOWN=""
KILL_LIFE_MEMORY_FILE=""
KILL_LIFE_MEMORY_STATUS="n/a"
KILL_LIFE_MEMORY_MARKDOWN=""
TRUST_LEVEL="inferred"
RESUME_REF=""
SKIP_LOG_OPS=false
LOG_OPS_SUMMARY_FILE=""
LOG_OPS_PURGE_FILE=""
LOG_OPS_SUMMARY_STATUS="n/a"
LOG_OPS_PURGE_STATUS="n/a"
LOG_OPS_STALE="0"
LOG_OPS_PURGED="0"
REGISTRY_SUMMARY_FILE=""
REGISTRY_SUMMARY_STATUS="n/a"
REGISTRY_TARGET_COUNT="0"
REGISTRY_DEFAULT_PROFILE=""
OVERALL_STATUS="ok"

json_field() {
  local file="$1"
  local field="$2"
  local raw=""

  raw="$(sed -n "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "${file}" | head -n1 || true)"
  if [[ -z "${raw}" ]]; then
    raw="$(sed -n "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\\([0-9][0-9]*\\).*/\\1/p" "${file}" | head -n1 || true)"
  fi
  printf '%s' "${raw}"
}

json_inline_object() {
  local file="$1"
  local field="${2:-}"
  python3 - "$file" "$field" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
field = sys.argv[2]
payload = {}
if path.exists():
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        payload = {"status": "invalid-json", "file": str(path)}
if field:
    value = payload.get(field, {}) if isinstance(payload, dict) else {}
else:
    value = payload
print(json.dumps(value if isinstance(value, (dict, list)) else {}, ensure_ascii=True))
PY
}

json_decision_object() {
  local action="$1"
  local reason="$2"
  python3 - "$action" "$reason" <<'PY'
import json
import sys

print(json.dumps({"action": sys.argv[1], "reason": sys.argv[2]}, ensure_ascii=True))
PY
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) json_output=true; shift ;;
    --skip-healthcheck) skip_healthcheck=true; shift ;;
    --skip-mesh) skip_mesh=true; shift ;;
    --skip-mascarade-health)
      SKIP_MASCARADE_HEALTH=true
      shift
      ;;
    --mesh-load-profile)
      MESH_LOAD_PROFILE="${2:-}"
      if [[ -z "${MESH_LOAD_PROFILE}" || ! "${MESH_LOAD_PROFILE}" =~ ^(tower-first|photon-safe)$ ]]; then
        echo "[error] --mesh-load-profile requires tower-first|photon-safe" >&2
        exit 1
      fi
      shift 2
      ;;
    --purge-days)
      PERSIST_DAYS="${2:-}"
      if ! [[ "$PERSIST_DAYS" =~ ^[0-9]+$ ]]; then
        echo "[error] --purge-days requires an integer" >&2
        exit 1
      fi
      shift 2
      ;;
    --no-purge) do_purge=false; shift ;;
    --skip-log-ops)
      SKIP_LOG_OPS=true
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[error] option inconnue: $1" >&2; usage; exit 1 ;;
  esac
done

mkdir -p "$LOG_DIR"
timestamp="$(date '+%Y%m%d_%H%M%S')"
log_file="$LOG_DIR/machine_alignment_daily_${timestamp}.log"
summary_file="${LOG_DIR}/machine_alignment_daily_latest.log"
start_ts="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

log() {
  printf '%s\n' "$*" | tee -a "$log_file"
}

run_step() {
  local label="$1"
  shift
  log "[run] $label"
  if "$@" >>"$log_file" 2>&1; then
    log "[ok] $label"
    return 0
  else
    local code=$?
    log "[ko] $label (exit=$code)"
    return $code
  fi
}

run_step_capture() {
  local label="$1"
  local capture_file="$2"
  shift 2
  log "[run] $label"
  if "$@" >"${capture_file}" 2>&1; then
    log "[ok] $label"
    return 0
  else
    local code=$?
    log "[ko] $label (exit=$code)"
    return $code
  fi
}

status=0
: >"$log_file"
(
  echo "generated_at=${start_ts}"
  echo "runner=run_alignment_daily"
  echo "root_dir=$ROOT_DIR"
) >>"$log_file"

if $skip_healthcheck; then
  log "[skip] healthcheck_json"
else
  run_step "healthcheck_json" bash "$ROOT_DIR/tools/cockpit/ssh_healthcheck.sh" --json || status=1
fi

REGISTRY_SUMMARY_FILE="$LOG_DIR/machine_registry_summary_${timestamp}.json"
if run_step_capture "machine_registry_summary_json" "${REGISTRY_SUMMARY_FILE}" \
  bash "$ROOT_DIR/tools/cockpit/machine_registry.sh" --action summary --json; then
  REGISTRY_SUMMARY_STATUS="$(json_field "${REGISTRY_SUMMARY_FILE}" status)"
  REGISTRY_TARGET_COUNT="$(json_field "${REGISTRY_SUMMARY_FILE}" target_count)"
  REGISTRY_DEFAULT_PROFILE="$(json_field "${REGISTRY_SUMMARY_FILE}" default_profile)"
else
  status=1
  REGISTRY_SUMMARY_STATUS="failed"
  REGISTRY_TARGET_COUNT="0"
  REGISTRY_DEFAULT_PROFILE=""
fi

if [[ -z "${REGISTRY_TARGET_COUNT}" ]]; then
  REGISTRY_TARGET_COUNT="0"
fi
if [[ -z "${REGISTRY_DEFAULT_PROFILE}" ]]; then
  REGISTRY_DEFAULT_PROFILE="unknown"
fi

run_step "repo_refresh_header" bash "$ROOT_DIR/tools/repo_state/repo_refresh.sh" --header-only || status=1

if $SKIP_MASCARADE_HEALTH; then
  log "[skip] mascarade_runtime_health_json"
  MASCARADE_HEALTH_STATUS="skipped"
  MASCARADE_RUNTIME_STATUS="skipped"
  MASCARADE_LOGS_STATUS="skipped"
  MASCARADE_BRIEF_STATUS="skipped"
  MASCARADE_REGISTRY_STATUS="skipped"
  MASCARADE_QUEUE_STATUS="skipped"
  MASCARADE_WATCH_STATUS="skipped"
  MASCARADE_WATCH_HISTORY_STATUS="skipped"
else
  MASCARADE_HEALTH_FILE="$LOG_DIR/mascarade_runtime_health_${timestamp}.json"
  if run_step_capture "mascarade_runtime_health_json" "${MASCARADE_HEALTH_FILE}" \
    bash "$ROOT_DIR/tools/cockpit/mascarade_runtime_health.sh" --json; then
    MASCARADE_HEALTH_STATUS="$(json_field "${MASCARADE_HEALTH_FILE}" status)"
    MASCARADE_RUNTIME_STATUS="$(json_field "${MASCARADE_HEALTH_FILE}" runtime_status)"
    MASCARADE_PROVIDER="$(json_field "${MASCARADE_HEALTH_FILE}" provider)"
    MASCARADE_MODEL="$(json_field "${MASCARADE_HEALTH_FILE}" model)"
  else
    MASCARADE_HEALTH_STATUS="failed"
    MASCARADE_RUNTIME_STATUS="failed"
    status=1
  fi

  MASCARADE_LOGS_FILE="$LOG_DIR/mascarade_logs_latest_${timestamp}.json"
  if run_step_capture "mascarade_logs_latest_json" "${MASCARADE_LOGS_FILE}" \
    bash "$ROOT_DIR/tools/cockpit/mascarade_logs_tui.sh" --action latest --json; then
    MASCARADE_LOGS_STATUS="$(json_field "${MASCARADE_LOGS_FILE}" status)"
  else
    MASCARADE_LOGS_STATUS="failed"
  fi

  MASCARADE_BRIEF_FILE="$LOG_DIR/mascarade_incident_brief_${timestamp}.json"
  if run_step_capture "mascarade_incident_brief_json" "${MASCARADE_BRIEF_FILE}" \
    bash "$ROOT_DIR/tools/cockpit/render_mascarade_incident_brief.sh" --json; then
    MASCARADE_BRIEF_STATUS="$(json_field "${MASCARADE_BRIEF_FILE}" status)"
    MASCARADE_BRIEF_MARKDOWN="$(json_field "${MASCARADE_BRIEF_FILE}" markdown_file)"
  else
    MASCARADE_BRIEF_STATUS="failed"
  fi

  MASCARADE_REGISTRY_FILE="$LOG_DIR/mascarade_incident_registry_${timestamp}.json"
  if run_step_capture "mascarade_incident_registry_json" "${MASCARADE_REGISTRY_FILE}" \
    bash "$ROOT_DIR/tools/cockpit/mascarade_incident_registry.sh" --json; then
    MASCARADE_REGISTRY_STATUS="$(json_field "${MASCARADE_REGISTRY_FILE}" status)"
    MASCARADE_REGISTRY_MARKDOWN="$(json_field "${MASCARADE_REGISTRY_FILE}" markdown_file)"
  else
    MASCARADE_REGISTRY_STATUS="failed"
  fi

  MASCARADE_QUEUE_FILE="$LOG_DIR/mascarade_incident_queue_${timestamp}.json"
  if run_step_capture "mascarade_incident_queue_json" "${MASCARADE_QUEUE_FILE}" \
    bash "$ROOT_DIR/tools/cockpit/render_mascarade_incident_queue.sh" --json; then
    MASCARADE_QUEUE_STATUS="$(json_field "${MASCARADE_QUEUE_FILE}" status)"
    MASCARADE_QUEUE_MARKDOWN="$(json_field "${MASCARADE_QUEUE_FILE}" markdown_file)"
  else
    MASCARADE_QUEUE_STATUS="failed"
  fi
fi

mesh_status="skipped"
mesh_json_file=""
if $skip_mesh; then
  log "[skip] mesh_sync_preflight_json"
else
  mesh_json_file="$LOG_DIR/machine_alignment_mesh_preflight_${timestamp}.json"
  if run_step_capture "mesh_sync_preflight_json" "${mesh_json_file}" \
    bash "$ROOT_DIR/tools/cockpit/mesh_sync_preflight.sh" --json --load-profile "${MESH_LOAD_PROFILE}"; then
    mesh_status="$(sed -n 's/.*"mesh_status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$mesh_json_file" | head -n 1)"
  else
    status=1
    mesh_status="failed"
  fi
fi

if $SKIP_LOG_OPS; then
  log "[skip] log_ops_summary_json"
  LOG_OPS_SUMMARY_STATUS="skipped"
  LOG_OPS_PURGE_STATUS="skipped"
else
  LOG_OPS_SUMMARY_FILE="$LOG_DIR/machine_alignment_log_ops_summary_${timestamp}.json"
  if run_step_capture "log_ops_summary_json" "${LOG_OPS_SUMMARY_FILE}" \
    bash "$ROOT_DIR/tools/cockpit/log_ops.sh" --action summary --json --retention-days "$PERSIST_DAYS"; then
    LOG_OPS_SUMMARY_STATUS="$(json_field "${LOG_OPS_SUMMARY_FILE}" status)"
    LOG_OPS_STALE="$(json_field "${LOG_OPS_SUMMARY_FILE}" stale)"
  else
    status=1
    LOG_OPS_SUMMARY_STATUS="failed"
    LOG_OPS_STALE="0"
  fi

  if [[ -z "${LOG_OPS_STALE}" ]]; then
    LOG_OPS_STALE="0"
  fi

  LOG_OPS_PURGE_FILE="$LOG_DIR/machine_alignment_log_ops_purge_${timestamp}.json"
  if $do_purge; then
    if run_step_capture "log_ops_purge_json" "${LOG_OPS_PURGE_FILE}" \
      bash "$ROOT_DIR/tools/cockpit/log_ops.sh" --action purge --apply --retention-days "$PERSIST_DAYS" --json; then
      LOG_OPS_PURGE_STATUS="$(json_field "${LOG_OPS_PURGE_FILE}" status)"
      LOG_OPS_PURGED="$(json_field "${LOG_OPS_PURGE_FILE}" purged_count)"
    else
      LOG_OPS_PURGE_STATUS="failed"
      LOG_OPS_PURGED="0"
      status=1
    fi
  else
    if run_step_capture "log_ops_purge_dry_json" "${LOG_OPS_PURGE_FILE}" \
      bash "$ROOT_DIR/tools/cockpit/log_ops.sh" --action purge --retention-days "$PERSIST_DAYS" --json; then
      LOG_OPS_PURGE_STATUS="$(json_field "${LOG_OPS_PURGE_FILE}" status)"
      LOG_OPS_PURGED="$(json_field "${LOG_OPS_PURGE_FILE}" purged_count)"
    else
      LOG_OPS_PURGE_STATUS="failed"
      LOG_OPS_PURGED="0"
      status=1
    fi
  fi
fi

if [[ -z "$mesh_status" ]]; then
  mesh_status="unknown"
fi
if [[ -z "$LOG_OPS_SUMMARY_STATUS" ]]; then
  LOG_OPS_SUMMARY_STATUS="unknown"
fi
if [[ -z "$LOG_OPS_PURGE_STATUS" ]]; then
  LOG_OPS_PURGE_STATUS="unknown"
fi
if [[ -z "$MASCARADE_HEALTH_STATUS" ]]; then
  MASCARADE_HEALTH_STATUS="unknown"
fi
if [[ -z "$MASCARADE_RUNTIME_STATUS" ]]; then
  MASCARADE_RUNTIME_STATUS="unknown"
fi
if [[ -z "$MASCARADE_PROVIDER" ]]; then
  MASCARADE_PROVIDER="unknown"
fi
if [[ -z "$MASCARADE_MODEL" ]]; then
  MASCARADE_MODEL="unknown"
fi
if [[ -z "$MASCARADE_LOGS_STATUS" ]]; then
  MASCARADE_LOGS_STATUS="unknown"
fi
if [[ -z "$MASCARADE_BRIEF_STATUS" ]]; then
  MASCARADE_BRIEF_STATUS="unknown"
fi
if [[ -z "$MASCARADE_REGISTRY_STATUS" ]]; then
  MASCARADE_REGISTRY_STATUS="unknown"
fi
if [[ -z "$MASCARADE_QUEUE_STATUS" ]]; then
  MASCARADE_QUEUE_STATUS="unknown"
fi
if [[ -z "$MASCARADE_WATCH_STATUS" ]]; then
  MASCARADE_WATCH_STATUS="unknown"
fi
if [[ -z "$MASCARADE_WATCH_HISTORY_STATUS" ]]; then
  MASCARADE_WATCH_HISTORY_STATUS="unknown"
fi

if (( status == 0 )); then
  result="ok"
else
  result="ko"
fi
if [[ "${mesh_status}" == "degraded" || "${LOG_OPS_SUMMARY_STATUS}" == "degraded" || "${LOG_OPS_PURGE_STATUS}" == "degraded" || "${MASCARADE_HEALTH_STATUS}" == "degraded" || "${MASCARADE_LOGS_STATUS}" == "degraded" || "${MASCARADE_BRIEF_STATUS}" == "degraded" || "${MASCARADE_REGISTRY_STATUS}" == "degraded" || "${MASCARADE_QUEUE_STATUS}" == "degraded" || "${DAILY_OPERATOR_SUMMARY_STATUS}" == "degraded" ]]; then
  OVERALL_STATUS="degraded"
elif [[ "${mesh_status}" == "blocked" || "${LOG_OPS_SUMMARY_STATUS}" == "blocked" || "${LOG_OPS_PURGE_STATUS}" == "blocked" || "${MASCARADE_HEALTH_STATUS}" == "blocked" || "${MASCARADE_HEALTH_STATUS}" == "failed" || "${MASCARADE_LOGS_STATUS}" == "blocked" || "${MASCARADE_LOGS_STATUS}" == "failed" || "${MASCARADE_BRIEF_STATUS}" == "blocked" || "${MASCARADE_BRIEF_STATUS}" == "failed" || "${MASCARADE_REGISTRY_STATUS}" == "blocked" || "${MASCARADE_REGISTRY_STATUS}" == "failed" || "${MASCARADE_QUEUE_STATUS}" == "blocked" || "${MASCARADE_QUEUE_STATUS}" == "failed" || "${DAILY_OPERATOR_SUMMARY_STATUS}" == "blocked" || "${DAILY_OPERATOR_SUMMARY_STATUS}" == "failed" || "${result}" == "ko" ]]; then
  OVERALL_STATUS="ko"
fi
if [[ "${result}" == "ko" ]]; then
  OVERALL_STATUS="ko"
fi
if [[ "${OVERALL_STATUS}" == "ok" ]]; then
  result="ok"
elif [[ "${OVERALL_STATUS}" == "degraded" ]]; then
  result="degraded"
else
  result="ko"
fi

artifacts=("${log_file}" "${summary_file}")
degraded_reasons=()
next_steps=()
if [[ -n "${REGISTRY_SUMMARY_FILE}" ]]; then
  artifacts+=("${REGISTRY_SUMMARY_FILE}")
fi
if [[ -n "${MASCARADE_HEALTH_FILE}" ]]; then
  artifacts+=("${MASCARADE_HEALTH_FILE}")
fi
if [[ -n "${MASCARADE_LOGS_FILE}" ]]; then
  artifacts+=("${MASCARADE_LOGS_FILE}")
fi
if [[ -n "${MASCARADE_BRIEF_FILE}" ]]; then
  artifacts+=("${MASCARADE_BRIEF_FILE}")
fi
if [[ -n "${MASCARADE_REGISTRY_FILE}" ]]; then
  artifacts+=("${MASCARADE_REGISTRY_FILE}")
fi
if [[ -n "${MASCARADE_QUEUE_FILE}" ]]; then
  artifacts+=("${MASCARADE_QUEUE_FILE}")
fi
if [[ -n "${DAILY_OPERATOR_SUMMARY_FILE}" ]]; then
  artifacts+=("${DAILY_OPERATOR_SUMMARY_FILE}")
fi
if [[ -n "${mesh_json_file}" ]]; then
  artifacts+=("${mesh_json_file}")
fi
if [[ -n "${LOG_OPS_SUMMARY_FILE}" ]]; then
  artifacts+=("${LOG_OPS_SUMMARY_FILE}")
fi
if [[ -n "${LOG_OPS_PURGE_FILE}" ]]; then
  artifacts+=("${LOG_OPS_PURGE_FILE}")
fi
if [[ "${mesh_status}" == "degraded" || "${mesh_status}" == "failed" || "${mesh_status}" == "blocked" ]]; then
  degraded_reasons+=("mesh-${mesh_status}")
  next_steps+=("bash tools/cockpit/mesh_health_check.sh --json --load-profile ${MESH_LOAD_PROFILE}")
fi
if [[ "${REGISTRY_SUMMARY_STATUS}" == "degraded" || "${REGISTRY_SUMMARY_STATUS}" == "failed" || "${REGISTRY_SUMMARY_STATUS}" == "blocked" ]]; then
  degraded_reasons+=("machine-registry-${REGISTRY_SUMMARY_STATUS}")
  next_steps+=("bash tools/cockpit/machine_registry.sh --action summary --json")
fi
if [[ "${MASCARADE_HEALTH_STATUS}" == "degraded" || "${MASCARADE_HEALTH_STATUS}" == "failed" || "${MASCARADE_HEALTH_STATUS}" == "blocked" ]]; then
  degraded_reasons+=("mascarade-runtime-${MASCARADE_HEALTH_STATUS}")
  next_steps+=("bash tools/cockpit/mascarade_runtime_health.sh --json")
fi
if [[ "${MASCARADE_LOGS_STATUS}" == "degraded" || "${MASCARADE_LOGS_STATUS}" == "failed" || "${MASCARADE_LOGS_STATUS}" == "blocked" ]]; then
  degraded_reasons+=("mascarade-logs-${MASCARADE_LOGS_STATUS}")
  next_steps+=("bash tools/cockpit/mascarade_logs_tui.sh --action latest --json")
fi
if [[ "${MASCARADE_BRIEF_STATUS}" == "degraded" || "${MASCARADE_BRIEF_STATUS}" == "failed" || "${MASCARADE_BRIEF_STATUS}" == "blocked" ]]; then
  degraded_reasons+=("mascarade-brief-${MASCARADE_BRIEF_STATUS}")
  next_steps+=("bash tools/cockpit/render_mascarade_incident_brief.sh --json")
fi
if [[ "${MASCARADE_REGISTRY_STATUS}" == "degraded" || "${MASCARADE_REGISTRY_STATUS}" == "failed" || "${MASCARADE_REGISTRY_STATUS}" == "blocked" ]]; then
  degraded_reasons+=("mascarade-registry-${MASCARADE_REGISTRY_STATUS}")
  next_steps+=("bash tools/cockpit/mascarade_incident_registry.sh --json")
fi
if [[ "${MASCARADE_QUEUE_STATUS}" == "degraded" || "${MASCARADE_QUEUE_STATUS}" == "failed" || "${MASCARADE_QUEUE_STATUS}" == "blocked" ]]; then
  degraded_reasons+=("mascarade-queue-${MASCARADE_QUEUE_STATUS}")
  next_steps+=("bash tools/cockpit/render_mascarade_incident_queue.sh --json")
fi
if [[ "${DAILY_OPERATOR_SUMMARY_STATUS}" == "degraded" || "${DAILY_OPERATOR_SUMMARY_STATUS}" == "failed" || "${DAILY_OPERATOR_SUMMARY_STATUS}" == "blocked" ]]; then
  degraded_reasons+=("daily-operator-summary-${DAILY_OPERATOR_SUMMARY_STATUS}")
  next_steps+=("bash tools/cockpit/render_daily_operator_summary.sh --json")
fi
if [[ "${LOG_OPS_SUMMARY_STATUS}" == "degraded" || "${LOG_OPS_SUMMARY_STATUS}" == "failed" || "${LOG_OPS_SUMMARY_STATUS}" == "blocked" ]]; then
  degraded_reasons+=("log-ops-summary-${LOG_OPS_SUMMARY_STATUS}")
  next_steps+=("bash tools/cockpit/log_ops.sh --action summary --retention-days ${PERSIST_DAYS} --json")
fi
if [[ "${LOG_OPS_PURGE_STATUS}" == "degraded" || "${LOG_OPS_PURGE_STATUS}" == "failed" || "${LOG_OPS_PURGE_STATUS}" == "blocked" ]]; then
  degraded_reasons+=("log-ops-purge-${LOG_OPS_PURGE_STATUS}")
  next_steps+=("bash tools/cockpit/log_ops.sh --action purge --retention-days ${PERSIST_DAYS} --apply --json")
fi
if [[ "${result}" == "ko" ]]; then
  degraded_reasons+=("alignment-run-failed")
  next_steps+=("Inspect ${log_file} for the failing step and rerun the degraded-safe checks.")
fi

if $do_purge; then
  find "$LOG_DIR" -type f -name 'machine_alignment_daily_*.log' -mtime +"$PERSIST_DAYS" -delete || true
fi

cp "$log_file" "$summary_file"

{
  echo "[summary] result=$result"
  echo "[summary] mesh_status=$mesh_status"
  echo "[summary] mesh_load_profile=$MESH_LOAD_PROFILE"
  if [[ -n "$mesh_json_file" ]]; then
    echo "[summary] mesh_json_file=$mesh_json_file"
  fi
  echo "[summary] registry_summary_file=$REGISTRY_SUMMARY_FILE"
  echo "[summary] registry_summary_status=$REGISTRY_SUMMARY_STATUS"
  echo "[summary] registry_target_count=$REGISTRY_TARGET_COUNT"
  echo "[summary] registry_default_profile=$REGISTRY_DEFAULT_PROFILE"
  echo "[summary] mascarade_health_status=$MASCARADE_HEALTH_STATUS"
  echo "[summary] mascarade_runtime_status=$MASCARADE_RUNTIME_STATUS"
  echo "[summary] mascarade_provider=$MASCARADE_PROVIDER"
  echo "[summary] mascarade_model=$MASCARADE_MODEL"
  echo "[summary] mascarade_health_file=$MASCARADE_HEALTH_FILE"
  echo "[summary] mascarade_logs_status=$MASCARADE_LOGS_STATUS"
  echo "[summary] mascarade_logs_file=$MASCARADE_LOGS_FILE"
  echo "[summary] mascarade_brief_status=$MASCARADE_BRIEF_STATUS"
  echo "[summary] mascarade_brief_file=$MASCARADE_BRIEF_FILE"
  echo "[summary] mascarade_brief_markdown=$MASCARADE_BRIEF_MARKDOWN"
  echo "[summary] mascarade_registry_status=$MASCARADE_REGISTRY_STATUS"
  echo "[summary] mascarade_registry_file=$MASCARADE_REGISTRY_FILE"
  echo "[summary] mascarade_registry_markdown=$MASCARADE_REGISTRY_MARKDOWN"
  echo "[summary] mascarade_queue_status=$MASCARADE_QUEUE_STATUS"
  echo "[summary] mascarade_queue_file=$MASCARADE_QUEUE_FILE"
  echo "[summary] mascarade_queue_markdown=$MASCARADE_QUEUE_MARKDOWN"
  echo "[summary] log_ops_summary_status=$LOG_OPS_SUMMARY_STATUS"
  echo "[summary] log_ops_stale=$LOG_OPS_STALE"
  echo "[summary] log_ops_purge_status=$LOG_OPS_PURGE_STATUS"
  echo "[summary] log_ops_purged=$LOG_OPS_PURGED"
  echo "[summary] log_ops_summary_file=$LOG_OPS_SUMMARY_FILE"
  echo "[summary] log_ops_purge_file=$LOG_OPS_PURGE_FILE"
  echo "[summary] log_file=$log_file"
  echo "[summary] latest_log=$summary_file"
  echo "[summary] timestamp=$timestamp"
} | tee -a "$log_file"

DAILY_OPERATOR_SUMMARY_FILE="$LOG_DIR/daily_operator_summary_${timestamp}.json"
if bash "$ROOT_DIR/tools/cockpit/render_daily_operator_summary.sh" \
  --daily-log "$log_file" \
  --brief-markdown "$MASCARADE_BRIEF_MARKDOWN" \
  --registry-markdown "$MASCARADE_REGISTRY_MARKDOWN" \
  --queue-markdown "$MASCARADE_QUEUE_MARKDOWN" \
  --json >"$DAILY_OPERATOR_SUMMARY_FILE" 2>>"$log_file"; then
  DAILY_OPERATOR_SUMMARY_STATUS="$(json_field "${DAILY_OPERATOR_SUMMARY_FILE}" status)"
  DAILY_OPERATOR_SUMMARY_MARKDOWN="$(json_field "${DAILY_OPERATOR_SUMMARY_FILE}" markdown_file)"
else
  DAILY_OPERATOR_SUMMARY_STATUS="failed"
fi

MASCARADE_WATCH_FILE="$LOG_DIR/mascarade_incident_watch_${timestamp}.json"
if bash "$ROOT_DIR/tools/cockpit/render_mascarade_incident_watch.sh" --json >"$MASCARADE_WATCH_FILE" 2>>"$log_file"; then
  MASCARADE_WATCH_STATUS="$(json_field "${MASCARADE_WATCH_FILE}" status)"
  MASCARADE_WATCH_MARKDOWN="$(json_field "${MASCARADE_WATCH_FILE}" markdown_file)"
else
  MASCARADE_WATCH_STATUS="failed"
fi

{
  echo "[summary] daily_operator_summary_status=$DAILY_OPERATOR_SUMMARY_STATUS"
  echo "[summary] daily_operator_summary_file=$DAILY_OPERATOR_SUMMARY_FILE"
  echo "[summary] daily_operator_summary_markdown=$DAILY_OPERATOR_SUMMARY_MARKDOWN"
  echo "[summary] mascarade_watch_status=$MASCARADE_WATCH_STATUS"
  echo "[summary] mascarade_watch_file=$MASCARADE_WATCH_FILE"
  echo "[summary] mascarade_watch_markdown=$MASCARADE_WATCH_MARKDOWN"
} | tee -a "$log_file"

MASCARADE_WATCH_HISTORY_FILE="$LOG_DIR/mascarade_watch_history_${timestamp}.json"
if bash "$ROOT_DIR/tools/cockpit/render_mascarade_watch_history.sh" --json >"$MASCARADE_WATCH_HISTORY_FILE" 2>>"$log_file"; then
  MASCARADE_WATCH_HISTORY_STATUS="$(json_field "${MASCARADE_WATCH_HISTORY_FILE}" status)"
  MASCARADE_WATCH_HISTORY_MARKDOWN="$(json_field "${MASCARADE_WATCH_HISTORY_FILE}" markdown_file)"
else
  MASCARADE_WATCH_HISTORY_STATUS="failed"
fi

{
  echo "[summary] mascarade_watch_history_status=$MASCARADE_WATCH_HISTORY_STATUS"
  echo "[summary] mascarade_watch_history_file=$MASCARADE_WATCH_HISTORY_FILE"
  echo "[summary] mascarade_watch_history_markdown=$MASCARADE_WATCH_HISTORY_MARKDOWN"
} | tee -a "$log_file"

if [[ "${DAILY_OPERATOR_SUMMARY_STATUS}" == "degraded" && "${OVERALL_STATUS}" == "ok" ]]; then
  OVERALL_STATUS="degraded"
fi
if [[ "${DAILY_OPERATOR_SUMMARY_STATUS}" == "blocked" || "${DAILY_OPERATOR_SUMMARY_STATUS}" == "failed" ]]; then
  OVERALL_STATUS="ko"
fi
if [[ -n "${DAILY_OPERATOR_SUMMARY_FILE}" ]]; then
  artifacts+=("${DAILY_OPERATOR_SUMMARY_FILE}")
fi
if [[ "${DAILY_OPERATOR_SUMMARY_STATUS}" == "degraded" || "${DAILY_OPERATOR_SUMMARY_STATUS}" == "failed" || "${DAILY_OPERATOR_SUMMARY_STATUS}" == "blocked" ]]; then
  degraded_reasons+=("daily-operator-summary-${DAILY_OPERATOR_SUMMARY_STATUS}")
  next_steps+=("bash tools/cockpit/render_daily_operator_summary.sh --json")
fi
if [[ "${MASCARADE_WATCH_STATUS}" == "degraded" && "${OVERALL_STATUS}" == "ok" ]]; then
  OVERALL_STATUS="degraded"
fi
if [[ "${MASCARADE_WATCH_STATUS}" == "blocked" || "${MASCARADE_WATCH_STATUS}" == "failed" ]]; then
  OVERALL_STATUS="ko"
fi
if [[ -n "${MASCARADE_WATCH_FILE}" ]]; then
  artifacts+=("${MASCARADE_WATCH_FILE}")
fi
if [[ "${MASCARADE_WATCH_STATUS}" == "degraded" || "${MASCARADE_WATCH_STATUS}" == "failed" || "${MASCARADE_WATCH_STATUS}" == "blocked" ]]; then
  degraded_reasons+=("mascarade-watch-${MASCARADE_WATCH_STATUS}")
  next_steps+=("bash tools/cockpit/render_mascarade_incident_watch.sh --json")
fi
if [[ "${MASCARADE_WATCH_HISTORY_STATUS}" == "degraded" && "${OVERALL_STATUS}" == "ok" ]]; then
  OVERALL_STATUS="degraded"
fi
if [[ "${MASCARADE_WATCH_HISTORY_STATUS}" == "blocked" || "${MASCARADE_WATCH_HISTORY_STATUS}" == "failed" ]]; then
  OVERALL_STATUS="ko"
fi
if [[ -n "${MASCARADE_WATCH_HISTORY_FILE}" ]]; then
  artifacts+=("${MASCARADE_WATCH_HISTORY_FILE}")
fi
if [[ "${MASCARADE_WATCH_HISTORY_STATUS}" == "degraded" || "${MASCARADE_WATCH_HISTORY_STATUS}" == "failed" || "${MASCARADE_WATCH_HISTORY_STATUS}" == "blocked" ]]; then
  degraded_reasons+=("mascarade-watch-history-${MASCARADE_WATCH_HISTORY_STATUS}")
  next_steps+=("bash tools/cockpit/render_mascarade_watch_history.sh --json")
fi
if [[ "${OVERALL_STATUS}" == "ok" ]]; then
  result="ok"
elif [[ "${OVERALL_STATUS}" == "degraded" ]]; then
  result="degraded"
else
  result="ko"
fi

MASCARADE_ROUTING_FILE="$LOG_DIR/mascarade_dispatch_route_${timestamp}.json"
if bash "$ROOT_DIR/tools/cockpit/mascarade_dispatch_mesh.sh" --action route --profile "kxkm-mesh-syncops" --json >"$MASCARADE_ROUTING_FILE" 2>>"$log_file"; then
  MASCARADE_ROUTING_STATUS="$(json_field "${MASCARADE_ROUTING_FILE}" status)"
else
  MASCARADE_ROUTING_STATUS="failed"
fi
if [[ -n "${MASCARADE_ROUTING_FILE}" ]]; then
  artifacts+=("${MASCARADE_ROUTING_FILE}")
fi
if [[ "${MASCARADE_ROUTING_STATUS}" == "degraded" || "${MASCARADE_ROUTING_STATUS}" == "failed" || "${MASCARADE_ROUTING_STATUS}" == "blocked" ]]; then
  degraded_reasons+=("mascarade-routing-${MASCARADE_ROUTING_STATUS}")
  next_steps+=("bash tools/cockpit/mascarade_dispatch_mesh.sh --action route --profile kxkm-mesh-syncops --json")
  if [[ "${result}" == "ok" ]]; then
    result="degraded"
  fi
fi

contract_status="$(json_contract_map_status "${result}")"
if [[ "${contract_status}" == "ok" && "${MASCARADE_ROUTING_STATUS}" == "ok" ]]; then
  TRUST_LEVEL="verified"
elif [[ "${MASCARADE_ROUTING_STATUS}" == "ok" ]]; then
  TRUST_LEVEL="bounded"
else
  TRUST_LEVEL="inferred"
fi
RESUME_REF="kill-life:run-alignment-daily:${timestamp}:${MESH_LOAD_PROFILE}"
KILL_LIFE_MEMORY_FILE="$LOG_DIR/kill_life_memory_run_alignment_daily_${timestamp}.json"
memory_next_step="bash tools/cockpit/run_alignment_daily.sh --json --mesh-load-profile ${MESH_LOAD_PROFILE}"
if [[ ${#next_steps[@]} -gt 0 ]]; then
  memory_next_step="${next_steps[0]}"
fi
if bash "$ROOT_DIR/tools/cockpit/write_kill_life_memory_entry.sh" \
  --component "run_alignment_daily" \
  --status "${contract_status}" \
  --owner "SyncOps" \
  --decision-action "run-alignment-daily" \
  --decision-reason "Daily cockpit alignment is persisted in kill_life with explicit Tower/KXKM routing for continuity." \
  --next-step "${memory_next_step}" \
  --resume-ref "${RESUME_REF}" \
  --trust-level "${TRUST_LEVEL}" \
  --routing-file "${MASCARADE_ROUTING_FILE}" \
  --artifact "${log_file}" \
  --artifact "${summary_file}" \
  --artifact "${DAILY_OPERATOR_SUMMARY_FILE}" \
  --artifact "${MASCARADE_WATCH_FILE}" \
  --json >"$KILL_LIFE_MEMORY_FILE" 2>>"$log_file"; then
  KILL_LIFE_MEMORY_STATUS="$(json_field "${KILL_LIFE_MEMORY_FILE}" status)"
  KILL_LIFE_MEMORY_MARKDOWN="$(json_field "${KILL_LIFE_MEMORY_FILE}" markdown_file)"
else
  KILL_LIFE_MEMORY_STATUS="failed"
fi
if [[ -n "${KILL_LIFE_MEMORY_FILE}" ]]; then
  artifacts+=("${KILL_LIFE_MEMORY_FILE}")
fi
if [[ "${KILL_LIFE_MEMORY_STATUS}" == "degraded" || "${KILL_LIFE_MEMORY_STATUS}" == "failed" || "${KILL_LIFE_MEMORY_STATUS}" == "blocked" ]]; then
  degraded_reasons+=("kill-life-memory-${KILL_LIFE_MEMORY_STATUS}")
  next_steps+=("bash tools/cockpit/write_kill_life_memory_entry.sh --component run_alignment_daily --json")
  if [[ "${result}" == "ok" ]]; then
    result="degraded"
  fi
fi

PRODUCT_CONTRACT_HANDOFF_FILE="$LOG_DIR/product_contract_handoff_${timestamp}.json"
if bash "$ROOT_DIR/tools/cockpit/render_product_contract_handoff.sh" --no-refresh --json >"$PRODUCT_CONTRACT_HANDOFF_FILE" 2>>"$log_file"; then
  PRODUCT_CONTRACT_HANDOFF_STATUS="$(json_field "${PRODUCT_CONTRACT_HANDOFF_FILE}" status)"
  PRODUCT_CONTRACT_HANDOFF_MARKDOWN="$(json_field "${PRODUCT_CONTRACT_HANDOFF_FILE}" markdown_file)"
else
  PRODUCT_CONTRACT_HANDOFF_STATUS="failed"
fi
if [[ -n "${PRODUCT_CONTRACT_HANDOFF_FILE}" ]]; then
  artifacts+=("${PRODUCT_CONTRACT_HANDOFF_FILE}")
fi
if [[ "${PRODUCT_CONTRACT_HANDOFF_STATUS}" == "degraded" || "${PRODUCT_CONTRACT_HANDOFF_STATUS}" == "failed" || "${PRODUCT_CONTRACT_HANDOFF_STATUS}" == "blocked" ]]; then
  degraded_reasons+=("product-contract-handoff-${PRODUCT_CONTRACT_HANDOFF_STATUS}")
  next_steps+=("bash tools/cockpit/render_product_contract_handoff.sh --json")
  if [[ "${result}" == "ok" ]]; then
    result="degraded"
  fi
fi

contract_status="$(json_contract_map_status "${result}")"
{
  echo "[summary] final_result=$result"
  echo "[summary] final_contract_status=$contract_status"
  echo "[summary] mascarade_routing_status=$MASCARADE_ROUTING_STATUS"
  echo "[summary] mascarade_routing_file=$MASCARADE_ROUTING_FILE"
  echo "[summary] kill_life_memory_status=$KILL_LIFE_MEMORY_STATUS"
  echo "[summary] kill_life_memory_file=$KILL_LIFE_MEMORY_FILE"
  echo "[summary] kill_life_memory_markdown=$KILL_LIFE_MEMORY_MARKDOWN"
  echo "[summary] product_contract_handoff_status=$PRODUCT_CONTRACT_HANDOFF_STATUS"
  echo "[summary] product_contract_handoff_file=$PRODUCT_CONTRACT_HANDOFF_FILE"
  echo "[summary] product_contract_handoff_markdown=$PRODUCT_CONTRACT_HANDOFF_MARKDOWN"
  echo "[summary] trust_level=$TRUST_LEVEL"
  echo "[summary] resume_ref=$RESUME_REF"
} | tee -a "$log_file"

cp "$log_file" "$summary_file"

if $json_output; then
  decision_json="$(json_decision_object "run-alignment-daily" "Daily cockpit alignment is persisted in kill_life with explicit Tower/KXKM routing for continuity.")"
  routing_json="$(json_inline_object "${MASCARADE_ROUTING_FILE}")"
  memory_entry_json="$(json_inline_object "${KILL_LIFE_MEMORY_FILE}" entry)"
  printf '{"contract_version":"cockpit-v1","component":"run_alignment_daily","action":"summary","status":"%s","contract_status":"%s","generated_at":"%s","registry_file":"%s","result":"%s","mesh_status":"%s","mesh_load_profile":"%s","log_file":"%s","latest_log":"%s","log_dir":"%s","artifacts":%s,"degraded_reasons":%s,"next_steps":%s' \
    "$contract_status" "$contract_status" "$start_ts" "$REGISTRY_FILE" "$result" "$mesh_status" "$MESH_LOAD_PROFILE" "$log_file" "$summary_file" "$LOG_DIR" "$(json_contract_array_from_args "${artifacts[@]}")" "$(json_contract_array_from_args "${degraded_reasons[@]}")" "$(json_contract_array_from_args "${next_steps[@]}")"
  printf ',"owner":"%s","trust_level":"%s","resume_ref":"%s","routing_status":"%s","routing_artifact":"%s","memory_entry_status":"%s","memory_entry_artifact":"%s","decision":%s,"routing":%s,"memory_entry":%s' \
    "SyncOps" "$TRUST_LEVEL" "$RESUME_REF" "$MASCARADE_ROUTING_STATUS" "$MASCARADE_ROUTING_FILE" "$KILL_LIFE_MEMORY_STATUS" "$KILL_LIFE_MEMORY_FILE" "$decision_json" "$routing_json" "$memory_entry_json"
  printf ',"registry_summary_file":"%s","registry_summary_status":"%s","registry_target_count":"%s","registry_default_profile":"%s"' \
    "$REGISTRY_SUMMARY_FILE" "$REGISTRY_SUMMARY_STATUS" "$REGISTRY_TARGET_COUNT" "$REGISTRY_DEFAULT_PROFILE"
  printf ',"mascarade_health_status":"%s","mascarade_runtime_status":"%s","mascarade_provider":"%s","mascarade_model":"%s"' \
    "$MASCARADE_HEALTH_STATUS" "$MASCARADE_RUNTIME_STATUS" "$MASCARADE_PROVIDER" "$MASCARADE_MODEL"
  if [[ -n "$MASCARADE_HEALTH_FILE" ]]; then
    printf ',"mascarade_health_artifact":"%s"' "$MASCARADE_HEALTH_FILE"
  fi
  if [[ -n "$MASCARADE_LOGS_FILE" ]]; then
    printf ',"mascarade_logs_status":"%s","mascarade_logs_artifact":"%s"' "$MASCARADE_LOGS_STATUS" "$MASCARADE_LOGS_FILE"
  fi
  if [[ -n "$MASCARADE_BRIEF_FILE" ]]; then
    printf ',"mascarade_brief_status":"%s","mascarade_brief_artifact":"%s","mascarade_brief_markdown":"%s"' "$MASCARADE_BRIEF_STATUS" "$MASCARADE_BRIEF_FILE" "$MASCARADE_BRIEF_MARKDOWN"
  fi
  if [[ -n "$MASCARADE_REGISTRY_FILE" ]]; then
    printf ',"mascarade_registry_status":"%s","mascarade_registry_artifact":"%s","mascarade_registry_markdown":"%s"' "$MASCARADE_REGISTRY_STATUS" "$MASCARADE_REGISTRY_FILE" "$MASCARADE_REGISTRY_MARKDOWN"
  fi
  if [[ -n "$MASCARADE_QUEUE_FILE" ]]; then
    printf ',"mascarade_queue_status":"%s","mascarade_queue_artifact":"%s","mascarade_queue_markdown":"%s"' "$MASCARADE_QUEUE_STATUS" "$MASCARADE_QUEUE_FILE" "$MASCARADE_QUEUE_MARKDOWN"
  fi
  if [[ -n "$MASCARADE_WATCH_FILE" ]]; then
    printf ',"mascarade_watch_status":"%s","mascarade_watch_artifact":"%s","mascarade_watch_markdown":"%s"' "$MASCARADE_WATCH_STATUS" "$MASCARADE_WATCH_FILE" "$MASCARADE_WATCH_MARKDOWN"
  fi
  if [[ -n "$MASCARADE_WATCH_HISTORY_FILE" ]]; then
    printf ',"mascarade_watch_history_status":"%s","mascarade_watch_history_artifact":"%s","mascarade_watch_history_markdown":"%s"' "$MASCARADE_WATCH_HISTORY_STATUS" "$MASCARADE_WATCH_HISTORY_FILE" "$MASCARADE_WATCH_HISTORY_MARKDOWN"
  fi
  if [[ -n "$DAILY_OPERATOR_SUMMARY_FILE" ]]; then
    printf ',"daily_operator_summary_status":"%s","daily_operator_summary_artifact":"%s","daily_operator_summary_markdown":"%s"' "$DAILY_OPERATOR_SUMMARY_STATUS" "$DAILY_OPERATOR_SUMMARY_FILE" "$DAILY_OPERATOR_SUMMARY_MARKDOWN"
  fi
  if [[ -n "$KILL_LIFE_MEMORY_MARKDOWN" ]]; then
    printf ',"memory_entry_markdown":"%s"' "$KILL_LIFE_MEMORY_MARKDOWN"
  fi
  if [[ -n "$PRODUCT_CONTRACT_HANDOFF_FILE" ]]; then
    printf ',"product_contract_handoff_status":"%s","product_contract_handoff_artifact":"%s","product_contract_handoff_markdown":"%s"' "$PRODUCT_CONTRACT_HANDOFF_STATUS" "$PRODUCT_CONTRACT_HANDOFF_FILE" "$PRODUCT_CONTRACT_HANDOFF_MARKDOWN"
  fi
  if [[ -n "$mesh_json_file" ]]; then
    printf ',"mesh_json_file":"%s"' "$mesh_json_file"
  fi
  if [[ -n "$LOG_OPS_SUMMARY_FILE" ]]; then
    printf ',"log_ops_summary_file":"%s","log_ops_summary_status":"%s","log_ops_stale":"%s"' \
      "$LOG_OPS_SUMMARY_FILE" "$LOG_OPS_SUMMARY_STATUS" "$LOG_OPS_STALE"
  fi
  if [[ -n "$LOG_OPS_PURGE_FILE" ]]; then
    printf ',"log_ops_purge_file":"%s","log_ops_purge_status":"%s","log_ops_purged":"%s"' \
      "$LOG_OPS_PURGE_FILE" "$LOG_OPS_PURGE_STATUS" "$LOG_OPS_PURGED"
  fi
  printf '}\n'
fi

if [[ "$result" == ko ]]; then
  echo "[error] alignment run failed; consult log: $log_file" >&2
  exit 1
fi
