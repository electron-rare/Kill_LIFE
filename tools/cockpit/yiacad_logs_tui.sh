#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts/yiacad_logs_tui"
ACTION="status"
DAYS="14"
YES="false"
JSON="false"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE=""
LOG_SOURCES=(
  "${ROOT_DIR}/artifacts/yiacad_operator_index"
  "${ROOT_DIR}/artifacts/yiacad_uiux_tui"
  "${ROOT_DIR}/artifacts/yiacad_backend_service_tui"
  "${ROOT_DIR}/artifacts/yiacad_proofs_tui"
  "${ROOT_DIR}/artifacts/cad-ai-native/service"
)

usage() {
  cat <<'USAGE'
Usage: yiacad_logs_tui.sh --action <status|summary|list|latest|purge-logs> [options]

Options:
  --action ACTION   Action to execute.
  --days N          Purge logs older than N days. Default: 14.
  --json            Emit JSON status for machine use.
  --yes             Confirm destructive actions like purge.
  --help            Show this help.
USAGE
}

ensure_dirs() {
  mkdir -p "${ARTIFACTS_DIR}"
  LOG_FILE="${ARTIFACTS_DIR}/yiacad_logs_tui_${STAMP}.log"
  touch "${LOG_FILE}"
}

log() {
  printf '[yiacad-logs] %s\n' "$*" | tee -a "${LOG_FILE}" >&2
}

collect_logs() {
  local source
  for source in "${LOG_SOURCES[@]}"; do
    if [[ -d "${source}" ]]; then
      find "${source}" -maxdepth 2 -type f \( -name '*.log' -o -name 'server.log' \) -print
    fi
  done | sort -u
}

render_status_text() {
  cat <<EOF2
YiACAD logs status
- canonical_entry: bash tools/cockpit/yiacad_logs_tui.sh --action status
- operator_entry: bash tools/cockpit/yiacad_operator_index.sh --action status
- source_count: $(printf '%s
' "${LOG_SOURCES[@]}" | wc -l | tr -d ' ')
- action_hint: utilisez --action summary pour un agregat et --action purge-logs --days 14 --yes pour nettoyer
EOF2
}

render_status_json() {
  cat <<EOF2
{
  "component": "yiacad-logs-tui",
  "timestamp": "${STAMP}",
  "canonical_entry": "bash tools/cockpit/yiacad_logs_tui.sh --action status",
  "operator_entry": "bash tools/cockpit/yiacad_operator_index.sh --action status",
  "source_count": $(printf '%s\n' "${LOG_SOURCES[@]}" | wc -l | tr -d ' ')
}
EOF2
}

summary_action() {
  local tmp count latest
  tmp="$(mktemp)"
  collect_logs > "${tmp}"
  count="$(wc -l < "${tmp}" | tr -d ' ')"
  latest="$(tail -n 1 "${tmp}")"
  if [[ "${JSON}" == "true" ]]; then
    cat <<EOF2
{
  "component": "yiacad-logs-tui",
  "log_count": ${count:-0},
  "latest_log": "${latest}",
  "sources": [
    "${ROOT_DIR}/artifacts/yiacad_operator_index",
    "${ROOT_DIR}/artifacts/yiacad_uiux_tui",
    "${ROOT_DIR}/artifacts/yiacad_backend_service_tui",
    "${ROOT_DIR}/artifacts/yiacad_proofs_tui",
    "${ROOT_DIR}/artifacts/cad-ai-native/service"
  ]
}
EOF2
  else
    printf 'YiACAD aggregated logs\n'
    printf -- '- log_count: %s\n' "${count:-0}"
    printf -- '- latest_log: %s\n' "${latest:-none}"
  fi
  rm -f "${tmp}"
}

list_action() {
  collect_logs
}

latest_action() {
  local latest
  latest="$(collect_logs | tail -n 1)"
  if [[ -n "${latest}" ]]; then
    cat "${latest}"
  fi
}

purge_action() {
  local source
  if [[ "${YES}" != "true" ]]; then
    printf 'Refusing to purge logs without --yes\n' >&2
    exit 1
  fi
  for source in "${LOG_SOURCES[@]}"; do
    if [[ -d "${source}" ]]; then
      find "${source}" -maxdepth 2 -type f \( -name '*.log' -o -name 'server.log' \) -mtime "+${DAYS}" -delete
    fi
  done
  printf 'Purged YiACAD logs older than %s days\n' "${DAYS}"
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
    --json)
      JSON="true"
      shift
      ;;
    --yes)
      YES="true"
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

ensure_dirs

case "${ACTION}" in
  status)
    if [[ "${JSON}" == "true" ]]; then
      render_status_json
    else
      render_status_text
    fi
    ;;
  summary)
    summary_action
    ;;
  list)
    list_action
    ;;
  latest)
    latest_action
    ;;
  purge-logs)
    purge_action
    ;;
  *)
    printf 'Unknown action: %s\n' "${ACTION}" >&2
    usage >&2
    exit 1
    ;;
esac
