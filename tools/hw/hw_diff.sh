#!/usr/bin/env bash
set -euo pipefail

# Visual diff between two hardware snapshots (before/after).
# Compares SVG renders, BOM CSVs, and ERC/DRC reports.
#
# Usage:
#   tools/hw/hw_diff.sh <before_dir> <after_dir> [--outdir diff_output]
#
# Output: a DIFF_REPORT.md summarizing changes + side-by-side file list.

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

if [[ $# -lt 2 ]]; then
  echo "Usage: tools/hw/hw_diff.sh <before_dir> <after_dir> [--outdir path]" >&2
  exit 1
fi

BEFORE="$1"
AFTER="$2"
shift 2
OUTDIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --outdir) OUTDIR="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

OUTDIR="${OUTDIR:-artifacts/hw_diffs/$(date +%Y%m%dT%H%M%S)}"
mkdir -p "$OUTDIR"

echo "Comparing:"
echo "  Before: $BEFORE"
echo "  After:  $AFTER"
echo "  Output: $OUTDIR"
echo ""

REPORT="$OUTDIR/DIFF_REPORT.md"
cat > "$REPORT" <<EOF
# Hardware Diff Report

| Property | Before | After |
|----------|--------|-------|
| Directory | \`$BEFORE\` | \`$AFTER\` |
| Generated | $(date -u +%Y-%m-%dT%H:%M:%SZ) | |

## File Comparison

EOF

# Compare BOM
BEFORE_BOM="$BEFORE/bom.csv"
AFTER_BOM="$AFTER/bom.csv"
if [[ -f "$BEFORE_BOM" && -f "$AFTER_BOM" ]]; then
  echo "### BOM Diff" >> "$REPORT"
  echo '```diff' >> "$REPORT"
  diff -u "$BEFORE_BOM" "$AFTER_BOM" >> "$REPORT" 2>/dev/null || true
  echo '```' >> "$REPORT"
  echo "" >> "$REPORT"

  # Also save standalone diff
  diff -u "$BEFORE_BOM" "$AFTER_BOM" > "$OUTDIR/bom.diff" 2>/dev/null || true
  echo "BOM diff: $(wc -l < "$OUTDIR/bom.diff" | tr -d ' ') lines"
else
  echo "### BOM" >> "$REPORT"
  echo "BOM not found in one or both snapshots." >> "$REPORT"
  echo "" >> "$REPORT"
fi

# Compare ERC
for report_file in erc.json drc.json; do
  BEFORE_F="$BEFORE/$report_file"
  AFTER_F="$AFTER/$report_file"
  NAME="${report_file%.json}"
  echo "### ${NAME^^} Report Diff" >> "$REPORT"
  if [[ -f "$BEFORE_F" && -f "$AFTER_F" ]]; then
    BEFORE_COUNT=$(python3 -c "
import json, sys
try:
    d = json.load(open('$BEFORE_F'))
    v = d.get('violations', d.get('errors', []))
    print(len(v))
except: print('?')
" 2>/dev/null || echo "?")
    AFTER_COUNT=$(python3 -c "
import json, sys
try:
    d = json.load(open('$AFTER_F'))
    v = d.get('violations', d.get('errors', []))
    print(len(v))
except: print('?')
" 2>/dev/null || echo "?")
    echo "| ${NAME^^} violations | $BEFORE_COUNT | $AFTER_COUNT |" >> "$REPORT"
  else
    echo "Report not found in one or both snapshots." >> "$REPORT"
  fi
  echo "" >> "$REPORT"
done

# List SVG renders for visual comparison
echo "### Visual Renders (SVG)" >> "$REPORT"
echo "" >> "$REPORT"
echo "Before:" >> "$REPORT"
find "$BEFORE" -name "*.svg" -type f 2>/dev/null | sort | while read -r f; do
  echo "- \`$(basename "$f")\`" >> "$REPORT"
done
echo "" >> "$REPORT"
echo "After:" >> "$REPORT"
find "$AFTER" -name "*.svg" -type f 2>/dev/null | sort | while read -r f; do
  echo "- \`$(basename "$f")\`" >> "$REPORT"
done
echo "" >> "$REPORT"

# Copy renders for side-by-side review
mkdir -p "$OUTDIR/before_svg" "$OUTDIR/after_svg"
find "$BEFORE" -name "*.svg" -type f -exec cp {} "$OUTDIR/before_svg/" \; 2>/dev/null || true
find "$AFTER" -name "*.svg" -type f -exec cp {} "$OUTDIR/after_svg/" \; 2>/dev/null || true

echo ""
echo "Diff report: $REPORT"
echo "SVG copies:  $OUTDIR/before_svg/ vs $OUTDIR/after_svg/"
