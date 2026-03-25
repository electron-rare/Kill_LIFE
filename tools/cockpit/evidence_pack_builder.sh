#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
source "${ROOT_DIR}/tools/cockpit/json_contract.sh"

TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
ARTIFACT_DIR="${ROOT_DIR}/artifacts/cockpit/evidence_packs"
mkdir -p "${ARTIFACT_DIR}"
REPORT_FILE="${ARTIFACT_DIR}/evidence_pack_${TIMESTAMP}.json"

# Repo roots (overridable via env)
KILL_LIFE_ROOT="${KILL_LIFE_ROOT:-${ROOT_DIR}}"
MASCARADE_ROOT="${MASCARADE_ROOT:-/Users/electron/Documents/Projets/mascarade}"
CRAZY_LIFE_ROOT="${CRAZY_LIFE_ROOT:-/Users/electron/Documents/Projets/crazy_life}"

JSON=0
VERBOSE=0

usage() {
  cat <<'EOF'
Usage: bash tools/cockpit/evidence_pack_builder.sh [options]

Collect evidence from Kill_LIFE, mascarade and crazy_life repos into a single
consolidated JSON report.

Options:
  --json            Output JSON to stdout
  --verbose         Print progress logs
  --kill-life-root  Override Kill_LIFE repo path
  --mascarade-root  Override mascarade repo path
  --crazy-life-root Override crazy_life repo path
  -h, --help        Show this help

Output:
  artifacts/cockpit/evidence_packs/evidence_pack_<ts>.json

Evidence collected per repo:
  - git branch, SHA, dirty count
  - last commit date and message
  - presence of key contract files
  - lot tracker status (if available)
EOF
}

log() {
  if [[ "${VERBOSE}" == "1" ]]; then
    printf '[evidence-pack] %s\n' "$*"
  fi
}

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

# Collect evidence for a single repo
# Returns a JSON object fragment (no surrounding braces in the caller)
collect_repo_evidence() {
  local name="$1"
  local repo_path="$2"
  local branch="n/a"
  local sha="n/a"
  local dirty_count=0
  local last_commit_date="n/a"
  local last_commit_msg="n/a"
  local status="missing"
  local contracts=""

  if [[ ! -d "${repo_path}/.git" ]]; then
    log "${name}: not found at ${repo_path}"
    printf '{"repo":"%s","path":"%s","status":"missing"}' \
      "$(json_contract_escape "${name}")" \
      "$(json_contract_escape "${repo_path}")"
    return
  fi

  branch="$(git -C "${repo_path}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")"
  sha="$(git -C "${repo_path}" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
  dirty_count="$(git -C "${repo_path}" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  last_commit_date="$(git -C "${repo_path}" log -1 --format='%ci' 2>/dev/null || echo "n/a")"
  last_commit_msg="$(git -C "${repo_path}" log -1 --format='%s' 2>/dev/null || echo "n/a")"

  # Check for key contract/evidence files
  local contract_list=""
  local check_files=(
    "README.md"
    "specs/03_plan.md"
    "specs/04_tasks.md"
    "docs/index.md"
  )
  for f in "${check_files[@]}"; do
    if [[ -f "${repo_path}/${f}" ]]; then
      contract_list="$(json_contract_append_string "${contract_list}" "${f}")"
    fi
  done

  if [[ "${dirty_count}" -eq 0 ]]; then
    status="clean"
  else
    status="dirty"
  fi

  log "${name}: branch=${branch} sha=${sha} dirty=${dirty_count} status=${status}"

  printf '{"repo":"%s","path":"%s","branch":"%s","sha":"%s","dirty_count":%d,"status":"%s","last_commit_date":"%s","last_commit_msg":"%s","contracts_present":[%s]}' \
    "$(json_contract_escape "${name}")" \
    "$(json_contract_escape "${repo_path}")" \
    "$(json_contract_escape "${branch}")" \
    "$(json_contract_escape "${sha}")" \
    "${dirty_count}" \
    "${status}" \
    "$(json_contract_escape "${last_commit_date}")" \
    "$(json_contract_escape "${last_commit_msg}")" \
    "${contract_list}"
}

# --- arg parse ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)         JSON=1; shift ;;
    --verbose)      VERBOSE=1; shift ;;
    --kill-life-root)  KILL_LIFE_ROOT="$2"; shift 2 ;;
    --mascarade-root)  MASCARADE_ROOT="$2"; shift 2 ;;
    --crazy-life-root) CRAZY_LIFE_ROOT="$2"; shift 2 ;;
    -h|--help)      usage; exit 0 ;;
    *)              die "Unknown option: $1" ;;
  esac
done

# --- collect ---
log "Collecting evidence from 3 repos..."

kl_json="$(collect_repo_evidence "Kill_LIFE" "${KILL_LIFE_ROOT}")"
ma_json="$(collect_repo_evidence "mascarade" "${MASCARADE_ROOT}")"
cl_json="$(collect_repo_evidence "crazy_life" "${CRAZY_LIFE_ROOT}")"

# --- mesh preflight status (if available) ---
mesh_status="unknown"
LATEST_HEALTH="${ROOT_DIR}/artifacts/cockpit/health_reports"
if [[ -d "${LATEST_HEALTH}" ]]; then
  latest_report="$(ls -t "${LATEST_HEALTH}"/mesh_health_check_*.json 2>/dev/null | head -n1 || true)"
  if [[ -n "${latest_report}" ]]; then
    mesh_status="$(sed -n 's/.*"overall_status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${latest_report}" | head -n1 || echo "unknown")"
  fi
fi

# --- overall status ---
overall="ready"
for s in "${kl_json}" "${ma_json}" "${cl_json}"; do
  repo_status="$(printf '%s' "${s}" | sed -n 's/.*"status":"\([^"]*\)".*/\1/p' | head -n1)"
  case "${repo_status}" in
    missing) overall="blocked" ;;
    dirty)   [[ "${overall}" != "blocked" ]] && overall="degraded" ;;
  esac
done

# --- assemble ---
report="$(cat <<ENDJSON
{
  "evidence_pack": "tri-repo",
  "timestamp": "${TIMESTAMP}",
  "overall_status": "${overall}",
  "mesh_status": "${mesh_status}",
  "repos": [
    ${kl_json},
    ${ma_json},
    ${cl_json}
  ]
}
ENDJSON
)"

printf '%s\n' "${report}" > "${REPORT_FILE}"
log "Report written to ${REPORT_FILE}"

if [[ "${JSON}" == "1" ]]; then
  printf '%s\n' "${report}"
else
  printf 'Evidence pack: %s\n' "${REPORT_FILE}"
  printf 'Overall: %s | Mesh: %s\n' "${overall}" "${mesh_status}"
  printf 'Repos:\n'
  for name in Kill_LIFE mascarade crazy_life; do
    line="$(printf '%s\n%s\n%s' "${kl_json}" "${ma_json}" "${cl_json}" | grep "\"repo\":\"${name}\"" || true)"
    if [[ -n "${line}" ]]; then
      repo_s="$(printf '%s' "${line}" | sed -n 's/.*"status":"\([^"]*\)".*/\1/p' | head -n1)"
      repo_sha="$(printf '%s' "${line}" | sed -n 's/.*"sha":"\([^"]*\)".*/\1/p' | head -n1)"
      repo_dirty="$(printf '%s' "${line}" | sed -n 's/.*"dirty_count":\([0-9]*\).*/\1/p' | head -n1)"
      printf '  %s: %s (sha=%s dirty=%s)\n' "${name}" "${repo_s}" "${repo_sha}" "${repo_dirty}"
    fi
  done
fi
