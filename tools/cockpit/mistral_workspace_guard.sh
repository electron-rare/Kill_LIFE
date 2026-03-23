#!/usr/bin/env bash
set -euo pipefail

# mistral_workspace_guard.sh
# Guardrail for the single authorized workspace layout used by Kill_LIFE Mistral lots.
# Contract: cockpit-v1
# Date: 2026-03-22

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STAMP="$(date +%Y%m%d_%H%M%S)"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts/cockpit/mistral_workspace_guard"
mkdir -p "${ARTIFACTS_DIR}"

ACTION="status"
JSON_MODE=0

KILL_LIFE_ROOT="/Users/electron/Documents/Lelectron_rare/Kill_LIFE"
MASCARADE_ROOT="/Users/electron/Documents/Projets/mascarade"
FORBIDDEN_ROOT="/Users/electron/Documents/Lelectron_rare/Github_Repos/Perso/mascarade-main"

usage() {
  cat <<'EOF'
Usage: mistral_workspace_guard.sh [--action status|assert|paths] [--json]

Actions:
  status   Show current workspace policy state
  assert   Exit non-zero if the policy is violated
  paths    Print the canonical paths only

Options:
  --json   Emit cockpit-v1 JSON
  --help   Show this help
EOF
}

json_escape() {
  python3 - "$1" <<'PY'
import json
import sys
print(json.dumps(sys.argv[1]))
PY
}

path_exists_json() {
  local path="$1"
  if [[ -e "$path" ]]; then
    printf 'true'
  else
    printf 'false'
  fi
}

build_json() {
  local status="$1"
  local action="$2"
  local reason="$3"
  local required_kill_life_exists required_mascarade_exists forbidden_exists

  required_kill_life_exists="$(path_exists_json "$KILL_LIFE_ROOT")"
  required_mascarade_exists="$(path_exists_json "$MASCARADE_ROOT")"
  forbidden_exists="$(path_exists_json "$FORBIDDEN_ROOT")"

  cat <<EOF
{
  "contract_version": "cockpit-v1",
  "component": "mistral-workspace-guard",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "action": "${action}",
  "status": "${status}",
  "reason": $(json_escape "${reason}"),
  "kill_life_root": $(json_escape "${KILL_LIFE_ROOT}"),
  "mascarade_root": $(json_escape "${MASCARADE_ROOT}"),
  "forbidden_root": $(json_escape "${FORBIDDEN_ROOT}"),
  "kill_life_exists": ${required_kill_life_exists},
  "mascarade_exists": ${required_mascarade_exists},
  "forbidden_exists": ${forbidden_exists},
  "policy": {
    "tracking_root": $(json_escape "${KILL_LIFE_ROOT}"),
    "active_mascarade_root": $(json_escape "${MASCARADE_ROOT}"),
    "forbidden_copy": $(json_escape "${FORBIDDEN_ROOT}")
  }
}
EOF
}

status_report() {
  local status="ok"
  local reason="single-workspace policy respected"

  if [[ ! -d "$KILL_LIFE_ROOT" ]]; then
    status="error"
    reason="Kill_LIFE root missing"
  elif [[ ! -d "$MASCARADE_ROOT" ]]; then
    status="error"
    reason="Mascarade root missing"
  elif [[ -e "$FORBIDDEN_ROOT" ]]; then
    status="degraded"
    reason="forbidden duplicate present; do not use it"
  fi

  if [[ "$JSON_MODE" -eq 1 ]]; then
    build_json "$status" "$ACTION" "$reason"
  else
    printf 'Mistral workspace guard\n'
    printf 'status: %s\n' "$status"
    printf 'reason: %s\n' "$reason"
    printf 'tracking_root: %s\n' "$KILL_LIFE_ROOT"
    printf 'active_mascarade_root: %s\n' "$MASCARADE_ROOT"
    printf 'forbidden_copy: %s\n' "$FORBIDDEN_ROOT"
  fi

  local latest_file="${ARTIFACTS_DIR}/latest.json"
  build_json "$status" "$ACTION" "$reason" > "${ARTIFACTS_DIR}/mistral_workspace_guard_${STAMP}.json"
  build_json "$status" "$ACTION" "$reason" > "$latest_file"

  [[ "$status" == "error" ]] && return 1
  [[ "$ACTION" == "assert" && "$status" != "ok" ]] && return 1
  return 0
}

paths_report() {
  if [[ "$JSON_MODE" -eq 1 ]]; then
    build_json "ok" "$ACTION" "canonical paths only"
  else
    printf '%s\n' "$KILL_LIFE_ROOT"
    printf '%s\n' "$MASCARADE_ROOT"
    printf '%s\n' "$FORBIDDEN_ROOT"
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

case "$ACTION" in
  status|assert)
    status_report
    ;;
  paths)
    paths_report
    ;;
  *)
    printf 'Unknown action: %s\n' "$ACTION" >&2
    usage >&2
    exit 2
    ;;
esac
