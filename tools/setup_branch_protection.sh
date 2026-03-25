#!/usr/bin/env bash
# setup_branch_protection.sh — Configure GitHub branch protection rules
# Requires: gh CLI authenticated with admin access
#
# Usage:
#   ./tools/setup_branch_protection.sh [--dry-run]
#
# What it configures on 'main':
#   - Require PR reviews (1 reviewer minimum)
#   - Require status checks: ci, scope-guard, spec-lint
#   - Require branches to be up to date
#   - Enforce for admins
#   - No force pushes
#   - No deletions

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --help|-h)
      echo "Usage: $0 [--dry-run]"
      exit 0
      ;;
  esac
done

# Detect repo from git remote
REPO=$(cd "$ROOT" && gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || echo "")
if [ -z "$REPO" ]; then
  echo "ERROR: Cannot detect GitHub repo. Ensure 'gh' is authenticated and you are in a git repo."
  exit 1
fi

BRANCH="main"

echo "=== Branch Protection Setup ==="
echo "Repo:   $REPO"
echo "Branch: $BRANCH"
echo "Mode:   $([ "$DRY_RUN" = true ] && echo 'DRY RUN' || echo 'LIVE')"
echo ""

# Required status checks (must match workflow job names)
REQUIRED_CHECKS='["ci","scope-guard","evidence-pack"]'

PAYLOAD=$(cat <<ENDJSON
{
  "required_status_checks": {
    "strict": true,
    "contexts": $REQUIRED_CHECKS
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
ENDJSON
)

echo "Configuration:"
echo "$PAYLOAD" | python3 -m json.tool 2>/dev/null || echo "$PAYLOAD"
echo ""

if [ "$DRY_RUN" = true ]; then
  echo "[DRY RUN] Would apply the above to $REPO branch $BRANCH"
  echo "Run without --dry-run to apply."
  exit 0
fi

echo "Applying branch protection..."
gh api \
  --method PUT \
  "repos/$REPO/branches/$BRANCH/protection" \
  --input - <<< "$PAYLOAD"

echo ""
echo "Branch protection applied to $REPO/$BRANCH"
echo "Verify at: https://github.com/$REPO/settings/branches"
