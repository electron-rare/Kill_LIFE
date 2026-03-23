#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts/yiacad_proofs_tui"
ACTION="status"
DAYS="14"
YES="false"
JSON="false"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE=""

usage() {
  cat <<'USAGE'
Usage: yiacad_proofs_tui.sh --action <status|backend|review-session|review-history|review-taxonomy|logs-summary|logs-list|logs-latest|purge-logs> [options]

Options:
  --action ACTION   Action to execute.
  --days N          Purge logs older than N days. Default: 14.
  --json            Emit JSON status for machine use.
  --yes             Confirm destructive actions like purge.
  --help            Show this help.
USAGE
}

log() {
  printf '[yiacad-proofs] %s\n' "$*" | tee -a "${LOG_FILE}" >&2
}

log_cmd() {
  log "cmd: $*"
}

ensure_dirs() {
  mkdir -p "${ARTIFACTS_DIR}"
  LOG_FILE="${ARTIFACTS_DIR}/yiacad_proofs_tui_${STAMP}.log"
  touch "${LOG_FILE}"
}

run_backend() {
  log_cmd bash "${ROOT_DIR}/tools/cockpit/yiacad_backend_proof.sh" --action run
  bash "${ROOT_DIR}/tools/cockpit/yiacad_backend_proof.sh" --action run
}

run_review_session() {
  log_cmd bash "${ROOT_DIR}/tools/cockpit/yiacad_uiux_tui.sh" --action review-session
  bash "${ROOT_DIR}/tools/cockpit/yiacad_uiux_tui.sh" --action review-session
}

run_review_history() {
  log_cmd bash "${ROOT_DIR}/tools/cockpit/yiacad_uiux_tui.sh" --action review-history
  bash "${ROOT_DIR}/tools/cockpit/yiacad_uiux_tui.sh" --action review-history
}

run_review_taxonomy() {
  log_cmd bash "${ROOT_DIR}/tools/cockpit/yiacad_uiux_tui.sh" --action review-taxonomy
  bash "${ROOT_DIR}/tools/cockpit/yiacad_uiux_tui.sh" --action review-taxonomy
}

render_status_text() {
  cat <<EOF2
YiACAD proofs status
- canonical_entry: bash tools/cockpit/yiacad_proofs_tui.sh --action status
- backend_proof: bash tools/cockpit/yiacad_backend_proof.sh --action run
- review_session: bash tools/cockpit/yiacad_uiux_tui.sh --action review-session
- review_history: bash tools/cockpit/yiacad_uiux_tui.sh --action review-history
- review_taxonomy: bash tools/cockpit/yiacad_uiux_tui.sh --action review-taxonomy
- log_dir: ${ARTIFACTS_DIR}
- note: surface canonique pour les preuves et l hygiene des logs, sans casser les alias historiques
EOF2
}

render_status_json() {
  cat <<EOF2
{
  "component": "yiacad-proofs-tui",
  "timestamp": "${STAMP}",
  "canonical_entry": "bash tools/cockpit/yiacad_proofs_tui.sh --action status",
  "routes": {
    "backend": "bash tools/cockpit/yiacad_backend_proof.sh --action run",
    "review_session": "bash tools/cockpit/yiacad_uiux_tui.sh --action review-session",
    "review_history": "bash tools/cockpit/yiacad_uiux_tui.sh --action review-history",
    "review_taxonomy": "bash tools/cockpit/yiacad_uiux_tui.sh --action review-taxonomy"
  },
  "log_dir": "${ARTIFACTS_DIR}",
  "notes": [
    "surface canonique pour les preuves et l hygiene des logs",
    "les alias historiques peuvent continuer a pointer vers cette surface plus tard"
  ]
}
EOF2
}

logs_summary() {
  local count latest
  count="$(find "${ARTIFACTS_DIR}" -maxdepth 1 -type f -name '*.log' | wc -l | tr -d ' ')"
  latest="$(find "${ARTIFACTS_DIR}" -maxdepth 1 -type f -name '*.log' | sort | tail -n 1)"
  if [[ "${JSON}" == "true" ]]; then
    cat <<EOF2
{
  "component": "yiacad-proofs-tui",
  "log_count": ${count:-0},
  "latest_log": "${latest}"
}
EOF2
  else
    printf 'YiACAD proofs logs\n'
    printf -- '- log_count: %s\n' "${count:-0}"
    printf -- '- latest_log: %s\n' "${latest:-none}"
  fi
}

logs_list() {
  find "${ARTIFACTS_DIR}" -maxdepth 1 -type f -name '*.log' | sort
}

logs_latest() {
  local latest
  latest="$(find "${ARTIFACTS_DIR}" -maxdepth 1 -type f -name '*.log' | sort | tail -n 1)"
  if [[ -n "${latest}" ]]; then
    cat "${latest}"
  fi
}

purge_logs() {
  if [[ "${YES}" != "true" ]]; then
    printf 'Refusing to purge logs without --yes\n' >&2
    exit 1
  fi
  find "${ARTIFACTS_DIR}" -maxdepth 1 -type f -name '*.log' -mtime "+${DAYS}" -delete
  printf 'Purged logs older than %s days from %s\n' "${DAYS}" "${ARTIFACTS_DIR}"
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
  backend)
    run_backend
    ;;
  review-session)
    run_review_session
    ;;
  review-history)
    run_review_history
    ;;
  review-taxonomy)
    run_review_taxonomy
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
    usage >&2
    exit 1
    ;;
esac
