#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts/uiux_tui"
mkdir -p "${ARTIFACTS_DIR}"

ACTION=""
JSON_MODE=0
VERBOSE=0
YES=0
DAYS=14
LINES=80

usage() {
  cat <<'EOF'
Usage: yiacad_uiux_tui.sh --action <status|lane-status|owners|proofs|backend|backend-proof|review-session|review-history|review-taxonomy|review-context|audit|program-audit|feature-map|next-feature-map|plan|todo|research|next-spec|insertion-points|agent-matrix|logs-summary|logs-list|logs-latest|purge-logs> [options]

Options:
  --action <name>   Action to run
  --days <N>        Retention window for purge-logs (default: 14)
  --lines <N>       Number of lines for logs-latest (default: 80)
  --json            Emit JSON for status/logs-summary
  --yes             Confirm destructive purge in non-interactive mode
  --verbose         Print executed commands
  --help            Show this help
EOF
}

have_tty() {
  [[ -t 0 && -t 1 ]]
}

choose_action_interactive() {
  if command -v gum >/dev/null 2>&1 && have_tty; then
    gum choose \
      status \
      lane-status \
      owners \
      proofs \
      backend \
      backend-proof \
      review-session \
      review-history \
      review-taxonomy \
      review-context \
      audit \
      program-audit \
      feature-map \
      next-feature-map \
      plan \
      todo \
      research \
      next-spec \
      insertion-points \
      agent-matrix \
      logs-summary \
      logs-list \
      logs-latest \
      purge-logs
    return 0
  fi
  return 1
}

log_cmd() {
  if [[ "${VERBOSE}" -eq 1 ]]; then
    printf '[cmd] %s\n' "$*"
  fi
}

render_backend_status() {
  YIACAD_STATUS_JSON="$1" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["YIACAD_STATUS_JSON"])
service = payload.get("service") or {}
artifacts = payload.get("artifacts") or []
next_steps = payload.get("next_steps") or []

print("# YiACAD Backend Status")
print("")
print(f"- status: {payload.get('status', 'unknown')}")
print(f"- severity: {payload.get('severity', 'unknown')}")
print(f"- action: {payload.get('action', 'unknown')}")
print(f"- execution_mode: {payload.get('execution_mode', 'unknown')}")
print(f"- transport: service-first ({service.get('mode', 'fallback')})")
print(f"- summary: {payload.get('summary', '')}")
details = payload.get("details")
if details:
    print(f"- details: {details}")

if artifacts:
    print("")
    print("## Artifacts")
    for artifact in artifacts:
        print(f"- {artifact.get('label', 'artifact')}: {artifact.get('path', '')}")

if next_steps:
    print("")
    print("## Next steps")
    for step in next_steps:
        print(f"- {step}")
PY
}

run_backend_status() {
  local payload=""
  local -a backend_cmd=()
  local -a native_cmd=()

  if [[ -x "${ROOT_DIR}/tools/cad/yiacad_backend_client.py" ]]; then
    backend_cmd=(python3 "${ROOT_DIR}/tools/cad/yiacad_backend_client.py" --surface tui --json-output status)
    log_cmd "${backend_cmd[@]}"
    if payload="$("${backend_cmd[@]}" 2>/dev/null)"; then
      if [[ "${JSON_MODE}" -eq 1 ]]; then
        printf '%s\n' "${payload}"
      else
        render_backend_status "${payload}"
      fi
      return 0
    fi
  fi

  if [[ -x "${ROOT_DIR}/tools/cad/yiacad_native_ops.py" ]]; then
    native_cmd=(python3 "${ROOT_DIR}/tools/cad/yiacad_native_ops.py" status)
    if [[ "${JSON_MODE}" -eq 1 ]]; then
      native_cmd+=(--json-output)
    fi
    log_cmd "${native_cmd[@]}"
    "${native_cmd[@]}"
    return 0
  fi

  printf 'yiacad_backend_client.py and yiacad_native_ops.py not found\n' >&2
  return 1
}

lane_status() {
  cat <<EOF
# YiACAD lane status

- active_lots:
  - T-UX-004
  - T-UX-003
- support_lane:
  - Support UI/UX Ops
- next_blocking_lot:
  - T-UX-004
  - T-UX-003
- blocker_reason:
  - le backend YiACAD passe maintenant en service-first jusque dans la TUI UI/UX et la preuve operateur est archivee
  - le prochain travail produit est la palette persistante, l inspector contextuel et la remontee vers les points d insertion natifs documentes
- canon_write_set:
  - KiCad shell: pcbnew/toolbars_pcb_editor.cpp + eeschema/toolbars_sch_editor.cpp
  - KiCad control: board_editor_control.* + sch_editor_control.*
  - FreeCAD safe: yiacad_freecad_gui.py
  - FreeCAD next shell: MainWindow.cpp
- no_touch:
  - common/eda_base_frame.cpp
  - src/Gui/DockWindowManager.cpp
  - src/Gui/ComboView.cpp
- proofs:
  - docs/YIACAD_OPERATOR_INDEX_2026-03-21.md
  - docs/YIACAD_BACKEND_SERVICE_2026-03-21.md
  - docs/plans/20_plan_refonte_ui_ux_yiacad_apple_native.md
  - docs/plans/20_todo_refonte_ui_ux_yiacad_apple_native.md
  - docs/plans/21_plan_refonte_globale_yiacad.md
  - docs/plans/21_todo_refonte_globale_yiacad.md
  - docs/YIACAD_NATIVE_UI_INSERTION_POINTS_2026-03-20.md
  - .runtime-home/cad-ai-native-forks/kicad-ki/scripting/plugins/yiacad_kicad_plugin/yiacad_action.py
  - .runtime-home/cad-ai-native-forks/freecad-ki/src/Mod/YiACADWorkbench/yiacad_freecad_gui.py
EOF
}

owners_summary() {
  cat <<EOF
# YiACAD owners summary

- T-UX-003A: CAD-UX / KiCad-Shell
- T-UX-003B: CAD-UX / FreeCAD-Shell
- T-UX-003C: CAD-UX / KiCad-Native
- T-UX-003D: CAD-UX / FreeCAD-Native
- T-UX-004A: CAD-UX / KiCad-Surface + FreeCAD-Surface
- T-UX-004B: Doc-Research / Mermaid-Map + OSS-Watch
- T-ARCH-101C: CAD-Native + AI-Integration
- Support UI/UX Ops: SyncOps / TUI-Ops + Log-Guard

- matrix:
  - docs/AGENT_SPEC_MODULE_MATRIX_2026-03-20.md
  - docs/plans/12_plan_gestion_des_agents.md
EOF
}

proofs_summary() {
  cat <<EOF
# YiACAD proofs

- plan:
  - docs/plans/20_plan_refonte_ui_ux_yiacad_apple_native.md
- todo:
  - docs/plans/20_todo_refonte_ui_ux_yiacad_apple_native.md
- output_contract:
  - docs/YIACAD_UIUX_OUTPUT_CONTRACT_2026-03-20.md
  - specs/contracts/yiacad_uiux_output.schema.json
  - specs/contracts/examples/yiacad_uiux_output.example.json
- insertion_points:
  - docs/YIACAD_NATIVE_UI_INSERTION_POINTS_2026-03-20.md
- feature_map:
  - docs/YIACAD_APPLE_UI_UX_FEATURE_MAP_2026-03-20.md
- research:
  - docs/YIACAD_APPLE_UI_UX_OSS_RESEARCH_2026-03-20.md
- agent_matrix:
  - docs/AGENT_SPEC_MODULE_MATRIX_2026-03-20.md
  - docs/plans/12_plan_gestion_des_agents.md
- global_bundle:
  - docs/YIACAD_GLOBAL_REFACTOR_AUDIT_2026-03-20.md
  - docs/YIACAD_GLOBAL_AI_INTEGRATION_ASSESSMENT_2026-03-20.md
  - docs/plans/21_plan_refonte_globale_yiacad.md
  - docs/plans/21_todo_refonte_globale_yiacad.md
- operator_entrypoint:
  - docs/YIACAD_OPERATOR_INDEX_2026-03-21.md
  - tools/cockpit/yiacad_operator_index.sh
- backend:
  - docs/YIACAD_BACKEND_ARCHITECTURE_2026-03-20.md
  - docs/YIACAD_BACKEND_SERVICE_2026-03-21.md
  - specs/yiacad_backend_architecture_spec.md
  - specs/contracts/yiacad_context_broker.schema.json
  - specs/contracts/examples/yiacad_context_broker.example.json
- backend_service:
  - tools/cockpit/yiacad_backend_service_tui.sh
- backend_proof:
  - docs/YIACAD_BACKEND_OPERATOR_PROOF_2026-03-21.md
  - tools/cockpit/yiacad_backend_proof.sh
- review_session:
  - docs/YIACAD_REVIEW_SESSION_2026-03-21.md
  - artifacts/cad-ai-native/latest_review_session.json
- review_history:
  - docs/YIACAD_REVIEW_SESSION_2026-03-21.md
  - artifacts/cad-ai-native/review_history.json
- review_context:
  - docs/YIACAD_REVIEW_SESSION_2026-03-21.md
  - tools/cockpit/yiacad_uiux_tui.sh --action review-context
EOF
}

review_session_view() {
  local session_file="${ROOT_DIR}/artifacts/cad-ai-native/latest_review_session.json"
  if [[ -f "${session_file}" ]]; then
    cat "${session_file}"
  else
    printf 'missing file: %s\n' "${session_file}"
    return 1
  fi
}

review_history_view() {
  local history_file="${ROOT_DIR}/artifacts/cad-ai-native/review_history.json"
  if [[ -f "${history_file}" ]]; then
    cat "${history_file}"
  else
    printf 'missing file: %s\n' "${history_file}"
    return 1
  fi
}

review_taxonomy_view() {
  local history_file="${ROOT_DIR}/artifacts/cad-ai-native/review_history.json"
  if [[ ! -f "${history_file}" ]]; then
    printf 'missing file: %s\n' "${history_file}"
    return 1
  fi

  python3 - <<PY
import json
from collections import Counter
from pathlib import Path

history = json.loads(Path("${history_file}").read_text(encoding="utf-8"))
entries = history.get("entries") or []
taxonomy = Counter((entry.get("taxonomy") or "unknown") for entry in entries)
status = Counter((entry.get("status") or "unknown") for entry in entries)
severity = Counter((entry.get("severity") or "unknown") for entry in entries)

print("# YiACAD review taxonomy")
print()
print(f"- entries: {len(entries)}")
print("- taxonomy:")
for key in sorted(taxonomy):
    print(f"  - {key}: {taxonomy[key]}")
print("- status:")
for key in sorted(status):
    print(f"  - {key}: {status[key]}")
print("- severity:")
for key in sorted(severity):
    print(f"  - {key}: {severity[key]}")
PY
}

review_context_view() {
  local session_file="${ROOT_DIR}/artifacts/cad-ai-native/latest_review_session.json"
  local history_file="${ROOT_DIR}/artifacts/cad-ai-native/review_history.json"
  if [[ ! -f "${session_file}" ]]; then
    printf 'missing file: %s\n' "${session_file}"
    return 1
  fi
  if [[ ! -f "${history_file}" ]]; then
    printf 'missing file: %s\n' "${history_file}"
    return 1
  fi

  python3 - <<PY
import json
from collections import Counter
from pathlib import Path

session = json.loads(Path("${session_file}").read_text(encoding="utf-8"))
history = json.loads(Path("${history_file}").read_text(encoding="utf-8"))
payload = session.get("payload") if isinstance(session.get("payload"), dict) else session
entries = history.get("entries") or []
taxonomy = Counter((entry.get("taxonomy") or "unknown") for entry in entries)
status = Counter((entry.get("status") or "unknown") for entry in entries)

print("# YiACAD review context")
print()
print(f"- current_action: {payload.get('action') or 'unknown'}")
print(f"- current_status: {payload.get('status') or 'unknown'}")
print(f"- current_severity: {payload.get('severity') or 'unknown'}")
print(f"- current_context: {payload.get('context_ref') or 'no-context'}")
print(f"- current_summary: {(payload.get('summary') or '').strip() or '-'}")
print("- taxonomy:")
for key in sorted(taxonomy):
    print(f"  - {key}: {taxonomy[key]}")
print("- status_mix:")
for key in sorted(status):
    print(f"  - {key}: {status[key]}")
print("- recent_trail:")
for entry in entries[:3]:
    action = entry.get("action") or "unknown"
    entry_status = entry.get("status") or "unknown"
    severity = entry.get("severity") or "unknown"
    summary = (entry.get("summary") or "").strip() or "-"
    print(f"  - {action} | {entry_status} | {severity} | {summary}")
print("- next_steps:")
seen = set()
for entry in entries[:5]:
    for step in entry.get("next_steps") or []:
        if step not in seen:
            seen.add(step)
            print(f"  - {step}")
if not seen:
    print("  - none")
PY
}

review_context_view() {
  local session_file="${ROOT_DIR}/artifacts/cad-ai-native/latest_review_session.json"
  local history_file="${ROOT_DIR}/artifacts/cad-ai-native/review_history.json"
  if [[ ! -f "${session_file}" ]]; then
    printf 'missing file: %s\n' "${session_file}"
    return 1
  fi
  if [[ ! -f "${history_file}" ]]; then
    printf 'missing file: %s\n' "${history_file}"
    return 1
  fi

  python3 - <<PY
import json
from collections import Counter
from pathlib import Path

session = json.loads(Path("${session_file}").read_text(encoding="utf-8"))
history = json.loads(Path("${history_file}").read_text(encoding="utf-8"))
entries = history.get("entries") or []
payload = session.get("payload") if isinstance(session, dict) else {}
if not isinstance(payload, dict) or not payload:
    payload = session if isinstance(session, dict) else {}
head = payload
action = str(head.get("action") or "").strip()
if (not action or action == "unknown") and entries:
    first = entries[0]
    if isinstance(first, dict):
        head = first
taxonomy = Counter((entry.get("taxonomy") or "unknown") for entry in entries)

print("# YiACAD review context")
print()
print(f"- command: {session.get('command') or head.get('action') or 'unknown'}")
print(f"- context_ref: {head.get('context_ref') or 'no context'}")
print(f"- status: {head.get('status') or 'unknown'}")
print(f"- severity: {head.get('severity') or 'unknown'}")
summary = str(head.get("summary") or "").strip()
if summary:
    print(f"- summary: {summary}")
print("- taxonomy:")
for key in sorted(taxonomy):
    print(f"  - {key}: {taxonomy[key]}")
print("- recent:")
for entry in entries[:4]:
    action = entry.get("action") or "unknown"
    status = entry.get("status") or "unknown"
    severity = entry.get("severity") or "unknown"
    context_ref = entry.get("context_ref") or "no context"
    summary = str(entry.get("summary") or "").strip()
    generated_at = entry.get("generated_at") or ""
    print(f"  - {action} | {status} | {severity}")
    print(f"    context: {context_ref}")
    if summary:
        print(f"    summary: {summary}")
    if generated_at:
        print(f"    generated_at: {generated_at}")
PY
}

show_file() {
  local path="$1"
  if [[ -f "${path}" ]]; then
    cat "${path}"
  else
    printf 'missing file: %s\n' "${path}"
    return 1
  fi
}

collect_log_files() {
  find "${ARTIFACTS_DIR}" -type f 2>/dev/null
  if [[ -d "${ROOT_DIR}/artifacts/cad-ai-native" ]]; then
    find "${ROOT_DIR}/artifacts/cad-ai-native" -type f 2>/dev/null
  fi
  if [[ -d "${ROOT_DIR}/artifacts/yiacad_backend_service_tui" ]]; then
    find "${ROOT_DIR}/artifacts/yiacad_backend_service_tui" -type f 2>/dev/null
  fi
}

logs_list() {
  local found=0
  local path=""

  while IFS= read -r path; do
    [[ -n "${path}" ]] || continue
    [[ "${path}" == "${LOG_FILE:-}" ]] && continue
    printf '%s\n' "${path}"
    found=1
  done < <(collect_log_files | sort)

  if [[ "${found}" -eq 0 ]]; then
    if [[ -n "${LOG_FILE:-}" ]]; then
      printf '%s\n' "${LOG_FILE}"
    else
      printf 'no logs found\n'
    fi
  fi
}

logs_latest() {
  local latest=""
  local path=""

  while IFS= read -r path; do
    [[ -n "${path}" ]] || continue
    [[ "${path}" == "${LOG_FILE:-}" ]] && continue
    latest="${path}"
  done < <(collect_log_files | sort)

  if [[ -z "${latest}" ]]; then
    if [[ -n "${LOG_FILE:-}" ]]; then
      latest="${LOG_FILE}"
    else
      printf 'no logs found\n'
      return 1
    fi
  fi

  printf '# Latest log\n\n'
  printf -- '- path: %s\n' "${latest}"
  printf -- '- lines: %s\n\n' "${LINES}"
  tail -n "${LINES}" "${latest}"
}

logs_summary() {
  local uiux_count native_count backend_service_count
  uiux_count="$(find "${ARTIFACTS_DIR}" -type f | wc -l | tr -d ' ')"
  native_count="0"
  backend_service_count="0"
  if [[ -d "${ROOT_DIR}/artifacts/cad-ai-native" ]]; then
    native_count="$(find "${ROOT_DIR}/artifacts/cad-ai-native" -type f | wc -l | tr -d ' ')"
  fi
  if [[ -d "${ROOT_DIR}/artifacts/yiacad_backend_service_tui" ]]; then
    backend_service_count="$(find "${ROOT_DIR}/artifacts/yiacad_backend_service_tui" -type f | wc -l | tr -d ' ')"
  fi

  if [[ "${JSON_MODE}" -eq 1 ]]; then
    python3 - <<PY
import json
print(json.dumps({
  "status": "done",
  "uiux_tui_files": int("${uiux_count}"),
  "cad_ai_native_files": int("${native_count}"),
  "backend_service_files": int("${backend_service_count}"),
  "artifacts_dir": "${ARTIFACTS_DIR}",
}, ensure_ascii=False))
PY
    return 0
  fi

  cat <<EOF
# YiACAD UI/UX logs summary

- uiux_tui files: ${uiux_count}
- cad-ai-native files: ${native_count}
- backend service files: ${backend_service_count}
- artifacts dir: ${ARTIFACTS_DIR}
EOF
}

purge_logs() {
  if [[ "${YES}" -ne 1 ]]; then
    if command -v gum >/dev/null 2>&1 && have_tty; then
      if ! gum confirm "Purger les logs UI/UX de plus de ${DAYS} jours ?"; then
        printf 'purge cancelled\n'
        return 0
      fi
    else
      printf 'Refusing purge without --yes outside interactive confirm\n' >&2
      return 2
    fi
  fi

  find "${ARTIFACTS_DIR}" -type f -mtime +"${DAYS}" -delete
  printf 'purged uiux logs older than %s days in %s\n' "${DAYS}" "${ARTIFACTS_DIR}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --action)
      ACTION="${2:-}"
      shift 2
      ;;
    --days)
      DAYS="${2:-}"
      shift 2
      ;;
    --lines)
      LINES="${2:-}"
      shift 2
      ;;
    --json)
      JSON_MODE=1
      shift
      ;;
    --yes)
      YES=1
      shift
      ;;
    --verbose)
      VERBOSE=1
      shift
      ;;
    --help)
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

if [[ -z "${ACTION}" ]]; then
  if ACTION="$(choose_action_interactive)"; then
    :
  else
    printf 'Missing --action (interactive selection unavailable)\n' >&2
    usage >&2
    exit 2
  fi
fi

if ! [[ "${DAYS}" =~ ^[0-9]+$ ]]; then
  printf -- '--days requires an integer\n' >&2
  exit 2
fi

if ! [[ "${LINES}" =~ ^[0-9]+$ ]]; then
  printf -- '--lines requires an integer\n' >&2
  exit 2
fi

STAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${ARTIFACTS_DIR}/yiacad_uiux_tui_${STAMP}.log"

if [[ "${JSON_MODE}" -eq 1 ]]; then
  : > "${LOG_FILE}"
else
  exec > >(tee -a "${LOG_FILE}") 2>&1
fi

if [[ "${JSON_MODE}" -ne 1 ]]; then
  printf '[yiacad-uiux-tui] action=%s timestamp=%s\n' "${ACTION}" "${STAMP}"
fi

case "${ACTION}" in
  status)
    run_backend_status
    ;;
  lane-status)
    lane_status
    ;;
  owners)
    owners_summary
    ;;
  proofs)
    proofs_summary
    ;;
  backend)
    show_file "${ROOT_DIR}/docs/YIACAD_BACKEND_SERVICE_2026-03-21.md"
    ;;
  backend-proof)
    log_cmd bash "${ROOT_DIR}/tools/cockpit/yiacad_backend_proof.sh" --action run
    bash "${ROOT_DIR}/tools/cockpit/yiacad_backend_proof.sh" --action run
    ;;
  review-session)
    review_session_view
    ;;
  review-history)
    review_history_view
    ;;
  review-taxonomy)
    review_taxonomy_view
    ;;
  review-context)
    review_context_view
    ;;
  audit)
    show_file "${ROOT_DIR}/docs/YIACAD_APPLE_UI_UX_AUDIT_2026-03-20.md"
    ;;
  program-audit)
    show_file "${ROOT_DIR}/docs/YIACAD_EXHAUSTIVE_REFOUNTE_AUDIT_2026-03-20.md"
    ;;
  feature-map)
    show_file "${ROOT_DIR}/docs/YIACAD_APPLE_UI_UX_FEATURE_MAP_2026-03-20.md"
    ;;
  next-feature-map)
    show_file "${ROOT_DIR}/docs/YIACAD_TUX004_FEATURE_MAP_2026-03-20.md"
    ;;
  plan)
    show_file "${ROOT_DIR}/docs/plans/20_plan_refonte_ui_ux_yiacad_apple_native.md"
    ;;
  todo)
    show_file "${ROOT_DIR}/docs/plans/20_todo_refonte_ui_ux_yiacad_apple_native.md"
    ;;
  research)
    show_file "${ROOT_DIR}/docs/YIACAD_APPLE_UI_UX_OSS_RESEARCH_2026-03-20.md"
    ;;
  next-spec)
    show_file "${ROOT_DIR}/specs/yiacad_tux004_orchestration_spec.md"
    ;;
  insertion-points)
    show_file "${ROOT_DIR}/docs/YIACAD_NATIVE_UI_INSERTION_POINTS_2026-03-20.md"
    ;;
  agent-matrix)
    log_cmd bash "${ROOT_DIR}/tools/cockpit/agent_matrix_tui.sh" --action summary
    bash "${ROOT_DIR}/tools/cockpit/agent_matrix_tui.sh" --action summary
    ;;
  logs-summary)
    logs_summary
    ;;
  logs-list)
    logs_list
    ;;
  logs-latest)
    logs_latest
    ;;
  purge-logs)
    purge_logs
    ;;
  *)
    printf 'Unknown action: %s\n' "${ACTION}" >&2
    exit 2
    ;;
esac
