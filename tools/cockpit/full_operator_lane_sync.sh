#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
LOG_DIR="${ROOT_DIR}/artifacts/cockpit"
STATE_DIR="${ROOT_DIR}/artifacts/operator_lane"
LOG_FILE="${LOG_DIR}/full_operator_lane_sync_${TIMESTAMP}.log"
SUMMARY_FILE="${STATE_DIR}/full_operator_lane_sync_${TIMESTAMP}.json"

JSON_MODE="no"
MODE="staged"

LOCAL_KILL_LIFE_MIRROR="${LOCAL_KILL_LIFE_MIRROR:-/Users/electron/Documents/Lelectron_rare/Github_Repos/Perso/Kill_LIFE-main}"
LOCAL_MASCARADE_MIRROR="${LOCAL_MASCARADE_MIRROR:-/Users/electron/Documents/Lelectron_rare/Github_Repos/Perso/mascarade-main}"
LOCAL_CRAZY_LIFE_MIRROR="${LOCAL_CRAZY_LIFE_MIRROR:-/Users/electron/Documents/Lelectron_rare/Github_Repos/Perso/crazy_life-main}"

KILL_LIFE_FILES=(
  "tools/cockpit/full_operator_lane.sh"
  "tools/cockpit/full_operator_lane_sync.sh"
  "tools/cockpit/README.md"
  "tools/ops/operator_live_provider_smoke.py"
  "tools/ops/operator_live_provider_smoke.js"
  "workflows/embedded-operator-live.json"
  "docs/FULL_OPERATOR_LANE_2026-03-20.md"
  "docs/PROVIDER_RUNTIME_COMPAT_2026-03-20.md"
  "docs/MACHINE_SYNC_STATUS_2026-03-20.md"
  "docs/plans/12_plan_gestion_des_agents.md"
  "docs/plans/19_todo_mesh_tri_repo.md"
  "docs/index.md"
  "README.md"
  "specs/03_plan.md"
  "specs/04_tasks.md"
)

MASCARADE_FILES=(
  "api/src/lib/killlife.ts"
  "docs/FULL_OPERATOR_LANE_2026-03-20.md"
  "docs/TODO_MESH_TRI_REPO_2026-03-20.md"
  "README.md"
)

CRAZY_LIFE_FILES=(
  "api/src/lib/killlife.ts"
  "docs/FULL_OPERATOR_LANE_2026-03-20.md"
  "docs/TODO_MESH_TRI_REPO_2026-03-20.md"
  "README.md"
)

REMOTE_TARGETS=(
  "clems@192.168.0.120|/home/clems/Kill_LIFE-main|/home/clems/mascarade-main|/home/clems/crazy_life-main"
  "root@192.168.0.119|/root/Kill_LIFE-main|/root/mascarade-main|/root/crazy_life-main"
  "kxkm@kxkm-ai|/home/kxkm/Kill_LIFE-main|/home/kxkm/mascarade-main|/home/kxkm/crazy_life-main"
  "cils@100.126.225.111|/Users/cils/Kill_LIFE-main|/Users/cils/mascarade-main|/Users/cils/crazy_life-main"
)

usage() {
  cat <<'EOF'
Usage: bash tools/cockpit/full_operator_lane_sync.sh [--json] [--mode staged|clems-live]
EOF
}

log_line() {
  local level="$1"
  local message="$2"
  mkdir -p "${LOG_DIR}" "${STATE_DIR}"
  local line
  line="${level} $(date +"%Y-%m-%d %H:%M:%S %z") ${message}"
  printf '%s\n' "${line}" >> "${LOG_FILE}"
  if [[ "${JSON_MODE}" != "yes" ]]; then
    printf '%s\n' "${line}"
  fi
}

copy_local_file() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "${dest}")"
  cp "${src}" "${dest}"
}

sync_local_repo() {
  local src_root="$1"
  local dest_root="$2"
  shift 2
  local rel
  for rel in "$@"; do
    copy_local_file "${src_root}/${rel}" "${dest_root}/${rel}"
  done
}

sync_remote_repo() {
  local src_root="$1"
  local target="$2"
  local dest_root="$3"
  shift 3
  tar -cf - -C "${src_root}" "$@" | ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new "${target}" \
    "mkdir -p \"${dest_root}\" && cd \"${dest_root}\" && tar -xf -"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      JSON_MODE="yes"
      shift
      ;;
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

if [[ "${MODE}" != "staged" && "${MODE}" != "clems-live" ]]; then
  usage
  exit 2
fi

mkdir -p "${LOG_DIR}" "${STATE_DIR}"
log_line INFO "Starting full operator lane sync mode=${MODE}"

sync_local_repo "${ROOT_DIR}" "${LOCAL_KILL_LIFE_MIRROR}" "${KILL_LIFE_FILES[@]}"
log_line INFO "Updated local Kill_LIFE-main mirror"

for entry in "${REMOTE_TARGETS[@]}"; do
  IFS='|' read -r target kill_life_root mascarade_root crazy_life_root <<< "${entry}"
  log_line INFO "Syncing staged lanes on ${target}"
  sync_remote_repo "${ROOT_DIR}" "${target}" "${kill_life_root}" "${KILL_LIFE_FILES[@]}"
  sync_remote_repo "${LOCAL_MASCARADE_MIRROR}" "${target}" "${mascarade_root}" "${MASCARADE_FILES[@]}"
  sync_remote_repo "${LOCAL_CRAZY_LIFE_MIRROR}" "${target}" "${crazy_life_root}" "${CRAZY_LIFE_FILES[@]}"
  log_line INFO "Synced staged lanes on ${target}"
done

if [[ "${MODE}" == "clems-live" ]]; then
  sync_remote_repo "${ROOT_DIR}" "clems@192.168.0.120" "/home/clems/Kill_LIFE" \
    "tools/ops/operator_live_provider_smoke.py" \
    "tools/ops/operator_live_provider_smoke.js" \
    "workflows/embedded-operator-live.json"
  sync_remote_repo "${LOCAL_MASCARADE_MIRROR}" "clems@192.168.0.120" "/home/clems/mascarade" \
    "api/src/lib/killlife.ts"
  log_line INFO "Synced clems live roots"
fi

cat > "${SUMMARY_FILE}" <<EOF
{
  "generated_at": "$(date +"%Y-%m-%d %H:%M:%S %z")",
  "status": "done",
  "mode": "${MODE}",
  "targets": ${#REMOTE_TARGETS[@]},
  "log_file": "${LOG_FILE}"
}
EOF

if [[ "${JSON_MODE}" == "yes" ]]; then
  cat "${SUMMARY_FILE}"
fi
