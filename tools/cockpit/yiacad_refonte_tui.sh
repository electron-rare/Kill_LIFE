#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts/yiacad_refonte_tui"
mkdir -p "${ARTIFACTS_DIR}"

ACTION=""
JSON_MODE=0
VERBOSE=0
YES=0
DAYS=14
LINES=80

usage() {
  cat <<'EOF'
Usage: yiacad_refonte_tui.sh --action <status|backend-architecture|audit|ai-assessment|feature-map|spec|plan|todo|research|logs-summary|logs-list|logs-latest|purge-logs> [options]

Options:
  --action <name>   Action to run
  --days <N>        Retention window for purge-logs (default: 14)
  --lines <N>       Number of lines for logs-latest (default: 80)
  --json            Emit JSON for logs-summary
  --yes             Confirm destructive purge in non-interactive mode
  --verbose         Print executed commands
  --help            Show this help
EOF
}

have_tty() {
  [[ -t 0 && -t 1 ]]
}

choose_action_interactive() {
  if command -v gum >/dev/null 2>&1 && have_tty; then
    gum choose \
      status \
      backend-architecture \
      audit \
      ai-assessment \
      feature-map \
      spec \
      plan \
      todo \
      research \
      logs-summary \
      logs-list \
      logs-latest \
      purge-logs
    return 0
  fi
  return 1
}

show_file() {
  local path="$1"
  if [[ -f "${path}" ]]; then
    cat "${path}"
  else
    printf 'missing file: %s\n' "${path}"
    return 1
  fi
}

status_view() {
  cat <<EOF
# YiACAD Global Refonte Status

- operator-index: ${ROOT_DIR}/tools/cockpit/yiacad_operator_index.sh
- audit: ${ROOT_DIR}/docs/YIACAD_GLOBAL_REFACTOR_AUDIT_2026-03-20.md
- ai-assessment: ${ROOT_DIR}/docs/YIACAD_GLOBAL_AI_INTEGRATION_ASSESSMENT_2026-03-20.md
- feature-map: ${ROOT_DIR}/docs/YIACAD_GLOBAL_FEATURE_MAP_2026-03-20.md
- backend-architecture: ${ROOT_DIR}/docs/YIACAD_BACKEND_ARCHITECTURE_2026-03-20.md
- backend-service: ${ROOT_DIR}/docs/YIACAD_BACKEND_SERVICE_2026-03-21.md
- spec: ${ROOT_DIR}/specs/yiacad_global_refonte_spec.md
- plan: ${ROOT_DIR}/docs/plans/21_plan_refonte_globale_yiacad.md
- todo: ${ROOT_DIR}/docs/plans/21_todo_refonte_globale_yiacad.md
- research: ${ROOT_DIR}/docs/YIACAD_GLOBAL_OSS_RESEARCH_2026-03-20.md
- operator-doc: ${ROOT_DIR}/docs/YIACAD_OPERATOR_INDEX_2026-03-21.md
- next lot: T-UX-004 + T-RE-209
EOF
}

collect_log_files() {
  find "${ARTIFACTS_DIR}" -type f 2>/dev/null
}

logs_list() {
  local found=0
  local path=""

  while IFS= read -r path; do
    [[ -n "${path}" ]] || continue
    [[ "${path}" == "${LOG_FILE:-}" ]] && continue
    printf '%s\n' "${path}"
    found=1
  done < <(collect_log_files | sort)

  if [[ "${found}" -eq 0 ]]; then
    if [[ -n "${LOG_FILE:-}" ]]; then
      printf '%s\n' "${LOG_FILE}"
    else
      printf 'no logs found\n'
    fi
  fi
}

logs_latest() {
  local latest=""
  local path=""

  while IFS= read -r path; do
    [[ -n "${path}" ]] || continue
    [[ "${path}" == "${LOG_FILE:-}" ]] && continue
    latest="${path}"
  done < <(collect_log_files | sort)

  if [[ -z "${latest}" ]]; then
    if [[ -n "${LOG_FILE:-}" ]]; then
      latest="${LOG_FILE}"
    else
      printf 'no logs found\n'
      return 1
    fi
  fi

  printf '# Latest log\n\n'
  printf -- '- path: %s\n' "${latest}"
  printf -- '- lines: %s\n\n' "${LINES}"
  tail -n "${LINES}" "${latest}"
}

logs_summary() {
  local log_count
  log_count="$(find "${ARTIFACTS_DIR}" -type f | wc -l | tr -d ' ')"

  if [[ "${JSON_MODE}" -eq 1 ]]; then
    python3 - <<PY
import json
print(json.dumps({
  "status": "done",
  "log_files": int("${log_count}"),
  "artifacts_dir": "${ARTIFACTS_DIR}",
  "next_lot": "T-UX-004 + T-RE-209",
}, ensure_ascii=False))
PY
    return 0
  fi

  cat <<EOF
# YiACAD global refonte logs summary

- log files: ${log_count}
- artifacts dir: ${ARTIFACTS_DIR}
- next lot: T-UX-004 + lot operateur YiACAD
EOF
}

purge_logs() {
  if [[ "${YES}" -ne 1 ]]; then
    if command -v gum >/dev/null 2>&1 && have_tty; then
      if ! gum confirm "Purger les logs YiACAD globaux de plus de ${DAYS} jours ?"; then
        printf 'purge cancelled\n'
        return 0
      fi
    else
      printf 'Refusing purge without --yes outside interactive confirm\n' >&2
      return 2
    fi
  fi

  find "${ARTIFACTS_DIR}" -type f -mtime +"${DAYS}" -delete
  printf 'purged yiacad refonte logs older than %s days in %s\n' "${DAYS}" "${ARTIFACTS_DIR}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --action)
      ACTION="${2:-}"
      shift 2
      ;;
    --days)
      DAYS="${2:-}"
      shift 2
      ;;
    --lines)
      LINES="${2:-}"
      shift 2
      ;;
    --json)
      JSON_MODE=1
      shift
      ;;
    --yes)
      YES=1
      shift
      ;;
    --verbose)
      VERBOSE=1
      shift
      ;;
    --help)
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
    printf 'Missing --action (interactive selection unavailable)\n' >&2
    usage >&2
    exit 2
  fi
fi

if ! [[ "${DAYS}" =~ ^[0-9]+$ ]]; then
  printf -- '--days requires an integer\n' >&2
  exit 2
fi

if ! [[ "${LINES}" =~ ^[0-9]+$ ]]; then
  printf -- '--lines requires an integer\n' >&2
  exit 2
fi

STAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${ARTIFACTS_DIR}/yiacad_refonte_tui_${STAMP}.log"
exec > >(tee -a "${LOG_FILE}") 2>&1

printf '[yiacad-refonte-tui] action=%s timestamp=%s\n' "${ACTION}" "${STAMP}"

case "${ACTION}" in
  status)
    status_view
    ;;
  backend-architecture)
    show_file "${ROOT_DIR}/docs/YIACAD_BACKEND_ARCHITECTURE_2026-03-20.md"
    ;;
  audit)
    show_file "${ROOT_DIR}/docs/YIACAD_GLOBAL_REFACTOR_AUDIT_2026-03-20.md"
    ;;
  ai-assessment)
    show_file "${ROOT_DIR}/docs/YIACAD_GLOBAL_AI_INTEGRATION_ASSESSMENT_2026-03-20.md"
    ;;
  feature-map)
    show_file "${ROOT_DIR}/docs/YIACAD_GLOBAL_FEATURE_MAP_2026-03-20.md"
    ;;
  spec)
    show_file "${ROOT_DIR}/specs/yiacad_global_refonte_spec.md"
    ;;
  plan)
    show_file "${ROOT_DIR}/docs/plans/21_plan_refonte_globale_yiacad.md"
    ;;
  todo)
    show_file "${ROOT_DIR}/docs/plans/21_todo_refonte_globale_yiacad.md"
    ;;
  research)
    show_file "${ROOT_DIR}/docs/YIACAD_GLOBAL_OSS_RESEARCH_2026-03-20.md"
    ;;
  logs-summary)
    logs_summary
    ;;
  logs-list)
    logs_list
    ;;
  logs-latest)
    logs_latest
    ;;
  purge-logs)
    purge_logs
    ;;
  *)
    printf 'Unknown action: %s\n' "${ACTION}" >&2
    exit 2
    ;;
esac
