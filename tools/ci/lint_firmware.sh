#!/usr/bin/env bash
set -euo pipefail

# Lint firmware C/C++ sources with clang-format.
# Usage:
#   tools/ci/lint_firmware.sh [--fix]
#
# Without --fix: dry-run, exits non-zero if formatting differs (CI mode).
# With --fix:    rewrites files in-place.

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
FW_DIR="$ROOT_DIR/firmware"
STYLE_FILE="$FW_DIR/.clang-format"

FIX=0
if [[ "${1:-}" == "--fix" ]]; then
  FIX=1
fi

# Locate clang-format
CF="${CLANG_FORMAT_BIN:-}"
if [[ -z "$CF" ]]; then
  for candidate in clang-format-18 clang-format-17 clang-format-16 clang-format; do
    if command -v "$candidate" >/dev/null 2>&1; then
      CF="$candidate"
      break
    fi
  done
fi

if [[ -z "$CF" ]]; then
  echo "WARNING: clang-format not found, skipping firmware lint."
  exit 0
fi

echo "Using: $CF ($("$CF" --version 2>/dev/null || echo unknown))"

# Collect source files
FILES=()
while IFS= read -r -d '' f; do
  FILES+=("$f")
done < <(find "$FW_DIR/src" "$FW_DIR/include" "$FW_DIR/test" \
  -type f \( -name '*.cpp' -o -name '*.c' -o -name '*.h' -o -name '*.hpp' \) \
  -print0 2>/dev/null || true)

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "No firmware source files found."
  exit 0
fi

echo "Checking ${#FILES[@]} file(s)..."

if [[ "$FIX" -eq 1 ]]; then
  "$CF" --style=file:"$STYLE_FILE" -i "${FILES[@]}"
  echo "Formatted ${#FILES[@]} file(s)."
else
  DIFF=$("$CF" --style=file:"$STYLE_FILE" --dry-run --Werror "${FILES[@]}" 2>&1 || true)
  if [[ -n "$DIFF" ]]; then
    echo "Formatting issues found:"
    echo "$DIFF"
    echo ""
    echo "Run: tools/ci/lint_firmware.sh --fix"
    exit 1
  fi
  echo "All files formatted correctly."
fi
