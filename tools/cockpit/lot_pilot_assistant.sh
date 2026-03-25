#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
source "${ROOT_DIR}/tools/cockpit/json_contract.sh"

TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
ARTIFACT_DIR="${ROOT_DIR}/artifacts/cockpit/lot_pilot"
mkdir -p "${ARTIFACT_DIR}"
LOG_FILE="${ARTIFACT_DIR}/lot_pilot_${TIMESTAMP}.json"

JSON=0
VERBOSE=0
LOT_ID=""
COMMAND=""

usage() {
  cat <<'EOF'
Usage: bash tools/cockpit/lot_pilot_assistant.sh <command> [options]

Guide operators through controlled lot execution:
  status check -> preflight -> execute -> validate -> close

Commands:
  status <lot_id>    Show current lot status and readiness
  preflight <lot_id> Run preflight checks before execution
  execute <lot_id>   Execute the lot (runs preflight first)
  validate <lot_id>  Validate lot results after execution
  close <lot_id>     Mark lot as done and archive evidence
  full <lot_id>      Run the full pipeline: preflight -> execute -> validate -> close

Options:
  --json             Output JSON
  --verbose          Print progress logs
  -h, --help         Show this help

Examples:
  bash tools/cockpit/lot_pilot_assistant.sh status T-MESH-010
  bash tools/cockpit/lot_pilot_assistant.sh full T-RE-304 --json
EOF
}

log() {
  if [[ "${VERBOSE}" == "1" ]]; then
    printf '[lot-pilot] %s\n' "$*"
  fi
}

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

emit_json() {
  local step="$1"
  local status="$2"
  local detail="$3"
  local payload
  payload="$(cat <<ENDJSON
{
  "lot_id": "$(json_contract_escape "${LOT_ID}")",
  "step": "${step}",
  "status": "${status}",
  "detail": "$(json_contract_escape "${detail}")",
  "timestamp": "${TIMESTAMP}"
}
ENDJSON
)"
  printf '%s\n' "${payload}"
}

# --- step: status ---
step_status() {
  local lot_id="$1"
  local found=0
  local lot_status="unknown"
  local lot_line=""

  # Search in specs/04_tasks.md and docs/plans/*.md
  local search_files=()
  [[ -f "${ROOT_DIR}/specs/04_tasks.md" ]] && search_files+=("${ROOT_DIR}/specs/04_tasks.md")
  for f in "${ROOT_DIR}"/docs/plans/*.md; do
    [[ -f "${f}" ]] && search_files+=("${f}")
  done

  for f in "${search_files[@]}"; do
    lot_line="$(grep -i "${lot_id}" "${f}" 2>/dev/null | head -n1 || true)"
    if [[ -n "${lot_line}" ]]; then
      found=1
      if printf '%s' "${lot_line}" | grep -q '\[x\]'; then
        lot_status="done"
      elif printf '%s' "${lot_line}" | grep -qi 'blocked\|bloque'; then
        lot_status="blocked"
      else
        lot_status="open"
      fi
      break
    fi
  done

  if [[ "${found}" == "0" ]]; then
    lot_status="not_found"
    lot_line="Lot ${lot_id} not found in specs or plans"
  fi

  log "status: ${lot_id} -> ${lot_status}"
  if [[ "${JSON}" == "1" ]]; then
    emit_json "status" "${lot_status}" "${lot_line}"
  else
    printf 'Lot: %s\nStatus: %s\nDetail: %s\n' "${lot_id}" "${lot_status}" "${lot_line}"
  fi
  printf '%s' "${lot_status}"
}

# --- step: preflight ---
step_preflight() {
  local lot_id="$1"
  local preflight_status="ready"
  local checks=""

  # 1. git status clean?
  local dirty
  dirty="$(git -C "${ROOT_DIR}" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "${dirty}" -gt 20 ]]; then
    preflight_status="degraded"
    checks="dirty_count=${dirty} (high)"
  else
    checks="dirty_count=${dirty}"
  fi

  # 2. mesh health recent?
  local mesh_ok="no"
  local latest_health
  latest_health="$(ls -t "${ROOT_DIR}"/artifacts/cockpit/health_reports/mesh_health_check_*.json 2>/dev/null | head -n1 || true)"
  if [[ -n "${latest_health}" ]]; then
    mesh_ok="yes"
    checks="${checks}, mesh_report=present"
  else
    checks="${checks}, mesh_report=missing"
    [[ "${preflight_status}" == "ready" ]] && preflight_status="degraded"
  fi

  # 3. lot_chain status available?
  if [[ -f "${ROOT_DIR}/artifacts/cockpit/useful_lots_status.md" ]]; then
    checks="${checks}, lot_tracker=present"
  else
    checks="${checks}, lot_tracker=missing"
  fi

  log "preflight: ${lot_id} -> ${preflight_status} (${checks})"
  if [[ "${JSON}" == "1" ]]; then
    emit_json "preflight" "${preflight_status}" "${checks}"
  else
    printf 'Preflight for %s: %s\nChecks: %s\n' "${lot_id}" "${preflight_status}" "${checks}"
  fi
  printf '%s' "${preflight_status}"
}

# --- step: execute ---
step_execute() {
  local lot_id="$1"
  local exec_status="done"
  local detail=""

  # Run lot_chain status to refresh tracker
  log "execute: refreshing lot tracker..."
  local chain_output
  chain_output="$(bash "${ROOT_DIR}/tools/cockpit/lot_chain.sh" status 2>&1 || true)"
  detail="lot_chain status refreshed"

  # Run evidence pack
  log "execute: building evidence pack..."
  local evidence_output
  evidence_output="$(bash "${ROOT_DIR}/tools/cockpit/evidence_pack_builder.sh" --json 2>/dev/null || true)"
  if [[ -n "${evidence_output}" ]]; then
    detail="${detail}, evidence_pack=built"
  else
    detail="${detail}, evidence_pack=failed"
    exec_status="degraded"
  fi

  log "execute: ${lot_id} -> ${exec_status}"
  if [[ "${JSON}" == "1" ]]; then
    emit_json "execute" "${exec_status}" "${detail}"
  else
    printf 'Execute %s: %s\nDetail: %s\n' "${lot_id}" "${exec_status}" "${detail}"
  fi
  printf '%s' "${exec_status}"
}

# --- step: validate ---
step_validate() {
  local lot_id="$1"
  local val_status="done"
  local detail=""

  # Check that evidence pack exists
  local latest_pack
  latest_pack="$(ls -t "${ROOT_DIR}"/artifacts/cockpit/evidence_packs/evidence_pack_*.json 2>/dev/null | head -n1 || true)"
  if [[ -n "${latest_pack}" ]]; then
    local pack_status
    pack_status="$(sed -n 's/.*"overall_status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${latest_pack}" | head -n1 || echo "unknown")"
    detail="evidence_pack=${pack_status}"
    case "${pack_status}" in
      blocked) val_status="blocked" ;;
      degraded) val_status="degraded" ;;
    esac
  else
    detail="no evidence pack found"
    val_status="degraded"
  fi

  log "validate: ${lot_id} -> ${val_status}"
  if [[ "${JSON}" == "1" ]]; then
    emit_json "validate" "${val_status}" "${detail}"
  else
    printf 'Validate %s: %s\nDetail: %s\n' "${lot_id}" "${val_status}" "${detail}"
  fi
  printf '%s' "${val_status}"
}

# --- step: close ---
step_close() {
  local lot_id="$1"
  local close_status="done"
  local detail="lot ${lot_id} closed at ${TIMESTAMP}"

  # Archive: copy latest evidence pack to lot-specific name
  local latest_pack
  latest_pack="$(ls -t "${ROOT_DIR}"/artifacts/cockpit/evidence_packs/evidence_pack_*.json 2>/dev/null | head -n1 || true)"
  if [[ -n "${latest_pack}" ]]; then
    local archive_name="${ARTIFACT_DIR}/${lot_id}_evidence_${TIMESTAMP}.json"
    cp "${latest_pack}" "${archive_name}"
    detail="${detail}, archived=${archive_name}"
  fi

  log "close: ${lot_id} -> ${close_status}"
  if [[ "${JSON}" == "1" ]]; then
    emit_json "close" "${close_status}" "${detail}"
  else
    printf 'Close %s: %s\nDetail: %s\n' "${lot_id}" "${close_status}" "${detail}"
  fi
  printf '%s' "${close_status}"
}

# --- arg parse ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    status|preflight|execute|validate|close|full)
      COMMAND="$1"
      if [[ $# -ge 2 && ! "$2" =~ ^-- ]]; then
        LOT_ID="$2"; shift
      fi
      shift
      ;;
    --json)    JSON=1; shift ;;
    --verbose) VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)         die "Unknown option: $1" ;;
  esac
done

[[ -n "${COMMAND}" ]] || { usage; die "Error: command required"; }
[[ -n "${LOT_ID}" ]] || die "Error: lot_id required"

# --- dispatch ---
case "${COMMAND}" in
  status)
    step_status "${LOT_ID}" > /dev/null
    step_status "${LOT_ID}"
    ;;
  preflight)
    step_preflight "${LOT_ID}" > /dev/null
    step_preflight "${LOT_ID}"
    ;;
  execute)
    pf="$(step_preflight "${LOT_ID}" 2>/dev/null | tail -1)"
    if [[ "${pf}" == "blocked" ]]; then
      die "Preflight blocked for ${LOT_ID} -- fix issues before executing"
    fi
    step_execute "${LOT_ID}" > /dev/null
    step_execute "${LOT_ID}"
    ;;
  validate)
    step_validate "${LOT_ID}" > /dev/null
    step_validate "${LOT_ID}"
    ;;
  close)
    step_close "${LOT_ID}" > /dev/null
    step_close "${LOT_ID}"
    ;;
  full)
    log "=== Full pipeline for ${LOT_ID} ==="
    results=()

    # preflight
    pf="$(step_preflight "${LOT_ID}" 2>/dev/null | tail -1)"
    results+=("preflight=${pf}")
    if [[ "${pf}" == "blocked" ]]; then
      die "Preflight blocked -- aborting pipeline for ${LOT_ID}"
    fi

    # execute
    ex="$(step_execute "${LOT_ID}" 2>/dev/null | tail -1)"
    results+=("execute=${ex}")

    # validate
    va="$(step_validate "${LOT_ID}" 2>/dev/null | tail -1)"
    results+=("validate=${va}")

    # close (only if validate passed)
    if [[ "${va}" != "blocked" ]]; then
      cl="$(step_close "${LOT_ID}" 2>/dev/null | tail -1)"
      results+=("close=${cl}")
    else
      results+=("close=skipped")
    fi

    # summary
    pipeline_status="done"
    for r in "${results[@]}"; do
      case "${r}" in
        *=blocked) pipeline_status="blocked" ;;
        *=degraded) [[ "${pipeline_status}" != "blocked" ]] && pipeline_status="degraded" ;;
      esac
    done

    summary="$(printf '%s, ' "${results[@]}" | sed 's/, $//')"
    if [[ "${JSON}" == "1" ]]; then
      emit_json "full" "${pipeline_status}" "${summary}"
    else
      printf 'Pipeline for %s: %s\nSteps: %s\n' "${LOT_ID}" "${pipeline_status}" "${summary}"
    fi
    ;;
esac

# Write log
{
  emit_json "${COMMAND}" "completed" "lot_id=${LOT_ID}"
} > "${LOG_FILE}" 2>/dev/null || true
