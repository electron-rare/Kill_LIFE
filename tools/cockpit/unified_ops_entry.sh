#!/usr/bin/env bash
set -euo pipefail

# unified_ops_entry.sh -- Point d'entree unique pour logs, handoffs et resume hebdomadaire
# Converge log_ops, render_weekly_refonte_summary et full_operator_lane status
# en une seule surface cockpit.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
source "${ROOT_DIR}/tools/cockpit/json_contract.sh"

ARTIFACT_DIR="${ROOT_DIR}/artifacts/cockpit"
UNIFIED_LOG_DIR="${ARTIFACT_DIR}/unified_ops"
mkdir -p "${UNIFIED_LOG_DIR}"
STAMP="$(date +%Y%m%d-%H%M%S)"
UNIFIED_LOG="${UNIFIED_LOG_DIR}/unified_ops-${STAMP}.log"

ACTION="all"
JSON_OUTPUT=0
VERBOSE=0

usage() {
  cat <<'USAGE'
Usage: bash tools/cockpit/unified_ops_entry.sh [options]

Combine log_ops summary, weekly refonte summary, and operator lane status
into a single unified view.

Actions:
  --action all        Run all three panels (default)
  --action logs       Run log_ops summary only
  --action weekly     Run weekly refonte summary only
  --action lane       Run full_operator_lane status only
  --action quick      Logs + lane status (skip weekly render)

Options:
  --json              Output structured JSON to stdout
  --verbose           Show full output from sub-commands
  -h, --help          Show this help
USAGE
}

log_msg() {
  local level="$1"; shift
  printf '[%s] [%s] %s\n' "$(date +%H:%M:%S)" "$level" "$*" | tee -a "$UNIFIED_LOG" >&2
}

separator() {
  if [[ "$JSON_OUTPUT" -eq 0 ]]; then
    printf '\n%s\n' "$(printf '=%.0s' {1..72})" >&2
  fi
}

# --- Panel 1: log_ops summary ---
run_log_ops() {
  local log_ops_script="${SCRIPT_DIR}/log_ops.sh"
  local status="skipped"
  local detail=""

  if [[ -x "$log_ops_script" ]] || [[ -f "$log_ops_script" ]]; then
    log_msg "INFO" "Running log_ops summary..."
    if detail="$(bash "$log_ops_script" --action summary 2>&1)"; then
      status="ok"
    else
      status="degraded"
    fi
    if [[ "$VERBOSE" -eq 1 ]] && [[ "$JSON_OUTPUT" -eq 0 ]]; then
      printf '%s\n' "$detail" >&2
    fi
  else
    log_msg "WARN" "log_ops.sh not found"
    detail="log_ops.sh not found at $log_ops_script"
  fi

  LOG_OPS_STATUS="$status"
  LOG_OPS_DETAIL="$detail"
}

# --- Panel 2: weekly refonte summary ---
run_weekly_summary() {
  local weekly_script="${SCRIPT_DIR}/render_weekly_refonte_summary.sh"
  local status="skipped"
  local detail=""
  local output_file="${ARTIFACT_DIR}/weekly_refonte_summary.md"

  if [[ -x "$weekly_script" ]] || [[ -f "$weekly_script" ]]; then
    log_msg "INFO" "Rendering weekly refonte summary..."
    if detail="$(bash "$weekly_script" --output "$output_file" 2>&1)"; then
      status="ok"
      if [[ -f "$output_file" ]]; then
        detail="Generated: $output_file"
      fi
    else
      status="degraded"
    fi
    if [[ "$VERBOSE" -eq 1 ]] && [[ "$JSON_OUTPUT" -eq 0 ]]; then
      printf '%s\n' "$detail" >&2
    fi
  else
    log_msg "WARN" "render_weekly_refonte_summary.sh not found"
    detail="render_weekly_refonte_summary.sh not found"
  fi

  WEEKLY_STATUS="$status"
  WEEKLY_DETAIL="$detail"
}

# --- Panel 3: full_operator_lane status ---
run_operator_lane() {
  local lane_script="${SCRIPT_DIR}/full_operator_lane.sh"
  local status="skipped"
  local detail=""

  if [[ -x "$lane_script" ]] || [[ -f "$lane_script" ]]; then
    log_msg "INFO" "Fetching operator lane status..."
    if detail="$(bash "$lane_script" status --json 2>&1)"; then
      status="ok"
    else
      status="degraded"
    fi
    if [[ "$VERBOSE" -eq 1 ]] && [[ "$JSON_OUTPUT" -eq 0 ]]; then
      printf '%s\n' "$detail" >&2
    fi
  else
    log_msg "WARN" "full_operator_lane.sh not found"
    detail="full_operator_lane.sh not found"
  fi

  LANE_STATUS="$status"
  LANE_DETAIL="$detail"
}

# --- Output ---
render_text_summary() {
  separator
  printf '  UNIFIED OPS ENTRY -- %s\n' "$(date '+%Y-%m-%d %H:%M')" >&2
  separator

  printf '\n[1/3] LOG OPS        : %s\n' "$LOG_OPS_STATUS" >&2
  if [[ "$LOG_OPS_STATUS" != "skipped" ]]; then
    printf '       %s\n' "$(echo "$LOG_OPS_DETAIL" | head -5)" >&2
  fi

  printf '\n[2/3] WEEKLY SUMMARY : %s\n' "$WEEKLY_STATUS" >&2
  if [[ "$WEEKLY_STATUS" != "skipped" ]]; then
    printf '       %s\n' "$(echo "$WEEKLY_DETAIL" | head -3)" >&2
  fi

  printf '\n[3/3] OPERATOR LANE  : %s\n' "$LANE_STATUS" >&2
  if [[ "$LANE_STATUS" != "skipped" ]]; then
    printf '       %s\n' "$(echo "$LANE_DETAIL" | head -5)" >&2
  fi

  separator
  local overall
  if [[ "$LOG_OPS_STATUS" == "ok" ]] && [[ "$WEEKLY_STATUS" == "ok" || "$WEEKLY_STATUS" == "skipped" ]] && [[ "$LANE_STATUS" == "ok" || "$LANE_STATUS" == "skipped" ]]; then
    overall="ok"
  elif [[ "$LOG_OPS_STATUS" == "degraded" ]] || [[ "$WEEKLY_STATUS" == "degraded" ]] || [[ "$LANE_STATUS" == "degraded" ]]; then
    overall="degraded"
  else
    overall="unknown"
  fi
  printf '  OVERALL: %s\n' "$overall" >&2
  printf '  Log: %s\n\n' "$UNIFIED_LOG" >&2
}

render_json_summary() {
  local overall
  if [[ "$LOG_OPS_STATUS" == "ok" ]] && [[ "$WEEKLY_STATUS" == "ok" || "$WEEKLY_STATUS" == "skipped" ]] && [[ "$LANE_STATUS" == "ok" || "$LANE_STATUS" == "skipped" ]]; then
    overall="ok"
  elif [[ "$LOG_OPS_STATUS" == "degraded" ]] || [[ "$WEEKLY_STATUS" == "degraded" ]] || [[ "$LANE_STATUS" == "degraded" ]]; then
    overall="degraded"
  else
    overall="unknown"
  fi

  local log_ops_escaped weekly_escaped lane_escaped
  log_ops_escaped="$(json_contract_escape "$LOG_OPS_DETAIL")"
  weekly_escaped="$(json_contract_escape "$WEEKLY_DETAIL")"
  lane_escaped="$(json_contract_escape "$LANE_DETAIL")"

  cat <<EOF
{
  "component": "unified_ops_entry",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "overall_status": "${overall}",
  "panels": {
    "log_ops": {
      "status": "${LOG_OPS_STATUS}",
      "detail": "${log_ops_escaped}"
    },
    "weekly_summary": {
      "status": "${WEEKLY_STATUS}",
      "detail": "${weekly_escaped}"
    },
    "operator_lane": {
      "status": "${LANE_STATUS}",
      "detail": "${lane_escaped}"
    }
  },
  "log_file": "${UNIFIED_LOG}"
}
EOF
}

# --- Main ---
LOG_OPS_STATUS="skipped"
LOG_OPS_DETAIL=""
WEEKLY_STATUS="skipped"
WEEKLY_DETAIL=""
LANE_STATUS="skipped"
LANE_DETAIL=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --action) ACTION="${2:-all}"; shift 2 ;;
    --json) JSON_OUTPUT=1; shift ;;
    --verbose) VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) log_msg "WARN" "Unknown argument: $1"; shift ;;
  esac
done

case "$ACTION" in
  all)
    run_log_ops
    run_weekly_summary
    run_operator_lane
    ;;
  logs)
    run_log_ops
    ;;
  weekly)
    run_weekly_summary
    ;;
  lane)
    run_operator_lane
    ;;
  quick)
    run_log_ops
    run_operator_lane
    ;;
  *)
    log_msg "ERROR" "Unknown action: $ACTION"
    usage
    exit 1
    ;;
esac

if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  render_json_summary
else
  render_text_summary
fi

exit 0
