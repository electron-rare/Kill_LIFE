#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OPS_DIR="$ROOT_DIR/.ops/kicad-benchmark"
REPORT_FILE="$OPS_DIR/report.md"
DOCTOR_LOG="$OPS_DIR/doctor.log"
MATRIX_LOG="$OPS_DIR/matrix.log"

VERBOSE=0
YES=0
COMMAND=""

usage() {
  cat <<'EOF'
Usage: kicad_benchmark_review.sh [run|report|doctor|matrix|menu|purge] [--yes] [--verbose]

Subcommands:
  run      Alias for report
  report   Generate .ops/kicad-benchmark/report.md and raw logs
  doctor   Capture a local environment snapshot into doctor.log and print it
  matrix   Capture the comparison matrix into matrix.log and print it
  menu     Interactive selector for doctor, matrix, report, or purge
  purge    Remove raw .log files under .ops/kicad-benchmark and keep report.md

Options:
  --yes      Skip confirmation for purge
  --verbose  Echo debug output
  --help     Show this help

Notes:
  - No external dependencies are installed by default.
  - Keep `bash tools/tui/cad_mcp_audit.sh audit` as the CAD/MCP guardrail.
  - The canonical doc lives in docs/KICAD_BENCHMARK_MATRIX.md.
EOF
}

log() {
  printf '%s\n' "$*"
}

debug() {
  if [ "$VERBOSE" -eq 1 ]; then
    printf '[debug] %s\n' "$*" >&2
  fi
}

die() {
  printf '[error] %s\n' "$1" >&2
  exit "${2:-1}"
}

has_tty() {
  [ -t 0 ] && [ -t 1 ]
}

confirm() {
  local prompt="$1"
  if [ "$YES" -eq 1 ]; then
    return 0
  fi
  if ! has_tty; then
    return 0
  fi
  printf '%s [y/N] ' "$prompt" >&2
  read -r reply
  case "$reply" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

ensure_ops_dir() {
  mkdir -p "$OPS_DIR"
}

render_matrix() {
  cat <<'EOF'
| Surface / chaine | Provenance | Dependance externe par defaut | ERC / DRC | Export / doc | Fit `Kill_LIFE` | Decision | Position operatoire |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `kicad-cli` + `kicad-mcp` | officiel + custom local | aucune nouvelle dependance | fort | fort | maximal | keep | chaine canonique; deja supportee par `tools/hw/cad_stack.sh` et `tools/hw/run_kicad_mcp.sh` |
| `KiAuto` | community valide | oui, explicite et optionnelle | fort | moyen a fort | moyen | adopt | appoint cible si un lot KiCad reclame des exports ou checks au-dela de la chaine canonique |
| `kicad-automation-scripts` | community valide | oui, explicite et optionnelle | moyen | moyen | faible | ignore | reference historique de patterns Docker/doc, pas une dependance runtime a introduire dans ce repo |
EOF
}

write_doctor_log() {
  ensure_ops_dir
  {
    printf 'date_utc=%s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    printf 'root_dir=%s\n' "$ROOT_DIR"
    printf 'guardrail_cmd=%s\n' 'bash tools/tui/cad_mcp_audit.sh audit'
    printf 'default_dependency_policy=%s\n' 'no external benchmark dependency is installed by default'

    local path=""
    for path in \
      "tools/tui/cad_mcp_audit.sh" \
      "tools/tui/kicad_benchmark_review.sh" \
      "tools/hw/cad_stack.sh" \
      "tools/hw/run_kicad_mcp.sh" \
      "docs/KICAD_BENCHMARK_MATRIX.md" \
      "docs/MCP_CAD_PROVENANCE_2026-03-14.md"
    do
      if [ -e "$ROOT_DIR/$path" ]; then
        printf 'path[%s]=present\n' "$path"
      else
        printf 'path[%s]=missing\n' "$path"
      fi
    done

    local cmd=""
    for cmd in bash python3 docker kicad-cli; do
      if command -v "$cmd" >/dev/null 2>&1; then
        printf 'cmd[%s]=%s\n' "$cmd" "$(command -v "$cmd")"
      else
        printf 'cmd[%s]=missing\n' "$cmd"
      fi
    done

    printf 'operator_note=%s\n' 'K-025 stays doc-first; KiAuto and kicad-automation-scripts remain optional references until an explicit future lot installs or vendors them.'
  } > "$DOCTOR_LOG"
}

doctor_cmd() {
  debug "writing $DOCTOR_LOG"
  write_doctor_log
  cat "$DOCTOR_LOG"
}

matrix_cmd() {
  ensure_ops_dir
  debug "writing $MATRIX_LOG"
  render_matrix > "$MATRIX_LOG"
  cat "$MATRIX_LOG"
}

write_report() {
  ensure_ops_dir
  write_doctor_log
  render_matrix > "$MATRIX_LOG"

  {
    printf '# Kill_LIFE KiCad benchmark report\n\n'
    printf -- '- date_utc: %s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    printf -- '- generated_by: %s\n' 'bash tools/tui/kicad_benchmark_review.sh report'
    printf -- '- guardrail: %s\n' '`bash tools/tui/cad_mcp_audit.sh audit` remains mandatory before promoting CAD/MCP runtime changes'
    printf -- '- canonical_doc: %s\n\n' '`docs/KICAD_BENCHMARK_MATRIX.md`'

    printf '## Scope\n\n'
    printf -- '- benchmark the backlog references `KiAuto` and `kicad-automation-scripts`\n'
    printf -- '- keep the canonical chain `kicad-cli` + `kicad-mcp`\n'
    printf -- '- avoid installing external dependencies by default\n\n'

    printf '## Environment snapshot\n\n'
    sed 's/^/- /' "$DOCTOR_LOG"
    printf '\n## Comparison matrix\n\n'
    cat "$MATRIX_LOG"
    printf '\n## Durable decision\n\n'
    printf -- '- `kicad-cli` + `kicad-mcp`: `keep`\n'
    printf -- '- `KiAuto`: `adopt` only as an explicit, opt-in adjunct when a future lot needs extra ERC/DRC/export coverage not already served by the canonical chain\n'
    printf -- '- `kicad-automation-scripts`: `ignore` as a runtime dependency; keep it as historical inspiration for documentation or Docker loop design only\n\n'
    printf '## Operator workflow\n\n'
    printf '```bash\n'
    printf 'bash tools/tui/cad_mcp_audit.sh audit\n'
    printf 'bash tools/tui/kicad_benchmark_review.sh report\n'
    printf 'bash tools/tui/kicad_benchmark_review.sh purge --yes\n'
    printf '```\n'
  } > "$REPORT_FILE"
}

report_cmd() {
  debug "writing $REPORT_FILE"
  write_report
  log "Kill_LIFE KiCad benchmark report ready"
  log "report: $REPORT_FILE"
  log "raw:    $DOCTOR_LOG"
  log "raw:    $MATRIX_LOG"
}

choose_from_menu() {
  if command -v gum >/dev/null 2>&1; then
    gum choose report doctor matrix purge quit
    return
  fi

  local choice=""
  PS3="Select action: "
  select choice in report doctor matrix purge quit; do
    if [ -n "$choice" ]; then
      printf '%s\n' "$choice"
      return 0
    fi
  done
}

menu_cmd() {
  if ! has_tty; then
    die "menu requires a TTY; use report, doctor, matrix, or purge explicitly" 2
  fi
  local choice=""
  choice="$(choose_from_menu)"
  case "$choice" in
    report) report_cmd ;;
    doctor) doctor_cmd ;;
    matrix) matrix_cmd ;;
    purge) purge_cmd ;;
    quit) log "Kill_LIFE KiCad benchmark: nothing executed" ;;
    *) die "unknown menu action: $choice" 2 ;;
  esac
}

purge_cmd() {
  if [ ! -d "$OPS_DIR" ]; then
    log "Kill_LIFE KiCad benchmark: nothing to purge"
    return 0
  fi
  if ! compgen -G "$OPS_DIR/*.log" >/dev/null 2>&1; then
    log "Kill_LIFE KiCad benchmark: no raw logs to purge"
    return 0
  fi
  if ! confirm "Purger les logs bruts sous $OPS_DIR ?"; then
    log "Kill_LIFE KiCad benchmark: purge cancelled"
    return 1
  fi
  rm -f "$OPS_DIR"/*.log
  log "Kill_LIFE KiCad benchmark: purged raw logs under $OPS_DIR"
  if [ -f "$REPORT_FILE" ]; then
    log "report kept: $REPORT_FILE"
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    run|report|doctor|matrix|menu|purge)
      if [ -n "$COMMAND" ]; then
        die "only one subcommand is allowed" 2
      fi
      COMMAND="$1"
      ;;
    --yes)
      YES=1
      ;;
    --verbose)
      VERBOSE=1
      ;;
    --help|-h)
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

if [ -z "$COMMAND" ]; then
  if has_tty; then
    COMMAND="menu"
  else
    COMMAND="report"
  fi
fi

case "$COMMAND" in
  run|report)
    report_cmd
    ;;
  doctor)
    doctor_cmd
    ;;
  matrix)
    matrix_cmd
    ;;
  menu)
    menu_cmd
    ;;
  purge)
    purge_cmd
    ;;
esac
