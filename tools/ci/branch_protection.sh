#!/usr/bin/env bash
set -euo pipefail

# Configure GitHub branch protection rules for the main branch.
# Requires: gh CLI authenticated with admin access.
#
# Usage:
#   tools/ci/branch_protection.sh [--dry-run]
#
# Sets:
#   - Required status checks (CI, Evidence Pack)
#   - Require PR reviews before merge
#   - Dismiss stale reviews
#   - Require up-to-date branches

REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo '')}"
BRANCH="main"
DRY_RUN=0

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

if [[ -z "$REPO" ]]; then
  echo "ERROR: Cannot determine repository. Set GITHUB_REPOSITORY or run from a git repo with gh configured." >&2
  exit 1
fi

REQUIRED_CHECKS='["python-stable","evidence_pack"]'

PAYLOAD=$(cat <<'ENDJSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["python-stable", "evidence_pack"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
ENDJSON
)

echo "Repository:  $REPO"
echo "Branch:      $BRANCH"
echo "Checks:      $REQUIRED_CHECKS"
echo ""

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[dry-run] Would apply the following branch protection:"
  echo "$PAYLOAD" | python3 -m json.tool 2>/dev/null || echo "$PAYLOAD"
  exit 0
fi

echo "Applying branch protection rules..."
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "/repos/$REPO/branches/$BRANCH/protection" \
  --input - <<< "$PAYLOAD"

echo ""
echo "Branch protection applied to $BRANCH."
echo "Required checks: python-stable, evidence_pack"
