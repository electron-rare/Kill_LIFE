#!/usr/bin/env bash
# Kill_LIFE — Hardware export pipeline (KiCad 10 CLI)
# Usage: bash tools/hw/hw_export.sh [schematic]
# Generates: ERC report, SVG, PDF, BOM, netlist in artifacts/hw/<date>/

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCH="${1:-$REPO_ROOT/hardware/esp32_minimal/esp32_minimal.kicad_sch}"
DATE=$(date +%Y%m%d_%H%M%S)
OUT_DIR="$REPO_ROOT/artifacts/hw/$DATE"
mkdir -p "$OUT_DIR"

echo "[hw_export] Schematic: $SCH"
echo "[hw_export] Output:    $OUT_DIR"

# ERC
echo "[hw_export] Running ERC..."
kicad-cli sch erc "$SCH" --format json --output "$OUT_DIR/erc_report.json" 2>&1
VIOLATIONS=$(python3 -c "import json; d=json.load(open('$OUT_DIR/erc_report.json')); v=d['sheets'][0]['violations']; e=[x for x in v if x['severity']=='error']; print(len(e))")
echo "[hw_export] ERC: $VIOLATIONS errors"

# SVG export
echo "[hw_export] Exporting SVG..."
kicad-cli sch export svg "$SCH" --output "$OUT_DIR/" 2>&1 || echo "[hw_export] SVG export failed (non-fatal)"

# PDF export
echo "[hw_export] Exporting PDF..."
kicad-cli sch export pdf "$SCH" --output "$OUT_DIR/schematic.pdf" 2>&1 || echo "[hw_export] PDF export failed (non-fatal)"

# BOM (via kicad-cli python-scripted or schops)
echo "[hw_export] Generating BOM..."
if command -v python3 &>/dev/null; then
    python3 "$REPO_ROOT/tools/hw/schops/schops.py" bom --schematic "$SCH" 2>&1 || echo "[hw_export] BOM via schops failed (non-fatal)"
    # Copy latest BOM artifact if generated
    find "$REPO_ROOT/artifacts/hw/" -name "bom.csv" -newer "$OUT_DIR/erc_report.json" -exec cp {} "$OUT_DIR/bom.csv" \; 2>/dev/null
fi

# Netlist
echo "[hw_export] Exporting netlist..."
kicad-cli sch export netlist "$SCH" --output "$OUT_DIR/netlist.xml" 2>&1 || echo "[hw_export] Netlist export failed (non-fatal)"

echo ""
echo "[hw_export] Done. Files:"
ls -lh "$OUT_DIR/"
echo ""

# Exit with error if ERC has errors
if [[ "$VIOLATIONS" -gt 0 ]]; then
    echo "[hw_export] FAIL: $VIOLATIONS ERC errors"
    exit 1
fi
echo "[hw_export] PASS: 0 ERC errors"
