#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

OUTPUT_FILE="${ROOT_DIR}/artifacts/cockpit/weekly_refonte_summary.md"
WINDOW_DAYS=7
TASKS_FILE="${ROOT_DIR}/specs/04_tasks.md"
MACHINE_SYNC_FILE="${ROOT_DIR}/docs/MACHINE_SYNC_STATUS_2026-03-20.md"
REFONTE_LOG_DIR="${ROOT_DIR}/artifacts/refonte_tui"
CAD_LOG_DIR="${ROOT_DIR}/artifacts/cad-fusion"
COCKPIT_DIR="${ROOT_DIR}/artifacts/cockpit"

usage() {
  cat <<'EOF_USAGE'
Usage: bash tools/cockpit/render_weekly_refonte_summary.sh [options]

Génère une synthèse hebdomadaire exploitable pour l’opérateur et les agents.

Options:
  --output FILE    Fichier markdown cible. Défaut: artifacts/cockpit/weekly_refonte_summary.md
  --days N         Fenêtre d’analyse de logs. Défaut: 7
  -h, --help       Aide
EOF_USAGE
}

ensure_dirs() {
  mkdir -p "$(dirname "$OUTPUT_FILE")"
}

collect_files_by_mtime_desc() {
  local dir="$1"
  local pattern="$2"
  local path
  local epoch

  [[ -d "$dir" ]] || return 0
  while IFS= read -r -d '' path; do
    if epoch="$(stat -c '%Y' "$path" 2>/dev/null)"; then
      :
    elif epoch="$(stat -f '%m' "$path" 2>/dev/null)"; then
      :
    else
      epoch="0"
    fi
    printf '%s %s\n' "$epoch" "$path"
  done < <(find "$dir" -maxdepth 1 -type f -name "$pattern" -print0)
}

latest_file() {
  local dir="$1"
  local pattern="$2"

  collect_files_by_mtime_desc "$dir" "$pattern" | sort -nr | head -n 1 | cut -d' ' -f2-
}

recent_count() {
  local dir="$1"
  local pattern="$2"

  if [[ ! -d "$dir" ]]; then
    printf '0'
    return 0
  fi
  find "$dir" -maxdepth 1 -type f -name "$pattern" -mtime "-${WINDOW_DAYS}" | wc -l | tr -d ' '
}

render_open_tasks() {
  if [[ ! -f "$TASKS_FILE" ]]; then
    printf -- '- tasks file missing: %s\n' "$TASKS_FILE"
    return 0
  fi

  if ! rg -n "^[[:space:]]*-[[:space:]]*\\[[[:space:]]\\]" "$TASKS_FILE" | head -n 10 | while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    printf -- '- %s\n' "$line"
  done; then
    printf -- '- no open task found in %s\n' "$TASKS_FILE"
  fi
}

render_machine_sync() {
  if [[ ! -f "$MACHINE_SYNC_FILE" ]]; then
    printf -- '- machine sync file missing: %s\n' "$MACHINE_SYNC_FILE"
    return 0
  fi

  if ! rg -n "ready|degraded|blocked|Priorit|incident|sync|delta|status" "$MACHINE_SYNC_FILE" | head -n 8 | while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    printf -- '- %s\n' "$line"
  done; then
    printf -- '- no machine-sync highlight extracted\n'
  fi
}

render_registry_severity() {
  local file="$1"

  if [[ -z "$file" || ! -f "$file" ]]; then
    printf -- '- severity snapshot unavailable\n'
    return 0
  fi

  python3 - "$file" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
try:
    data = json.loads(path.read_text(encoding="utf-8"))
except Exception:
    print("- severity snapshot unavailable")
    raise SystemExit(0)

severity = data.get("severity_counts", {}) if isinstance(data.get("severity_counts"), dict) else {}
priority = data.get("priority_counts", {}) if isinstance(data.get("priority_counts"), dict) else {}
print(f"- severity high/medium/low: {severity.get('high', 0)}/{severity.get('medium', 0)}/{severity.get('low', 0)}")
print(f"- priority P1/P2/P3: {priority.get('P1', 0)}/{priority.get('P2', 0)}/{priority.get('P3', 0)}")
PY
}

render_log_tail() {
  local file="$1"
  if [[ -z "$file" || ! -f "$file" ]]; then
    printf 'No log available.\n'
    return 0
  fi
  tail -n 12 "$file"
}

render_kill_life_meta() {
  local file="$1"

  if [[ -z "$file" || ! -f "$file" ]]; then
    printf -- '- trust_level: missing\n- resume_ref: missing\n- owner: unknown\n- selected_target: unknown\n- memory_entry: missing\n'
    return 0
  fi

  python3 - "$file" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
try:
    data = json.loads(path.read_text(encoding="utf-8"))
  except Exception:
    print("- trust_level: invalid")
    print("- resume_ref: invalid")
    print("- owner: unknown")
    print("- selected_target: unknown")
    print("- memory_entry: invalid")
    raise SystemExit(0)

entry = data.get("entry", {}) if isinstance(data.get("entry"), dict) else {}
routing = entry.get("routing", {}) if isinstance(entry.get("routing"), dict) else {}
memory_entry = entry.get("memory_entry", {}) if isinstance(entry.get("memory_entry"), dict) else {}
handoff = memory_entry.get("handoff") if isinstance(memory_entry, dict) else None
print(f"- trust_level: {data.get('trust_level') or entry.get('trust_level', 'inferred')}")
print(f"- resume_ref: {data.get('resume_ref') or entry.get('resume_ref', 'missing')}")
print(f"- owner: {entry.get('owner', 'unknown')}")
print(f"- selected_target: {routing.get('selected_target', 'unknown')}")
print(f"- memory_entry: {handoff or memory_entry or 'missing'}")
PY
}

cad_lane_status() {
  local file="$1"

  if [[ -z "$file" || ! -f "$file" ]]; then
    printf 'unknown'
    return 0
  fi

  if rg -q "FAIL KiCad MCP Seeed doctor" "$file"; then
    printf 'blocked:kicad-seeed-doctor'
    return 0
  fi

  if rg -q "FAIL KiCad MCP Seeed smoke" "$file"; then
    printf 'blocked:kicad-seeed-smoke'
    return 0
  fi

  if rg -q "host entrypoint missing|FAIL KiCad MCP host smoke" "$file"; then
    printf 'blocked:kicad-mcp-legacy'
    return 0
  fi

  if rg -q "FAIL " "$file"; then
    printf 'degraded'
    return 0
  fi

  printf 'ready'
}

route_next_blocking_lot() {
  local cad_status="$1"

  case "$cad_status" in
    blocked:*|degraded)
      printf 'yiacad-fusion'
      ;;
    *)
      printf 'mesh-governance'
      ;;
  esac
}

render_routing() {
  local cad_status="$1"

  case "$cad_status" in
    blocked:kicad-seeed-doctor)
      cat <<'EOF_ROUTING'
- Exec lot prioritaire: `yiacad-fusion` tant que le launcher `KiCad MCP Seeed doctor` ne sort pas proprement.
- Lane parallèle: `mesh-governance` reste en maintien documentaire/TUI sans propagation risquée.
- Revue attendue: valider `uvx`, le wrapper `tools/hw/run_kicad_seeed_mcp.sh` et le runtime home généré sous `.cad-home/kicad-seeed-mcp`.
EOF_ROUTING
      ;;
    blocked:kicad-seeed-smoke)
      cat <<'EOF_ROUTING'
- Exec lot prioritaire: `yiacad-fusion` tant que `KiCad MCP Seeed smoke` ne passe pas `initialize` + `tools/list`.
- Lane parallèle: `mesh-governance` reste en maintien documentaire/TUI sans propagation risquée.
- Revue attendue: inspecter le bridge `tools/hw/kicad_seeed_mcp_bridge.py`, puis rejouer `yiacad-fusion --action smoke`.
EOF_ROUTING
      ;;
    blocked:kicad-mcp-legacy)
      cat <<'EOF_ROUTING'
- Exec lot prioritaire: `yiacad-fusion` pour régénérer une preuve CAD sur le launcher KiCad MCP courant.
- Lane parallèle: `mesh-governance` reste en maintien documentaire/TUI sans propagation risquée.
- Revue attendue: rejouer `bash tools/cad/yiacad_fusion_lot.sh --action smoke` afin de sortir d’un ancien état `kicad-host`.
EOF_ROUTING
      ;;
    degraded)
      cat <<'EOF_ROUTING'
- Exec lot prioritaire: `yiacad-fusion` pour fermer les checks CAD encore dégradés.
- Lane parallèle: `mesh-governance` en maintien et synthèse.
- Revue attendue: relire le dernier log CAD et purger les artefacts périmés si besoin.
EOF_ROUTING
      ;;
    ready)
      cat <<'EOF_ROUTING'
- Exec lot prioritaire: `mesh-governance` une fois la lane CAD stable.
- Lane parallèle: `yiacad-uiux-apple-native` pour la montée P1 palette/review center.
- Revue attendue: publier la preuve opératoire YiACAD dans les trackers hebdomadaires.
EOF_ROUTING
      ;;
    *)
      cat <<'EOF_ROUTING'
- Exec lot prioritaire: `mesh-governance`.
- Lane parallèle: `yiacad-fusion`.
- Revue attendue: compléter les preuves avant propagation.
EOF_ROUTING
      ;;
  esac
}

write_summary() {
  local latest_refonte_log
  local latest_cad_log
  local latest_mascarade_brief
  local latest_mascarade_registry
  local latest_mascarade_registry_json
  local latest_mascarade_queue
  local latest_mascarade_watch
  local latest_mascarade_watch_history
  local latest_kill_life_memory_json
  local latest_kill_life_memory_md
  local cad_status
  local next_blocking_lot

  bash "${ROOT_DIR}/tools/cockpit/render_mascarade_incident_brief.sh" >/dev/null 2>&1 || true
  bash "${ROOT_DIR}/tools/cockpit/mascarade_incident_registry.sh" >/dev/null 2>&1 || true
  bash "${ROOT_DIR}/tools/cockpit/render_mascarade_incident_queue.sh" >/dev/null 2>&1 || true
  bash "${ROOT_DIR}/tools/cockpit/render_mascarade_incident_watch.sh" >/dev/null 2>&1 || true
  bash "${ROOT_DIR}/tools/cockpit/render_mascarade_watch_history.sh" >/dev/null 2>&1 || true

  latest_refonte_log="$(latest_file "$REFONTE_LOG_DIR" "*.log")"
  latest_cad_log="$(latest_file "$CAD_LOG_DIR" "*.log")"
  latest_mascarade_brief="$(latest_file "$COCKPIT_DIR" "mascarade_incident_brief_*.md")"
  latest_mascarade_registry="$(latest_file "$COCKPIT_DIR" "mascarade_incident_registry_*.md")"
  latest_mascarade_registry_json="$(latest_file "$COCKPIT_DIR" "mascarade_incident_registry_*.json")"
  latest_mascarade_queue="$(latest_file "$COCKPIT_DIR" "mascarade_incident_queue_*.md")"
  latest_mascarade_watch="$(latest_file "$COCKPIT_DIR" "mascarade_incident_watch_*.md")"
  latest_mascarade_watch_history="$(latest_file "$COCKPIT_DIR" "mascarade_watch_history_*.md")"
  latest_kill_life_memory_json="${COCKPIT_DIR}/kill_life_memory/latest.json"
  latest_kill_life_memory_md="${COCKPIT_DIR}/kill_life_memory/latest.md"
  cad_status="$(cad_lane_status "$latest_cad_log")"
  next_blocking_lot="$(route_next_blocking_lot "$cad_status")"

  cat >"$OUTPUT_FILE" <<EOF
# Weekly Refonte Summary

- generated_at: $(date '+%Y-%m-%d %H:%M:%S %z')
- window_days: ${WINDOW_DAYS}
- next_blocking_lot: ${next_blocking_lot}
- parallel_design_lane: yiacad-uiux-apple-native
- refonte_logs_recent: $(recent_count "$REFONTE_LOG_DIR" "*.log")
- cad_logs_recent: $(recent_count "$CAD_LOG_DIR" "*.log")
- latest_refonte_log: ${latest_refonte_log:-none}
- latest_cad_log: ${latest_cad_log:-none}
- latest_cad_status: ${cad_status}
- latest_mascarade_brief: ${latest_mascarade_brief:-none}
- latest_mascarade_registry: ${latest_mascarade_registry:-none}
- latest_mascarade_queue: ${latest_mascarade_queue:-none}
- latest_mascarade_watch: ${latest_mascarade_watch:-none}
- latest_mascarade_watch_history: ${latest_mascarade_watch_history:-none}
- latest_kill_life_memory: ${latest_kill_life_memory_md:-none}

## Open tasks

$(render_open_tasks)

## Machine sync highlights

$(render_machine_sync)

## Latest refonte log tail

\`\`\`text
$(render_log_tail "$latest_refonte_log")
\`\`\`

## Latest YiACAD log tail

\`\`\`text
$(render_log_tail "$latest_cad_log")
\`\`\`

## Latest Mascarade incident brief

\`\`\`text
$(render_log_tail "$latest_mascarade_brief")
\`\`\`

## Mascarade incident registry

$(render_registry_severity "$latest_mascarade_registry_json")

\`\`\`text
$(render_log_tail "$latest_mascarade_registry")
\`\`\`

## Mascarade incident queue

\`\`\`text
$(render_log_tail "$latest_mascarade_queue")
\`\`\`

## Mascarade incident watch

\`\`\`text
$(render_log_tail "$latest_mascarade_watch")
\`\`\`

## Mascarade watch history

\`\`\`text
$(render_log_tail "$latest_mascarade_watch_history")
\`\`\`

## Kill life execution continuity

$(render_kill_life_meta "$latest_kill_life_memory_json")

\`\`\`text
$(render_log_tail "$latest_kill_life_memory_md")
\`\`\`

## Routing

$(render_routing "$cad_status")
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      OUTPUT_FILE="${2:-}"
      shift 2
      ;;
    --days)
      WINDOW_DAYS="${2:-7}"
      shift 2
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
write_summary
cat "$OUTPUT_FILE"
