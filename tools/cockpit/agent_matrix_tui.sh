#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
MATRIX_DOC="${ROOT_DIR}/docs/AGENT_SPEC_MODULE_MATRIX_2026-03-20.md"
TASKS_DOC="${ROOT_DIR}/specs/04_tasks.md"
PLAN_DOC="${ROOT_DIR}/docs/plans/12_plan_gestion_des_agents.md"
INSERTION_DOC="${ROOT_DIR}/docs/YIACAD_NATIVE_UI_INSERTION_POINTS_2026-03-20.md"
LOG_DIR="${ROOT_DIR}/artifacts/cockpit"
mkdir -p "${LOG_DIR}"

ACTION="summary"
JSON=0
RETENTION_DAYS=7
LOG_FILE="${LOG_DIR}/agent_matrix_tui_$(date '+%Y%m%d_%H%M%S').log"

log_line() {
  local level="$1"
  shift
  local msg="${level} $(date '+%Y-%m-%d %H:%M:%S %z') ${*}"
  printf '%s\n' "${msg}" | tee -a "${LOG_FILE}"
}

usage() {
  cat <<'EOF'
Usage: bash tools/cockpit/agent_matrix_tui.sh [--action summary|owners|open-tasks|insertion-points|logs-list|logs-latest|clean-logs] [--json] [--days N]
EOF
}

count_lines() {
  local pattern="$1"
  local file="$2"
  rg -c "${pattern}" "${file}" 2>/dev/null || printf '0\n'
}

emit_summary_json() {
  local specs_count="$1"
  local kl_modules_count="$2"
  local mascarade_count="$3"
  local crazy_count="$4"
  local open_tasks="$5"
  local native_forks_count="$6"
  printf '{\n'
  printf '  "generated_at": "%s",\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
  printf '  "matrix_doc": "%s",\n' "${MATRIX_DOC}"
  printf '  "spec_rows": %s,\n' "${specs_count}"
  printf '  "kill_life_module_rows": %s,\n' "${kl_modules_count}"
  printf '  "mascarade_rows": %s,\n' "${mascarade_count}"
  printf '  "crazy_life_rows": %s,\n' "${crazy_count}"
  printf '  "native_fork_rows": %s,\n' "${native_forks_count}"
  printf '  "open_tasks": %s,\n' "${open_tasks}"
  printf '  "log_file": "%s"\n' "${LOG_FILE}"
  printf '}\n'
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

case "${ACTION}" in
  summary)
    specs_count="$(count_lines '^\| `specs/' "${MATRIX_DOC}")"
    kl_modules_count="$(count_lines '^\| `tools/|^\| `workflows/|^\| `\.github/workflows/|^\| `hardware/|^\| `firmware/|^\| `compliance/|^\| `openclaw/|^\| `agents/|^\| `docs/' "${MATRIX_DOC}")"
    mascarade_count="$(count_lines '^\| `WS[0-9]' "${MATRIX_DOC}")"
    crazy_count="$(count_lines '^\| `WS-[0-9]' "${MATRIX_DOC}")"
    native_forks_count="$(count_lines '^\| `\.runtime-home/cad-ai-native-forks/' "${MATRIX_DOC}")"
    open_tasks="$(count_lines '^- \[ \]' "${TASKS_DOC}")"
    log_line "INFO" "spec_rows=${specs_count} kill_life_module_rows=${kl_modules_count} mascarade_rows=${mascarade_count} crazy_life_rows=${crazy_count} native_fork_rows=${native_forks_count} open_tasks=${open_tasks}"
    if [[ "${JSON}" -eq 1 ]]; then
      emit_summary_json "${specs_count}" "${kl_modules_count}" "${mascarade_count}" "${crazy_count}" "${open_tasks}" "${native_forks_count}"
    else
      printf 'Matrix: %s\n' "${MATRIX_DOC}"
      printf 'Spec rows: %s\n' "${specs_count}"
      printf 'Kill_LIFE module rows: %s\n' "${kl_modules_count}"
      printf 'mascarade rows: %s\n' "${mascarade_count}"
      printf 'crazy_life rows: %s\n' "${crazy_count}"
      printf 'Native fork rows: %s\n' "${native_forks_count}"
      printf 'Open tasks: %s\n' "${open_tasks}"
      printf 'Log: %s\n' "${LOG_FILE}"
    fi
    ;;
  owners)
    log_line "INFO" "Printing owner registry"
    sed -n '1,260p' "${MATRIX_DOC}"
    ;;
  open-tasks)
    log_line "INFO" "Printing open tasks"
    rg '^- \[ \]' "${TASKS_DOC}" || true
    ;;
  insertion-points)
    log_line "INFO" "Printing YiACAD native insertion points"
    sed -n '1,260p' "${INSERTION_DOC}"
    ;;
  logs-list)
    log_line "INFO" "Listing agent_matrix_tui logs"
    find "${LOG_DIR}" -name 'agent_matrix_tui_*.log' -type f | sort
    ;;
  logs-latest)
    log_line "INFO" "Printing latest agent_matrix_tui log"
    latest_log="$(find "${LOG_DIR}" -name 'agent_matrix_tui_*.log' -type f | sort | tail -n 1)"
    if [[ -n "${latest_log}" ]]; then
      cat "${latest_log}"
    fi
    ;;
  clean-logs)
    log_line "INFO" "Cleaning agent_matrix_tui logs older than ${RETENTION_DAYS} days"
    find "${LOG_DIR}" -name 'agent_matrix_tui_*.log' -type f -mtime +"${RETENTION_DAYS}" -delete
    ;;
  *)
    printf 'Unknown action: %s\n' "${ACTION}" >&2
    usage >&2
    exit 2
    ;;
esac
