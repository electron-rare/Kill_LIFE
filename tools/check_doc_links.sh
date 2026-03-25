#!/usr/bin/env bash
# check_doc_links.sh — Verify internal markdown links are not broken
# Scans all .md files under docs/ and checks that relative links resolve.
#
# Usage:
#   ./tools/check_doc_links.sh [--fix]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIX_MODE=false

for arg in "$@"; do
  case "$arg" in
    --fix) FIX_MODE=true ;;
    --help|-h)
      echo "Usage: $0 [--fix]"
      echo "  --fix   Show suggested fixes for broken links"
      exit 0
      ;;
  esac
done

echo "=== Markdown Link Checker ==="
echo "Root: $ROOT"
echo ""

BROKEN=0
CHECKED=0
SKIPPED=0

# Find all markdown files
while IFS= read -r mdfile; do
  dir=$(dirname "$mdfile")

  # Extract markdown links: [text](path) — skip URLs, anchors, and mailto
  while IFS= read -r link; do
    # Skip empty
    [ -z "$link" ] && continue
    # Skip URLs
    echo "$link" | grep -qE '^https?://' && continue
    # Skip mailto
    echo "$link" | grep -qE '^mailto:' && continue
    # Skip pure anchors
    echo "$link" | grep -qE '^\#' && continue

    CHECKED=$((CHECKED + 1))

    # Strip anchor from link
    clean_link=$(echo "$link" | sed 's/#.*//')
    [ -z "$clean_link" ] && continue

    # Resolve relative to the markdown file's directory
    target="$dir/$clean_link"

    if [ ! -e "$target" ]; then
      # Also try from repo root (some links use repo-relative paths)
      target_root="$ROOT/$clean_link"
      if [ ! -e "$target_root" ]; then
        BROKEN=$((BROKEN + 1))
        rel_md="${mdfile#$ROOT/}"
        echo "  BROKEN: $rel_md -> $link"

        if [ "$FIX_MODE" = true ]; then
          # Try to find the file somewhere in the repo
          basename_link=$(basename "$clean_link")
          found=$(find "$ROOT/docs" "$ROOT/specs" "$ROOT/tools" -name "$basename_link" -type f 2>/dev/null | head -1)
          if [ -n "$found" ]; then
            echo "    SUGGEST: ${found#$ROOT/}"
          fi
        fi
      fi
    fi
  done < <(grep -oP '\[.*?\]\(\K[^)]+' "$mdfile" 2>/dev/null || true)

done < <(find "$ROOT/docs" "$ROOT/specs" -name "*.md" -type f 2>/dev/null)

echo ""
echo "=== Results: $CHECKED links checked, $BROKEN broken ==="

if [ "$BROKEN" -gt 0 ]; then
  echo "Fix broken links or run with --fix for suggestions."
  exit 1
else
  echo "All internal links OK."
fi
