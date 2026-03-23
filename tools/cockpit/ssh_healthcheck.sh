#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
source "${PROJECT_DIR}/tools/cockpit/json_contract.sh"
LOG_DIR="${PROJECT_DIR}/artifacts/cockpit"
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
REGISTRY_FILE="${PROJECT_DIR}/specs/contracts/machine_registry.mesh.json"

JSON_OUTPUT=0
VERBOSE=0
LOG_FILE="${LOG_DIR}/ssh_healthcheck_${TIMESTAMP}.log"
TARGETS=()

usage() {
  cat <<'USAGE'
Usage: bash tools/cockpit/ssh_healthcheck.sh [options]

Options:
  --json           Emit a JSON summary to stdout.
  --no-log         Disable log file creation.
  --verbose        Show command-level details.
  -h, --help       Show this help message.

This script checks SSH reachability on the project-operator machines.
Each JSON result now includes `priority`, `port` and `role` for audit traceability.
USAGE
}

log_line() {
  local level="$1"
  shift
  local msg="${level} $(date '+%Y-%m-%d %H:%M:%S %z') ${*}"
  printf '%s\n' "${msg}"
  if [[ -n "${LOG_FILE:-}" ]]; then
    printf '%s\n' "${msg}" >> "${LOG_FILE}"
  fi
}

load_targets_from_registry() {
  python3 - "${REGISTRY_FILE}" <<'PY'
import json
import sys
from pathlib import Path

registry_path = Path(sys.argv[1])
data = json.loads(registry_path.read_text(encoding="utf-8"))
targets = sorted(data.get("targets", []), key=lambda item: item.get("priority", 999))

for item in targets:
    target = item.get("target", "")
    port = int(item.get("port", 0) or 0)
    if target == "local" or port <= 0:
        continue
    priority = item.get("priority", 999)
    role = item.get("role", "unknown")
    print(f"{target}|{port}|{priority}|{role}")
PY
}

run_target() {
  local target_host
  local port
  local priority
  local role
  local entry="$1"
  local ok=0

  IFS='|' read -r target_host port priority role <<< "${entry}"

  local ssh_cmd=(
    ssh
    -o BatchMode=yes
    -o ConnectTimeout=5
    -o StrictHostKeyChecking=accept-new
    -p "${port}"
    "${target_host}"
    'echo OK'
  )

  if [[ "${VERBOSE}" -eq 1 ]]; then
    if "${ssh_cmd[@]}" >/dev/null; then
      ok=1
    fi
  else
    if "${ssh_cmd[@]}" >/dev/null 2>&1; then
      ok=1
    fi
  fi

  if [[ "${ok}" -eq 1 ]]; then
    log_line "INFO" "[OK] P${priority} ${role} -> ${target_host} (port ${port})"
  else
    log_line "WARN" "[KO] P${priority} ${role} -> ${target_host} (port ${port})"
  fi

  RESULTS+=("${target_host}|${port}|${priority}|${role}|${ok}")
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      JSON_OUTPUT=1
      ;;
    --no-log)
      LOG_FILE=""
      ;;
    --verbose)
      VERBOSE=1
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
  shift
done

if [[ -n "${LOG_FILE}" ]]; then
  mkdir -p "${LOG_DIR}"
  touch "${LOG_DIR}/.keep"
  log_line "INFO" "Log file: ${LOG_FILE}"
fi

log_line "INFO" "Starting Kill_LIFE SSH health-check"
mapfile -t TARGETS < <(load_targets_from_registry)
if [[ "${#TARGETS[@]}" -eq 0 ]]; then
  log_line "WARN" "No SSH targets resolved from ${REGISTRY_FILE}"
  exit 1
fi

RESULTS=()
for entry in "${TARGETS[@]}"; do
  run_target "${entry}"
done

ok_count=0
ko_count=0
for r in "${RESULTS[@]}"; do
  ok_count=$((ok_count + $(awk -F'|' '{print $5}' <<< "${r}")))
done
ko_count=$((${#TARGETS[@]} - ok_count))

log_line "INFO" "Completed: ${ok_count} OK, ${ko_count} KO"
for r in "${RESULTS[@]}"; do
  IFS='|' read -r target_host port priority role ok <<< "${r}"
  log_line "INFO" " - P${priority} ${target_host} (${port}) ${role} => $([[ "${ok}" -eq 1 ]] && echo OK || echo KO)"
done

if [[ "${JSON_OUTPUT}" -eq 1 ]]; then
  contract_status="ok"
  degraded_reasons=()
  next_steps=()
  artifacts=()
  [[ -n "${LOG_FILE}" ]] && artifacts+=("${LOG_FILE}")
  if [[ "${ko_count}" -gt 0 ]]; then
    contract_status="degraded"
    degraded_reasons+=("ssh-target-unreachable")
    next_steps+=("Inspect SSH access, port 22 reachability and operator keys on KO targets.")
  fi
  printf '{\n'
  printf '  "contract_version": "cockpit-v1",\n'
  printf '  "component": "ssh_healthcheck",\n'
  printf '  "action": "summary",\n'
  printf '  "status": "%s",\n' "${contract_status}"
  printf '  "contract_status": "%s",\n' "${contract_status}"
  printf '  "generated_at": "%s",\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
  printf '  "log_file": "%s",\n' "${LOG_FILE}"
  printf '  "registry_file": "%s",\n' "${REGISTRY_FILE}"
  printf '  "target_source": "registry",\n'
  printf '  "artifacts": %s,\n' "$(json_contract_array_from_args "${artifacts[@]}")"
  printf '  "degraded_reasons": %s,\n' "$(json_contract_array_from_args "${degraded_reasons[@]}")"
  printf '  "next_steps": %s,\n' "$(json_contract_array_from_args "${next_steps[@]}")"
  printf '  "ok_count": %d,\n' "${ok_count}"
  printf '  "ko_count": %d,\n' "${ko_count}"
  printf '  "targets": [\n'
  for ((idx = 0; idx < ${#RESULTS[@]}; idx++)); do
    IFS='|' read -r target_host port priority role ok <<< "${RESULTS[${idx}]}"
    status="ok"
    [[ "${ok}" -eq 0 ]] && status="ko"
    comma=","
    if [[ ${idx} -eq $(( ${#RESULTS[@]} - 1 )) ]]; then
      comma=""
    fi
    printf '    {"target":"%s","port":"%s","priority":"%s","role":"%s","status":"%s"}%s\n' \
      "${target_host}" "${port}" "${priority}" "${role}" "${status}" "${comma}"
  done
  printf '  ]\n'
  printf '}\n'
fi

if [[ "${ok_count}" -eq "${#TARGETS[@]}" ]]; then
  log_line "INFO" "SSH health-check: all targets reachable"
  exit 0
else
  log_line "WARN" "SSH health-check: one or more targets unreachable"
  exit 2
fi
