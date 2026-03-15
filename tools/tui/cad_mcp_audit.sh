#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OPS_DIR="$ROOT_DIR/.ops/cad-mcp-audit"
REPORT_FILE="$OPS_DIR/report.md"
RAW_HITS_FILE="$OPS_DIR/cad_execution_hits.log"
IGNORED_HITS_FILE="$OPS_DIR/ignored_hits.log"
ACTIONABLE_HITS_FILE="$OPS_DIR/actionable_hits.log"
DOC_ANCHORS_FILE="$OPS_DIR/doc_anchors.log"

VERBOSE=0
YES=0
STRICT=0
COMMAND="audit"

usage() {
  cat <<'EOF'
Usage: cad_mcp_audit.sh [run|audit|purge] [--yes] [--verbose] [--strict]

Subcommands:
  run     Alias for audit
  audit   Generate report under .ops/cad-mcp-audit
  purge   Remove .ops/cad-mcp-audit

Options:
  --yes      Skip confirmation for purge
  --verbose  Echo debug output and matched lines
  --strict   Exit non-zero when actionable hits remain
  --help     Show this help
EOF
}

log() {
  printf '%s\n' "$*"
}

debug() {
  if [ "$VERBOSE" -eq 1 ]; then
    printf '[debug] %s\n' "$*"
  fi
}

confirm() {
  local prompt="$1"
  if [ "$YES" -eq 1 ] || [ ! -t 0 ]; then
    return 0
  fi
  printf '%s [y/N] ' "$prompt" >&2
  read -r reply
  case "$reply" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    run|audit|purge)
      COMMAND="$1"
      ;;
    --yes)
      YES=1
      ;;
    --verbose)
      VERBOSE=1
      ;;
    --strict)
      STRICT=1
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

purge_ops() {
  if [ ! -d "$OPS_DIR" ]; then
    log "Kill_LIFE CAD/MCP audit: nothing to purge"
    return 0
  fi
  if ! confirm "Purger $OPS_DIR ?"; then
    log "Kill_LIFE CAD/MCP audit: purge cancelled"
    return 1
  fi
  rm -rf "$OPS_DIR"
  log "Kill_LIFE CAD/MCP audit: purged $OPS_DIR"
}

collect_matches() {
  : > "$RAW_HITS_FILE"
  : > "$IGNORED_HITS_FILE"
  : > "$ACTIONABLE_HITS_FILE"
  : > "$DOC_ANCHORS_FILE"

  local -a target_files=(
    "$ROOT_DIR/tools/freecad_mcp.py"
    "$ROOT_DIR/tools/cad_runtime.py"
    "$ROOT_DIR/tools/mcp_runtime_status.py"
  )
  local -a patterns=(
    'exec\(compile\('
    'eval\('
    'shell=True'
    'subprocess\.Popen\('
    'asyncio\.create_subprocess_exec\('
    'os\.system\('
  )
  local -a doc_files=(
    "$ROOT_DIR/README.md"
    "$ROOT_DIR/deploy/cad/README.md"
    "$ROOT_DIR/docs/MCP_SETUP.md"
    "$ROOT_DIR/docs/MCP_SUPPORT_MATRIX.md"
    "$ROOT_DIR/docs/RUNBOOK.md"
  )

  local pattern
  for pattern in "${patterns[@]}"; do
    rg -n "$pattern" "${target_files[@]}" >> "$RAW_HITS_FILE" || true
  done

  sort -u "$RAW_HITS_FILE" -o "$RAW_HITS_FILE"

  while IFS= read -r hit; do
    case "$hit" in
      *"tools/freecad_mcp.py:"*"exec(compile("*)
        printf '%s\n' "$hit" >> "$IGNORED_HITS_FILE"
        ;;
      *"tools/cad_runtime.py:"*"exec(compile("*)
        printf '%s\n' "$hit" >> "$IGNORED_HITS_FILE"
        ;;
      *"tools/cad_runtime.py:"*"subprocess.Popen("*)
        printf '%s\n' "$hit" >> "$IGNORED_HITS_FILE"
        ;;
      *"tools/mcp_runtime_status.py:"*"asyncio.create_subprocess_exec("*)
        printf '%s\n' "$hit" >> "$IGNORED_HITS_FILE"
        ;;
      *)
        printf '%s\n' "$hit" >> "$ACTIONABLE_HITS_FILE"
        ;;
    esac
  done < "$RAW_HITS_FILE"

  local doc
  for doc in "${doc_files[@]}"; do
    [ -f "$doc" ] || continue
    rg -n 'freecad|openscad|mcp|validate_specs|validate-specs' "$doc" >> "$DOC_ANCHORS_FILE" || true
  done

  sort -u "$IGNORED_HITS_FILE" -o "$IGNORED_HITS_FILE"
  sort -u "$ACTIONABLE_HITS_FILE" -o "$ACTIONABLE_HITS_FILE"
  sort -u "$DOC_ANCHORS_FILE" -o "$DOC_ANCHORS_FILE"
}

write_report() {
  local raw_hits ignored_hits actionable_hits actionable_files doc_anchor_hits
  raw_hits="$(wc -l < "$RAW_HITS_FILE" | tr -d ' ')"
  ignored_hits="$(wc -l < "$IGNORED_HITS_FILE" | tr -d ' ')"
  actionable_hits="$(wc -l < "$ACTIONABLE_HITS_FILE" | tr -d ' ')"
  actionable_files="$(
    if [ -s "$ACTIONABLE_HITS_FILE" ]; then
      cut -d: -f1 "$ACTIONABLE_HITS_FILE" | sort -u | wc -l | tr -d ' '
    else
      printf '0'
    fi
  )"
  doc_anchor_hits="$(wc -l < "$DOC_ANCHORS_FILE" | tr -d ' ')"

  {
    printf '# Kill_LIFE CAD / MCP Audit\n\n'
    printf -- '- date_utc: %s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    printf -- '- target_dir: %s\n' "$ROOT_DIR"
    printf -- '- raw_hits: %s\n' "$raw_hits"
    printf -- '- ignored_hits: %s\n' "$ignored_hits"
    printf -- '- actionable_hits: %s\n' "$actionable_hits"
    printf -- '- actionable_files: %s\n' "$actionable_files"
    printf -- '- doc_anchor_hits: %s\n' "$doc_anchor_hits"
    printf -- '- strict_mode: %s\n\n' "$STRICT"
    printf '## Compatibility Allowlist\n\n'
    printf -- '- tools/freecad_mcp.py exec(compile(...)) is the constrained user-script sandbox entrypoint\n'
    printf -- '- tools/cad_runtime.py exec(compile(...)) belongs to the internal FreeCAD pool daemon\n'
    printf -- '- tools/cad_runtime.py subprocess.Popen(...) is the controlled background CAD runtime wrapper\n'
    printf -- '- tools/mcp_runtime_status.py asyncio.create_subprocess_exec(...) is the bounded local smoke orchestration layer\n\n'
    printf '## Hotspots (top 20 files)\n\n'
    printf '## Ignored Matches\n'
    if [ -s "$IGNORED_HITS_FILE" ]; then
      sed 's/^/- /' "$IGNORED_HITS_FILE"
    fi
    printf '\n## Actionable Matches\n'
    if [ -s "$ACTIONABLE_HITS_FILE" ]; then
      sed 's/^/- /' "$ACTIONABLE_HITS_FILE"
    fi
    printf '\n## Documentation Anchors\n'
    if [ -s "$DOC_ANCHORS_FILE" ]; then
      sed 's/^/- /' "$DOC_ANCHORS_FILE"
    fi
  } > "$REPORT_FILE"
}

run_audit() {
  mkdir -p "$OPS_DIR"
  log "Kill_LIFE CAD/MCP audit started ($(date -u +"%Y-%m-%dT%H:%M:%SZ"))"
  debug "target_dir=$ROOT_DIR"
  debug "ops_dir=$OPS_DIR"
  debug "strict_mode=$STRICT"
  collect_matches
  write_report
  log "Audit complete"
  log "report: $REPORT_FILE"
  log "raw:    $RAW_HITS_FILE"
  if [ "$VERBOSE" -eq 1 ]; then
    if [ -s "$ACTIONABLE_HITS_FILE" ]; then
      cat "$ACTIONABLE_HITS_FILE"
    fi
  fi
  if [ "$STRICT" -eq 1 ] && [ -s "$ACTIONABLE_HITS_FILE" ]; then
    exit 1
  fi
}

case "$COMMAND" in
  run|audit)
    run_audit
    ;;
  purge)
    purge_ops
    ;;
esac
