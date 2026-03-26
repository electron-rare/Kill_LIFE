#!/usr/bin/env python3
"""Generate power_usbc_ldo.kicad_sch for KiCad 10 — ERC-clean.

Block: USB-C Receptacle PowerOnly 6P + AMS1117-3.3 LDO
Outputs +3V3 net label at LDO VO pin, GND symbols, +5V PWR_FLAG at VBUS.

All placements at multiples of 1.27 mm.
Pin endpoints computed via pin_screen() Y-flip transform.
"""

import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "lib"))
from kicad_gen import (gen_uuid, pin_screen, extract_symbol, lib_sym_entry,
                        prop, sym_inst, power_sym, wire, no_connect, junction,
                        text, net_lbl, SYMLIB)


# ── Build schematic ──────────────────────────────────────────────────────────

def build(output: pathlib.Path):
    print("Extracting symbols from KiCad 10 libraries...")

    lib_symbols_entries = [
        lib_sym_entry("power", "GND"),
        lib_sym_entry("power", "+5V"),
        lib_sym_entry("power", "PWR_FLAG"),
        # AMS1117-3.3 extends AP1117-ADJ; flatten so KiCad resolves pins
        lib_sym_entry("Regulator_Linear", "AP1117-ADJ"),
        lib_sym_entry("Regulator_Linear", "AMS1117-3.3"),
        lib_sym_entry("Connector", "USB_C_Receptacle_PowerOnly_6P"),
    ]
    print(f"  Extracted {len(lib_symbols_entries)} symbols.")
    lib_symbols_block = "\t(lib_symbols\n" + "\n".join(lib_symbols_entries) + "\n\t)"

    placements = []
    pwr_syms = []
    nc_markers = []
    labels = []
    pwr_n = [1]

    def next_pwr():
        n = pwr_n[0]
        pwr_n[0] += 1
        return n

    placed_pwr_keys = set()

    def add_pwr(lib_id, x, y):
        key = (lib_id, round(x, 3), round(y, 3))
        if key not in placed_pwr_keys:
            placed_pwr_keys.add(key)
            pwr_syms.append(power_sym(lib_id, x, y, next_pwr()))

    placed_nc_keys = set()

    def add_nc(x, y):
        key = (round(x, 3), round(y, 3))
        if key not in placed_nc_keys:
            placed_nc_keys.add(key)
            nc_markers.append(no_connect(x, y))

    # ── J1: USB-C Receptacle at (30.48, 71.12) ──────────────────────────────
    # Same position as esp32_minimal for consistency
    J1X, J1Y = 30.48, 71.12
    placements.append(sym_inst(
        lib_id="Connector:USB_C_Receptacle_PowerOnly_6P",
        x=J1X, y=J1Y, angle=0,
        ref="J1", value="USB-C Power",
        footprint="Connector_USB:USB_C_Receptacle_HRO_TYPE-C-31-M-12",
        datasheet="~",
        props_extra={"Manufacturer": "HRO", "MPN": "TYPE-C-31-M-12"},
        pin_numbers=["A9", "B9", "A12", "B12", "A5", "B5", "SH"],
    ))

    # J1 pin endpoints:
    # VBUS: A9/B9 at lib (15.24, 7.62) and (15.24, 5.08) — use A9 for +5V
    # GND:  A12/B12 at lib (0, -17.78)
    # CC1:  A5 at lib (15.24, -5.08)
    # CC2:  B5 at lib (15.24, -7.62)
    # SH:   at lib (-7.62, -17.78)
    vbus_x, vbus_y   = pin_screen(J1X, J1Y, 0, 15.24,  7.62)   # (45.72, 63.50)
    j1_gnd_x, j1_gnd_y = pin_screen(J1X, J1Y, 0, 0.0, -17.78) # (30.48, 88.90)
    cc1_x, cc1_y     = pin_screen(J1X, J1Y, 0, 15.24, -5.08)   # (45.72, 76.20)
    cc2_x, cc2_y     = pin_screen(J1X, J1Y, 0, 15.24, -7.62)   # (45.72, 78.74)
    sh_x,  sh_y      = pin_screen(J1X, J1Y, 0, -7.62, -17.78)  # (22.86, 88.90)

    add_pwr("power:+5V", vbus_x, vbus_y)
    add_pwr("power:GND", j1_gnd_x, j1_gnd_y)
    add_nc(cc1_x, cc1_y)
    add_nc(cc2_x, cc2_y)
    add_nc(sh_x,  sh_y)

    # PWR_FLAG for +5V (external source) and GND
    add_pwr("power:PWR_FLAG", vbus_x, vbus_y)
    add_pwr("power:PWR_FLAG", j1_gnd_x, j1_gnd_y)

    # ── U1: AMS1117-3.3 at (81.28, 60.96) ───────────────────────────────────
    # Inherits from AP1117-ADJ: pin1 ADJ=(0,-7.62), pin2 VO=(7.62,0), pin3 VI=(-7.62,0)
    U1X, U1Y = 81.28, 60.96
    placements.append(sym_inst(
        lib_id="Regulator_Linear:AMS1117-3.3",
        x=U1X, y=U1Y, angle=0,
        ref="U1", value="AMS1117-3.3",
        footprint="Package_TO_SOT_SMD:SOT-223-3_TabPin2",
        datasheet="http://www.advanced-monolithic.com/pdf/ds1117.pdf",
        props_extra={
            "Manufacturer": "Advanced Monolithic Systems",
            "MPN": "AMS1117-3.3",
        },
        pin_numbers=["1", "2", "3"],
    ))

    u1_vi_x,  u1_vi_y  = pin_screen(U1X, U1Y, 0, -7.62, 0.0)   # (73.66, 60.96)
    u1_vo_x,  u1_vo_y  = pin_screen(U1X, U1Y, 0,  7.62, 0.0)   # (88.90, 60.96)
    u1_adj_x, u1_adj_y = pin_screen(U1X, U1Y, 0,  0.0, -7.62)  # (81.28, 68.58)

    # U1 VI: connect to +5V rail
    add_pwr("power:+5V", u1_vi_x, u1_vi_y)
    # U1 ADJ (GND): connect to GND
    add_pwr("power:GND", u1_adj_x, u1_adj_y)
    # U1 VO: power_out pin — place +3V3 net label (no power:+3V3 to avoid pin_to_pin)
    labels.append(net_lbl("+3V3", u1_vo_x, u1_vo_y, 0))

    print(f"\nPin endpoints (screen coords, all on 1.27mm grid):")
    print(f"  J1 VBUS  : ({vbus_x}, {vbus_y})")
    print(f"  J1 GND   : ({j1_gnd_x}, {j1_gnd_y})")
    print(f"  U1 VI    : ({u1_vi_x}, {u1_vi_y})")
    print(f"  U1 VO    : ({u1_vo_x}, {u1_vo_y})")
    print(f"  U1 ADJ   : ({u1_adj_x}, {u1_adj_y})")

    annotations = [
        text("Kill_LIFE Power Block: USB-C + AMS1117-3.3 LDO", 10, 6, size=1.5),
        text("Input: +5V USB VBUS  |  Output: +3V3 net label at LDO VO", 10, 10, size=1.0),
        text("CC1, CC2 (A5/B5): NC — configure-only, no pull-down shown", 10, 13, size=1.0),
    ]

    all_elements = placements + pwr_syms + nc_markers + labels + annotations
    body = "\n".join(all_elements)

    sch = f"""(kicad_sch
\t(version 20260101)
\t(generator "kill_life_gen")
\t(generator_version "10.0")
\t(uuid "{gen_uuid()}")
\t(paper "A4")
\t(title_block
\t\t(title "Kill_LIFE Power Block: USB-C + AMS1117-3.3")
\t\t(date "2026-03-25")
\t\t(rev "1.0")
\t\t(company "Kill_LIFE")
\t\t(comment 1 "USB-C Receptacle PowerOnly 6P + AMS1117-3.3 LDO")
\t\t(comment 2 "VBUS → AMS1117-3.3 → +3V3 (net label at VO)")
\t\t(comment 3 "Reusable block — integrate into parent schematic")
\t)
{lib_symbols_block}

{body}

\t(sheet_instances
\t\t(path "/"
\t\t\t(page "1")
\t\t)
\t)
)
"""
    output.write_text(sch)
    print(f"\nWritten: {output} ({len(sch):,} bytes)")


if __name__ == "__main__":
    out = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path("power_usbc_ldo.kicad_sch")
    build(out)
