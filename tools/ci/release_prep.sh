#!/usr/bin/env bash
set -euo pipefail

# Prepare a release candidate: freeze features, create RC branch, run checks.
#
# Usage:
#   tools/ci/release_prep.sh <version>        # e.g. v1.2.0
#   tools/ci/release_prep.sh <version> --tag   # also create the git tag
#
# Steps:
#   1. Validate version format (vMAJOR.MINOR.PATCH)
#   2. Create release branch (release/<version>) if not on one
#   3. Run test suite
#   4. Generate CHANGELOG section
#   5. Optionally tag

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

if [[ $# -lt 1 ]]; then
  echo "Usage: tools/ci/release_prep.sh <version> [--tag]" >&2
  exit 1
fi

VERSION="$1"
DO_TAG=0
shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag) DO_TAG=1; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# Validate version
if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: Version must match vMAJOR.MINOR.PATCH (got: $VERSION)" >&2
  exit 1
fi

echo "=== Release Prep: $VERSION ==="
echo ""

# Check for dirty working tree
if [[ -n "$(git status --porcelain)" ]]; then
  echo "WARNING: Working tree is dirty. Commit or stash changes first."
  git status --short
  echo ""
fi

# Create release branch if needed
CURRENT_BRANCH="$(git branch --show-current)"
RELEASE_BRANCH="release/$VERSION"

if [[ "$CURRENT_BRANCH" != "$RELEASE_BRANCH" ]]; then
  if git show-ref --verify --quiet "refs/heads/$RELEASE_BRANCH"; then
    echo "Release branch exists, switching: $RELEASE_BRANCH"
    git checkout "$RELEASE_BRANCH"
  else
    echo "Creating release branch: $RELEASE_BRANCH"
    git checkout -b "$RELEASE_BRANCH"
  fi
fi

# Run tests
echo ""
echo "--- Running test suite ---"
if [[ -f "tools/test_python.sh" ]]; then
  bash tools/test_python.sh --suite stable || {
    echo "WARNING: Some tests failed. Fix before tagging."
  }
fi

# Generate changelog section
echo ""
echo "--- Generating release notes ---"
python3 tools/ci/generate_changelog.py --version "$VERSION" --output "CHANGELOG_DRAFT.md" 2>/dev/null || {
  echo "Changelog generator not available or failed. Creating minimal draft."
  PREV_TAG="$(git describe --tags --abbrev=0 2>/dev/null || echo '')"
  if [[ -n "$PREV_TAG" ]]; then
    RANGE="$PREV_TAG..HEAD"
  else
    RANGE="HEAD~20..HEAD"
  fi
  {
    echo "## $VERSION ($(date +%Y-%m-%d))"
    echo ""
    echo "### Changes"
    echo ""
    git log "$RANGE" --pretty=format:"- %s" --no-merges 2>/dev/null || echo "- (no commits)"
    echo ""
  } > CHANGELOG_DRAFT.md
}

echo "Draft: CHANGELOG_DRAFT.md"
echo ""

# Tag
if [[ "$DO_TAG" -eq 1 ]]; then
  echo "--- Creating tag: $VERSION ---"
  git tag -a "$VERSION" -m "Release $VERSION"
  echo "Tag created. Push with: git push origin $VERSION"
else
  echo "Skipping tag (use --tag to create)."
fi

echo ""
echo "=== Release prep complete ==="
echo "Next steps:"
echo "  1. Review CHANGELOG_DRAFT.md"
echo "  2. Merge into CHANGELOG.md"
echo "  3. Tag: tools/ci/release_prep.sh $VERSION --tag"
echo "  4. Push: git push origin $VERSION"
