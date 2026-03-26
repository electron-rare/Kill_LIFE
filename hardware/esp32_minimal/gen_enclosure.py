#!/usr/bin/env python3
"""
gen_enclosure.py — Boîtier paramétrique ESP32-S3-DevKitC-1 en FreeCAD headless.

Dimensions basées sur ESP32-S3-DevKitC-1 (Espressif officiel):
  PCB : 68.58 × 27.94 mm
  Boîtier extérieur : 72.0 × 32.0 × 22.0 mm (clearance 1.7 mm / côté)
  Parois : 2.0 mm
  Découpes : USB-C bas (10 × 4 mm), GPIO headers côtés longs

Outputs:
  hardware/esp32_minimal/esp32s3_enclosure.FCStd
  hardware/esp32_minimal/esp32s3_enclosure.step
"""

from __future__ import annotations

import sys
from pathlib import Path

HERE = Path(__file__).parent

# FreeCAD headless
import FreeCAD  # type: ignore
import Part      # type: ignore

App = FreeCAD

# ── paramètres ─────────────────────────────────────────────────────────────
BOARD_W   = 68.58
BOARD_D   = 27.94
BOARD_THK = 1.6

CLEARANCE_XY = 1.71   # lateral clearance board→wall
CLEARANCE_Z  = 2.0    # headroom above board
WALL         = 2.0    # wall thickness
FLOOR        = 2.0    # bottom floor thickness

ENC_W = BOARD_W + 2 * CLEARANCE_XY + 2 * WALL   # 72.0 mm
ENC_D = BOARD_D + 2 * CLEARANCE_XY + 2 * WALL   # 32.0 mm
ENC_H = FLOOR + BOARD_THK + CLEARANCE_Z + WALL   # ~8 mm (lidless shell)

# Adjust to a nicer number
ENC_W = 73.0
ENC_D = 32.0
ENC_H = 22.0  # full-height shell including lid

# Interior cutout
INT_W = ENC_W - 2 * WALL
INT_D = ENC_D - 2 * WALL
INT_H = ENC_H - FLOOR - WALL  # open top will be closed by separate lid

# USB-C opening (bottom face, centred)
USB_W = 10.0
USB_H =  4.5
USB_Y_FROM_BOTTOM = FLOOR  # flush with floor = 0 in local Z

# GPIO header slots (both long sides, centred vertically on wall)
GPIO_SLOT_W = 52.0   # 26 pins × 2 mm pitch
GPIO_SLOT_H =  3.5
GPIO_SLOT_Z_FROM_FLOOR = FLOOR + 1.5

# M2 standoff cylinders (4 corners, inside)
STDOFF_H  = BOARD_THK + 0.5  # slightly above floor
STDOFF_R  = 1.8
STDOFF_DRILL = 1.1
M2_X_MARGIN = 4.5   # from inner wall
M2_Y_MARGIN = 3.5


def v(x: float, y: float, z: float) -> App.Vector:
    return App.Vector(x, y, z)


def make_box(w: float, d: float, h: float, origin: App.Vector | None = None) -> Part.Shape:
    box = Part.makeBox(w, d, h)
    if origin:
        box.translate(origin)
    return box


def make_cylinder(r: float, h: float, origin: App.Vector | None = None) -> Part.Shape:
    cyl = Part.makeCylinder(r, h)
    if origin:
        cyl.translate(origin)
    return cyl


def main() -> int:
    # ── outer shell ─────────────────────────────────────────────────────────
    outer = make_box(ENC_W, ENC_D, ENC_H)

    # interior pocket (open top)
    inner = make_box(INT_W, INT_D, ENC_H - FLOOR, v(WALL, WALL, FLOOR))

    shell = outer.cut(inner)

    # ── USB-C cutout  — bottom front face (Y=0 face) ────────────────────────
    usb_cx = ENC_W / 2
    usb_cut = make_box(
        USB_W, WALL + 2, USB_H,
        v(usb_cx - USB_W / 2, -1.0, FLOOR),
    )
    shell = shell.cut(usb_cut)

    # ── GPIO header slots — left face (X=0) and right face (X=ENC_W) ───────
    gpio_z  = GPIO_SLOT_Z_FROM_FLOOR
    gpio_cy = ENC_D / 2

    # left wall slot
    slot_l = make_box(
        WALL + 2, GPIO_SLOT_W, GPIO_SLOT_H,
        v(-1.0, gpio_cy - GPIO_SLOT_W / 2, gpio_z),
    )
    shell = shell.cut(slot_l)

    # right wall slot
    slot_r = make_box(
        WALL + 2, GPIO_SLOT_W, GPIO_SLOT_H,
        v(ENC_W - WALL - 1.0, gpio_cy - GPIO_SLOT_W / 2, gpio_z),
    )
    shell = shell.cut(slot_r)

    # ── M2 standoffs (hollow cylinders on floor) ────────────────────────────
    inner_x_min = WALL + M2_X_MARGIN
    inner_x_max = ENC_W - WALL - M2_X_MARGIN
    inner_y_min = WALL + M2_Y_MARGIN
    inner_y_max = ENC_D - WALL - M2_Y_MARGIN

    for sx, sy in [
        (inner_x_min, inner_y_min),
        (inner_x_max, inner_y_min),
        (inner_x_min, inner_y_max),
        (inner_x_max, inner_y_max),
    ]:
        solid_cyl = make_cylinder(STDOFF_R, STDOFF_H, v(sx, sy, FLOOR))
        drill_cyl = make_cylinder(STDOFF_DRILL, STDOFF_H + 1, v(sx, sy, FLOOR - 0.5))
        standoff = solid_cyl.cut(drill_cyl)
        shell = shell.fuse(standoff)

    # ── FreeCAD document ────────────────────────────────────────────────────
    doc = App.newDocument("ESP32S3_Enclosure")
    obj = doc.addObject("Part::Feature", "Enclosure")
    obj.Shape = shell
    doc.recompute()

    fcstd_path = str(HERE / "esp32s3_enclosure.FCStd")
    step_path  = str(HERE / "esp32s3_enclosure.step")

    doc.saveAs(fcstd_path)
    print(f"Saved FCStd: {fcstd_path}")

    Part.export([obj], step_path)
    print(f"Exported STEP: {step_path}")
    print()
    print(f"  Outer dimensions : {ENC_W:.1f} × {ENC_D:.1f} × {ENC_H:.1f} mm")
    print(f"  Wall / floor     : {WALL:.1f} / {FLOOR:.1f} mm")
    print(f"  USB-C slot       : {USB_W:.1f} × {USB_H:.1f} mm (bottom front)")
    print(f"  GPIO slots       : {GPIO_SLOT_W:.1f} × {GPIO_SLOT_H:.1f} mm (both sides)")
    print(f"  Standoffs        : 4× M2 Ø{STDOFF_DRILL*2:.1f}mm drill, h={STDOFF_H:.1f}mm")
    return 0


import sys
raise SystemExit(main())
