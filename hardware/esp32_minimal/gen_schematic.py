#!/usr/bin/env python3
"""Generate esp32_minimal.kicad_sch from extracted KiCad symbols."""
import json
import uuid
from pathlib import Path

HERE = Path(__file__).parent
with open(HERE / "extracted_symbols.json") as f:
    SYM = json.load(f)

def uid():
    return str(uuid.uuid4())

# Rename lib-keyed symbols to match lib:name format
# KiCad lib_symbols section needs symbols as "LibName:SymbolName"
# We write them with their lib prefix already in the key
LIB_MAP = {
    "ESP32-S3-WROOM-1": "RF_Module:ESP32-S3-WROOM-1",
    "AMS1117-3.3":      "Regulator_Linear:AMS1117-3.3",
    "R":                "Device:R",
    "C":                "Device:C",
    "LED":              "Device:LED",
    "+3.3V":            "power:+3.3V",
    "GND":              "power:GND",
    "+5V":              "power:+5V",
    "PWR_FLAG":         "power:PWR_FLAG",
    "USB_C_Receptacle": "Connector:USB_C_Receptacle",
}

def lib_sym_block():
    """lib_symbols section: rename symbol keys to Lib:Name format."""
    parts = []
    for short, full in LIB_MAP.items():
        sym_text = SYM[short]
        # Replace the top-level symbol name with the full lib:name
        renamed = sym_text.replace(f'(symbol "{short}"', f'(symbol "{full}"', 1)
        # Also rename sub-symbols (e.g. R_0_1 → Device:R_0_1)
        renamed = renamed.replace(f'(symbol "{short}_', f'(symbol "{full}_')
        parts.append("    " + renamed.replace("\n", "\n    "))
    return "\n".join(parts)

def power_sym(lib_name, ref, at_x, at_y, u_id=None):
    """Instantiate a power symbol."""
    u = u_id or uid()
    return f"""  (symbol (lib_id "{lib_name}") (at {at_x} {at_y} 0) (unit 1)
    (in_bom yes) (on_board yes) (dnp no) (fields_autoplaced yes)
    (uuid "{u}")
    (property "Reference" "#PWR0{ref}" (at {at_x} {at_y+1.27:.2f} 0) (effects (font (size 1.27 1.27)) hide))
    (property "Value" "{lib_name.split(':')[1]}" (at {at_x} {at_y-1.27:.2f} 0) (effects (font (size 1.27 1.27))))
    (property "Footprint" "" (at {at_x} {at_y} 0) (effects (font (size 1.27 1.27)) hide))
    (property "Datasheet" "" (at {at_x} {at_y} 0) (effects (font (size 1.27 1.27)) hide))
    (pin "1" (uuid "{uid()}"))
  )"""

def component(lib_id, ref, value, at_x, at_y, angle=0, footprint="", extra_props=None):
    u = uid()
    props = f"""    (property "Reference" "{ref}" (at {at_x+1.27:.2f} {at_y-1.27:.2f} 0) (effects (font (size 1.27 1.27))))
    (property "Value" "{value}" (at {at_x+1.27:.2f} {at_y+1.27:.2f} 0) (effects (font (size 1.27 1.27))))
    (property "Footprint" "{footprint}" (at {at_x} {at_y} 0) (effects (font (size 1.27 1.27)) hide))
    (property "Datasheet" "" (at {at_x} {at_y} 0) (effects (font (size 1.27 1.27)) hide))"""
    if extra_props:
        for k, v in extra_props.items():
            props += f'\n    (property "{k}" "{v}" (at {at_x} {at_y} 0) (effects (font (size 1.27 1.27)) hide))'
    return f"""  (symbol (lib_id "{lib_id}") (at {at_x} {at_y} {angle}) (unit 1)
    (in_bom yes) (on_board yes) (dnp no) (fields_autoplaced yes)
    (uuid "{u}")
{props}
  )"""

def wire(x1, y1, x2, y2):
    return f"""  (wire (pts (xy {x1} {y1}) (xy {x2} {y2}))
    (stroke (width 0) (type default))
    (uuid "{uid()}")
  )"""

def net_label(text, x, y, angle=0):
    return f"""  (label "{text}" (at {x} {y} {angle})
    (effects (font (size 1.27 1.27)) (justify left))
    (uuid "{uid()}")
    (fields_autoplaced yes)
  )"""

# ─────────────────────────────────────────────────────────────
# Layout (all in mm, KiCad default grid 2.54mm / 1.27mm)
# ─────────────────────────────────────────────────────────────
#
#   J1 (USB-C)  ── +5V net ──→  U2 (AMS1117-3.3) ──→ +3V3 net ──→ U1 (ESP32-S3)
#                                                                     │
#                                                         D1,D2 (LEDs) + decoupling caps
#
# Coordinates:
#   U1 (ESP32):       (120, 70)
#   U2 (AMS1117):     (60, 70)
#   J1 (USB-C):       (20, 70)
#   D1 (LED-PWR):     (120, 110)
#   D2 (LED-IO):      (135, 110)
#   Caps C1-C4:       (80-100, 90)
#   R1 (CC1):         (20, 90)
#   R2 (CC2):         (25, 90)
#   R3 (LED1 res):    (120, 105)
#   R4 (LED2 res):    (135, 105)

symbols_section = f"""  (lib_symbols
{lib_sym_block()}
  )"""

components_section = "\n".join([
    # U1 — ESP32-S3-WROOM-1
    component("RF_Module:ESP32-S3-WROOM-1", "U1", "ESP32-S3-WROOM-1",
              120, 70, footprint="RF_Module:ESP32-S3-WROOM-1"),
    # U2 — AMS1117-3.3
    component("Regulator_Linear:AMS1117-3.3", "U2", "AMS1117-3.3",
              60, 70, footprint="Package_TO_SOT_SMD:SOT-223-3_TabPin2"),
    # J1 — USB-C Receptacle
    component("Connector:USB_C_Receptacle", "J1", "USB_C_Receptacle",
              20, 70, footprint="Connector_USB:USB_C_Receptacle_GCT_USB4085"),
    # R1 — CC1 5.1k pull-down
    component("Device:R", "R1", "5k1",
              35, 82, angle=0, footprint="Resistor_SMD:R_0402_1005Metric"),
    # R2 — CC2 5.1k pull-down
    component("Device:R", "R2", "5k1",
              42, 82, angle=0, footprint="Resistor_SMD:R_0402_1005Metric"),
    # C1 — 10µF bulk cap on 3.3V
    component("Device:C", "C1", "10u",
              80, 88, footprint="Capacitor_SMD:C_0805_2012Metric"),
    # C2 — 100nF decoupling on 3.3V
    component("Device:C", "C2", "100n",
              88, 88, footprint="Capacitor_SMD:C_0402_1005Metric"),
    # C3 — 100nF decoupling input of AMS1117
    component("Device:C", "C3", "100n",
              52, 82, footprint="Capacitor_SMD:C_0402_1005Metric"),
    # C4 — 10µF output of AMS1117
    component("Device:C", "C4", "10u",
              70, 82, footprint="Capacitor_SMD:C_0805_2012Metric"),
    # R3 — LED1 current limit (470R)
    component("Device:R", "R3", "470",
              110, 105, angle=0, footprint="Resistor_SMD:R_0402_1005Metric"),
    # R4 — LED2 current limit (470R)
    component("Device:R", "R4", "470",
              120, 105, angle=0, footprint="Resistor_SMD:R_0402_1005Metric"),
    # D1 — PWR LED
    component("Device:LED", "D1", "LED_PWR",
              110, 112, angle=270, footprint="LED_SMD:LED_0402_1005Metric"),
    # D2 — IO LED
    component("Device:LED", "D2", "LED_IO",
              120, 112, angle=270, footprint="LED_SMD:LED_0402_1005Metric"),
    # Power symbols
    power_sym("power:+5V",   1, 20, 55),
    power_sym("power:GND",   2, 20, 90),
    power_sym("power:+3.3V", 3, 60, 55),
    power_sym("power:GND",   4, 60, 90),
    power_sym("power:+3.3V", 5, 120, 55),
    power_sym("power:GND",   6, 120, 90),
    power_sym("power:GND",   7, 35, 92),
    power_sym("power:GND",   8, 42, 92),
    power_sym("power:GND",   9, 80, 95),
    power_sym("power:GND",  10, 88, 95),
    power_sym("power:GND",  11, 110, 118),
    power_sym("power:GND",  12, 120, 118),
    power_sym("power:PWR_FLAG", 13, 25, 55),
    power_sym("power:PWR_FLAG", 14, 65, 55),
])

wires_section = "\n".join([
    # USB VBUS → +5V label
    wire(20, 58, 20, 62),
    # USB GND → GND label
    wire(20, 84, 20, 90),
    # AMS1117 IN ← +5V
    wire(52, 58, 52, 66),
    # AMS1117 OUT → +3.3V
    wire(68, 66, 68, 58),
    # AMS1117 GND
    wire(60, 74, 60, 90),
    # ESP32 VCC ← +3.3V
    wire(120, 58, 120, 62),
    # ESP32 GND
    wire(120, 78, 120, 90),
])

labels_section = "\n".join([
    net_label("VBUS", 22, 62),
    net_label("CC1", 35, 78),
    net_label("CC2", 42, 78),
    net_label("+3V3", 68, 62),
])

schematic = f"""(kicad_sch (version 20250114) (generator "schops-gen")

  (uuid "{uid()}")

  (paper "A3")

  (title_block
    (title "ESP32-S3 Minimal")
    (rev "v0.1")
    (company "Kill_LIFE")
    (comment 1 "WiFi Scanner reference design")
  )

{symbols_section}

{components_section}

{wires_section}

{labels_section}

)
"""

out = HERE / "esp32_minimal.kicad_sch"
out.write_text(schematic, encoding="utf-8")
print(f"Written: {out}")
print(f"Size: {len(schematic)} chars")
