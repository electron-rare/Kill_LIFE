#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
source "${ROOT_DIR}/tools/cockpit/json_contract.sh"
REGISTRY_FILE="${ROOT_DIR}/specs/contracts/machine_registry.mesh.json"
LOG_DIR="${ROOT_DIR}/artifacts/cockpit"
mkdir -p "${LOG_DIR}"

ACTION=""
TARGET_ID=""
JSON=0
RETENTION_DAYS=14
LOG_FILE=""

usage() {
  cat <<'EOF'
Usage: bash tools/cockpit/machine_registry.sh [options]

Options:
  --action <summary|list|show|clean-logs>  Action to run
  --machine <id>                           Filter a single machine id
  --json                                   Emit JSON when available
  --days <N>                               Retention for clean-logs (default: 14)
  -h, --help                               Show this help
EOF
}

have_tty() {
  [[ -t 0 && -t 1 ]]
}

choose_action_interactive() {
  if command -v gum >/dev/null 2>&1 && have_tty; then
    gum choose summary list show clean-logs
    return 0
  fi
  return 1
}

log_line() {
  local level="$1"
  shift
  local msg="${level} $(date '+%Y-%m-%d %H:%M:%S %z') ${*}"
  printf '%s\n' "${msg}" | tee -a "${LOG_FILE}" >&2
}

require_registry() {
  if [[ ! -f "${REGISTRY_FILE}" ]]; then
    printf 'Missing registry file: %s\n' "${REGISTRY_FILE}" >&2
    exit 1
  fi
}

emit_summary() {
  python3 - "${REGISTRY_FILE}" "${JSON}" "${LOG_FILE}" <<'PY'
import json
import sys
from pathlib import Path

registry_path = Path(sys.argv[1])
json_mode = sys.argv[2] == "1"
log_file = sys.argv[3]
data = json.loads(registry_path.read_text(encoding="utf-8"))
targets = data.get("targets", [])
reserve = [t["id"] for t in targets if t.get("reserve_only")]
order = [t["id"] for t in sorted(targets, key=lambda item: item.get("priority", 999))]
payload = {
    "contract_version": "cockpit-v1",
    "status": "ok",
    "contract_status": "ok",
    "component": "machine_registry",
    "action": "summary",
    "artifacts": [log_file, str(registry_path)],
    "degraded_reasons": [],
    "next_steps": [
        "bash tools/cockpit/machine_registry.sh --action list --json",
        "bash tools/cockpit/machine_registry.sh --action show --machine tower --json",
    ],
    "registry_file": str(registry_path),
    "default_profile": data.get("default_profile"),
    "target_count": len(targets),
    "reserve_targets": reserve,
    "priority_order": order,
}
if json_mode:
    print(json.dumps(payload, ensure_ascii=False))
else:
    print("# Machine registry summary\n")
    print(f"- registry: {payload['registry_file']}")
    print(f"- default_profile: {payload['default_profile']}")
    print(f"- target_count: {payload['target_count']}")
    print(f"- reserve_targets: {', '.join(reserve) if reserve else 'none'}")
    print(f"- priority_order: {' -> '.join(order)}")
PY
}

emit_targets() {
  python3 - "${REGISTRY_FILE}" "${TARGET_ID}" "${JSON}" "${LOG_FILE}" <<'PY'
import json
import sys
from pathlib import Path

registry_path = Path(sys.argv[1])
target_id = sys.argv[2]
json_mode = sys.argv[3] == "1"
log_file = sys.argv[4]
data = json.loads(registry_path.read_text(encoding="utf-8"))
targets = data.get("targets", [])
if target_id:
    targets = [item for item in targets if item.get("id") == target_id]
payload = {
    "contract_version": "cockpit-v1",
    "status": "ok",
    "contract_status": "ok",
    "component": "machine_registry",
    "action": "show" if target_id else "list",
    "artifacts": [log_file, str(registry_path)],
    "degraded_reasons": [],
    "next_steps": [
        "bash tools/cockpit/machine_registry.sh --action summary --json",
    ],
    "targets": targets,
}
if json_mode:
    print(json.dumps(payload, ensure_ascii=False))
else:
    if not targets:
      print("no targets found")
      raise SystemExit(0)
    print("# Machine registry\n")
    for item in targets:
        print(f"- id: {item['id']}")
        print(f"  target: {item['target']}")
        print(f"  role: {item['role']}")
        print(f"  priority: {item['priority']}")
        print(f"  placement: {item['placement']}")
        print(f"  profiles: {', '.join(item.get('enabled_profiles', []))}")
        print(f"  reserve_only: {item.get('reserve_only')}")
        print(f"  critical_repos: {', '.join(item.get('critical_repos', []))}")
        print(f"  notes: {item.get('notes', '')}")
PY
}

emit_clean_logs() {
  local stale_files=()
  local pattern='machine_registry_*.log'
  while IFS= read -r file; do
    [[ -n "${file}" ]] || continue
    stale_files+=("${file}")
  done < <(find "${LOG_DIR}" -type f -name "${pattern}" -mtime +"${RETENTION_DAYS}" -print | sort)

  local count="${#stale_files[@]}"
  if [[ "${count}" -gt 0 ]]; then
    find "${LOG_DIR}" -type f -name "${pattern}" -mtime +"${RETENTION_DAYS}" -delete
  fi

  if [[ "${JSON}" -eq 1 ]]; then
    printf '{\n'
    printf '  "contract_version": "cockpit-v1",\n'
    printf '  "component": "machine_registry",\n'
    printf '  "contract_status": "ok",\n'
    printf '  "status": "ok",\n'
    printf '  "action": "clean-logs",\n'
    printf '  "artifacts": %s,\n' "$(json_contract_array_from_args "${LOG_FILE}" "${LOG_DIR}")"
    printf '  "degraded_reasons": [],\n'
    printf '  "next_steps": %s,\n' "$(json_contract_array_from_args "bash tools/cockpit/machine_registry.sh --action summary --json")"
    printf '  "retention_days": %s,\n' "${RETENTION_DAYS}"
    printf '  "deleted_count": %s,\n' "${count}"
    printf '  "log_dir": "%s"\n' "${LOG_DIR}"
    printf '}\n'
  else
    printf 'cleaned machine_registry logs older than %s days in %s (%s deleted)\n' "${RETENTION_DAYS}" "${LOG_DIR}" "${count}"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --action)
      ACTION="${2:-}"
      shift 2
      ;;
    --machine)
      TARGET_ID="${2:-}"
      shift 2
      ;;
    --json)
      JSON=1
      shift
      ;;
    --days)
      RETENTION_DAYS="${2:-14}"
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
    ACTION="summary"
  fi
fi

if ! [[ "${RETENTION_DAYS}" =~ ^[0-9]+$ ]]; then
  printf -- '--days requires an integer\n' >&2
  exit 2
fi

LOG_FILE="${LOG_DIR}/machine_registry_$(date '+%Y%m%d_%H%M%S').log"
require_registry
log_line "INFO" "action=${ACTION} target=${TARGET_ID:-all}"

case "${ACTION}" in
  summary)
    emit_summary
    ;;
  list)
    emit_targets
    ;;
  show)
    if [[ -z "${TARGET_ID}" ]]; then
      printf -- '--machine is required with --action show\n' >&2
      exit 2
    fi
    emit_targets
    ;;
  clean-logs)
    emit_clean_logs
    ;;
  *)
    printf 'Unknown action: %s\n' "${ACTION}" >&2
    usage >&2
    exit 2
    ;;
esac
