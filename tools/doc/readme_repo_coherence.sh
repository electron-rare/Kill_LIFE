#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

README_FILE="${ROOT_DIR}/README.md"
LABELS_FILE="${ROOT_DIR}/docs/LABELS.md"
PLAN_FILE="${ROOT_DIR}/specs/03_plan.md"
TASKS_FILE="${ROOT_DIR}/specs/04_tasks.md"
REPORT_FILE="${ROOT_DIR}/artifacts/doc/readme_repo_audit.md"

VERBOSE=0
YES=0

FINDINGS=()
PASSES=()

COUNT_DRIFT=0
BROKEN_LINKS=0
MISSING_TEMPLATES=0
BULK_EDIT_LABEL_DRIFT=0
UNSUPPORTED_COMPLIANCE_AGENT=0
GENERATED_PATH_DRIFT=0
ZEROCLAW_PATH_DRIFT=0
KICAD_VERSION_DRIFT=0

usage() {
  cat <<'EOF'
Usage: bash tools/doc/readme_repo_coherence.sh <audit|plan|all> [options]

Automate the README/repo coherence loop:
  - audit the documented claims against the repository state
  - refresh the current canonical plan/todo files
  - chain both steps in one command

Commands:
  audit   Write a Markdown audit report and exit non-zero if findings remain
  plan    Refresh specs/03_plan.md and specs/04_tasks.md auto-managed sections
  all     Run audit, then plan

Options:
  --report PATH  Override the Markdown report path
  --yes          Allow updates to tracked plan/todo files
  --verbose      Print progress logs
  -h, --help     Show this help

Examples:
  bash tools/doc/readme_repo_coherence.sh audit
  bash tools/doc/readme_repo_coherence.sh plan --yes
  bash tools/doc/readme_repo_coherence.sh all --yes
EOF
}

log() {
  if [[ "${VERBOSE}" == "1" ]]; then
    printf '[readme-repo-coherence] %s\n' "$*"
  fi
}

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

record_pass() {
  PASSES+=("$1")
}

record_finding() {
  local severity="$1"
  local message="$2"
  local ref="$3"
  FINDINGS+=("${severity}|${message}|${ref}")
}

extract_readme_refs() {
  python3 - "$README_FILE" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
seen = set()

def keep(path: str) -> bool:
    if not path:
        return False
    if path.startswith(("http://", "https://", "mailto:", "#")):
        return False
    if path.startswith("data:"):
        return False
    return True

for match in re.finditer(r'\[[^\]]+\]\(([^)]+)\)', text):
    path = match.group(1).strip()
    if keep(path) and path not in seen:
        seen.add(path)
        print(path)

for match in re.finditer(r'src="([^"]+)"', text):
    path = match.group(1).strip()
    if keep(path) and path not in seen:
        seen.add(path)
        print(path)
PY
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

has_markers() {
  local file="$1"
  local begin_marker="$2"
  local end_marker="$3"

  [[ -f "${file}" ]] || return 1
  rg -qF "${begin_marker}" "${file}" && rg -qF "${end_marker}" "${file}"
}

run_audit() {
  local claim actual path ref total_findings report_dir
  local valid_ai_labels readme_ai_labels invalid_ai_labels

  FINDINGS=()
  PASSES=()

  COUNT_DRIFT=0
  BROKEN_LINKS=0
  MISSING_TEMPLATES=0
  BULK_EDIT_LABEL_DRIFT=0
  UNSUPPORTED_COMPLIANCE_AGENT=0
  GENERATED_PATH_DRIFT=0
  ZEROCLAW_PATH_DRIFT=0
  KICAD_VERSION_DRIFT=0

  log "Auditing local README links and assets"
  while IFS= read -r ref; do
    [[ -n "${ref}" ]] || continue
    path="${ROOT_DIR}/${ref}"
    if [[ ! -e "${path}" ]]; then
      BROKEN_LINKS=1
      record_finding \
        high \
        "README local reference is broken: \`${ref}\`" \
        "README.md"
    fi
  done < <(extract_readme_refs)
  if [[ "${BROKEN_LINKS}" == "0" ]]; then
    record_pass "README linked local files and image assets resolve on disk."
  fi

  log "Auditing count claims"
  claim="$(rg -o 'specs/[^\n]*# [0-9]+ specs' "${README_FILE}" | head -n1 | rg -o '[0-9]+' || true)"
  actual="$(find "${ROOT_DIR}/specs" -maxdepth 1 -type f | wc -l | tr -d ' ')"
  if [[ -n "${claim}" && "${claim}" != "${actual}" ]]; then
    COUNT_DRIFT=1
    record_finding high "README claims ${claim} spec files, repository has ${actual} in \`specs/\`." "README.md"
  fi

  claim="$(rg -o '[0-9]+ agents spécialisés' "${README_FILE}" | head -n1 | rg -o '[0-9]+' || true)"
  actual="$(find "${ROOT_DIR}/agents" -maxdepth 1 -type f | wc -l | tr -d ' ')"
  if [[ -n "${claim}" && "${claim}" != "${actual}" ]]; then
    COUNT_DRIFT=1
    record_finding high "README claims ${claim} agents, repository has ${actual} in \`agents/\`." "README.md"
  fi

  claim="$(rg -o '[0-9]+ prompts dans' "${README_FILE}" | head -n1 | rg -o '[0-9]+' || true)"
  actual="$(find "${ROOT_DIR}/.github/prompts" -maxdepth 1 -type f | wc -l | tr -d ' ')"
  if [[ -n "${claim}" && "${claim}" != "${actual}" ]]; then
    COUNT_DRIFT=1
    record_finding high "README claims ${claim} prompts, repository has ${actual} in \`.github/prompts/\`." "README.md"
  fi

  claim="$(rg -o '[0-9]+ workflows GitHub Actions' "${README_FILE}" | head -n1 | rg -o '[0-9]+' || true)"
  actual="$(find "${ROOT_DIR}/.github/workflows" -maxdepth 1 -type f | wc -l | tr -d ' ')"
  if [[ -n "${claim}" && "${claim}" != "${actual}" ]]; then
    COUNT_DRIFT=1
    record_finding high "README claims ${claim} GitHub workflows, repository has ${actual} in \`.github/workflows/\`." "README.md"
  fi

  claim="$(rg -o '[0-9]+ serveurs MCP' "${README_FILE}" | head -n1 | rg -o '[0-9]+' || true)"
  actual="$(python3 - "${ROOT_DIR}/mcp.json" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
print(len(data.get("mcpServers", {})))
PY
)"
  if [[ -n "${claim}" && "${claim}" != "${actual}" ]]; then
    COUNT_DRIFT=1
    record_finding high "README claims ${claim} MCP servers, repository has ${actual} in \`mcp.json\`." "README.md"
  fi

  if [[ "${COUNT_DRIFT}" == "0" ]]; then
    record_pass "README numeric claims match repository counts for specs, agents, prompts, workflows, and MCP servers."
  fi

  log "Auditing issue templates"
  if [[ ! -d "${ROOT_DIR}/.github/ISSUE_TEMPLATE" ]] || ! find "${ROOT_DIR}/.github/ISSUE_TEMPLATE" -maxdepth 1 -type f | grep -q .; then
    MISSING_TEMPLATES=1
    record_finding \
      high \
      "Operator docs reference \`.github/ISSUE_TEMPLATE/\`, but the directory is missing or empty." \
      ".github/ISSUE_TEMPLATE/"
  else
    record_pass "GitHub issue templates exist and can back the documented intake flow."
  fi

  log "Auditing ai:* labels"
  valid_ai_labels="$(rg -o 'ai:[a-z-]+' "${LABELS_FILE}" | sort -u || true)"
  readme_ai_labels="$(rg -o 'ai:[a-z-]+' "${README_FILE}" | sort -u || true)"
  invalid_ai_labels="$(
    comm -23 \
      <(printf '%s\n' "${readme_ai_labels}" | sed '/^$/d') \
      <(printf '%s\n' "${valid_ai_labels}" | sed '/^$/d')
  )"
  if [[ -n "${invalid_ai_labels}" ]]; then
    BULK_EDIT_LABEL_DRIFT=1
    while IFS= read -r path; do
      [[ -n "${path}" ]] || continue
      record_finding medium "README uses unsupported automation label \`${path}\`." "README.md"
    done <<< "${invalid_ai_labels}"
  fi

  if rg -uu -q 'ai:hw|type:hardware' \
      "${ROOT_DIR}/README.md" \
      "${ROOT_DIR}/docs/plans/09_plan_bulk_edit_hardware.md" \
      "${ROOT_DIR}/.github/prompts/plan_wizard_bulk_edit_hw.prompt.md"; then
    BULK_EDIT_LABEL_DRIFT=1
    record_finding \
      medium \
      "The bulk-edit hardware flow still references obsolete labels (\`ai:hw\` or \`type:hardware\`) instead of the documented \`type:systems\`/ \`scope:hardware\` + \`ai:*\` contract." \
      "README.md"
  fi

  if [[ "${BULK_EDIT_LABEL_DRIFT}" == "0" ]]; then
    record_pass "README and hardware bulk-edit entrypoints use the documented automation labels."
  fi

  if rg -q 'issue_label_required: "ai:codex"' "${ROOT_DIR}/specs/constraints.yaml" || \
      rg -q 'ai:codex' "${ROOT_DIR}/docs/AI_WORKFLOWS.md"; then
    BULK_EDIT_LABEL_DRIFT=1
    record_finding \
      medium \
      "The canonical label contract still contains the legacy \`ai:codex\` label instead of the documented \`ai:*\` flow." \
      "specs/constraints.yaml"
  fi

  log "Auditing agent-role wording"
  if rg -q "agent Conformité" "${README_FILE}" && \
      ! find "${ROOT_DIR}/agents" "${ROOT_DIR}/.github/agents" -maxdepth 1 -type f | rg -q 'compliance'; then
    UNSUPPORTED_COMPLIANCE_AGENT=1
    record_finding \
      medium \
      "README mentions an \`agent Conformité\`, but the repository only defines PM, Architect, Firmware, HW, QA, and Doc agents." \
      "README.md"
  else
    record_pass "README agent-role wording matches the defined agent set."
  fi

  log "Auditing generated runtime paths"
  if rg -q '^- `\.crazy-life/runs/` : état des runs locaux$' "${README_FILE}" && [[ ! -e "${ROOT_DIR}/.crazy-life/runs" ]]; then
    GENERATED_PATH_DRIFT=1
    record_finding \
      medium \
      "README presents \`.crazy-life/runs/\` as if it were present in a fresh checkout, but it is runtime-generated state." \
      "README.md"
  fi
  if rg -q '^- `\.crazy-life/backups/workflows/` : révisions et restores$' "${README_FILE}" && [[ ! -e "${ROOT_DIR}/.crazy-life/backups/workflows" ]]; then
    GENERATED_PATH_DRIFT=1
    record_finding \
      medium \
      "README presents \`.crazy-life/backups/workflows/\` as if it were present in a fresh checkout, but it is runtime-generated state." \
      "README.md"
  fi
  if [[ "${GENERATED_PATH_DRIFT}" == "0" ]]; then
    record_pass "README distinguishes versioned paths from runtime-generated crazy_life state."
  fi

  log "Auditing ZeroClaw launcher wording"
  if rg -q '~/.cargo/bin' "${README_FILE}" && \
      rg -q 'ZEROCLAW_BIN="\$\{ZEROCLAW_BIN:-\$ROOT_DIR/zeroclaw/target/release/zeroclaw\}"' "${ROOT_DIR}/tools/ai/zeroclaw_stack_up.sh" && \
      ! rg -q 'command -v zeroclaw' "${README_FILE}"; then
    ZEROCLAW_PATH_DRIFT=1
    record_finding \
      low \
      "README says the supported ZeroClaw path is \`~/.cargo/bin\`, but the launcher first tries the repo-local build and only then falls back to \`command -v zeroclaw\`." \
      "README.md"
  else
    record_pass "README ZeroClaw launcher wording matches the actual fallback order."
  fi

  log "Auditing KiCad wording"
  if rg -q 'KiCad 10 first' "${README_FILE}" && \
      rg -q 'version_min: 9' "${ROOT_DIR}/specs/constraints.yaml" && \
      ! rg -q 'KiCad ≥ 9 minimum' "${README_FILE}"; then
    KICAD_VERSION_DRIFT=1
    record_finding \
      low \
      "README should clarify that the preferred CAD path is KiCad 10-first while the minimum repo constraint remains KiCad 9." \
      "README.md"
  else
    record_pass "README KiCad wording is explicit about preferred versus minimum supported versions."
  fi

  report_dir="$(dirname -- "${REPORT_FILE}")"
  mkdir -p "${report_dir}"

  {
    printf '# README vs repo audit\n\n'
    printf 'Generated: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf '## Summary\n\n'
    printf -- '- Findings: %s\n' "${#FINDINGS[@]}"
    printf -- '- Report path: `%s`\n' "${REPORT_FILE#${ROOT_DIR}/}"
    printf -- '- Scope: `README.md`, issue templates, label-contract docs, bulk-edit hardware entrypoints, canonical plan/todo files\n\n'

    if [[ "${#FINDINGS[@]}" -gt 0 ]]; then
      printf '## Findings\n\n'
      for entry in "${FINDINGS[@]}"; do
        IFS='|' read -r severity message ref <<< "${entry}"
        printf -- '- [%s] %s (%s)\n' "${severity}" "${message}" "${ref}"
      done
      printf '\n'
    else
      printf '## Findings\n\n'
      printf -- '- None.\n\n'
    fi

    printf '## Passed checks\n\n'
    for entry in "${PASSES[@]}"; do
      printf -- '- %s\n' "${entry}"
    done
    printf '\n'
  } > "${REPORT_FILE}"

  total_findings="${#FINDINGS[@]}"
  log "Wrote ${REPORT_FILE}"
  if [[ "${total_findings}" -gt 0 ]]; then
    return 1
  fi
  return 0
}

update_plan_files() {
  local plan_tmp tasks_tmp findings_open

  [[ "${YES}" == "1" ]] || die "Refusing to edit tracked files without --yes."
  if ! has_markers "${PLAN_FILE}" "<!-- BEGIN AUTO README-REPO PLAN -->" "<!-- END AUTO README-REPO PLAN -->"; then
    log "Skipping plan refresh in ${PLAN_FILE}: README-specific markers are absent"
    return 0
  fi
  if ! has_markers "${TASKS_FILE}" "<!-- BEGIN AUTO README-REPO TASKS -->" "<!-- END AUTO README-REPO TASKS -->"; then
    log "Skipping todo refresh in ${TASKS_FILE}: README-specific markers are absent"
    return 0
  fi

  findings_open="${#FINDINGS[@]}"
  plan_tmp="$(mktemp)"
  tasks_tmp="$(mktemp)"

  {
    printf -- '- Audit report: `%s`\n' "${REPORT_FILE#${ROOT_DIR}/}"
    printf -- '- Open findings: `%s`\n' "${findings_open}"
    printf -- '- Batch A - audit script and report: `[x]` done.\n'
    if [[ "${MISSING_TEMPLATES}" == "0" ]]; then
      printf -- '- Batch B - issue templates aligned with the documented workflow categories: `[x]` done.\n'
    else
      printf -- '- Batch B - issue templates aligned with the documented workflow categories: `[ ]` open.\n'
    fi
    if [[ "${BULK_EDIT_LABEL_DRIFT}" == "0" && "${UNSUPPORTED_COMPLIANCE_AGENT}" == "0" && "${GENERATED_PATH_DRIFT}" == "0" && "${ZEROCLAW_PATH_DRIFT}" == "0" && "${KICAD_VERSION_DRIFT}" == "0" ]]; then
      printf -- '- Batch C - README/operator contract alignment: `[x]` done.\n'
    else
      printf -- '- Batch C - README/operator contract alignment: `[ ]` open.\n'
    fi
    if [[ "${findings_open}" == "0" ]]; then
      printf -- '- Next useful lot: rerun this script after the next README, workflow-label, or repo-structure change.\n'
    else
      printf -- '- Next useful lot: close the remaining audit findings listed in `%s`.\n' "${REPORT_FILE#${ROOT_DIR}/}"
    fi
  } > "${plan_tmp}"

  {
    if [[ "${COUNT_DRIFT}" == "0" && "${BROKEN_LINKS}" == "0" ]]; then
      printf -- '- [x] T-RC-001 - Keep README claims and local references aligned with repository reality.\n'
    else
      printf -- '- [ ] T-RC-001 - Keep README claims and local references aligned with repository reality.\n'
    fi
    printf -- '  - Evidence: `bash tools/doc/readme_repo_coherence.sh audit`\n'

    if [[ "${BULK_EDIT_LABEL_DRIFT}" == "0" && "${UNSUPPORTED_COMPLIANCE_AGENT}" == "0" ]]; then
      printf -- '- [x] T-RC-002 - Align labels and agent roles used in README, prompts, and plan docs.\n'
    else
      printf -- '- [ ] T-RC-002 - Align labels and agent roles used in README, prompts, and plan docs.\n'
    fi
    printf -- '  - Evidence: `rg -uu -n "ai:hw|type:hardware|agent Conformité" README.md docs .github`\n'

    if [[ "${MISSING_TEMPLATES}" == "0" ]]; then
      printf -- '- [x] T-RC-003 - Provide issue templates that match the documented workflow menu.\n'
    else
      printf -- '- [ ] T-RC-003 - Provide issue templates that match the documented workflow menu.\n'
    fi
    printf -- '  - Evidence: `.github/ISSUE_TEMPLATE/`\n'

    if [[ "${GENERATED_PATH_DRIFT}" == "0" && "${ZEROCLAW_PATH_DRIFT}" == "0" && "${KICAD_VERSION_DRIFT}" == "0" ]]; then
      printf -- '- [x] T-RC-004 - Clarify runtime-generated paths, ZeroClaw launcher fallback, and KiCad version policy.\n'
    else
      printf -- '- [ ] T-RC-004 - Clarify runtime-generated paths, ZeroClaw launcher fallback, and KiCad version policy.\n'
    fi
    printf -- '  - Evidence: `README.md`\n'

    printf -- '- [x] T-RC-005 - Regenerate the canonical plan/todo files from the audit loop.\n'
    printf -- '  - Evidence: `bash tools/doc/readme_repo_coherence.sh plan --yes`\n'

    if [[ "${findings_open}" == "0" ]]; then
      printf -- '- [x] T-RC-006 - Close the current coherence lot on a clean audit rerun.\n'
      printf -- '  - Evidence: `%s`\n' "${REPORT_FILE#${ROOT_DIR}/}"
    else
      printf -- '- [ ] T-RC-006 - Close the current coherence lot on a clean audit rerun.\n'
      printf -- '  - Evidence: `%s`\n' "${REPORT_FILE#${ROOT_DIR}/}"
    fi
  } > "${tasks_tmp}"

  replace_block "${PLAN_FILE}" "<!-- BEGIN AUTO README-REPO PLAN -->" "<!-- END AUTO README-REPO PLAN -->" "${plan_tmp}"
  replace_block "${TASKS_FILE}" "<!-- BEGIN AUTO README-REPO TASKS -->" "<!-- END AUTO README-REPO TASKS -->" "${tasks_tmp}"

  rm -f "${plan_tmp}" "${tasks_tmp}"
}

COMMAND=""
if [[ $# -eq 0 ]]; then
  usage >&2
  exit 2
fi

COMMAND="$1"
shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report)
      shift
      [[ $# -gt 0 ]] || die "Missing value for --report"
      REPORT_FILE="$1"
      ;;
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
  audit)
    if run_audit; then
      exit 0
    fi
    exit 1
    ;;
  plan)
    run_audit || true
    update_plan_files
    ;;
  all)
    audit_rc=0
    run_audit || audit_rc=$?
    update_plan_files
    exit "${audit_rc}"
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
