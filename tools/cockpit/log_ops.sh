#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/tools/cockpit/json_contract.sh"
ARTIFACT_DIR="$ROOT_DIR/artifacts/cockpit"
LOG_DIR="$ARTIFACT_DIR/log_ops"
mkdir -p "$LOG_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
RUN_LOG="$LOG_DIR/log_ops-$STAMP.log"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
ACTION="summary"
COMPONENT="log_ops"
JSON=0
APPLY=0
TARGET_DIRS=(
  "$ROOT_DIR/artifacts"
  "$ROOT_DIR/logs"
  "$ROOT_DIR/tmp"
)

if [ -n "${LOG_OPS_TARGET_DIRS:-}" ]; then
  IFS=':' read -r -a TARGET_DIRS <<< "${LOG_OPS_TARGET_DIRS}"
fi

usage() {
  cat <<USAGE
Usage: bash tools/cockpit/log_ops.sh [--action summary|purge|list] [--json] [--apply] [--retention-days N]

Actions:
  summary   Summarize known logs and age buckets.
  list      Emit the file list considered by the tool.
  purge     Dry-run by default; delete logs older than retention only with --apply.
USAGE
}

log() {
  local level="$1"
  shift
  local msg="$*"
  printf '[%s] [%s] %s\n' "$(date +%H:%M:%S)" "$level" "$msg" | tee -a "$RUN_LOG" >&2
}

collect_logs() {
  local dir
  for dir in "${TARGET_DIRS[@]}"; do
    [ -d "$dir" ] || continue
    find "$dir" -type f \( -name '*.log' -o -name '*.out' -o -name '*.err' -o -name '*.jsonl' \) -print
  done | sort -u
}

main() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --action)
        ACTION="${2:-}"
        shift 2
        ;;
      --json)
        JSON=1
        shift
        ;;
      --apply)
        APPLY=1
        shift
        ;;
      --retention-days)
        RETENTION_DAYS="${2:-7}"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        printf 'Unknown arg: %s\n' "$1" >&2
        usage >&2
        exit 2
        ;;
    esac
  done

  local files
  files="$(collect_logs || true)"
  local count=0
  local stale=0
  local bytes=0
  local listed_json=""
  local purged_json=""
  local purged_count=0
  local status="done"
  local contract_status="ok"
  local artifacts=("${RUN_LOG}")
  local degraded_reasons=()
  local next_steps=()

  if [ -n "$files" ]; then
    while IFS= read -r file; do
      [ -n "$file" ] || continue
      count=$((count + 1))
      local size
      size="$(wc -c < "$file" | tr -d ' ')"
      bytes=$((bytes + size))
      listed_json="$(json_contract_append_string "$listed_json" "$file")"
      if find "$file" -mtime +"$RETENTION_DAYS" -print -quit | grep -q .; then
        stale=$((stale + 1))
        if [ "$ACTION" = "purge" ] && [ "$APPLY" -eq 1 ]; then
          rm -f "$file"
          purged_json="$(json_contract_append_string "$purged_json" "$file")"
          purged_count=$((purged_count + 1))
        fi
      fi
    done <<EOF_INNER
$files
EOF_INNER
  fi

  case "$ACTION" in
    summary)
      if [ "$stale" -gt 0 ]; then
        status="degraded"
        degraded_reasons+=("stale-logs-detected")
        next_steps+=("bash tools/cockpit/log_ops.sh --action purge --retention-days ${RETENTION_DAYS} --apply --json")
        log WARN "$stale stale log(s) older than $RETENTION_DAYS day(s) detected"
      else
        log INFO "No stale logs detected"
      fi
      log INFO "Count=$count Bytes=$bytes"
      ;;
    list)
      log INFO "Listing $count candidate log(s)"
      ;;
    purge)
      if [ "$APPLY" -eq 1 ]; then
        log INFO "Purged ${purged_count} stale log(s)"
      else
        log WARN "Dry-run purge only; re-run with --apply to delete stale logs"
        if [ "$stale" -gt 0 ]; then
          status="degraded"
          degraded_reasons+=("dry-run-purge-pending")
          next_steps+=("bash tools/cockpit/log_ops.sh --action purge --retention-days ${RETENTION_DAYS} --apply --json")
        fi
      fi
      ;;
    *)
      log ERROR "Unsupported action: $ACTION"
      status="blocked"
      degraded_reasons+=("unsupported-action")
      next_steps+=("bash tools/cockpit/log_ops.sh --help")
      ;;
  esac

  contract_status="$(json_contract_map_status "${status}")"

  if [ "$JSON" -eq 1 ]; then
    printf '{\n'
    printf '  "contract_version": "cockpit-v1",\n'
    printf '  "component": "%s",\n' "${COMPONENT}"
    printf '  "contract_status": "%s",\n' "${contract_status}"
    printf '  "generated_at": "%s",\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf '  "log_file": "%s",\n' "${RUN_LOG}"
    printf '  "artifacts": %s,\n' "$(json_contract_array_from_args "${artifacts[@]}")"
    printf '  "degraded_reasons": %s,\n' "$(json_contract_array_from_args "${degraded_reasons[@]}")"
    printf '  "next_steps": %s,\n' "$(json_contract_array_from_args "${next_steps[@]}")"
    printf '  "status": "%s",\n' "$status"
    printf '  "action": "%s",\n' "$ACTION"
    printf '  "retention_days": %s,\n' "$RETENTION_DAYS"
    printf '  "count": %s,\n' "$count"
    printf '  "stale": %s,\n' "$stale"
    printf '  "purged_count": %s,\n' "$purged_count"
    printf '  "bytes": %s,\n' "$bytes"
    printf '  "apply": %s,\n' "$APPLY"
    printf '  "files": [%s],\n' "$listed_json"
    printf '  "purged": [%s]\n' "$purged_json"
    printf '}\n'
  else
    printf 'status=%s action=%s count=%s stale=%s bytes=%s retention_days=%s apply=%s\n' \
      "$status" "$ACTION" "$count" "$stale" "$bytes" "$RETENTION_DAYS" "$APPLY"
  fi

  case "$status" in
    blocked) exit 1 ;;
    *) exit 0 ;;
  esac
}

main "$@"
