#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# dataset_audit_tui.sh — Audit and preflight for Mistral fine-tune datasets
# Contract: cockpit-v1
# Lots: 23 / 24 — T-MA-015, T-MS-002, T-MS-003
# Date: 2026-03-22
# ============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MASCARADE_ROOT="${MASCARADE_ROOT:-/Users/electron/Documents/Projets/mascarade}"
FINETUNE_DIR="${FINETUNE_DIR:-${MASCARADE_ROOT}/finetune}"
DATASETS_DIR="${DATASETS_DIR:-${FINETUNE_DIR}/datasets}"
FORBIDDEN_MASCARADE_ROOT="${FORBIDDEN_MASCARADE_ROOT:-/Users/electron/Documents/Lelectron_rare/Github_Repos/Perso/mascarade-main}"
WORKSPACE_GUARD="${ROOT_DIR}/tools/cockpit/mistral_workspace_guard.sh"
DATASET_VM_HOST="${DATASET_VM_HOST:-photon-docker}"

ACTION="audit"
JSON_MODE=0

DATASETS=(
  "kicad:build_kicad_dataset.py:KiCad PCB/Schematic"
  "spice:build_spice_dataset.py:SPICE Simulation"
  "freecad:build_freecad_dataset.py:FreeCAD 3D/Mecanique"
  "stm32:build_stm32_dataset.py:STM32 HAL/Firmware"
  "embedded:build_embedded_dataset.py:Embedded C/C++"
  "iot:build_iot_dataset.py:IoT MQTT/LoRa/Zigbee"
  "emc:build_emc_dataset.py:EMC/CEM Compatibilite"
  "dsp:build_dsp_dataset.py:DSP Traitement Signal"
  "power:build_power_dataset.py:Power Electronics"
  "platformio:build_platformio_dataset.py:PlatformIO CI/CD"
)

usage() {
  cat <<'EOF'
Usage: dataset_audit_tui.sh [--action audit|preflight|paths] [--json]

Actions:
  audit       Static analysis of dataset builders and generated files
  preflight   Report readiness for T-MS-002/003 and downstream fine-tune lots
  paths       Print canonical paths

Options:
  --json      Emit cockpit-v1 JSON only
  --help      Show this help

Env vars:
  MASCARADE_ROOT          Active Mascarade workspace (default: /Users/electron/Documents/Projets/mascarade)
  FINETUNE_DIR            Fine-tune root override
  DATASETS_DIR            Dataset builders/output root override
  DATASET_VM_HOST         VM host label for upload/fine-tune lots (default: photon-docker)
EOF
}

json_escape() {
  python3 - "$1" <<'PY'
import json
import sys
print(json.dumps(sys.argv[1]))
PY
}

bool_json() {
  if [[ "$1" == "1" ]]; then
    printf 'true'
  else
    printf 'false'
  fi
}

builder_path() {
  local script="$1"
  if [[ -f "${DATASETS_DIR}/${script}" ]]; then
    printf '%s\n' "${DATASETS_DIR}/${script}"
    return 0
  fi
  if [[ -f "${FINETUNE_DIR}/${script}" ]]; then
    printf '%s\n' "${FINETUNE_DIR}/${script}"
    return 0
  fi
  return 1
}

count_found_builders() {
  local found=0
  local entry script
  for entry in "${DATASETS[@]}"; do
    IFS=':' read -r _ script _ <<< "${entry}"
    if builder_path "${script}" >/dev/null; then
      ((found+=1))
    fi
  done
  printf '%s\n' "${found}"
}

count_generated_files() {
  local found=0
  local dir
  local dirs=(
    "${DATASETS_DIR}"
    "${FINETUNE_DIR}/datasets"
    "${FINETUNE_DIR}"
  )

  for dir in "${dirs[@]}"; do
    if [[ -d "${dir}" ]]; then
      while IFS= read -r _; do
        ((found+=1))
      done < <(find "${dir}" -maxdepth 1 -type f \( -name '*.jsonl' -o -name '*.json' -o -name '*.csv' -o -name '*.parquet' \) 2>/dev/null)
    fi
  done

  printf '%s\n' "${found}"
}

print_header() {
  echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}${CYAN}║   Dataset Fine-tune Audit / Preflight           ║${NC}"
  echo -e "${BOLD}${CYAN}║   $(date '+%Y-%m-%d %H:%M:%S')                            ║${NC}"
  echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════╝${NC}"
  echo ""
}

emit_status_json() {
  local component="$1"
  local action="$2"
  local status="$3"
  local reason="$4"
  local builders_found="$5"
  local generated_files="$6"
  local upload_ready="$7"
  local finetune_ready="$8"
  local workspace_guard_available=0

  [[ -x "${WORKSPACE_GUARD}" ]] && workspace_guard_available=1

  cat <<EOF
{
  "contract_version": "cockpit-v1",
  "component": "${component}",
  "action": "${action}",
  "status": "${status}",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "reason": $(json_escape "${reason}"),
  "tracking_root": $(json_escape "${ROOT_DIR}"),
  "mascarade_root": $(json_escape "${MASCARADE_ROOT}"),
  "finetune_dir": $(json_escape "${FINETUNE_DIR}"),
  "datasets_dir": $(json_escape "${DATASETS_DIR}"),
  "forbidden_mascarade_root": $(json_escape "${FORBIDDEN_MASCARADE_ROOT}"),
  "workspace_guard": $(json_escape "${WORKSPACE_GUARD}"),
  "workspace_guard_available": $(bool_json "${workspace_guard_available}"),
  "mascarade_root_exists": $(bool_json "$([[ -d "${MASCARADE_ROOT}" ]] && echo 1 || echo 0)"),
  "finetune_dir_exists": $(bool_json "$([[ -d "${FINETUNE_DIR}" ]] && echo 1 || echo 0)"),
  "datasets_dir_exists": $(bool_json "$([[ -d "${DATASETS_DIR}" ]] && echo 1 || echo 0)"),
  "forbidden_copy_present": $(bool_json "$([[ -e "${FORBIDDEN_MASCARADE_ROOT}" ]] && echo 1 || echo 0)"),
  "builders_total": ${#DATASETS[@]},
  "builders_found": ${builders_found},
  "generated_files": ${generated_files},
  "dataset_vm_host": $(json_escape "${DATASET_VM_HOST}"),
  "dataset_vm_required": true,
  "dataset_vm_access_checked": false,
  "upload_ready": $(bool_json "${upload_ready}"),
  "finetune_ready": $(bool_json "${finetune_ready}"),
  "blocked_lots": ["T-MS-002","T-MS-003","T-MA-016","T-MA-017","T-MA-021"],
  "next_steps": [
    "Use the active Mascarade workspace only: /Users/electron/Documents/Projets/mascarade",
    "Prepare merged and validated datasets before T-MS-002/T-MS-003",
    "Run upload and fine-tune lots on the dataset VM host after local preflight is green"
  ]
}
EOF
}

action_paths() {
  if [[ "${JSON_MODE}" -eq 1 ]]; then
    emit_status_json "dataset-audit" "paths" "ok" "canonical paths" 0 0 0 0
  else
    printf '%s\n' "${ROOT_DIR}"
    printf '%s\n' "${MASCARADE_ROOT}"
    printf '%s\n' "${FINETUNE_DIR}"
    printf '%s\n' "${DATASETS_DIR}"
    printf '%s\n' "${FORBIDDEN_MASCARADE_ROOT}"
  fi
}

action_preflight() {
  local builders_found generated_files status reason upload_ready=0 finetune_ready=0
  builders_found="$(count_found_builders)"
  generated_files="$(count_generated_files)"
  status="ready"
  reason="dataset builders and outputs available for the next VM-bound lots"

  if [[ ! -d "${MASCARADE_ROOT}" || ! -d "${FINETUNE_DIR}" || ! -d "${DATASETS_DIR}" ]]; then
    status="blocked"
    reason="active Mascarade fine-tune paths missing"
  elif [[ "${builders_found}" -lt "${#DATASETS[@]}" ]]; then
    status="degraded"
    reason="dataset builder coverage incomplete"
  elif [[ "${generated_files}" -eq 0 ]]; then
    status="degraded"
    reason="no generated dataset files found yet"
  fi

  if [[ "${status}" == "ready" ]]; then
    upload_ready=1
    finetune_ready=1
  fi

  if [[ "${JSON_MODE}" -eq 1 ]]; then
    emit_status_json "dataset-audit" "preflight" "${status}" "${reason}" "${builders_found}" "${generated_files}" "${upload_ready}" "${finetune_ready}"
    return
  fi

  print_header
  echo -e "${BOLD}[Preflight]${NC}"
  echo -e "  Status: ${status}"
  echo -e "  Reason: ${reason}"
  echo -e "  Active Mascarade root: ${MASCARADE_ROOT}"
  echo -e "  Fine-tune dir: ${FINETUNE_DIR}"
  echo -e "  Datasets dir: ${DATASETS_DIR}"
  echo -e "  Builders found: ${builders_found}/${#DATASETS[@]}"
  echo -e "  Generated files: ${generated_files}"
  echo -e "  VM host for upload/fine-tune: ${DATASET_VM_HOST}"
  echo -e "  Lots gated by VM: T-MS-002, T-MS-003, T-MA-016, T-MA-017, T-MA-021"
}

audit_builder() {
  local name="$1"
  local script="$2"
  local desc="$3"
  local script_path=""

  if script_path="$(builder_path "${script}" 2>/dev/null)"; then
    :
  else
    echo -e "  ${RED}x${NC} ${BOLD}${name}${NC} (${desc}): ${RED}Script not found${NC}"
    echo "NOT_FOUND"
    return
  fi

  local lines score has_output_format has_validation has_dedup has_balance_check issues
  lines="$(wc -l < "${script_path}" 2>/dev/null || echo 0)"
  score=0
  has_output_format=0
  has_validation=0
  has_dedup=0
  has_balance_check=0
  issues=""

  grep -Eq "jsonl|json\.dumps|to_json|ChatML|messages" "${script_path}" 2>/dev/null && has_output_format=1
  grep -Eq "validate|assert|check|quality|filter" "${script_path}" 2>/dev/null && has_validation=1
  grep -Eq "deduplicate|dedup|drop_duplicates|set\(\)|unique" "${script_path}" 2>/dev/null && has_dedup=1
  grep -Eq "balance|distribution|count.*category|value_counts|Counter" "${script_path}" 2>/dev/null && has_balance_check=1

  [[ "${lines}" -gt 50 ]] && ((score+=1))
  [[ "${lines}" -gt 200 ]] && ((score+=1))
  [[ "${has_output_format}" -eq 1 ]] && ((score+=2))
  [[ "${has_validation}" -eq 1 ]] && ((score+=2))
  [[ "${has_dedup}" -eq 1 ]] && ((score+=1))
  [[ "${has_balance_check}" -eq 1 ]] && ((score+=1))

  [[ "${lines}" -lt 20 ]] && issues="${issues}skeleton-only "
  [[ "${has_output_format}" -eq 0 ]] && issues="${issues}no-output-format "
  [[ "${has_validation}" -eq 0 ]] && issues="${issues}no-validation "
  [[ "${has_dedup}" -eq 0 ]] && issues="${issues}no-dedup "

  local color="${RED}"
  local status_text="POOR"
  if [[ "${score}" -ge 6 ]]; then
    color="${GREEN}"
    status_text="GOOD"
  elif [[ "${score}" -ge 3 ]]; then
    color="${YELLOW}"
    status_text="FAIR"
  fi

  echo -e "  ${color}o${NC} ${BOLD}${name}${NC} (${desc})"
  echo -e "    Path: ${script_path}"
  echo -e "    Lines: ${lines} | Score: ${score}/8 | Status: ${color}${status_text}${NC}"
  if [[ -n "${issues}" ]]; then
    echo -e "    Issues: ${YELLOW}${issues}${NC}"
  fi
  echo "${score}"
}

check_generated_datasets() {
  echo -e "\n${BOLD}[Generated Dataset Files]${NC}"

  local dirs=(
    "${DATASETS_DIR}"
    "${FINETUNE_DIR}/datasets"
    "${FINETUNE_DIR}"
  )
  local dir
  local found=0

  for dir in "${dirs[@]}"; do
    if [[ -d "${dir}" ]]; then
      while IFS= read -r f; do
        local size lines
        size="$(du -h "${f}" 2>/dev/null | cut -f1)"
        lines="$(wc -l < "${f}" 2>/dev/null || echo '?')"
        echo -e "  ${GREEN}o${NC} $(basename "${f}"): ${size} (${lines} lines)"
        ((found+=1))
      done < <(find "${dir}" -maxdepth 1 -type f \( -name '*.jsonl' -o -name '*.json' -o -name '*.csv' -o -name '*.parquet' \) 2>/dev/null)
    fi
  done

  if [[ "${found}" -eq 0 ]]; then
    echo -e "  ${YELLOW}o${NC} No generated dataset files found"
  fi

  echo -e "  Total: ${found} dataset files"
}

action_audit() {
  local builders_found generated_files
  builders_found="$(count_found_builders)"
  generated_files="$(count_generated_files)"

  if [[ "${JSON_MODE}" -eq 1 ]]; then
    local status="pass"
    local reason="dataset audit completed"
    local upload_ready=0
    local finetune_ready=0
    if [[ ! -d "${MASCARADE_ROOT}" || ! -d "${FINETUNE_DIR}" || ! -d "${DATASETS_DIR}" ]]; then
      status="blocked"
      reason="active Mascarade fine-tune paths missing"
    elif [[ "${builders_found}" -lt "${#DATASETS[@]}" || "${generated_files}" -eq 0 ]]; then
      status="needs-work"
      reason="dataset builders or outputs incomplete"
    else
      upload_ready=1
      finetune_ready=1
    fi
    emit_status_json "dataset-audit" "audit" "${status}" "${reason}" "${builders_found}" "${generated_files}" "${upload_ready}" "${finetune_ready}"
    return
  fi

  print_header
  echo -e "${BOLD}[Workspace Policy]${NC}"
  echo -e "  Tracking root: ${ROOT_DIR}"
  echo -e "  Active Mascarade root: ${MASCARADE_ROOT}"
  echo -e "  Forbidden copy: ${FORBIDDEN_MASCARADE_ROOT}"
  echo -e "  VM host for upload/fine-tune: ${DATASET_VM_HOST}"
  echo ""

  echo -e "${BOLD}[Builder Scripts Analysis]${NC}\n"

  local total=0 good=0 fair=0 poor=0 missing=0 total_score=0
  local entry result score
  for entry in "${DATASETS[@]}"; do
    IFS=':' read -r name script desc <<< "${entry}"
    ((total+=1))
    result="$(audit_builder "${name}" "${script}" "${desc}" 2>/dev/null)"
    score="$(echo "${result}" | tail -n 1)"

    case "${score}" in
      NOT_FOUND) ((missing+=1)) ;;
      [6-8]) ((good+=1)); total_score=$((total_score + score)) ;;
      [3-5]) ((fair+=1)); total_score=$((total_score + score)) ;;
      *) ((poor+=1)); total_score=$((total_score + ${score:-0})) ;;
    esac

    echo "${result}" | head -n -1
    echo ""
  done

  check_generated_datasets
  echo ""

  local avg_score=0
  [[ "${total}" -gt 0 ]] && avg_score=$((total_score / total))

  echo -e "${BOLD}[Audit Summary]${NC}"
  echo -e "  Builders: ${total} total"
  echo -e "    ${GREEN}Good${NC}: ${good} | ${YELLOW}Fair${NC}: ${fair} | ${RED}Poor${NC}: ${poor} | Missing: ${missing}"
  echo -e "  Average score: ${avg_score}/8"
  echo -e "  Builders found on disk: ${builders_found}/${#DATASETS[@]}"
  echo -e "  Generated dataset files: ${generated_files}"
  echo ""

  echo -e "${BOLD}[Lot Readiness]${NC}"
  echo -e "  Local audit lot: T-MA-015"
  echo -e "  VM-gated upload lots: T-MS-002, T-MS-003"
  echo -e "  VM-gated fine-tune lots: T-MA-016, T-MA-017"
  echo -e "  Downstream benchmark lot: T-MA-021"
  if [[ "${missing}" -gt 0 || "${generated_files}" -eq 0 ]]; then
    echo -e "  ${YELLOW}->${NC} Local preflight is not ready for VM upload/fine-tune"
  else
    echo -e "  ${GREEN}o${NC} Local preflight is ready; next gate remains VM execution"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --action)
      ACTION="${2:-}"
      shift 2
      ;;
    --json)
      JSON_MODE=1
      shift
      ;;
    --help|-h)
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
  audit)
    action_audit
    ;;
  preflight)
    action_preflight
    ;;
  paths)
    action_paths
    ;;
  *)
    printf 'Unknown action: %s\n' "${ACTION}" >&2
    usage >&2
    exit 2
    ;;
esac
