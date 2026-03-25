#!/usr/bin/env bash
# check_doc_commands.sh — Verify that commands documented in markdown files actually work
# Extracts ```bash code blocks from key docs and smoke-tests them.
#
# Usage:
#   ./tools/check_doc_commands.sh [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --help|-h)
      echo "Usage: $0 [--dry-run]"
      echo "  --dry-run   List commands without executing"
      exit 0
      ;;
  esac
done

echo "=== Documentation Command Tester ==="
echo "Root: $ROOT"
echo "Mode: $([ "$DRY_RUN" = true ] && echo 'DRY RUN' || echo 'EXECUTE')"
echo ""

PASS=0
FAIL=0
SKIP=0

# Files to test commands from
DOC_FILES=(
  "$ROOT/docs/INSTALL.md"
  "$ROOT/docs/QUICKSTART.md"
  "$ROOT/docs/RUNBOOK.md"
)

# Commands that are safe to test (whitelist patterns)
SAFE_PATTERNS=(
  "python3 tools/"
  "bash tools/"
  "make "
  "cat "
  "ls "
  "git status"
  "git log"
)

# Commands to skip (dangerous or interactive)
SKIP_PATTERNS=(
  "sudo"
  "rm "
  "docker"
  "ssh "
  "git push"
  "git commit"
  "gh pr"
  "gh issue"
  "npm install"
  "pip install"
  "platformio"
  "pio "
  "brew "
  "apt "
  "EDITOR"
)

is_safe() {
  local cmd="$1"
  for skip in "${SKIP_PATTERNS[@]}"; do
    if echo "$cmd" | grep -q "$skip"; then
      return 1
    fi
  done
  for safe in "${SAFE_PATTERNS[@]}"; do
    if echo "$cmd" | grep -q "$safe"; then
      return 0
    fi
  done
  return 1
}

for docfile in "${DOC_FILES[@]}"; do
  [ -f "$docfile" ] || continue
  rel="${docfile#$ROOT/}"
  echo "--- $rel ---"

  # Extract bash code blocks
  in_block=false
  while IFS= read -r line; do
    if echo "$line" | grep -q '```bash'; then
      in_block=true
      continue
    fi
    if echo "$line" | grep -q '```' && [ "$in_block" = true ]; then
      in_block=false
      continue
    fi
    if [ "$in_block" = true ]; then
      # Skip comments and empty lines
      trimmed=$(echo "$line" | sed 's/^[[:space:]]*//')
      [ -z "$trimmed" ] && continue
      echo "$trimmed" | grep -q '^#' && continue
      # Skip lines with variable assignments only
      echo "$trimmed" | grep -qE '^[A-Z_]+=.*$' && continue

      cmd="$trimmed"

      if is_safe "$cmd"; then
        if [ "$DRY_RUN" = true ]; then
          echo "  [WOULD TEST] $cmd"
          PASS=$((PASS + 1))
        else
          echo -n "  [$cmd] ... "
          if (cd "$ROOT" && timeout 30 bash -c "$cmd" > /dev/null 2>&1); then
            echo "PASS"
            PASS=$((PASS + 1))
          else
            echo "FAIL"
            FAIL=$((FAIL + 1))
          fi
        fi
      else
        echo "  [SKIP] $cmd"
        SKIP=$((SKIP + 1))
      fi
    fi
  done < "$docfile"
  echo ""
done

echo "=== Results: $PASS pass, $FAIL fail, $SKIP skip ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
