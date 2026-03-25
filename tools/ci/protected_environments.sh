#!/usr/bin/env bash
set -euo pipefail

# Configure GitHub deployment environments with protection rules.
# Requires: gh CLI authenticated with admin access.
#
# Usage:
#   tools/ci/protected_environments.sh [--dry-run]
#
# Creates two environments:
#   - staging:    auto-deploy, no reviewers
#   - production: requires 1 reviewer, wait timer 5 min

REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo '')}"
DRY_RUN=0

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

if [[ -z "$REPO" ]]; then
  echo "ERROR: Cannot determine repository." >&2
  exit 1
fi

create_environment() {
  local name="$1"
  local wait_timer="$2"
  local reviewers_json="$3"

  echo "--- Environment: $name ---"

  local payload
  payload=$(python3 -c "
import json, sys
data = {
    'wait_timer': $wait_timer,
    'prevent_self_review': False,
    'deployment_branch_policy': {
        'protected_branches': True,
        'custom_branch_policies': False
    }
}
reviewers = $reviewers_json
if reviewers:
    data['reviewers'] = reviewers
print(json.dumps(data))
")

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] PUT /repos/$REPO/environments/$name"
    echo "$payload" | python3 -m json.tool 2>/dev/null || echo "$payload"
    echo ""
    return
  fi

  gh api \
    --method PUT \
    -H "Accept: application/vnd.github+json" \
    "/repos/$REPO/environments/$name" \
    --input - <<< "$payload"

  echo "Created/updated environment: $name"
  echo ""
}

echo "Repository: $REPO"
echo ""

# staging: no wait, no reviewers
create_environment "staging" 0 "[]"

# production: 5-min wait, require repo admin review
# Note: reviewer IDs need to be fetched dynamically; we use an empty list
# and instruct the admin to add reviewers via the GitHub UI.
create_environment "production" 5 "[]"

echo "Done. Add reviewers to the 'production' environment via GitHub Settings > Environments."
