#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
source "${ROOT_DIR}/tools/cockpit/json_contract.sh"
ARTIFACT_DIR="${ROOT_DIR}/artifacts/cockpit"
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
REPORT_DIR="${ARTIFACT_DIR}/health_reports"
mkdir -p "${REPORT_DIR}"
REGISTRY_FILE="${ROOT_DIR}/specs/contracts/machine_registry.mesh.json"

JSON=0
LOAD_PROFILE="tower-first"
RETENTION_DAYS="7"
OUTPUT_STATUS="blocked"

usage() {
  cat <<'USAGE'
Usage: bash tools/cockpit/mesh_health_check.sh [options]

Options:
  --load-profile <tower-first|photon-safe>  Mode de précheck P2P (défaut: tower-first)
  --photon-safe                             Alias de --load-profile photon-safe
  --retention-days N                        Retention utilisée pour la lecture log_ops
  --json                                    Sortie JSON
  -h, --help                                Affiche cette aide

  Cette commande exécute en chaîne:
  1) mesh_sync_preflight --json
  2) readme_repo_coherence.sh audit
  3) log_ops.sh summary --json
  La sortie JSON contient le `mesh_report` et l'ordre `host_order` du préflight.

Retourne un statut consolidé: ready | degraded | blocked.
USAGE
}

parse_json_field() {
  local file="$1"
  local field="$2"
  local raw=""

  raw="$(sed -n "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "${file}" | head -n1 || true)"
  if [[ -z "${raw}" ]]; then
    raw="$(sed -n "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\\([0-9][0-9]*\\).*/\\1/p" "${file}" | head -n1 || true)"
  fi
  printf '%s' "${raw}"
}

normalize_log_status() {
  local status="$1"
  case "${status}" in
    done|ok|ready)
      echo "ready"
      ;;
    degraded|warn|warning)
      echo "degraded"
      ;;
    blocked|error|fail|failed)
      echo "blocked"
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

parse_json_array_string() {
  local file="$1"
  local field="$2"
  awk -v field="\"${field}\"" '
    match($0, field"[[:space:]]*:[[:space:]]*\\[") { capture=1; line=$0; next }
    capture {
      line = line "\n" $0
      if ($0 ~ /\]/) {
        gsub(/^[[:space:]]*/, "", line)
        start = index(line, "[")
        end = index(line, "]")
        if (start > 0 && end > start) {
          value = substr(line, start + 1, end - start - 1)
          gsub(/"/, "", value)
          gsub(/[[:space:]]/, "", value)
          print value
        }
        exit
      }
    }
  ' "${file}"
}

json_array_count() {
  local value="$1"
  if [[ -z "${value}" ]]; then
    printf '0'
    return
  fi
  printf '%s' "${value}" | awk 'BEGIN{FS=","} {print NF}'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --load-profile)
    LOAD_PROFILE="${2:-}"
    if [[ -z "${LOAD_PROFILE}" || ! "${LOAD_PROFILE}" =~ ^(tower-first|photon-safe)$ ]]; then
      echo "[error] --load-profile requires tower-first|photon-safe" >&2
      exit 2
    fi
    shift 2
    ;;
  --photon-safe)
    LOAD_PROFILE="photon-safe"
    shift
    ;;
    --retention-days)
      RETENTION_DAYS="${2:-7}"
      if ! [[ "${RETENTION_DAYS}" =~ ^[0-9]+$ ]]; then
        echo "[error] --retention-days requires an integer" >&2
        exit 2
      fi
      shift 2
      ;;
    --json)
      JSON=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

mesh_report="${REPORT_DIR}/mesh_health_check_mesh_${TIMESTAMP}.json"
readme_report="${ROOT_DIR}/artifacts/doc/readme_repo_audit_${TIMESTAMP}.md"
log_report="${REPORT_DIR}/mesh_health_check_logops_${TIMESTAMP}.json"
registry_report="${REPORT_DIR}/mesh_health_check_registry_${TIMESTAMP}.json"

if bash "${ROOT_DIR}/tools/cockpit/machine_registry.sh" --action summary --json > "${registry_report}" 2>&1; then
  registry_rc=0
else
  registry_rc=$?
fi
registry_status="$(normalize_log_status "$(parse_json_field "${registry_report}" status)")"
if [[ "${registry_status}" == "unknown" ]]; then
  if (( registry_rc == 0 )); then
    registry_status="ready"
  else
    registry_status="blocked"
  fi
fi
registry_target_count="$(parse_json_field "${registry_report}" target_count)"
registry_default_profile="$(parse_json_field "${registry_report}" default_profile)"
if [[ -z "${registry_target_count}" ]]; then
  registry_target_count="0"
fi
if [[ -z "${registry_default_profile}" ]]; then
  registry_default_profile="unknown"
fi

if bash "${ROOT_DIR}/tools/cockpit/mesh_sync_preflight.sh" --json --no-log --load-profile "${LOAD_PROFILE}" >"${mesh_report}" 2>&1; then
  mesh_rc=0
else
  mesh_rc=$?
fi
mesh_status="$(parse_json_field "${mesh_report}" mesh_status)"
mesh_host_order="$(parse_json_array_string "${mesh_report}" host_order)"
mesh_host_order_count="$(json_array_count "${mesh_host_order}")"
if [[ -z "${mesh_status}" ]]; then
  mesh_status="blocked"
  if (( mesh_rc != 0 )); then
    mesh_status="blocked"
  else
    mesh_status="degraded"
  fi
fi

if bash "${ROOT_DIR}/tools/doc/readme_repo_coherence.sh" audit --report "${readme_report}" > /dev/null 2>&1; then
  readme_rc=0
else
  readme_rc=$?
fi
if [[ -f "${readme_report}" ]]; then
  readme_findings="$(awk '/^-[[:space:]]*Findings:/ { if (match($0, /[0-9]+/)) { print substr($0, RSTART, RLENGTH); exit } }' "${readme_report}" || true)"
  if [[ -z "${readme_findings}" ]]; then
    readme_findings="$(grep -m1 'Findings:' "${readme_report}" | tr -cd '0-9' || true)"
    if [[ -z "${readme_findings}" ]]; then
      readme_findings="0"
    fi
  fi
else
  readme_findings="0"
  readme_report=""
fi
if [[ "${readme_rc}" -eq 0 ]]; then
  readme_status="ready"
else
  readme_status="degraded"
fi
if [[ -n "${readme_findings}" && "${readme_findings}" != "0" ]]; then
  readme_status="degraded"
fi

if bash "${ROOT_DIR}/tools/cockpit/log_ops.sh" --action summary --json --retention-days "${RETENTION_DAYS}" > "${log_report}" 2>&1; then
  log_rc=0
else
  log_rc=$?
fi
log_status="$(normalize_log_status "$(parse_json_field "${log_report}" status)")"
  log_stale="$(parse_json_field "${log_report}" stale)"
  if [[ -z "${log_stale}" ]]; then
    log_stale="0"
  fi
  if [[ "${log_status}" == "unknown" ]]; then
  log_status="degraded"
fi

if [[ "${mesh_status}" == "blocked" || "${readme_status}" == "blocked" || "${log_status}" == "blocked" || "${registry_status}" == "blocked" ]]; then
  OUTPUT_STATUS="blocked"
elif [[ "${mesh_status}" == "degraded" || "${readme_status}" == "degraded" || "${log_status}" == "degraded" || "${registry_status}" == "degraded" ]]; then
  OUTPUT_STATUS="degraded"
else
  OUTPUT_STATUS="ready"
fi

if [[ "${mesh_status}" == "${readme_status}" && "${mesh_status}" == "${log_status}" && "${mesh_status}" == "${registry_status}" ]]; then
  health_consistency="aligned"
elif [[ "${mesh_status}" == "blocked" || "${readme_status}" == "blocked" || "${log_status}" == "blocked" || "${registry_status}" == "blocked" ]]; then
  health_consistency="blocked_divergence"
else
  health_consistency="degraded_divergence"
fi

degraded_reasons=()
next_steps=()
artifacts=("${registry_report}" "${mesh_report}")
[[ -n "${readme_report}" ]] && artifacts+=("${readme_report}")
[[ -n "${log_report}" ]] && artifacts+=("${log_report}")

if [[ "${registry_status}" != "ready" ]]; then
  degraded_reasons+=("registry-${registry_status}")
  next_steps+=("bash tools/cockpit/machine_registry.sh --action summary --json")
fi
if [[ "${mesh_status}" != "ready" ]]; then
  degraded_reasons+=("mesh-${mesh_status}")
  next_steps+=("bash tools/cockpit/mesh_sync_preflight.sh --json --load-profile ${LOAD_PROFILE}")
fi
if [[ "${readme_status}" != "ready" ]]; then
  degraded_reasons+=("readme-${readme_status}")
  next_steps+=("bash tools/doc/readme_repo_coherence.sh audit")
fi
if [[ "${log_status}" != "ready" ]]; then
  degraded_reasons+=("log-${log_status}")
  next_steps+=("bash tools/cockpit/log_ops.sh --action purge --retention-days ${RETENTION_DAYS} --apply --json")
fi

contract_status="$(json_contract_map_status "${OUTPUT_STATUS}")"

if [[ "${JSON}" -eq 1 ]]; then
  printf '{\n'
  printf '  "contract_version":"cockpit-v1",\n'
  printf '  "component":"mesh_health_check",\n'
  printf '  "action":"summary",\n'
  printf '  "contract_status":"%s",\n' "${contract_status}"
  printf '  "generated_at":"%s",\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
  printf '  "registry_file":"%s",\n' "${REGISTRY_FILE}"
  printf '  "artifacts":%s,\n' "$(json_contract_array_from_args "${artifacts[@]}")"
  printf '  "degraded_reasons":%s,\n' "$(json_contract_array_from_args "${degraded_reasons[@]}")"
  printf '  "next_steps":%s,\n' "$(json_contract_array_from_args "${next_steps[@]}")"
  printf '  "mesh_load_profile":"%s",\n' "${LOAD_PROFILE}"
  printf '  "registry_status":"%s",\n' "${registry_status}"
  printf '  "registry_target_count":%s,\n' "${registry_target_count}"
  printf '  "registry_default_profile":"%s",\n' "${registry_default_profile}"
  printf '  "registry_report":"%s",\n' "${registry_report}"
  printf '  "mesh_status":"%s",\n' "${mesh_status}"
  printf '  "mesh_host_order":"%s",\n' "${mesh_host_order:-}"
  printf '  "mesh_host_order_count":%s,\n' "${mesh_host_order_count:-0}"
  printf '  "mesh_status_reason_code":"%s",\n' "${mesh_rc}"
  printf '  "readme_status":"%s",\n' "${readme_status}"
  printf '  "readme_findings":%s,\n' "${readme_findings:-0}"
  printf '  "readme_report":"%s",\n' "${readme_report}"
  printf '  "log_status":"%s",\n' "${log_status}"
  printf '  "log_stale":%s,\n' "${log_stale}"
  printf '  "log_retention_days":%s,\n' "${RETENTION_DAYS}"
  printf '  "health_consistency":"%s",\n' "${health_consistency}"
  printf '  "status":"%s",\n' "${OUTPUT_STATUS}"
  printf '  "mesh_report":"%s"\n' "${mesh_report}"
  printf '}\n'
else
  cat <<EOF_SUMMARY
mesh_health_check report:
  generated_at: $(date '+%Y-%m-%d %H:%M:%S %z')
  load_profile: ${LOAD_PROFILE}
  machine_registry: ${registry_status} (targets=${registry_target_count}, default_profile=${registry_default_profile})
  mesh_sync_preflight: ${mesh_status}
  mesh_host_order: ${mesh_host_order}
  readme_repo_coherence: ${readme_status} (findings=${readme_findings:-0})
  log_ops: ${log_status}
  consistency: ${health_consistency}
  status: ${OUTPUT_STATUS}
  evidence_registry: ${registry_report}
  evidence mesh-host-order-count: ${mesh_host_order_count}
  evidence_mesh: ${mesh_report}
  evidence_readme: ${readme_report}
  evidence_log: ${log_report}
EOF_SUMMARY
fi

if [[ "${OUTPUT_STATUS}" == "blocked" ]]; then
  exit 1
fi
