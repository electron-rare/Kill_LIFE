#!/usr/bin/env python3
"""
Generate esp32_minimal.kicad_pcb — ESP32-S3-DevKitC-1 board outline + module.

Board: ESP32-S3-DevKitC-1 (official Espressif dimensions)
  PCB outline : 68.58 mm × 27.94 mm
  ESP32-S3-WROOM-1 module footprint (18.0 × 25.5 mm, centred on board)
  4 x M2 mounting holes at corners (3.2 mm drill, 2.0 mm from edges)
  USB-C connector footprint on bottom edge (centre-bottom)
"""

from __future__ import annotations

import sys
from pathlib import Path

# Suppress pcbnew assert noise
import os
os.environ["KSP_QUIET"] = "1"

import pcbnew  # type: ignore

HERE = Path(__file__).parent
OUT = HERE / "esp32_minimal.kicad_pcb"

# ── dimensions (mm → converted to nm internally) ──────────────────────────
BOARD_W = 68.58
BOARD_H = 27.94
WALL    = 1.6   # PCB thickness (cosmetic, not modelled in outline)

M2_DRILL  = 2.2   # M2 clearance drill
M2_MARGIN = 2.0   # distance from edge to hole centre

MODULE_W  = 18.0
MODULE_H  = 25.5

def mm(v: float) -> int:
    return pcbnew.FromMM(v)


def add_edge_cut_rect(board: pcbnew.BOARD, x0: float, y0: float, x1: float, y1: float) -> None:
    corners = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
    layer = pcbnew.Edge_Cuts
    for i in range(4):
        seg = pcbnew.PCB_SHAPE(board)
        seg.SetShape(pcbnew.SHAPE_T_SEGMENT)
        seg.SetLayer(layer)
        seg.SetWidth(mm(0.05))
        ax, ay = corners[i]
        bx, by = corners[(i + 1) % 4]
        seg.SetStart(pcbnew.VECTOR2I(mm(ax), mm(ay)))
        seg.SetEnd(pcbnew.VECTOR2I(mm(bx), mm(by)))
        board.Add(seg)


def add_mounting_hole(board: pcbnew.BOARD, cx: float, cy: float) -> None:
    """M2 NPTH mounting hole as a footprint with one NPTH pad."""
    fp = pcbnew.FOOTPRINT(board)
    fp.SetPosition(pcbnew.VECTOR2I(mm(cx), mm(cy)))
    fp.SetReference(f"MH_{cx:.0f}_{cy:.0f}")
    fp.Reference().SetVisible(False)

    pad = pcbnew.PAD(fp)
    pad.SetShape(pcbnew.PAD_SHAPE_CIRCLE)
    pad.SetAttribute(pcbnew.PAD_ATTRIB_NPTH)
    pad.SetDrillSize(pcbnew.VECTOR2I(mm(M2_DRILL), mm(M2_DRILL)))
    pad.SetSize(pcbnew.VECTOR2I(mm(M2_DRILL), mm(M2_DRILL)))
    pad.SetPosition(pcbnew.VECTOR2I(mm(cx), mm(cy)))
    fp.Add(pad)
    board.Add(fp)


def add_courtyard_rect(board: pcbnew.BOARD, x0: float, y0: float, x1: float, y1: float, layer) -> None:
    corners = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
    for i in range(4):
        seg = pcbnew.PCB_SHAPE(board)
        seg.SetShape(pcbnew.SHAPE_T_SEGMENT)
        seg.SetLayer(layer)
        seg.SetWidth(mm(0.05))
        ax, ay = corners[i]
        bx, by = corners[(i + 1) % 4]
        seg.SetStart(pcbnew.VECTOR2I(mm(ax), mm(ay)))
        seg.SetEnd(pcbnew.VECTOR2I(mm(bx), mm(by)))
        board.Add(seg)


def add_silkscreen_label(board: pcbnew.BOARD, x: float, y: float, text: str) -> None:
    t = pcbnew.PCB_TEXT(board)
    t.SetText(text)
    t.SetPosition(pcbnew.VECTOR2I(mm(x), mm(y)))
    t.SetLayer(pcbnew.F_SilkS)
    t.SetTextSize(pcbnew.VECTOR2I(mm(1.0), mm(1.0)))
    t.SetTextThickness(mm(0.15))
    board.Add(t)


def main() -> int:
    board = pcbnew.BOARD()

    # Board outline (Edge.Cuts)
    add_edge_cut_rect(board, 0.0, 0.0, BOARD_W, BOARD_H)

    # 4 × M2 mounting holes
    for mx, my in [
        (M2_MARGIN, M2_MARGIN),
        (BOARD_W - M2_MARGIN, M2_MARGIN),
        (M2_MARGIN, BOARD_H - M2_MARGIN),
        (BOARD_W - M2_MARGIN, BOARD_H - M2_MARGIN),
    ]:
        add_mounting_hole(board, mx, my)

    # ESP32-S3-WROOM-1 module courtyard (F.Courtyard)
    mod_x0 = (BOARD_W - MODULE_W) / 2
    mod_y0 = (BOARD_H - MODULE_H) / 2
    mod_x1 = mod_x0 + MODULE_W
    mod_y1 = mod_y0 + MODULE_H
    add_courtyard_rect(board, mod_x0, mod_y0, mod_x1, mod_y1, pcbnew.F_CrtYd)

    # USB-C keepout marker on bottom edge (centre-bottom, 9mm wide)
    usb_cx = BOARD_W / 2
    usb_w  = 9.0
    add_courtyard_rect(
        board,
        usb_cx - usb_w / 2, BOARD_H - 2.5,
        usb_cx + usb_w / 2, BOARD_H,
        pcbnew.B_CrtYd,
    )

    # Silkscreen labels
    add_silkscreen_label(board, BOARD_W / 2, BOARD_H / 2 - 4.0, "ESP32-S3-DevKitC-1")
    add_silkscreen_label(board, BOARD_W / 2, BOARD_H / 2 - 2.0, f"{BOARD_W:.2f}x{BOARD_H:.2f}mm")

    board.SetFileName(str(OUT))
    board.Save(str(OUT))
    print(f"Saved: {OUT}")
    print(f"Board outline: {BOARD_W} x {BOARD_H} mm")
    print(f"Module courtyard: {MODULE_W} x {MODULE_H} mm @ ({mod_x0:.2f}, {mod_y0:.2f})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
