#!/usr/bin/env bash
set -euo pipefail

# Hardware gate:
# - auto-detect first schematic + pcb under provided root (default: hardware/kicad)
# - export previews (SVG) + reports (ERC/DRC/BOM/netlist) to artifacts
# - lint design blocks + regenerate blocks registry

ROOT_DIR="${1:-hardware/kicad}"

if [[ ! -d "${ROOT_DIR}" ]]; then
  echo "ERROR: ${ROOT_DIR} not found" >&2
  exit 2
fi

SCHEM="$(find "${ROOT_DIR}" -name "*.kicad_sch" -maxdepth 4 | head -n 1 || true)"
PCB="$(find "${ROOT_DIR}" -name "*.kicad_pcb" -maxdepth 4 | head -n 1 || true)"

if [[ -z "${SCHEM}" && -z "${PCB}" ]]; then
  echo "No .kicad_sch or .kicad_pcb found under ${ROOT_DIR} (nothing to do)."
  exit 0
fi

echo "Using schematic: ${SCHEM:-<none>}"
echo "Using pcb: ${PCB:-<none>}"

OUTDIR="$(python tools/hw/exports.py ${SCHEM:+--schematic "$SCHEM"} ${PCB:+--pcb "$PCB"})"
echo "Previews: ${OUTDIR}"

python tools/hw/blocks/lint_blocks.py --blocks-dir hardware/blocks
python tools/hw/blocks/generate_registry.py --blocks-dir hardware/blocks --out hardware/blocks/REGISTRY.md

python tools/compliance/validate.py

echo "OK"
