#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SERVICE_ARTIFACTS_DIR="${ROOT_DIR}/artifacts/cad-ai-native/service"
TUI_ARTIFACTS_DIR="${ROOT_DIR}/artifacts/yiacad_backend_service_tui"
mkdir -p "${TUI_ARTIFACTS_DIR}"

ACTION=""
JSON_MODE=0
YES=0
DAYS=14
LINES=80

usage() {
  cat <<'EOF'
Usage: yiacad_backend_service_tui.sh --action <status|health|logs-summary|logs-list|logs-latest|purge-logs> [options]

Options:
  --action <name>   Action to run
  --days <N>        Retention window for purge-logs (default: 14)
  --lines <N>       Number of lines for logs-latest (default: 80)
  --json            Emit JSON for health/logs-summary
  --yes             Confirm destructive purge in non-interactive mode
  --help            Show this help
EOF
}

have_tty() {
  [[ -t 0 && -t 1 ]]
}

choose_action_interactive() {
  if command -v gum >/dev/null 2>&1 && have_tty; then
    gum choose status health logs-summary logs-list logs-latest purge-logs
    return 0
  fi
  return 1
}

collect_log_files() {
  find "${SERVICE_ARTIFACTS_DIR}" -type f 2>/dev/null
  find "${TUI_ARTIFACTS_DIR}" -type f 2>/dev/null
}

service_health() {
  if [[ "${JSON_MODE}" -eq 1 ]]; then
    python3 "${ROOT_DIR}/tools/cad/yiacad_backend_client.py" --json-output health 2>/dev/null || printf '{"status":"blocked"}\n'
  else
    if ! python3 "${ROOT_DIR}/tools/cad/yiacad_backend_client.py" --json-output health 2>/dev/null; then
      printf '# YiACAD backend service health\n\n- status: blocked\n'
    fi
  fi
}

status_view() {
  cat <<EOF
# YiACAD backend service status

- operator_index:
  - tools/cockpit/yiacad_operator_index.sh --action status
- mode:
  - service-first
- health:
  - python3 tools/cad/yiacad_backend_client.py --json-output health
- service_artifacts:
  - ${SERVICE_ARTIFACTS_DIR}
- latest_server:
  - ${SERVICE_ARTIFACTS_DIR}/latest_server.json
- latest_health:
  - ${SERVICE_ARTIFACTS_DIR}/latest_health.json
- latest_response:
  - ${SERVICE_ARTIFACTS_DIR}/latest_response.json
EOF
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
    printf 'no logs found\n'
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
    printf 'no logs found\n'
    return 1
  fi
  printf '# Latest log\n\n'
  printf -- '- path: %s\n' "${latest}"
  printf -- '- lines: %s\n\n' "${LINES}"
  tail -n "${LINES}" "${latest}"
}

logs_summary() {
  local service_count tui_count
  service_count="$(find "${SERVICE_ARTIFACTS_DIR}" -type f 2>/dev/null | wc -l | tr -d ' ')"
  tui_count="$(find "${TUI_ARTIFACTS_DIR}" -type f 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "${JSON_MODE}" -eq 1 ]]; then
    python3 - <<PY
import json
print(json.dumps({
  "status": "done",
  "service_artifact_files": int("${service_count}"),
  "tui_log_files": int("${tui_count}"),
  "service_artifacts_dir": "${SERVICE_ARTIFACTS_DIR}",
  "tui_artifacts_dir": "${TUI_ARTIFACTS_DIR}",
}, ensure_ascii=False))
PY
    return 0
  fi
  cat <<EOF
# YiACAD backend service logs summary

- service artifact files: ${service_count}
- tui log files: ${tui_count}
- service artifacts dir: ${SERVICE_ARTIFACTS_DIR}
- tui artifacts dir: ${TUI_ARTIFACTS_DIR}
EOF
}

purge_logs() {
  if [[ "${YES}" -ne 1 ]]; then
    if command -v gum >/dev/null 2>&1 && have_tty; then
      if ! gum confirm "Purger les logs backend service YiACAD de plus de ${DAYS} jours ?"; then
        printf 'purge cancelled\n'
        return 0
      fi
    else
      printf 'Refusing purge without --yes outside interactive confirm\n' >&2
      return 2
    fi
  fi
  find "${SERVICE_ARTIFACTS_DIR}" -type f -mtime +"${DAYS}" -delete 2>/dev/null || true
  find "${TUI_ARTIFACTS_DIR}" -type f -mtime +"${DAYS}" -delete 2>/dev/null || true
  printf 'purged backend service logs older than %s days\n' "${DAYS}"
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

STAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${TUI_ARTIFACTS_DIR}/yiacad_backend_service_tui_${STAMP}.log"
exec > >(tee -a "${LOG_FILE}") 2>&1

case "${ACTION}" in
  status)
    status_view
    ;;
  health)
    service_health
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
