#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

PLAN_FILE="${ROOT_DIR}/specs/03_plan.md"
TASKS_FILE="${ROOT_DIR}/specs/04_tasks.md"
STATUS_FILE="${ROOT_DIR}/artifacts/cockpit/useful_lots_status.md"
QUESTION_FILE="${ROOT_DIR}/artifacts/cockpit/next_question.md"
STATE_FILE="${ROOT_DIR}/artifacts/cockpit/last_validation.env"

COMMAND=""
VERBOSE=0
YES=0

README_STATUS="unknown"
MIRROR_STATUS="unknown"
STRICT_STATUS="not_run"
PYTHON_STATUS="not_run"
UPSTREAM_STATUS="unknown"
UPSTREAM_MODE="status"
NEXT_LOT="pending"
QUESTION_COUNT=0

QUESTION_ITEMS=()

usage() {
  cat <<'EOF'
Usage: bash tools/cockpit/lot_chain.sh <status|plan|run|all> [options]

Chain the next useful local lots with a single entrypoint:
  - auto-fix documentation/spec hygiene first
  - rerun canonical validations
  - stop only when a real manual choice is required

Commands:
  status   Refresh Markdown status/question artifacts without changing tracked files
  plan     Refresh specs/03_plan.md and specs/04_tasks.md from current status
  run      Execute auto-fix lots, rerun validations, refresh artifacts
  all      Run then refresh specs/03_plan.md and specs/04_tasks.md

Options:
  --yes      Allow updates to tracked files and the spec mirror
  --verbose  Print progress logs
  -h, --help Show this help

Artifacts:
  artifacts/cockpit/useful_lots_status.md
  artifacts/cockpit/next_question.md
  artifacts/cockpit/last_validation.env

Examples:
  bash tools/cockpit/lot_chain.sh status
  bash tools/cockpit/lot_chain.sh run --yes
  bash tools/cockpit/lot_chain.sh all --yes
EOF
}

log() {
  if [[ "${VERBOSE}" == "1" ]]; then
    printf '[lot-chain] %s\n' "$*"
  fi
}

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

replace_block() {
  local file="$1"
  local begin_marker="$2"
  local end_marker="$3"
  local content_file="$4"
  local tmp_file

  [[ -f "${file}" ]] || die "Missing file: ${file}"
  rg -qF "${begin_marker}" "${file}" || die "Missing marker ${begin_marker} in ${file}"
  rg -qF "${end_marker}" "${file}" || die "Missing marker ${end_marker} in ${file}"

  tmp_file="$(mktemp)"
  awk -v begin="${begin_marker}" -v end="${end_marker}" -v content="${content_file}" '
    $0 == begin {
      print
      while ((getline line < content) > 0) {
        print line
      }
      close(content)
      in_block = 1
      next
    }
    $0 == end {
      in_block = 0
      print
      next
    }
    !in_block {
      print
    }
  ' "${file}" > "${tmp_file}"

  mv "${tmp_file}" "${file}"
}

load_validation_state() {
  if [[ -f "${STATE_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${STATE_FILE}"
    STRICT_STATUS="${STRICT_STATUS:-not_run}"
    PYTHON_STATUS="${PYTHON_STATUS:-not_run}"
    STRICT_AT="${STRICT_AT:-}"
    PYTHON_AT="${PYTHON_AT:-}"
  else
    STRICT_AT=""
    PYTHON_AT=""
  fi
}

save_validation_state() {
  local state_dir
  state_dir="$(dirname -- "${STATE_FILE}")"
  mkdir -p "${state_dir}"

  cat > "${STATE_FILE}" <<EOF
STRICT_STATUS="${STRICT_STATUS}"
STRICT_AT="${STRICT_AT:-}"
PYTHON_STATUS="${PYTHON_STATUS}"
PYTHON_AT="${PYTHON_AT:-}"
EOF
}

refresh_auto_lot_status() {
  if bash "${ROOT_DIR}/tools/doc/readme_repo_coherence.sh" audit >/dev/null 2>&1; then
    README_STATUS="done"
  else
    README_STATUS="open"
  fi

  if bash "${ROOT_DIR}/tools/specs/sync_spec_mirror.sh" check >/dev/null 2>&1; then
    MIRROR_STATUS="done"
  else
    MIRROR_STATUS="open"
  fi
}

refresh_upstream_autonomous_lane() {
  local mode="${1:-${UPSTREAM_MODE}}"

  if bash "${ROOT_DIR}/tools/run_autonomous_next_lots.sh" "${mode}" >/dev/null 2>&1; then
    UPSTREAM_STATUS="synced"
    UPSTREAM_MODE="${mode}"
  else
    UPSTREAM_STATUS="failed"
  fi
}

collect_manual_questions() {
  local file match line_no line_text clean_text item_id recommended recommended_text

  QUESTION_ITEMS=()

  while IFS= read -r file; do
    [[ -n "${file}" ]] || continue
    match="$(rg -n '^- \[ \]' "${ROOT_DIR}/${file}" | head -n 1 || true)"
    if [[ -n "${match}" ]]; then
      line_no="${match%%:*}"
      line_text="${match#*:}"
      clean_text="$(printf '%s\n' "${line_text}" | sed -E 's/^- \[ \] //')"
      item_id="$(printf '%s\n' "${line_text}" | sed -E 's/^- \[ \] ([A-Z]-[0-9]+).*/\1/' )"
      if [[ "${item_id}" == "${line_text}" ]]; then
        item_id="$(printf '%s\n' "${file}" | sed 's#specs/##; s#\.md##')"
      fi
      if item_is_optional "${file}" "${item_id}"; then
        continue
      fi
      QUESTION_ITEMS+=("${item_id}|${file}|${line_no}|${clean_text}")
    fi
  done <<'EOF'
specs/mcp_tasks.md
specs/zeroclaw_dual_hw_todo.md
EOF

  QUESTION_COUNT="${#QUESTION_ITEMS[@]}"
  mkdir -p "$(dirname -- "${QUESTION_FILE}")"

  if [[ "${QUESTION_COUNT}" -eq 0 ]]; then
    NEXT_LOT="none"
    {
      printf '# Next required question\n\n'
      printf -- '- None. No curated manual backlog item is currently open.\n'
    } > "${QUESTION_FILE}"
    return 0
  fi

  NEXT_LOT="question"
  recommended=""
  recommended_text=""
  for item in "${QUESTION_ITEMS[@]}"; do
    IFS='|' read -r item_id file line_no line_text <<< "${item}"
    if [[ "${file}" == "specs/zeroclaw_dual_hw_todo.md" ]]; then
      recommended="${item_id}"
      recommended_text="${line_text}"
      break
    fi
  done
  if [[ -z "${recommended}" ]]; then
    IFS='|' read -r recommended _ _ recommended_text <<< "${QUESTION_ITEMS[0]}"
  fi
  {
    printf '# Next required question\n\n'
    printf 'No more auto-fix lot is pending. A manual choice is now required to set the next active plan.\n\n'
    printf '## Recommended default\n\n'
    printf -- '- `%s` — %s\n\n' "${recommended}" "${recommended_text}"
    printf '## Open curated choices\n\n'
    for item in "${QUESTION_ITEMS[@]}"; do
      IFS='|' read -r label file line_no line_text <<< "${item}"
      printf -- '- `%s` in `%s:%s` — %s\n' "${label}" "${file}" "${line_no}" "${line_text}"
    done
  } > "${QUESTION_FILE}"
}

item_is_optional() {
  local file="$1"
  local item_id="$2"

  awk -v item="${item_id}" '
    $0 ~ "^- \\[ \\] " item {
      in_item = 1
      next
    }
    in_item && $0 ~ "^- \\[[ x]\\] [A-Z]-[0-9]+" {
      exit
    }
    in_item {
      lower = tolower($0)
      if (lower ~ /statut:[[:space:]]*optionnel/ ||
          lower ~ /optionnel tant que/ ||
          lower ~ /aucun lot automatique supplementaire n.est pertinent/ ||
          lower ~ /blocked by host environment/) {
        found = 1
      }
    }
    END {
      exit(found ? 0 : 1)
    }
  ' "${ROOT_DIR}/${file}"
}

write_status_report() {
  local status_dir
  status_dir="$(dirname -- "${STATUS_FILE}")"
  mkdir -p "${status_dir}"

  {
    printf '# Useful lot chain status\n\n'
    printf 'Generated: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf '## Auto-fix lots\n\n'
    printf -- '- README/repo coherence: `%s`\n' "${README_STATUS}"
    printf -- '  - Command: `bash tools/doc/readme_repo_coherence.sh all --yes`\n'
    printf -- '  - Evidence: `artifacts/doc/readme_repo_audit.md`\n'
    printf -- '- Spec mirror sync: `%s`\n' "${MIRROR_STATUS}"
    printf -- '  - Command: `bash tools/specs/sync_spec_mirror.sh all --yes`\n'
    printf -- '  - Evidence: `artifacts/specs/mirror_sync_report.md`\n\n'
    printf -- '- MCP/CAD runtime lane sync: `%s`\n' "${UPSTREAM_STATUS}"
    printf -- '  - Command: `bash tools/run_autonomous_next_lots.sh status`\n'
    printf -- '  - Evidence: `docs/plans/18_plan_enchainement_autonome_des_lots_utiles.md`\n\n'

    printf '## Validations\n\n'
    printf -- '- Strict spec contract: `%s`' "${STRICT_STATUS}"
    if [[ -n "${STRICT_AT:-}" ]]; then
      printf ' at `%s`' "${STRICT_AT}"
    fi
    printf '\n'
    printf -- '  - Command: `python3 tools/validate_specs.py --strict --require-mirror-sync`\n'
    printf -- '- Stable Python suite: `%s`' "${PYTHON_STATUS}"
    if [[ -n "${PYTHON_AT:-}" ]]; then
      printf ' at `%s`' "${PYTHON_AT}"
    fi
    printf '\n'
    printf -- '  - Command: `bash tools/test_python.sh --suite stable`\n\n'

    printf '## Next step\n\n'
    if [[ "${NEXT_LOT}" == "question" ]]; then
      printf -- '- Manual choice required. See `%s`.\n' "${QUESTION_FILE#${ROOT_DIR}/}"
    elif [[ "${NEXT_LOT}" == "none" ]]; then
      printf -- '- No curated manual backlog item is currently open.\n'
    else
      printf -- '- Continue auto-fix lots until both are done.\n'
    fi
  } > "${STATUS_FILE}"
}

update_plan_files() {
  local plan_tmp tasks_tmp

  [[ "${YES}" == "1" ]] || die "Refusing to update tracked plan/todo files without --yes."

  plan_tmp="$(mktemp)"
  tasks_tmp="$(mktemp)"

  {
    printf -- '- Auto-fix lots pending: '
    if [[ "${README_STATUS}" == "done" && "${MIRROR_STATUS}" == "done" ]]; then
      printf '`0`\n'
    else
      printf '`1+`\n'
    fi
    printf -- '- README/repo coherence: `%s`\n' "${README_STATUS}"
    printf -- '- Spec mirror sync: `%s`\n' "${MIRROR_STATUS}"
    printf -- '- MCP/CAD runtime lane sync: `%s`\n' "${UPSTREAM_STATUS}"
    printf -- '- Strict spec contract: `%s`\n' "${STRICT_STATUS}"
    printf -- '- Stable Python suite: `%s`\n' "${PYTHON_STATUS}"
    if [[ "${NEXT_LOT}" == "question" ]]; then
      printf -- '- Next real need: ask the operator to choose the next manual lot from `%s`.\n' "${QUESTION_FILE#${ROOT_DIR}/}"
    elif [[ "${NEXT_LOT}" == "none" ]]; then
      printf -- '- Next real need: none detected in the curated backlog list.\n'
    else
      printf -- '- Next useful lot: keep running the auto-fix chain.\n'
    fi
  } > "${plan_tmp}"

  {
    if [[ "${README_STATUS}" == "done" ]]; then
      printf -- '- [x] T-LC-001 - Keep the README/repo coherence lot clean via the dedicated audit loop.\n'
    else
      printf -- '- [ ] T-LC-001 - Keep the README/repo coherence lot clean via the dedicated audit loop.\n'
    fi
    printf -- '  - Evidence: `artifacts/doc/readme_repo_audit.md`\n'

    if [[ "${MIRROR_STATUS}" == "done" ]]; then
    printf -- '- [x] T-LC-002 - Keep the exported spec mirror synchronized with the canonical `specs/` tree.\n'
    else
      printf -- '- [ ] T-LC-002 - Keep the exported spec mirror synchronized with the canonical `specs/` tree.\n'
    fi
    printf -- '  - Evidence: `artifacts/specs/mirror_sync_report.md`\n'

    if [[ "${UPSTREAM_STATUS}" == "synced" ]]; then
      printf -- '- [x] T-LC-003 - Keep the upstream MCP/CAD runtime lane docs synchronized with the current local state.\n'
    else
      printf -- '- [ ] T-LC-003 - Keep the upstream MCP/CAD runtime lane docs synchronized with the current local state.\n'
    fi
    printf -- '  - Evidence: `docs/plans/18_plan_enchainement_autonome_des_lots_utiles.md`\n'

    if [[ "${STRICT_STATUS}" == "passed" ]]; then
      printf -- '- [x] T-LC-004 - Revalidate the strict spec contract after each auto-fix run.\n'
    else
      printf -- '- [ ] T-LC-004 - Revalidate the strict spec contract after each auto-fix run.\n'
    fi
    printf -- '  - Evidence: `python3 tools/validate_specs.py --strict --require-mirror-sync`\n'

    if [[ "${PYTHON_STATUS}" == "passed" ]]; then
      printf -- '- [x] T-LC-005 - Re-run the stable Python suite after the chained lots.\n'
    else
      printf -- '- [ ] T-LC-005 - Re-run the stable Python suite after the chained lots.\n'
    fi
    printf -- '  - Evidence: `bash tools/test_python.sh --suite stable`\n'

    if [[ "${NEXT_LOT}" == "question" ]]; then
      printf -- '- [ ] T-LC-006 - Choose the next manual lot once automation reaches a real fork.\n'
      printf -- '  - Evidence: `%s`\n' "${QUESTION_FILE#${ROOT_DIR}/}"
    else
      printf -- '- [x] T-LC-006 - Choose the next manual lot once automation reaches a real fork.\n'
      printf -- '  - Evidence: `%s`\n' "${QUESTION_FILE#${ROOT_DIR}/}"
    fi
  } > "${tasks_tmp}"

  replace_block "${PLAN_FILE}" "<!-- BEGIN AUTO LOT-CHAIN PLAN -->" "<!-- END AUTO LOT-CHAIN PLAN -->" "${plan_tmp}"
  replace_block "${TASKS_FILE}" "<!-- BEGIN AUTO LOT-CHAIN TASKS -->" "<!-- END AUTO LOT-CHAIN TASKS -->" "${tasks_tmp}"

  rm -f "${plan_tmp}" "${tasks_tmp}"
}

run_auto_lots() {
  log "Running README/repo coherence loop"
  bash "${ROOT_DIR}/tools/doc/readme_repo_coherence.sh" all --yes
  README_STATUS="done"

  log "Running spec mirror sync loop"
  bash "${ROOT_DIR}/tools/specs/sync_spec_mirror.sh" all --yes
  MIRROR_STATUS="done"

  log "Refreshing upstream autonomous next-lots lane"
  refresh_upstream_autonomous_lane run
}

run_validations() {
  log "Running strict spec validation"
  if python3 "${ROOT_DIR}/tools/validate_specs.py" --strict --require-mirror-sync >/dev/null; then
    STRICT_STATUS="passed"
    STRICT_AT="$(date '+%Y-%m-%d %H:%M:%S %z')"
  else
    STRICT_STATUS="failed"
    STRICT_AT="$(date '+%Y-%m-%d %H:%M:%S %z')"
    save_validation_state
    die "Strict spec validation failed."
  fi

  log "Running stable Python suite"
  if bash "${ROOT_DIR}/tools/test_python.sh" --suite stable >/dev/null; then
    PYTHON_STATUS="passed"
    PYTHON_AT="$(date '+%Y-%m-%d %H:%M:%S %z')"
  else
    PYTHON_STATUS="failed"
    PYTHON_AT="$(date '+%Y-%m-%d %H:%M:%S %z')"
    save_validation_state
    die "Stable Python suite failed."
  fi

  save_validation_state
}

finalize_tracked_updates() {
  update_plan_files
  log "Re-synchronizing spec mirror after tracked plan/todo updates"
  bash "${ROOT_DIR}/tools/specs/sync_spec_mirror.sh" all --yes >/dev/null
  log "Re-running strict spec validation after tracked plan/todo updates"
  if python3 "${ROOT_DIR}/tools/validate_specs.py" --strict --require-mirror-sync >/dev/null; then
    STRICT_STATUS="passed"
    STRICT_AT="$(date '+%Y-%m-%d %H:%M:%S %z')"
  else
    STRICT_STATUS="failed"
    STRICT_AT="$(date '+%Y-%m-%d %H:%M:%S %z')"
    save_validation_state
    die "Strict spec validation failed after tracked plan/todo updates."
  fi
  save_validation_state
  refresh_state
  update_plan_files
}

refresh_state() {
  load_validation_state
  refresh_auto_lot_status
  refresh_upstream_autonomous_lane "${UPSTREAM_MODE}"
  collect_manual_questions
  write_status_report
}

if [[ $# -eq 0 ]]; then
  usage >&2
  exit 2
fi

COMMAND="$1"
shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes)
      YES=1
      ;;
    --verbose)
      VERBOSE=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
  shift
done

case "${COMMAND}" in
  status)
    refresh_state
    ;;
  plan)
    refresh_state
    finalize_tracked_updates
    ;;
  run)
    [[ "${YES}" == "1" ]] || die "Refusing to run auto-fix lots without --yes."
    run_auto_lots
    run_validations
    refresh_state
    ;;
  all)
    [[ "${YES}" == "1" ]] || die "Refusing to run the chain without --yes."
    run_auto_lots
    run_validations
    refresh_state
    finalize_tracked_updates
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

if [[ "${COMMAND}" == "run" || "${COMMAND}" == "all" ]]; then
  if [[ "${NEXT_LOT}" == "question" ]]; then
    exit 3
  fi
fi
