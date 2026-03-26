#!/usr/bin/env python3
"""Generate uart_header.kicad_sch for KiCad 10 — ERC-clean.

Block: 4-pin 2.54mm connector (Conn_01x04_Pin)
  Pin 1: GND
  Pin 2: +3V3 (net label)
  Pin 3: UART_TX (net label)
  Pin 4: UART_RX (net label)

Connector pin connection points (Conn_01x04_Pin, angle=0):
  Pin "at" position in lib space IS the net node (not the visual tip).
  Pin 1: at lib (5.08,  2.54, 180) → screen (SX+5.08, SY-2.54)
  Pin 2: at lib (5.08,  0.00, 180) → screen (SX+5.08, SY)
  Pin 3: at lib (5.08, -2.54, 180) → screen (SX+5.08, SY+2.54)
  Pin 4: at lib (5.08, -5.08, 180) → screen (SX+5.08, SY+5.08)

All placements at multiples of 1.27 mm.
"""

import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "lib"))
from kicad_gen import (gen_uuid, pin_screen, extract_symbol, lib_sym_entry,
                        prop, sym_inst, power_sym, no_connect, text, net_lbl,
                        SYMLIB)


# ── Build schematic ──────────────────────────────────────────────────────────

def build(output: pathlib.Path):
    print("Extracting symbols from KiCad 10 libraries...")

    lib_symbols_entries = [
        lib_sym_entry("power", "GND"),
        lib_sym_entry("power", "PWR_FLAG"),
        lib_sym_entry("Connector", "Conn_01x04_Pin"),
    ]
    print(f"  Extracted {len(lib_symbols_entries)} symbols.")
    lib_symbols_block = "\t(lib_symbols\n" + "\n".join(lib_symbols_entries) + "\n\t)"

    placements = []
    pwr_syms = []
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

    # ── J1: Conn_01x04_Pin at (30.48, 60.96) ─────────────────────────────────
    # Conn_01x04_Pin: pins at lib Y-up coords, angle 180° (pin exits right side):
    #   Pin 1 tip at lib (1.27,  2.54) → screen (SX+1.27, SY-2.54)
    #   Pin 2 tip at lib (1.27,  0.00) → screen (SX+1.27, SY)
    #   Pin 3 tip at lib (1.27, -2.54) → screen (SX+1.27, SY+2.54)
    #   Pin 4 tip at lib (1.27, -5.08) → screen (SX+1.27, SY+5.08)
    J1X, J1Y = 30.48, 60.96
    placements.append(sym_inst(
        lib_id="Connector:Conn_01x04_Pin",
        x=J1X, y=J1Y, angle=0,
        ref="J1", value="UART Header",
        footprint="Connector_PinHeader_2.54mm:PinHeader_1x04_P2.54mm_Vertical",
        datasheet="~",
        props_extra={"Pitch": "2.54mm"},
        pin_numbers=["1", "2", "3", "4"],
    ))

    # Connection points for Conn_01x04_Pin:
    # In KiCad, the pin "at" position IS the electrical connection point.
    # Library definition: (at 5.08, Y, 180)(length 3.81)
    # The "at" coord (5.08, Y) in lib space is the net node.
    # pin_screen(SX, SY, angle, 5.08, Y_lib) gives the screen connection point.
    #   Pin 1: at lib (5.08,  2.54, 180) → screen (SX+5.08, SY-2.54)
    #   Pin 2: at lib (5.08,  0.00, 180) → screen (SX+5.08, SY)
    #   Pin 3: at lib (5.08, -2.54, 180) → screen (SX+5.08, SY+2.54)
    #   Pin 4: at lib (5.08, -5.08, 180) → screen (SX+5.08, SY+5.08)
    p1x, p1y = pin_screen(J1X, J1Y, 0, 5.08,  2.54)   # Pin 1: GND
    p2x, p2y = pin_screen(J1X, J1Y, 0, 5.08,  0.00)   # Pin 2: +3V3
    p3x, p3y = pin_screen(J1X, J1Y, 0, 5.08, -2.54)   # Pin 3: UART_TX
    p4x, p4y = pin_screen(J1X, J1Y, 0, 5.08, -5.08)   # Pin 4: UART_RX

    print(f"\nPin endpoints (screen coords, all on 1.27mm grid):")
    print(f"  J1 Pin 1 (GND)     : ({p1x}, {p1y})")
    print(f"  J1 Pin 2 (+3V3)    : ({p2x}, {p2y})")
    print(f"  J1 Pin 3 (UART_TX) : ({p3x}, {p3y})")
    print(f"  J1 Pin 4 (UART_RX) : ({p4x}, {p4y})")

    # Pin 1: GND power symbol
    add_pwr("power:GND", p1x, p1y)
    # Add PWR_FLAG for GND net
    add_pwr("power:PWR_FLAG", p1x, p1y)

    # Pin 2: +3V3 net label (do not use power:+3V3 — this is a passive connector,
    # not a power source; net label connects to the +3V3 rail in the parent sheet)
    labels.append(net_lbl("+3V3", p2x, p2y, 0))

    # Pin 3: UART_TX net label
    labels.append(net_lbl("UART_TX", p3x, p3y, 0))

    # Pin 4: UART_RX net label
    labels.append(net_lbl("UART_RX", p4x, p4y, 0))

    annotations = [
        text("Kill_LIFE UART Header Block (4-pin 2.54mm)", 10, 6, size=1.5),
        text("Pin 1: GND  |  Pin 2: +3V3  |  Pin 3: UART_TX  |  Pin 4: UART_RX", 10, 10, size=1.0),
        text("Footprint: PinHeader_1x04_P2.54mm_Vertical", 10, 13, size=1.0),
    ]

    all_elements = placements + pwr_syms + labels + annotations
    body = "\n".join(all_elements)

    sch = f"""(kicad_sch
\t(version 20260101)
\t(generator "kill_life_gen")
\t(generator_version "10.0")
\t(uuid "{gen_uuid()}")
\t(paper "A4")
\t(title_block
\t\t(title "Kill_LIFE UART Header Block")
\t\t(date "2026-03-25")
\t\t(rev "1.0")
\t\t(company "Kill_LIFE")
\t\t(comment 1 "4-pin 2.54mm connector for UART debug/programming")
\t\t(comment 2 "Pin 1 GND, Pin 2 +3V3, Pin 3 UART_TX, Pin 4 UART_RX")
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
    out = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path("uart_header.kicad_sch")
    build(out)
