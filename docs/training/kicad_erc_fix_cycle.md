# Training Example: KiCad 10 ERC Correction Cycle
date: 2026-03-25
domain: hardware/eda/kicad
type: debugging_cycle
outcome: 127_violations → 0_violations

## Summary

Complete ERC debugging cycle for a programmatically-generated KiCad 10 schematic. Starting from 127 ERC violations, resolved to 0 errors/0 warnings through 5 distinct root cause fixes.

## Context

- Tool: `hardware/esp32_minimal/gen_kicad10.py` — Python generator writing `.kicad_sch` (KiCad 10 format, version 20260101)
- Schematic: ESP32-S3-WROOM-1 minimal power board (USB-C → AMS1117-3.3 LDO → ESP32)
- KiCad version: 10.0 (Docker image `kicad/kicad:10.0`)
- ERC runner: `kicad-cli sch erc`

---

## Initial State: 127 Violations

```
79  pin_not_connected      — no NC markers on unused ESP32 GPIO pins
28  endpoint_off_grid      — component placement not on 1.27mm grid
10  label_dangling         — net labels not connected to any pin
 7  power_pin_not_driven   — missing PWR_FLAG on power nets
 2  no_connect_dangling    — NC markers not at exact pin endpoints
 1  pin_not_driven         — floating pin
```

---

## Fix 1: Grid Alignment (endpoint_off_grid → 0)

**Root cause**: Component placement coordinates (30, 54, 60, 70, 80, etc.) are NOT multiples of 1.27mm. KiCad's connection grid is 1.27mm (50 mil). All pin offsets in KiCad 10 libraries are multiples of 1.27mm. If the placement coordinate is not on the grid, pin endpoints land off-grid and cannot connect.

**Key insight**: `54 / 1.27 = 42.52` → not integer → off-grid.

**Fix**: Recompute all placements as multiples of 1.27mm. Use the formula:
```python
def pin_screen(sx, sy, angle_deg, px_lib, py_lib):
    """Screen coordinate of a pin endpoint.
    KiCad library Y-axis is UP (math convention).
    Schematic Y-axis is DOWN (screen convention).
    Transform: rotate in lib coords, then flip Y.
    """
    a = math.radians(angle_deg)
    rx = px_lib * math.cos(a) - py_lib * math.sin(a)
    ry = px_lib * math.sin(a) + py_lib * math.cos(a)
    return (sx + rx, sy - ry)  # Y-flip for screen coords
```

**Verification**: `pin_screen(137.16, 81.28, 0, 0, -27.94)` → `(137.16, 109.22)`, and `109.22 / 1.27 = 86.0` ✓

**New placements** (all on 1.27mm grid):
- J1 USB-C: (30.48, 71.12) = (24×1.27, 56×1.27)
- FB1 FerriteBead: (53.34, 60.96, 90°) = (42×1.27, 48×1.27)
- U1 AMS1117: (81.28, 60.96) = (64×1.27, 48×1.27)
- U2 ESP32: (137.16, 81.28) = (108×1.27, 64×1.27)
- Caps: multiples of 1.27mm at standard spacing

---

## Fix 2: No-Connect Markers (pin_not_connected → 0)

**Root cause**: 41 ESP32-S3 pins, only 2 used (GND, 3V3). All 39 unused signal pins need explicit `no_connect` markers at their exact pin endpoints.

**Fix**: Precompute pin endpoint for every pin using `pin_screen()`, add `no_connect` at each unused endpoint:
```python
def add_nc(x, y):
    key = (round(x, 3), round(y, 3))
    if key not in placed_nc_keys:
        placed_nc_keys.add(key)
        nc_markers.append(no_connect(x, y))
```

Track placed NCs to avoid duplicates at coincident pins (e.g., ESP32 pins 1, 40, 41 all share the same GND location).

---

## Fix 3: AMS1117-3.3 Extends Resolution (lib_symbol_mismatch + pin_not_connected)

**Root cause**: `AMS1117-3.3` uses `(extends "AP1117-ADJ")` in KiCad library. When embedding in schematic `lib_symbols`, the parent `AP1117-ADJ` was missing. KiCad could not resolve pin positions → ERC couldn't find pin endpoints → power symbols at those coordinates showed as "not connected".

**Fix**: Flatten the `extends` chain at generation time. Extract the parent symbol's sub-symbols (which contain the actual pin definitions) and inject them directly into the child symbol:

```python
if extends_m:
    parent_raw = extract_symbol(lib_file, parent_name)
    sub_pat = re.compile(
        r'\t\t\(symbol "' + re.escape(parent_name) + r'_\d+_\d+".*?(?=\n\t\t\(symbol |\n\t\(embedded_fonts|\n\t\))',
        re.DOTALL,
    )
    parent_subs = sub_pat.findall(parent_raw)
    # Rename sub-symbols and inject into child
```

This produces a fully self-contained `(symbol "Regulator_Linear:AMS1117-3.3" ...)` without the `extends` dependency.

**Lesson**: For ERC-clean programmatic schematic generation, always resolve `extends` chains and embed flat symbols.

---

## Fix 4: Power Net + LDO Output (pin_to_pin → 0)

**Root cause**: `power:+3V3` (KiCad global power symbol with `(power global)`) acts as "Power output" in ERC. Connecting it to `AMS1117-3.3 VO` (also `power_out`) gives `pin_to_pin` error: two power sources on the same net.

**Attempted fixes that failed**:
- Use `power:+3V3` at U1 VO → pin_to_pin ✗
- Use `power:PWR_FLAG` on the +3V3 net → PWR_FLAG is also `power_out` → pin_to_pin ✗
- Wire bus from U1 VO to consumers, no power symbols → `wire_dangling` (endpoints in empty space) ✗

**Correct fix**: Use **local net labels** `(label "+3V3" ...)` placed exactly at each consumer pin endpoint. Same-named labels on one schematic sheet form a net. No power symbols needed on the +3V3 net.

```python
# At U1 VO pin endpoint — drives +3V3 net (power_out)
labels_3v3.append(net_lbl("+3V3", u1_vo_x, u1_vo_y, angle=0))
# At each consumer pin — upward-exiting caps and ESP32 pin
labels_3v3.append(net_lbl("+3V3", cap_pin1_x, cap_pin1_y, angle=90))
labels_3v3.append(net_lbl("+3V3", esp32_3v3_x, esp32_3v3_y, angle=90))
```

**Key rule**: `(power global)` symbols (GND, +5V, +3V3, PWR_FLAG) are all treated as "Power output" by KiCad ERC. Never connect two of them to the same net as an explicit `power_out` pin from a component.

**Corollary**: PWR_FLAG is only needed for nets with no `power_out` driver (external power). For on-sheet LDO output, the LDO VO pin IS the driver — no PWR_FLAG.

---

## Fix 5: Dangling Labels (label_dangling → 0)

**Root cause**: Net labels placed at coordinates that don't match any pin endpoint → "dangling".

**Fix**: Place labels with `angle` matching the pin exit direction:
- Right-exiting pin (angle=0 in library): label `angle=0`
- Top-exiting pin (angle=270 in library): label `angle=90` (anchor at bottom = pin tip)

---

## Final State: 0 Violations

```
ERC messages: 0  Errors 0  Warnings 0
```

Generator output: `esp32_minimal.kicad_sch` (78,247 bytes), KiCad 10 format, 10 components, BOM clean.

---

## Lessons for Future Training

| Violation | Root Cause | Fix Pattern |
|-----------|-----------|-------------|
| `endpoint_off_grid` | Placement not on 1.27mm grid | Compute pin endpoints, snap placement to grid |
| `pin_not_connected` | Missing NC markers | Place `no_connect` at exact pin_screen() result |
| `lib_symbol_mismatch` | Unresolved `extends` in lib_symbols | Flatten extends chain at generation time |
| `pin_to_pin` with LDO | Two power_out on same net | Use net labels for LDO output net; no power symbols |
| `wire_dangling` | Wire endpoint in empty space | Use net labels instead of wires where possible |
| `label_dangling` | Label not at pin endpoint | Use `pin_screen()` to get exact anchor coordinates |

---

## Files

- Generator: `hardware/esp32_minimal/gen_kicad10.py`
- Schematic: `hardware/esp32_minimal/esp32_minimal.kicad_sch`
- ERC report: `hardware/esp32_minimal/erc_report.txt`
- BOM: `artifacts/hw/20260325T061825/bom.csv`
