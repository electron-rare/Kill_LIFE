#!/usr/bin/env bash
set -euo pipefail

SCHEMATIC="${1:-}"
if [[ -z "${SCHEMATIC}" ]]; then
  echo "usage: hw_check.sh <path-to.kicad_sch>"
  exit 2
fi

python tools/hw/schops/schops.py erc --schematic "${SCHEMATIC}"
python tools/hw/schops/schops.py netlist --schematic "${SCHEMATIC}"
python tools/hw/schops/schops.py bom --schematic "${SCHEMATIC}"
