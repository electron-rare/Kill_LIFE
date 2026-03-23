#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts/yiacad_operator_index"
mkdir -p "${ARTIFACTS_DIR}"

ACTION=""
JSON_MODE=0
VERBOSE=0
YES=0
DAYS=14
LINES=80

usage() {
  cat <<'EOF'
Usage: yiacad_operator_index.sh --action <action> [options]

Actions:
  status              View operator index status and routes
  incident-watch      Monitor incidents via mascarade_incidents_tui.sh
  incident-history    View incident history
  uiux                Run UI/UX status checks
  global              Run global refonte status
  backend             Backend service status
  review-context      Review context/session/history/taxonomy
  proofs              View proofs and continuity artifacts
  logs-summary        Summarize logs (supports --json)
  logs-list           List all log files
  logs-latest         Show latest log
  purge-logs          Clean old logs (--days N, requires --yes)
  --- Mistral Agents (Lot 23) ---
  agents-status       Check all 4 Mistral agents status
  agents-chat         Chat with a Mistral agent interactively
  agents-health       Run Sentinelle full diagnostic
  agents-e2e          Run E2E agents integration tests
  --- Mistral Studio (Lot 24) ---
  studio-status       Mistral Studio health overview (agents+files+ft+libraries)
  studio-files        List Mistral Files API
  studio-finetune     List fine-tune jobs status
  studio-libraries    List Document Libraries (Beta RAG)
  studio-conversations List Beta Conversations
  studio-models       Full models catalog
  infra-health        Infrastructure container health check (web+docker)

Aliases: backend-proof, review-session, review-history, review-taxonomy

Options:
  --action <name>   Action to run
  --days <N>        Retention window for purge-logs (default: 14)
  --lines <N>       Number of lines for logs-latest (default: 80)
  --json            Emit JSON for logs-summary
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
      incident-watch \
      incident-history \
      uiux \
      global \
      backend \
      backend-proof \
      review-session \
      review-history \
      review-taxonomy \
      review-context \
      proofs \
      agents-status \
      agents-chat \
      agents-health \
      agents-e2e \
      studio-status \
      studio-files \
      studio-finetune \
      studio-libraries \
      studio-conversations \
      studio-models \
      infra-health \
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

run_uiux_status() {
  log_cmd bash "${ROOT_DIR}/tools/cockpit/yiacad_uiux_tui.sh" --action lane-status
  bash "${ROOT_DIR}/tools/cockpit/yiacad_uiux_tui.sh" --action lane-status
}

run_global_status() {
  log_cmd bash "${ROOT_DIR}/tools/cockpit/yiacad_refonte_tui.sh" --action status
  bash "${ROOT_DIR}/tools/cockpit/yiacad_refonte_tui.sh" --action status
}

run_backend_service() {
  log_cmd bash "${ROOT_DIR}/tools/cockpit/yiacad_backend_service_tui.sh" --action status
  bash "${ROOT_DIR}/tools/cockpit/yiacad_backend_service_tui.sh" --action status
}

run_backend_proof() {
  run_backend_service
}

run_incident_watch() {
  log_cmd bash "${ROOT_DIR}/tools/cockpit/mascarade_incidents_tui.sh" --action watch
  bash "${ROOT_DIR}/tools/cockpit/mascarade_incidents_tui.sh" --action watch
}

run_incident_history() {
  log_cmd bash "${ROOT_DIR}/tools/cockpit/render_mascarade_watch_history.sh"
  bash "${ROOT_DIR}/tools/cockpit/render_mascarade_watch_history.sh"
}

run_review_session() {
  log_cmd bash "${ROOT_DIR}/tools/cockpit/yiacad_uiux_tui.sh" --action review-session
  bash "${ROOT_DIR}/tools/cockpit/yiacad_uiux_tui.sh" --action review-session
}

run_review_history() {
  log_cmd bash "${ROOT_DIR}/tools/cockpit/yiacad_uiux_tui.sh" --action review-history
  bash "${ROOT_DIR}/tools/cockpit/yiacad_uiux_tui.sh" --action review-history
}

run_review_taxonomy() {
  log_cmd bash "${ROOT_DIR}/tools/cockpit/yiacad_uiux_tui.sh" --action review-taxonomy
  bash "${ROOT_DIR}/tools/cockpit/yiacad_uiux_tui.sh" --action review-taxonomy
}

run_review_context() {
  log_cmd bash "${ROOT_DIR}/tools/cockpit/yiacad_uiux_tui.sh" --action review-context
  bash "${ROOT_DIR}/tools/cockpit/yiacad_uiux_tui.sh" --action review-context
}

run_review_context() {
  log_cmd bash "${ROOT_DIR}/tools/cockpit/yiacad_uiux_tui.sh" --action review-context
  bash "${ROOT_DIR}/tools/cockpit/yiacad_uiux_tui.sh" --action review-context
}

# ── Mistral Agents (Lot 23 T-MA-024) ─────────────────────────────────────
run_agents_status() {
  log_cmd bash "${ROOT_DIR}/tools/cockpit/mistral_agents_tui.sh" --action status
  bash "${ROOT_DIR}/tools/cockpit/mistral_agents_tui.sh" --action status
}

run_agents_chat() {
  log_cmd bash "${ROOT_DIR}/tools/cockpit/mistral_agents_tui.sh" --action chat
  bash "${ROOT_DIR}/tools/cockpit/mistral_agents_tui.sh" --action chat
}

run_agents_health() {
  log_cmd bash "${ROOT_DIR}/tools/cockpit/mistral_agents_tui.sh" --action health
  bash "${ROOT_DIR}/tools/cockpit/mistral_agents_tui.sh" --action health
}

run_agents_e2e() {
  log_cmd bash "${ROOT_DIR}/tools/cockpit/e2e_agents_test.sh" --action all
  bash "${ROOT_DIR}/tools/cockpit/e2e_agents_test.sh" --action all
}

# ── Mistral Studio (Lot 24) ──────────────────────────────────────────────
run_studio_status() {
  log_cmd bash "${ROOT_DIR}/tools/cockpit/mistral_studio_tui.sh" --health
  bash "${ROOT_DIR}/tools/cockpit/mistral_studio_tui.sh" --health
}

run_studio_files() {
  log_cmd bash "${ROOT_DIR}/tools/cockpit/mistral_studio_tui.sh" --files-list
  bash "${ROOT_DIR}/tools/cockpit/mistral_studio_tui.sh" --files-list
}

run_studio_finetune() {
  log_cmd bash "${ROOT_DIR}/tools/cockpit/mistral_studio_tui.sh" --finetune-list
  bash "${ROOT_DIR}/tools/cockpit/mistral_studio_tui.sh" --finetune-list
}

run_studio_libraries() {
  log_cmd bash "${ROOT_DIR}/tools/cockpit/mistral_studio_tui.sh" --libraries-list
  bash "${ROOT_DIR}/tools/cockpit/mistral_studio_tui.sh" --libraries-list
}

run_studio_conversations() {
  log_cmd bash "${ROOT_DIR}/tools/cockpit/mistral_studio_tui.sh" --conversations-list
  bash "${ROOT_DIR}/tools/cockpit/mistral_studio_tui.sh" --conversations-list
}

run_studio_models() {
  log_cmd bash "${ROOT_DIR}/tools/cockpit/mistral_studio_tui.sh" --models-list
  bash "${ROOT_DIR}/tools/cockpit/mistral_studio_tui.sh" --models-list
}

run_infra_health() {
  log_cmd bash "${ROOT_DIR}/tools/cockpit/infra_container_health.sh" --action status
  bash "${ROOT_DIR}/tools/cockpit/infra_container_health.sh" --action status
}

status_view() {
  cat <<EOF
# YiACAD operator index

- short_entry:
  - bash tools/cockpit/yiacad_operator_index.sh --action status
- execution_continuity:
  - kill_life memory latest: ${ROOT_DIR}/artifacts/cockpit/kill_life_memory/latest.md
  - operator daily summary: ${ROOT_DIR}/artifacts/cockpit/daily_operator_summary_latest.md
  - product contract handoff json: ${ROOT_DIR}/artifacts/cockpit/product_contract_handoff/latest.json
  - product contract handoff markdown: ${ROOT_DIR}/artifacts/cockpit/product_contract_handoff/latest.md
  - incident watch: bash tools/cockpit/mascarade_incidents_tui.sh --action watch
- routes:
  - incident-watch: bash tools/cockpit/mascarade_incidents_tui.sh --action watch
  - incident-history: bash tools/cockpit/render_mascarade_watch_history.sh
  - uiux: bash tools/cockpit/yiacad_uiux_tui.sh --action status
  - global: bash tools/cockpit/yiacad_refonte_tui.sh --action status
  - backend: bash tools/cockpit/yiacad_backend_service_tui.sh --action status
  - review-context: bash tools/cockpit/yiacad_operator_index.sh --action review-context
  - proofs: bash tools/cockpit/yiacad_operator_index.sh --action proofs
- mistral_agents:
  - agents-status: bash tools/cockpit/mistral_agents_tui.sh --action status
  - agents-chat: bash tools/cockpit/mistral_agents_tui.sh --action chat
  - agents-health: bash tools/cockpit/mistral_agents_tui.sh --action health
  - agents-e2e: bash tools/cockpit/e2e_agents_test.sh --action all
- mistral_studio:
  - studio-status: bash tools/cockpit/mistral_studio_tui.sh --health
  - studio-files: bash tools/cockpit/mistral_studio_tui.sh --files-list
  - studio-finetune: bash tools/cockpit/mistral_studio_tui.sh --finetune-list
  - studio-libraries: bash tools/cockpit/mistral_studio_tui.sh --libraries-list
  - studio-conversations: bash tools/cockpit/mistral_studio_tui.sh --conversations-list
  - studio-models: bash tools/cockpit/mistral_studio_tui.sh --models-list
- infrastructure:
  - infra-health: bash tools/cockpit/infra_container_health.sh --action status
- aliases:
  - backend-proof -> backend
  - review-session -> yiacad_uiux_tui.sh --action review-session
  - review-history -> yiacad_uiux_tui.sh --action review-history
  - review-taxonomy -> yiacad_uiux_tui.sh --action review-taxonomy
  - review-context -> yiacad_uiux_tui.sh --action review-context
- next_lots:
  - T-UX-006
  - T-ARCH-101C
- operator_doc:
  - docs/YIACAD_OPERATOR_INDEX_2026-03-21.md
- artifacts:
  - ${ARTIFACTS_DIR}
EOF
}

proofs_view() {
  cat <<EOF
# YiACAD operator proofs

- operator_index:
  - docs/YIACAD_OPERATOR_INDEX_2026-03-21.md
  - tools/cockpit/yiacad_operator_index.sh
- uiux_lane:
  - docs/plans/20_plan_refonte_ui_ux_yiacad_apple_native.md
  - docs/plans/20_todo_refonte_ui_ux_yiacad_apple_native.md
  - tools/cockpit/yiacad_uiux_tui.sh
- global_lane:
  - docs/plans/21_plan_refonte_globale_yiacad.md
  - docs/plans/21_todo_refonte_globale_yiacad.md
  - tools/cockpit/yiacad_refonte_tui.sh
- global_docs:
  - docs/YIACAD_GLOBAL_REFACTOR_AUDIT_2026-03-20.md
  - docs/YIACAD_GLOBAL_AI_INTEGRATION_ASSESSMENT_2026-03-20.md
- backend:
  - docs/YIACAD_BACKEND_SERVICE_2026-03-21.md
  - tools/cockpit/yiacad_backend_service_tui.sh
- proofs:
  - docs/YIACAD_OPERATOR_INDEX_2026-03-21.md
  - tools/cockpit/yiacad_operator_index.sh --action proofs
  - tools/cockpit/mascarade_incidents_tui.sh --action watch
  - tools/cockpit/render_mascarade_watch_history.sh
- continuity:
  - artifacts/cockpit/kill_life_memory/latest.json
  - artifacts/cockpit/kill_life_memory/latest.md
  - artifacts/cockpit/daily_operator_summary_latest.md
  - artifacts/cockpit/product_contract_handoff/latest.json
  - artifacts/cockpit/product_contract_handoff/latest.md
EOF
}

collect_log_files() {
  find "${ARTIFACTS_DIR}" -type f 2>/dev/null
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
  local log_count
  log_count="$(find "${ARTIFACTS_DIR}" -type f | wc -l | tr -d ' ')"

  if [[ "${JSON_MODE}" -eq 1 ]]; then
    python3 - <<PY
import json
print(json.dumps({
  "status": "done",
  "log_files": int("${log_count}"),
  "artifacts_dir": "${ARTIFACTS_DIR}",
  "entrypoint": "tools/cockpit/yiacad_operator_index.sh",
  "uiux_artifacts_dir": "${ROOT_DIR}/artifacts/uiux_tui",
  "global_artifacts_dir": "${ROOT_DIR}/artifacts/yiacad_refonte_tui",
  "backend_artifacts_dir": "${ROOT_DIR}/artifacts/yiacad_backend_service_tui",
}, ensure_ascii=False))
PY
    return 0
  fi

  cat <<EOF
# YiACAD operator index logs summary

- log files: ${log_count}
- artifacts dir: ${ARTIFACTS_DIR}
- uiux artifacts dir: ${ROOT_DIR}/artifacts/uiux_tui
- global artifacts dir: ${ROOT_DIR}/artifacts/yiacad_refonte_tui
- backend artifacts dir: ${ROOT_DIR}/artifacts/yiacad_backend_service_tui
EOF
}

purge_logs() {
  if [[ "${YES}" -ne 1 ]]; then
    if command -v gum >/dev/null 2>&1 && have_tty; then
      if ! gum confirm "Purger les logs d'index operateur YiACAD de plus de ${DAYS} jours ?"; then
        printf 'purge cancelled\n'
        return 0
      fi
    else
      printf 'Refusing purge without --yes outside interactive confirm\n' >&2
      return 2
    fi
  fi

  find "${ARTIFACTS_DIR}" -type f -mtime +"${DAYS}" -delete
  printf 'purged yiacad operator index logs older than %s days in %s\n' "${DAYS}" "${ARTIFACTS_DIR}"
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
LOG_FILE="${ARTIFACTS_DIR}/yiacad_operator_index_${STAMP}.log"
exec > >(tee -a "${LOG_FILE}") 2>&1

printf '[yiacad-operator-index] action=%s timestamp=%s\n' "${ACTION}" "${STAMP}"

case "${ACTION}" in
    status)
      status_view
      ;;
    incident-watch)
      run_incident_watch
      ;;
    incident-history)
      run_incident_history
      ;;
    uiux)
      run_uiux_status
      ;;
  global)
    run_global_status
    ;;
  backend)
    run_backend_service
    ;;
  backend-proof)
    run_backend_proof
    ;;
  review-session)
    run_review_session
    ;;
  review-history)
    run_review_history
    ;;
  review-taxonomy)
    run_review_taxonomy
    ;;
  review-context)
    run_review_context
    ;;
  review-context)
    run_review_context
    ;;
  proofs)
    proofs_view
    ;;
  agents-status)
    run_agents_status
    ;;
  agents-chat)
    run_agents_chat
    ;;
  agents-health)
    run_agents_health
    ;;
  agents-e2e)
    run_agents_e2e
    ;;
  studio-status)
    run_studio_status
    ;;
  studio-files)
    run_studio_files
    ;;
  studio-finetune)
    run_studio_finetune
    ;;
  studio-libraries)
    run_studio_libraries
    ;;
  studio-conversations)
    run_studio_conversations
    ;;
  studio-models)
    run_studio_models
    ;;
  infra-health)
    run_infra_health
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
    usage >&2
    exit 2
    ;;
esac
