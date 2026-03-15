#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

CANONICAL_DIR="${CANONICAL_SPECS_DIR:-${ROOT_DIR}/specs}"
MIRROR_DIR="${MIRROR_SPECS_DIR:-${ROOT_DIR}/ai-agentic-embedded-base/specs}"
REPORT_FILE="${REPORT_FILE:-${ROOT_DIR}/artifacts/specs/mirror_sync_report.md}"

COMMAND=""
VERBOSE=0
YES=0

usage() {
  cat <<'EOF'
Usage: bash tools/specs/sync_spec_mirror.sh <check|sync|all> [options]

Synchronize the exported `spec_kit` mirror with the canonical `specs/` tree.

Commands:
  check   Compare canonical specs and mirror, then write a Markdown report
  sync    Synchronize the mirror from canonical specs
  all     Check, sync if needed, then re-check

Options:
  --report PATH  Override the Markdown report path
  --yes          Allow mirror updates
  --verbose      Print progress logs
  -h, --help     Show this help

Env overrides:
  CANONICAL_SPECS_DIR
  MIRROR_SPECS_DIR
  REPORT_FILE

Examples:
  bash tools/specs/sync_spec_mirror.sh check
  bash tools/specs/sync_spec_mirror.sh sync --yes
  bash tools/specs/sync_spec_mirror.sh all --yes
EOF
}

log() {
  if [[ "${VERBOSE}" == "1" ]]; then
    printf '[sync-spec-mirror] %s\n' "$*"
  fi
}

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

require_rsync() {
  command -v rsync >/dev/null 2>&1 || die "Missing dependency: rsync"
}

drift_output() {
  rsync -ani --delete "${CANONICAL_DIR%/}/" "${MIRROR_DIR%/}/" | sed '/^$/d'
}

write_report() {
  local status="$1"
  local action="$2"
  local drift="$3"
  local report_dir

  report_dir="$(dirname -- "${REPORT_FILE}")"
  mkdir -p "${report_dir}"

  {
    printf '# Spec mirror sync report\n\n'
    printf 'Generated: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf '## Summary\n\n'
    printf -- '- Status: `%s`\n' "${status}"
    printf -- '- Action: `%s`\n' "${action}"
    printf -- '- Canonical: `%s`\n' "${CANONICAL_DIR#${ROOT_DIR}/}"
    printf -- '- Mirror: `%s`\n' "${MIRROR_DIR#${ROOT_DIR}/}"
    printf -- '- Report path: `%s`\n\n' "${REPORT_FILE#${ROOT_DIR}/}"

    printf '## Drift\n\n'
    if [[ -n "${drift}" ]]; then
      printf '```text\n%s\n```\n' "${drift}"
    else
      printf -- '- None.\n'
    fi
  } > "${REPORT_FILE}"
}

run_repo_validation() {
  if [[ "${CANONICAL_DIR}" == "${ROOT_DIR}/specs" && "${MIRROR_DIR}" == "${ROOT_DIR}/ai-agentic-embedded-base/specs" ]]; then
    python3 "${ROOT_DIR}/tools/validate_specs.py" --require-mirror-sync >/dev/null
  fi
}

run_check() {
  local drift

  require_rsync
  [[ -d "${CANONICAL_DIR}" ]] || die "Missing canonical specs directory: ${CANONICAL_DIR}"
  mkdir -p "${MIRROR_DIR}"

  drift="$(drift_output)"
  if [[ -n "${drift}" ]]; then
    write_report "drift" "check" "${drift}"
    log "Mirror drift detected"
    return 1
  fi

  write_report "clean" "check" ""
  log "Mirror is synchronized"
  return 0
}

run_sync() {
  local drift_after

  require_rsync
  [[ -d "${CANONICAL_DIR}" ]] || die "Missing canonical specs directory: ${CANONICAL_DIR}"
  mkdir -p "${MIRROR_DIR}"

  [[ "${YES}" == "1" ]] || die "Refusing to update the mirror without --yes."

  log "Synchronizing mirror"
  rsync -a --delete "${CANONICAL_DIR%/}/" "${MIRROR_DIR%/}/"

  drift_after="$(drift_output)"
  if [[ -n "${drift_after}" ]]; then
    write_report "drift" "sync-failed" "${drift_after}"
    die "Mirror sync did not converge. See ${REPORT_FILE}."
  fi

  run_repo_validation
  write_report "clean" "sync" ""
  log "Mirror synchronized"
}

if [[ $# -eq 0 ]]; then
  usage >&2
  exit 2
fi

COMMAND="$1"
shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report)
      shift
      [[ $# -gt 0 ]] || die "Missing value for --report"
      REPORT_FILE="$1"
      ;;
    --yes)
      YES=1
      ;;
    --verbose)
      VERBOSE=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
  shift
done

case "${COMMAND}" in
  check)
    if run_check; then
      exit 0
    fi
    exit 1
    ;;
  sync)
    run_sync
    ;;
  all)
    if run_check; then
      exit 0
    fi
    run_sync
    run_check
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
