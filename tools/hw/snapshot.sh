#!/usr/bin/env bash
set -euo pipefail

# Take a "before" or "after" snapshot of hardware design files.
# Exports: schematic PDF/SVG, PCB renders, BOM, ERC, DRC, netlist.
#
# Usage:
#   tools/hw/snapshot.sh [--label before|after] [--hw-root hardware/kicad] [--outdir path]
#
# Default output: artifacts/hw_snapshots/<label>_<timestamp>/

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
LABEL="snapshot"
HW_ROOT="hardware/kicad"
OUTDIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --label)   LABEL="$2"; shift 2 ;;
    --hw-root) HW_ROOT="$2"; shift 2 ;;
    --outdir)  OUTDIR="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

cd "$ROOT_DIR"

if [[ ! -d "$HW_ROOT" ]]; then
  echo "Hardware root not found: $HW_ROOT (skipping snapshot)"
  exit 0
fi

TS="$(date +%Y%m%dT%H%M%S)"
OUTDIR="${OUTDIR:-artifacts/hw_snapshots/${LABEL}_${TS}}"
mkdir -p "$OUTDIR"

SCHEM="$(find "$HW_ROOT" -name "*.kicad_sch" -maxdepth 4 | head -n 1 || true)"
PCB="$(find "$HW_ROOT" -name "*.kicad_pcb" -maxdepth 4 | head -n 1 || true)"

echo "Snapshot label: $LABEL"
echo "Schematic:      ${SCHEM:-<none>}"
echo "PCB:            ${PCB:-<none>}"
echo "Output:         $OUTDIR"

ARGS=()
if [[ -n "$SCHEM" ]]; then
  ARGS+=(--schematic "$SCHEM")
fi
if [[ -n "$PCB" ]]; then
  ARGS+=(--pcb "$PCB")
fi

if [[ ${#ARGS[@]} -eq 0 ]]; then
  echo "No KiCad files found, nothing to snapshot."
  exit 0
fi

python3 tools/hw/exports.py "${ARGS[@]}" --outdir "$OUTDIR"

# Record metadata
cat > "$OUTDIR/snapshot_meta.json" <<ENDJSON
{
  "label": "$LABEL",
  "timestamp": "$TS",
  "schematic": "${SCHEM:-null}",
  "pcb": "${PCB:-null}",
  "git_sha": "$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
}
ENDJSON

echo "Snapshot complete: $OUTDIR"
