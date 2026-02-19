#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# setup_repo.sh — GitHub CLI bootstrap for this template
#
# What it does:
#  1) Creates/updates all recommended labels (ai:*, type:*, scope:*, prio:*, risk:*, needs:*).
#  2) Optionally enables Discussions.
#  3) Configures branch protection on the target branch with required checks.
#
# Usage:
#   bash setup_repo.sh owner/repo
#
# Env:
#   BRANCH=main
#   ENABLE_DISCUSSIONS=0|1
#   REQUIRE_BUILD_CHECKS=0|1
#   DRY_RUN=0|1
#
# Notes:
#   - Requires: gh >= 2.x, authenticated (gh auth login)
#   - Branch protection requires admin rights.
# -----------------------------------------------------------------------------

REPO_FULL="${1:-}"
BRANCH="${BRANCH:-main}"
ENABLE_DISCUSSIONS="${ENABLE_DISCUSSIONS:-0}"
REQUIRE_BUILD_CHECKS="${REQUIRE_BUILD_CHECKS:-1}"
DRY_RUN="${DRY_RUN:-0}"

if [[ -z "${REPO_FULL}" ]]; then
  echo "Usage: $0 <owner/repo>" >&2
  exit 2
fi

OWNER="${REPO_FULL%/*}"
REPO="${REPO_FULL#*/}"

run() {
  if [[ "${DRY_RUN}" == "1" ]]; then
    echo "[dry-run] $*"
  else
    eval "$@"
  fi
}

need_gh() {
  command -v gh >/dev/null 2>&1 || { echo "gh not found. Install GitHub CLI first." >&2; exit 1; }
  gh auth status -h github.com >/dev/null 2>&1 || { echo "Not authenticated. Run: gh auth login" >&2; exit 1; }
}

create_label() {
  local name="$1"; local color="$2"; local desc="$3"
  run "gh label create \"${name}\" -R \"${REPO_FULL}\" --color \"${color}\" --description \"${desc}\" --force >/dev/null"
}

setup_labels() {
  echo "==> Creating/updating labels in ${REPO_FULL} ..."

  # ai:*
  create_label "ai:spec"  "0E8A16" "Agent scope: generate/normalize specification (RFC2119)."
  create_label "ai:plan"  "1D76DB" "Agent scope: architecture/plan/ADR/test strategy."
  create_label "ai:tasks" "5319E7" "Agent scope: task breakdown, checklists, backlog."
  create_label "ai:impl"  "FBCA04" "Agent scope: implementation within allowed directories."
  create_label "ai:qa"    "D93F0B" "Agent scope: tests, edge cases, validation, hardening."
  create_label "ai:docs"  "0B4F6C" "Agent scope: documentation only."
  create_label "ai:hold"  "B60205" "STOP automation. Human review required."

  # type:*
  create_label "type:feature"     "C2E0C6" "Feature request."
  create_label "type:bug"         "B60205" "Bug report."
  create_label "type:consulting"  "D4C5F9" "Consulting-style intake/cadrage."
  create_label "type:systems"     "A2EEEF" "Systems/engineering/architecture."
  create_label "type:design"      "F9D0C4" "UX/UI/industrial design."
  create_label "type:creative"    "FAD8C7" "Creative/narrative/content production."
  create_label "type:spike"       "FEF2C0" "R&D spike, time-boxed."
  create_label "type:compliance"  "0052CC" "Compliance / release readiness."
  create_label "type:agentics"    "6F42C1" "Agentic workflow updates."

  # scope:*
  create_label "scope:firmware" "1F6FEB" "Firmware scope."
  create_label "scope:hardware" "0E8A16" "Hardware scope."
  create_label "scope:docs"     "0B4F6C" "Docs scope."
  create_label "scope:ux"       "FBCA04" "UX/UI scope."
  create_label "scope:content"  "FAD8C7" "Creative content scope."
  create_label "scope:infra"    "5319E7" "CI/CD & repo infrastructure scope."

  # risk:*
  create_label "risk:low"  "C2E0C6" "Low risk."
  create_label "risk:med"  "FBCA04" "Medium risk."
  create_label "risk:high" "B60205" "High risk."

  # prio:*
  create_label "prio:p0" "B60205" "P0 urgent."
  create_label "prio:p1" "D93F0B" "P1 high."
  create_label "prio:p2" "FBCA04" "P2 normal."
  create_label "prio:p3" "C2E0C6" "P3 low."

  # needs:*
  create_label "needs:triage"   "EDEDED" "Needs triage."
  create_label "needs:decision" "EDEDED" "Needs decision / arbitration."
  create_label "needs:review"   "EDEDED" "Needs review."
  create_label "needs:assets"   "EDEDED" "Needs assets (design/content)."

  echo "==> Labels done."
}

enable_discussions() {
  if [[ "${ENABLE_DISCUSSIONS}" != "1" ]]; then
    echo "==> Discussions: skipped (ENABLE_DISCUSSIONS=0)."
    return 0
  fi

  echo "==> Enabling Discussions on ${REPO_FULL} ..."

  local repo_id
  repo_id="$(gh api graphql -f owner="${OWNER}" -f name="${REPO}" -f query='
    query($owner:String!, $name:String!) {
      repository(owner:$owner, name:$name) { id hasDiscussionsEnabled }
    }' --jq '.data.repository.id')"

  run "gh api graphql -f repositoryId=\"${repo_id}\" -F enabled=true -f query='\
    mutation($repositoryId:ID!, $enabled:Boolean!) {\
      updateRepository(input:{repositoryId:$repositoryId, hasDiscussionsEnabled:$enabled}) {\
        repository { name hasDiscussionsEnabled }\
      }\
    }' >/dev/null"

  echo "==> Discussions enabled."
}

setup_branch_protection() {
  echo "==> Configuring branch protection for ${REPO_FULL}:${BRANCH} ..."

  # Required check contexts (GitHub Actions job names):
  # These MUST match the check names you see in PR -> Checks.
  # If you change workflow/job names, update this list.
  local -a contexts
  contexts+=("PR Label Enforcement / label-enforcement")
  contexts+=("Scope Guard / guard")

  if [[ "${REQUIRE_BUILD_CHECKS}" == "1" ]]; then
    contexts+=("Firmware CI / pio (esp32s3_arduino)")
    contexts+=("Firmware CI / pio (esp32_arduino)")
    contexts+=("Firmware CI / pio (native)")
    contexts+=("Hardware CI (KiCad) / hw")
    contexts+=("Compliance Gate / validate")
  fi

  # JSON array for contexts
  local contexts_json
  contexts_json="$(printf '%s\n' "${contexts[@]}" | python3 - <<'PY'
import sys, json
print(json.dumps([l.rstrip('\n') for l in sys.stdin if l.strip()]))
PY
  )"

  local body
  body="$(cat <<JSON
{
  "required_status_checks": {
    "strict": true,
    "contexts": ${contexts_json}
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
JSON
  )"

  if [[ "${DRY_RUN}" == "1" ]]; then
    echo "[dry-run] Would PUT /repos/${OWNER}/${REPO}/branches/${BRANCH}/protection with body:"
    echo "${body}"
    return 0
  fi

  gh api \
    --method PUT \
    -H "Accept: application/vnd.github+json" \
    "/repos/${OWNER}/${REPO}/branches/${BRANCH}/protection" \
    --input - <<<"${body}" >/dev/null

  echo "==> Branch protection enabled."
  echo "    Required checks:"
  printf '    - %s\n' "${contexts[@]}"
}

main() {
  need_gh
  setup_labels
  enable_discussions
  setup_branch_protection
  echo "✅ Done."
}

main
