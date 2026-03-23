#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
source "${ROOT_DIR}/tools/cockpit/json_contract.sh"

AUDIT_DOC="${ROOT_DIR}/docs/KILL_LIFE_CONSOLIDATION_AUDIT_2026-03-21.md"
SPEC_DOC="${ROOT_DIR}/specs/agentic_intelligence_integration_spec.md"
FEATURE_DOC="${ROOT_DIR}/docs/AGENTIC_INTELLIGENCE_FEATURE_MAP_2026-03-21.md"
PLAN_DOC="${ROOT_DIR}/docs/plans/22_plan_integration_intelligence_agentique.md"
TODO_DOC="${ROOT_DIR}/docs/plans/22_todo_integration_intelligence_agentique.md"
RESEARCH_DOC="${ROOT_DIR}/docs/WEB_RESEARCH_OPEN_SOURCE_2026-03-20.md"
OWNERS_DOC="${ROOT_DIR}/docs/plans/12_plan_gestion_des_agents.md"
GLOBAL_TASKS_DOC="${ROOT_DIR}/specs/04_tasks.md"

LOG_DIR="${ROOT_DIR}/artifacts/cockpit/intelligence_program_tui"
mkdir -p "${LOG_DIR}"

ACTION=""
JSON=0
RETENTION_DAYS=7
LINES=120
LOG_FILE="${LOG_DIR}/intelligence_program_tui_$(date '+%Y%m%d_%H%M%S').log"

usage() {
  cat <<'EOF'
Usage: bash tools/cockpit/intelligence_program_tui.sh [options]

Options:
  --action <status|audit|feature-map|spec|plan|todo|research|owners|logs-summary|logs-list|logs-latest|purge-logs>
  --json
  --days <N>
  --lines <N>
  -h, --help
EOF
}

have_tty() {
  [[ -t 0 && -t 1 ]]
}

choose_action_interactive() {
  if command -v gum >/dev/null 2>&1 && have_tty; then
    gum choose \
      status \
      audit \
      feature-map \
      spec \
      plan \
      todo \
      research \
      owners \
      logs-summary \
      logs-list \
      logs-latest \
      purge-logs
    return 0
  fi
  return 1
}

log_line() {
  local level="$1"
  shift
  local msg="$*"
  printf '[%s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')" "${level}" "${msg}" | tee -a "${LOG_FILE}" >&2
}

count_matching_lines() {
  local pattern="$1"
  local file="$2"
  rg -c "${pattern}" "${file}" 2>/dev/null || printf '0\n'
}

show_file() {
  local file="$1"
  if [[ ! -f "${file}" ]]; then
    printf 'Missing file: %s\n' "${file}" >&2
    return 1
  fi
  sed -n "1,${LINES}p" "${file}"
}

emit_status() {
  local status="ok"
  local contract_status="ok"
  local degraded_reasons=()
  local next_steps=(
    "bash tools/cockpit/intelligence_program_tui.sh --action plan"
    "bash tools/cockpit/intelligence_program_tui.sh --action todo"
    "bash tools/cockpit/intelligence_program_tui.sh --action research"
  )
  local open_todo_count completed_todo_count global_open_tasks

  open_todo_count="$(count_matching_lines '^- \[ \]' "${TODO_DOC}")"
  completed_todo_count="$(count_matching_lines '^- \[x\]' "${TODO_DOC}")"
  global_open_tasks="$(count_matching_lines '^- \[ \]' "${GLOBAL_TASKS_DOC}")"

  for required_file in "${AUDIT_DOC}" "${SPEC_DOC}" "${FEATURE_DOC}" "${PLAN_DOC}" "${TODO_DOC}" "${RESEARCH_DOC}" "${OWNERS_DOC}"; do
    if [[ ! -f "${required_file}" ]]; then
      status="degraded"
      degraded_reasons+=("missing:$(basename "${required_file}")")
    fi
  done

  contract_status="$(json_contract_map_status "${status}")"

  if [[ "${JSON}" -eq 1 ]]; then
    printf '{\n'
    printf '  "contract_version": "cockpit-v1",\n'
    printf '  "component": "intelligence_program_tui",\n'
    printf '  "contract_status": "%s",\n' "${contract_status}"
    printf '  "status": "%s",\n' "${status}"
    printf '  "action": "status",\n'
    printf '  "artifacts": %s,\n' "$(json_contract_array_from_args "${LOG_FILE}" "${AUDIT_DOC}" "${SPEC_DOC}" "${FEATURE_DOC}" "${PLAN_DOC}" "${TODO_DOC}")"
    printf '  "degraded_reasons": %s,\n' "$(json_contract_array_from_args "${degraded_reasons[@]}")"
    printf '  "next_steps": %s,\n' "$(json_contract_array_from_args "${next_steps[@]}")"
    printf '  "audit_doc": "%s",\n' "${AUDIT_DOC}"
    printf '  "spec_doc": "%s",\n' "${SPEC_DOC}"
    printf '  "feature_map_doc": "%s",\n' "${FEATURE_DOC}"
    printf '  "plan_doc": "%s",\n' "${PLAN_DOC}"
    printf '  "todo_doc": "%s",\n' "${TODO_DOC}"
    printf '  "research_doc": "%s",\n' "${RESEARCH_DOC}"
    printf '  "owners_doc": "%s",\n' "${OWNERS_DOC}"
    printf '  "open_todo_count": %s,\n' "${open_todo_count}"
    printf '  "completed_todo_count": %s,\n' "${completed_todo_count}"
    printf '  "global_open_tasks": %s,\n' "${global_open_tasks}"
    printf '  "log_file": "%s"\n' "${LOG_FILE}"
    printf '}\n'
  else
    printf 'Intelligence Program Status\n\n'
    printf 'status: %s\n' "${status}"
    printf 'audit: %s\n' "${AUDIT_DOC}"
    printf 'spec: %s\n' "${SPEC_DOC}"
    printf 'feature map: %s\n' "${FEATURE_DOC}"
    printf 'plan: %s\n' "${PLAN_DOC}"
    printf 'todo: %s\n' "${TODO_DOC}"
    printf 'research: %s\n' "${RESEARCH_DOC}"
    printf 'owners: %s\n' "${OWNERS_DOC}"
    printf 'todo open/completed: %s/%s\n' "${open_todo_count}" "${completed_todo_count}"
    printf 'global open tasks: %s\n' "${global_open_tasks}"
    printf 'log: %s\n' "${LOG_FILE}"
  fi
}

list_logs() {
  find "${LOG_DIR}" -type f -name 'intelligence_program_tui_*.log' | sort
}

latest_log() {
  find "${LOG_DIR}" -type f -name 'intelligence_program_tui_*.log' | sort | tail -n 1
}

purge_logs() {
  find "${LOG_DIR}" -type f -name 'intelligence_program_tui_*.log' -mtime +"${RETENTION_DAYS}" -delete
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --action)
      ACTION="${2:-}"
      shift 2
      ;;
    --json)
      JSON=1
      shift
      ;;
    --days)
      RETENTION_DAYS="${2:-7}"
      shift 2
      ;;
    --lines)
      LINES="${2:-120}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "${ACTION}" ]]; then
  if ACTION="$(choose_action_interactive)"; then
    :
  else
    ACTION="status"
  fi
fi

case "${ACTION}" in
  status)
    log_line "INFO" "status"
    emit_status
    ;;
  audit)
    log_line "INFO" "audit"
    show_file "${AUDIT_DOC}"
    ;;
  feature-map)
    log_line "INFO" "feature-map"
    show_file "${FEATURE_DOC}"
    ;;
  spec)
    log_line "INFO" "spec"
    show_file "${SPEC_DOC}"
    ;;
  plan)
    log_line "INFO" "plan"
    show_file "${PLAN_DOC}"
    ;;
  todo)
    log_line "INFO" "todo"
    show_file "${TODO_DOC}"
    ;;
  research)
    log_line "INFO" "research"
    show_file "${RESEARCH_DOC}"
    ;;
  owners)
    log_line "INFO" "owners"
    show_file "${OWNERS_DOC}"
    ;;
  logs-summary)
    log_line "INFO" "logs-summary"
    printf 'log_dir=%s\n' "${LOG_DIR}"
    printf 'latest=%s\n' "$(latest_log)"
    printf 'count=%s\n' "$(find "${LOG_DIR}" -type f -name 'intelligence_program_tui_*.log' | wc -l | tr -d ' ')"
    ;;
  logs-list)
    log_line "INFO" "logs-list"
    list_logs
    ;;
  logs-latest)
    log_line "INFO" "logs-latest"
    latest="$(latest_log)"
    if [[ -n "${latest}" ]]; then
      cat "${latest}"
    fi
    ;;
  purge-logs)
    log_line "INFO" "purge-logs days=${RETENTION_DAYS}"
    purge_logs
    ;;
  *)
    printf 'Unknown action: %s\n' "${ACTION}" >&2
    usage >&2
    exit 2
    ;;
esac
