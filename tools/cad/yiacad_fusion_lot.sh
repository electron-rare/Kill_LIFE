#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

BASE_DIR="${KILL_LIFE_CAD_AI_BASE_DIR:-${ROOT_DIR}/.runtime-home/cad-ai-native-forks}"
DEFAULT_OWNER="${KILL_LIFE_FORK_OWNER:-electron-rare}"
DEFAULT_BRANCH="${KILL_LIFE_FORK_BRANCH:-kill-life-ai-native}"
LOG_DIR="${ROOT_DIR}/artifacts/cad-fusion"
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
LOT_ID="yiacad-fusion"
OWNER_TEAM="Embedded-CAD"
OWNER_AGENT="Embedded-CAD"
OWNER_SUBAGENT="CAD-Fusion"
LAST_LOG_FILE="${LOG_DIR}/yiacad-fusion-last.log"
LAST_STATUS_FILE="${LOG_DIR}/yiacad-fusion-last-status.md"
ACTION="prepare"
YES=0
DAYS_KEEP=14
OWNER="$DEFAULT_OWNER"
BRANCH="$DEFAULT_BRANCH"
KICAD_MCP_VARIANT="seeed"
KICAD_MCP_LAUNCHER="${ROOT_DIR}/tools/hw/run_kicad_seeed_mcp.sh"
KICAD_MCP_SMOKE="${ROOT_DIR}/tools/hw/kicad_seeed_mcp_smoke.py"

usage() {
  cat <<'EOF_USAGE'
Usage: tools/cad/yiacad_fusion_lot.sh [options]

Lane d'orchestration YiACAD (KiCad + FreeCAD + OpenSCAD IA-native).

Options:
  --action <prepare|smoke|status|logs|clean-logs>
                            Action. Défaut: prepare
  --base-dir DIR           Dossier de base des clones forks (défaut: .runtime-home/cad-ai-native-forks)
  --owner OWNER            Propriétaire du fork GitHub (défaut: electron-rare)
  --branch BRANCH          Branche IA-native (défaut: kill-life-ai-native)
  --days N                 Rétention des logs pour clean-logs (défaut: 14)
  --yes                    Confirmer suppression (clean-logs)
  -h, --help               Aide

Examples:
  bash tools/cad/yiacad_fusion_lot.sh --action prepare
  bash tools/cad/yiacad_fusion_lot.sh --action smoke
  bash tools/cad/yiacad_fusion_lot.sh --action status
  bash tools/cad/yiacad_fusion_lot.sh --action logs
  bash tools/cad/yiacad_fusion_lot.sh --action clean-logs --days 7 --yes
EOF_USAGE
}

ensure_dirs() {
  mkdir -p "$LOG_DIR"
}

log_file() {
  printf '%s\n' "${LOG_DIR}/yiacad-fusion_${TIMESTAMP}.log"
}

status_file() {
  printf '%s\n' "${LOG_DIR}/yiacad-fusion-status_${TIMESTAMP}.md"
}

run_and_log() {
  local label="$1"
  shift
  local lf
  local rc=0
  lf="$(log_file)"
  printf '[%s] START %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')" "$label" >>"$lf"
  if "$@" >>"$lf" 2>&1; then
    printf '[%s] OK %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')" "$label" >>"$lf"
    return 0
  else
    rc="$?"
  fi

  printf '[%s] FAIL %s (code=%s)\n' "$(date '+%Y-%m-%d %H:%M:%S %z')" "$label" "$rc" >>"$lf"
  return "$rc"
}

write_repo_snapshot() {
  local repo_name="$1"
  local sf="$2"
  local repo_dir="$BASE_DIR/${repo_name}-ki"

  {
    printf '### %s\n' "$repo_name"
    if [[ -d "$repo_dir/.git" ]]; then
      local remote default_branch local_branch head
      remote="$(cd "$repo_dir" && git remote -v | awk '$1 == "origin" { print $2; exit }')"
      default_branch="$(cd "$repo_dir" && git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's#refs/remotes/origin/##')"
      local_branch="$(cd "$repo_dir" && git rev-parse --abbrev-ref HEAD)"
      head="$(cd "$repo_dir" && git rev-parse --short HEAD)"
      printf -- '- status: ok\n'
      printf -- '- local_branch: %s\n' "$local_branch"
      printf -- '- head: %s\n' "$head"
      printf -- '- remote_head: %s\n' "${default_branch:-unknown}"
      printf -- '- origin: %s\n' "${remote:-unknown}"
      printf -- '- remotes:\n'
      while IFS= read -r line; do
        printf -- '  - %s\n' "$line"
      done < <(cd "$repo_dir" && git remote -v | awk '{print $1 " -> " $2}' | sort -u)
      return
    fi

    printf -- '- status: missing\n'
  } >>"$sf"
}

write_status_snapshot() {
  local sf
  local manifest_path="${BASE_DIR}/manifest.md"

  sf="$(status_file)"
  {
    printf '# YiACAD status\n\n'
    printf -- '- lot_id: %s\n' "$LOT_ID"
    printf -- '- owner_team: %s\n' "$OWNER_TEAM"
    printf -- '- owner_agent: %s\n' "$OWNER_AGENT"
    printf -- '- owner_subagent: %s\n' "$OWNER_SUBAGENT"
    printf -- '- root: %s\n' "$ROOT_DIR"
    printf -- '- base_dir: %s\n' "$BASE_DIR"
    printf -- '- owner: %s\n' "$OWNER"
    printf -- '- branch: %s\n' "$BRANCH"
    printf -- '- kicad_mcp_variant: %s\n' "$KICAD_MCP_VARIANT"
    printf -- '- kicad_mcp_launcher: %s\n' "$KICAD_MCP_LAUNCHER"
    printf -- '- kicad_mcp_smoke: %s\n' "$KICAD_MCP_SMOKE"
    printf -- '- manifest: %s\n' "$manifest_path"
    if [[ -f "$manifest_path" ]]; then
      printf -- '- manifest_state: present\n'
    else
      printf -- '- manifest_state: missing\n'
    fi
    printf -- '- log_dir: %s\n' "$LOG_DIR"
    printf -- '- generated_at: %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf '\n'
  } >"$sf"
  write_repo_snapshot kicad "$sf"
  write_repo_snapshot freecad "$sf"
  cp "$sf" "$LAST_STATUS_FILE"
}

run_prepare() {
  ensure_dirs
  local args=(
    bash "$ROOT_DIR/tools/cad/ai_native_forks.sh"
    --owner "$OWNER"
    --branch "$BRANCH"
    --base-dir "$BASE_DIR"
    --projects "kicad freecad"
  )
  run_and_log "YiACAD prepare forks" "${args[@]}"
  write_status_snapshot
  cp "$(log_file)" "$LAST_LOG_FILE"
  cat "$LAST_STATUS_FILE"
}

run_smoke() {
  ensure_dirs
  local -a smoke_failures=()

  run_and_log "CAD stack doctor" bash "$ROOT_DIR/tools/hw/cad_stack.sh" doctor-mcp || smoke_failures+=("CAD stack doctor")
  run_and_log "KiCad MCP Seeed doctor" bash "$KICAD_MCP_LAUNCHER" --doctor || smoke_failures+=("KiCad MCP Seeed doctor")
  run_and_log "KiCad MCP Seeed smoke" python3 "$KICAD_MCP_SMOKE" --json --quick || smoke_failures+=("KiCad MCP Seeed smoke")
  run_and_log "FreeCAD MCP smoke" python3 "$ROOT_DIR/tools/freecad_mcp_smoke.py" --json --quick || smoke_failures+=("FreeCAD MCP smoke")
  run_and_log "OpenSCAD MCP smoke" python3 "$ROOT_DIR/tools/openscad_mcp_smoke.py" --json --quick || smoke_failures+=("OpenSCAD MCP smoke")
  run_and_log "FreeCAD MCP doctor" bash "$ROOT_DIR/tools/run_freecad_mcp.sh" --doctor || smoke_failures+=("FreeCAD MCP doctor")
  run_and_log "OpenSCAD MCP doctor" bash "$ROOT_DIR/tools/run_openscad_mcp.sh" --doctor || smoke_failures+=("OpenSCAD MCP doctor")
  write_status_snapshot
  cp "$(log_file)" "$LAST_LOG_FILE"
  if [[ "${#smoke_failures[@]}" -gt 0 ]]; then
    {
      printf '\n## smoke_failures\n'
      for failure in "${smoke_failures[@]}"; do
        printf -- '- %s\n' "$failure"
      done
    } >>"$LAST_STATUS_FILE"
    cat "$LAST_STATUS_FILE"
    return 1
  fi
  cat "$LAST_STATUS_FILE"
}

show_status() {
  ensure_dirs
  write_status_snapshot
  cat "$LAST_STATUS_FILE"
  echo
  if [[ -f "$LAST_LOG_FILE" ]]; then
    echo "Last log: $LAST_LOG_FILE"
  else
    echo "No run log yet."
  fi
}

list_logs() {
  echo "=== YiACAD logs (artifacts/cad-fusion) ==="
  local files
  files="$(
    find "$LOG_DIR" -maxdepth 1 -type f \
      \( -name 'yiacad-fusion_*.log' -o -name 'yiacad-fusion-status_*.md' -o -name 'yiacad-fusion-last.log' -o -name 'yiacad-fusion-last-status.md' \) \
      | sort | tail -n 40
  )"
  if [[ -z "$files" ]]; then
    echo "Aucun log YiACAD trouvé dans $LOG_DIR"
    return 0
  fi
  printf '%s\n' "$files"
}

clean_logs() {
  local days="${1:-$DAYS_KEEP}"
  if [[ "$days" -lt 1 ]]; then
    echo "--days doit être >= 1"
    return 1
  fi

  local stale_count
  stale_count="$(find "$LOG_DIR" -maxdepth 1 -type f \( -name 'yiacad-fusion_*.log' -o -name 'yiacad-fusion-status_*.md' \) -mtime +"$days" | wc -l | tr -d ' ')"
  if [[ "$stale_count" == "0" ]]; then
    echo "No log candidate older than ${days} day(s)."
    return 0
  fi

  if [[ "$YES" -ne 1 ]]; then
    echo "${stale_count} log files older than ${days} day(s) would be deleted. Re-run with --yes."
    return 0
  fi

  find "$LOG_DIR" -maxdepth 1 -type f \( -name 'yiacad-fusion_*.log' -o -name 'yiacad-fusion-status_*.md' \) -mtime +"$days" -delete
  echo "Deleted ${stale_count} logs older than ${days} day(s)."
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --action)
      ACTION="${2:-}"
      shift 2
      ;;
    --base-dir)
      BASE_DIR="${2:-}"
      shift 2
      ;;
    --owner)
      OWNER="${2:-}"
      shift 2
      ;;
    --branch)
      BRANCH="${2:-}"
      shift 2
      ;;
    --days)
      DAYS_KEEP="${2:-14}"
      shift 2
      ;;
    --yes)
      YES=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Option inconnue: $1" >&2
      usage
      exit 2
      ;;
  esac
done

ensure_dirs
case "$ACTION" in
  prepare)
    run_prepare
    ;;
  smoke)
    run_smoke
    ;;
  status)
    show_status
    ;;
  logs)
    list_logs
    ;;
  clean-logs)
    clean_logs "$DAYS_KEEP"
    ;;
  *)
    echo "Action inconnue: $ACTION" >&2
    usage
    exit 1
    ;;
esac
