#!/usr/bin/env python3
"""Generate esp32_minimal.kicad_sch for KiCad 10 — ERC-clean.

All component placements at multiples of 1.27 mm.
Pin endpoints computed via Y-flip transform; power/NC/label placed at exact endpoints.
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
        lib_sym_entry("power", "+3V3"),
        lib_sym_entry("power", "+5V"),
        lib_sym_entry("power", "PWR_FLAG"),
        lib_sym_entry("Device", "C"),
        lib_sym_entry("Device", "FerriteBead"),
        # AMS1117-3.3 extends AP1117-ADJ; include parent so KiCad resolves pins
        lib_sym_entry("Regulator_Linear", "AP1117-ADJ"),
        lib_sym_entry("Regulator_Linear", "AMS1117-3.3"),
        lib_sym_entry("Connector", "USB_C_Receptacle_PowerOnly_6P"),
        lib_sym_entry("RF_Module", "ESP32-S3-WROOM-1"),
    ]
    print(f"  Extracted {len(lib_symbols_entries)} symbols.")
    lib_symbols_block = "\t(lib_symbols\n" + "\n".join(lib_symbols_entries) + "\n\t)"

    placements = []
    pwr_syms = []
    nc_markers = []
    pwr_n = [1]  # mutable counter

    def next_pwr():
        n = pwr_n[0]
        pwr_n[0] += 1
        return n

    # Track placed power symbols to avoid duplicates at same (net, x, y)
    placed_pwr_keys = set()

    def add_pwr(lib_id, x, y):
        key = (lib_id, round(x, 3), round(y, 3))
        if key not in placed_pwr_keys:
            placed_pwr_keys.add(key)
            pwr_syms.append(power_sym(lib_id, x, y, next_pwr()))

    # Track placed no_connects to avoid duplicates
    placed_nc_keys = set()

    def add_nc(x, y):
        key = (round(x, 3), round(y, 3))
        if key not in placed_nc_keys:
            placed_nc_keys.add(key)
            nc_markers.append(no_connect(x, y))

    # ── J1: USB-C Receptacle at (30.48, 71.12) — 24×1.27, 56×1.27 ──────────
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

    # J1 pin endpoints (lib Y-up: A9/B9 VBUS at (15.24,7.62), A12/B12 GND at (0,-17.78))
    vbus_x, vbus_y   = pin_screen(J1X, J1Y, 0, 15.24, 7.62)     # (45.72, 63.50)
    j1_gnd_x, j1_gnd_y = pin_screen(J1X, J1Y, 0, 0.0, -17.78)   # (30.48, 88.90)
    cc1_x, cc1_y     = pin_screen(J1X, J1Y, 0, 15.24, -5.08)     # (45.72, 76.20)
    cc2_x, cc2_y     = pin_screen(J1X, J1Y, 0, 15.24, -7.62)     # (45.72, 78.74)
    sh_x,  sh_y      = pin_screen(J1X, J1Y, 0, -7.62, -17.78)    # (22.86, 88.90)

    add_pwr("power:+5V", vbus_x, vbus_y)
    add_pwr("power:GND", j1_gnd_x, j1_gnd_y)
    add_nc(cc1_x, cc1_y)
    add_nc(cc2_x, cc2_y)
    add_nc(sh_x,  sh_y)

    # ── FB1: FerriteBead at (53.34, 60.96, 90°) — 42×1.27, 48×1.27 ──────────
    FB1X, FB1Y = 53.34, 60.96
    placements.append(sym_inst(
        lib_id="Device:FerriteBead",
        x=FB1X, y=FB1Y, angle=90,
        ref="FB1", value="600Ω@100MHz",
        footprint="Inductor_SMD:L_0603_1608Metric",
        datasheet="~",
        props_extra={
            "Manufacturer": "Murata", "MPN": "BLM18KG601TN1D",
            "Impedance": "600R@100MHz", "Package": "0603",
        },
        pin_numbers=["1", "2"],
    ))
    # FerriteBead lib: pin1=(0,3.81), pin2=(0,-3.81), placed at 90°
    # pin_screen with angle=90: rx=-PY, ry=-PX (after lib-rot + Y-flip)
    fb1_p1x, fb1_p1y = pin_screen(FB1X, FB1Y, 90, 0.0, 3.81)     # (49.53, 60.96)
    fb1_p2x, fb1_p2y = pin_screen(FB1X, FB1Y, 90, 0.0, -3.81)    # (57.15, 60.96)
    add_pwr("power:+5V", fb1_p1x, fb1_p1y)
    add_pwr("power:+5V", fb1_p2x, fb1_p2y)

    # ── U1: AMS1117-3.3 at (81.28, 60.96) — 64×1.27, 48×1.27 ────────────────
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
    u1_vi_x,  u1_vi_y  = pin_screen(U1X, U1Y, 0, -7.62, 0.0)    # (73.66, 60.96)
    u1_vo_x,  u1_vo_y  = pin_screen(U1X, U1Y, 0,  7.62, 0.0)    # (88.90, 60.96)
    u1_adj_x, u1_adj_y = pin_screen(U1X, U1Y, 0,  0.0, -7.62)   # (81.28, 68.58)
    add_pwr("power:+5V",  u1_vi_x,  u1_vi_y)
    # U1 VO is power_out — do NOT place power:+3V3 here (pin_to_pin error).
    # +3V3 consumers (ESP32, caps) will be wired directly from U1 VO via a bus.
    add_pwr("power:GND",  u1_adj_x, u1_adj_y)

    # ── U2: ESP32-S3-WROOM-1 at (137.16, 81.28) — 108×1.27, 64×1.27 ─────────
    U2X, U2Y = 137.16, 81.28
    placements.append(sym_inst(
        lib_id="RF_Module:ESP32-S3-WROOM-1",
        x=U2X, y=U2Y, angle=0,
        ref="U2", value="ESP32-S3-WROOM-1-N16R8",
        footprint="RF_Module:ESP32-S3-WROOM-1",
        datasheet="https://www.espressif.com/sites/default/files/documentation/esp32-s3-wroom-1_wroom-1u_datasheet_en.pdf",
        props_extra={
            "Manufacturer": "Espressif Systems",
            "MPN": "ESP32-S3-WROOM-1-N16R8",
        },
        pin_numbers=[str(n) for n in range(1, 42)],
    ))

    # ESP32 pin data: (pin_number, px_lib, py_lib, net_or_nc)
    # "3v3" means connected via +3V3 wire bus (no power symbol — U1 VO is power_out)
    esp32_pins = [
        # Power
        ("1",  0.0, -27.94, "gnd"),   # GND
        ("2",  0.0,  27.94, "3v3"),   # 3V3 — wire bus
        ("40", 0.0, -27.94, "gnd"),   # GND dup
        ("41", 0.0, -27.94, "gnd"),   # GND dup
        # Left-side signal pins (x=-15.24)
        ("3",  -15.24,  22.86, "nc"),  # EN
        ("27", -15.24,  17.78, "nc"),  # IO0
        ("39", -15.24,  15.24, "nc"),  # IO1
        ("38", -15.24,  12.70, "nc"),  # IO2
        ("15", -15.24,  10.16, "nc"),  # IO3
        ("4",  -15.24,   7.62, "nc"),  # IO4
        ("5",  -15.24,   5.08, "nc"),  # IO5
        ("6",  -15.24,   2.54, "nc"),  # IO6
        ("7",  -15.24,   0.00, "nc"),  # IO7
        ("12", -15.24,  -2.54, "nc"),  # IO8
        ("17", -15.24,  -5.08, "nc"),  # IO9
        ("18", -15.24,  -7.62, "nc"),  # IO10
        ("19", -15.24, -10.16, "nc"),  # IO11
        ("20", -15.24, -12.70, "nc"),  # IO12
        ("21", -15.24, -15.24, "nc"),  # IO13
        ("22", -15.24, -17.78, "nc"),  # IO14
        ("8",  -15.24, -20.32, "nc"),  # IO15
        ("9",  -15.24, -22.86, "nc"),  # IO16
        # Right-side signal pins (x=+15.24)
        ("37",  15.24,  22.86, "nc"),  # TXD0
        ("36",  15.24,  20.32, "nc"),  # RXD0
        ("10",  15.24,  17.78, "nc"),  # IO17
        ("11",  15.24,  15.24, "nc"),  # IO18
        ("13",  15.24,  12.70, "nc"),  # USB_D-
        ("14",  15.24,  10.16, "nc"),  # USB_D+
        ("23",  15.24,   7.62, "nc"),  # IO21
        ("28",  15.24,   5.08, "nc"),  # IO35
        ("29",  15.24,   2.54, "nc"),  # IO36
        ("30",  15.24,   0.00, "nc"),  # IO37
        ("31",  15.24,  -2.54, "nc"),  # IO38
        ("32",  15.24,  -5.08, "nc"),  # IO39
        ("33",  15.24,  -7.62, "nc"),  # IO40
        ("34",  15.24, -10.16, "nc"),  # IO41
        ("35",  15.24, -12.70, "nc"),  # IO42
        ("26",  15.24, -15.24, "nc"),  # IO45
        ("16",  15.24, -17.78, "nc"),  # IO46
        ("24",  15.24, -20.32, "nc"),  # IO47
        ("25",  15.24, -22.86, "nc"),  # IO48
    ]
    for _pnum, px, py, net in esp32_pins:
        sx, sy = pin_screen(U2X, U2Y, 0, px, py)
        if net == "gnd":
            add_pwr("power:GND", sx, sy)
        elif net == "3v3":
            pass  # Connected via +3V3 wire bus (see wire_3v3 section below)
        else:
            add_nc(sx, sy)

    # ── Capacitors ────────────────────────────────────────────────────────────
    # Device:C pin1=(0,3.81) top/+, pin2=(0,-3.81) bottom/GND
    cap_defs = [
        # ref,  val,     cx,      cy,      rail,   fp,                               mfr,      mpn,                  pkg,  vlt
        ("C1", "100nF", 106.68, 41.91, "+3V3", "Capacitor_SMD:C_0603_1608Metric",  "Samsung", "CL10B104KB8NNNC",  "0603", "16V"),
        ("C2", "100nF", 114.30, 41.91, "+3V3", "Capacitor_SMD:C_0603_1608Metric",  "Samsung", "CL10B104KB8NNNC",  "0603", "16V"),
        ("C3", "10uF",  121.92, 41.91, "+3V3", "Capacitor_SMD:C_0805_2012Metric",  "Murata",  "GRM21BR61A106KE18L","0805","10V"),
        ("C4", "10uF",  129.54, 41.91, "+3V3", "Capacitor_SMD:C_0805_2012Metric",  "Murata",  "GRM21BR61A106KE18L","0805","10V"),
        ("C5", "100nF",  73.66, 81.28, "+5V",  "Capacitor_SMD:C_0603_1608Metric",  "Samsung", "CL10B104KB8NNNC",  "0603", "16V"),
        ("C6", "4.7uF",  88.90, 81.28, "+3V3", "Capacitor_SMD:C_0805_2012Metric",  "Murata",  "GRM21BR61A475KA73L","0805","10V"),
    ]
    for ref, val, cx, cy, rail, fp, mfr, mpn, pkg, vlt in cap_defs:
        placements.append(sym_inst(
            lib_id="Device:C",
            x=cx, y=cy, angle=0,
            ref=ref, value=val,
            footprint=fp, datasheet="~",
            props_extra={"Manufacturer": mfr, "MPN": mpn, "Package": pkg, "Voltage": vlt},
            pin_numbers=["1", "2"],
        ))
        p1x, p1y = pin_screen(cx, cy, 0, 0.0, 3.81)   # top pin (+)
        p2x, p2y = pin_screen(cx, cy, 0, 0.0, -3.81)  # bottom pin (GND)
        # +3V3 caps: top pin connected via wire bus (no power symbol — avoids pin_to_pin)
        if rail != "+3V3":
            add_pwr(f"power:{rail}", p1x, p1y)
        add_pwr("power:GND", p2x, p2y)

    # ── +3V3 net labels ───────────────────────────────────────────────────────
    # U1 VO (power_out) drives +3V3. Using same-named local net labels on one sheet
    # connects all +3V3 pins without wires and without pin_to_pin ERC errors.
    # Label anchor must be exactly at the component pin endpoint.
    labels_3v3 = []
    # U1 VO — right-exiting pin, angle=0 (anchor left, text right)
    labels_3v3.append(net_lbl("+3V3", u1_vo_x, u1_vo_y, 0))
    # Caps +3V3 tops — upward-exiting, angle=90 (anchor bottom, text up)
    for (ref, val, cx, cy, rail, *_) in cap_defs:
        if rail == "+3V3":
            p1x, p1y = pin_screen(cx, cy, 0, 0.0, 3.81)
            labels_3v3.append(net_lbl("+3V3", p1x, p1y, 90))
    # ESP32 3V3 pin — upward-exiting, angle=90
    u2_3v3_x, u2_3v3_y = pin_screen(U2X, U2Y, 0, 0.0, 27.94)
    labels_3v3.append(net_lbl("+3V3", u2_3v3_x, u2_3v3_y, 90))

    wires = []
    junctions_list = []

    # ── PWR_FLAG — one per net without an explicit power_out driver ───────────
    # +3V3: driven by U1 VO (power_out) — no PWR_FLAG (would cause pin_to_pin)
    # +5V: external USB source — PWR_FLAG tells ERC this net is intentionally driven
    add_pwr("power:PWR_FLAG", vbus_x, vbus_y)
    # GND: marked driven by GND power symbols + PWR_FLAG
    add_pwr("power:PWR_FLAG", j1_gnd_x, j1_gnd_y)

    # ── Annotations ───────────────────────────────────────────────────────────
    annotations = [
        text("Kill_LIFE ESP32-S3-WROOM-1 Minimal Power Board", 10, 6, size=1.5),
        text("SPICE validated: spice/05_power_ldo_ams1117.sp", 10, 10, size=1.0),
        text("v_droop=3.192V (>3.135V) — WiFi 350mA burst OK", 10, 13, size=1.0),
    ]

    # ── Assemble ──────────────────────────────────────────────────────────────
    all_elements = (placements + pwr_syms + nc_markers
                    + wires + junctions_list + labels_3v3 + annotations)
    body = "\n".join(all_elements)

    sch = f"""(kicad_sch
\t(version 20260101)
\t(generator "kill_life_gen")
\t(generator_version "10.0")
\t(uuid "{gen_uuid()}")
\t(paper "A3")
\t(title_block
\t\t(title "ESP32-S3 Minimal Power + Module")
\t\t(date "2026-03-25")
\t\t(rev "1.1")
\t\t(company "Kill_LIFE")
\t\t(comment 1 "ESP32-S3-WROOM-1 + USB-C (power) + AMS1117-3.3 LDO")
\t\t(comment 2 "Decoupling: 100nF + 10µF per VDD pair")
\t\t(comment 3 "SPICE: spice/05_power_ldo_ams1117.sp — v_droop=3.192V, v_steady=3.269V")
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
    print(f"Written: {output} ({len(sch):,} bytes)")
    print("\nExpected pin endpoints (screen coords, all on 1.27mm grid):")
    print(f"  J1 VBUS  : ({vbus_x}, {vbus_y})")
    print(f"  J1 GND   : ({j1_gnd_x}, {j1_gnd_y})")
    print(f"  FB1 pin1 : ({fb1_p1x}, {fb1_p1y})")
    print(f"  FB1 pin2 : ({fb1_p2x}, {fb1_p2y})")
    print(f"  U1 VI    : ({u1_vi_x}, {u1_vi_y})")
    print(f"  U1 VO    : ({u1_vo_x}, {u1_vo_y})")
    print(f"  U1 ADJ   : ({u1_adj_x}, {u1_adj_y})")
    u2_gnd_x, u2_gnd_y = pin_screen(U2X, U2Y, 0, 0.0, -27.94)
    u2_vcc_x, u2_vcc_y = pin_screen(U2X, U2Y, 0, 0.0,  27.94)
    print(f"  U2 GND   : ({u2_gnd_x}, {u2_gnd_y})")
    print(f"  U2 3V3   : ({u2_vcc_x}, {u2_vcc_y})")


if __name__ == "__main__":
    out = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path("esp32_minimal.kicad_sch")
    build(out)
