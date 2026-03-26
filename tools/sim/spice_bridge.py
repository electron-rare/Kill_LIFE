#!/usr/bin/env python3
"""
Kill_LIFE SPICE-QEMU Bridge — Proof of Concept
================================================

Purpose:
    Bridge between ngspice analog circuit simulation and QEMU ESP32-S3
    emulation. This script runs a SPICE transient analysis, parses the
    waveform output, and maps analog voltages to the digital domain the
    ESP32-S3 firmware would observe (ADC readings, brownout detector
    states, GPIO logic levels).

Architecture overview (current and future):
    ┌──────────┐         ┌──────────────┐         ┌──────────────┐
    │  ngspice │ ──csv──>│ spice_bridge │ ──ADC──>│  QEMU        │
    │  (.sp)   │         │   (Python)   │ <─GPIO──│  ESP32-S3    │
    └──────────┘         └──────────────┘         └──────────────┘

Current implementation (Phase 1 — proof of concept):
    - Runs ngspice in batch mode on a .sp netlist
    - Parses the tabular print output from the log file
    - Maps V(VPWR) to ESP32-S3 ADC1 readings (12-bit, 0-3.3V)
    - Evaluates brownout detector thresholds
    - Generates a timestamped report showing what the firmware would see

Future phases (not yet implemented):
    Phase 2 — Named-pipe interface:
        ngspice shared-library mode (libngspice / --shared) allows
        programmatic step-by-step simulation. A Python ctypes wrapper
        can call ngspice_Init(), ngspice_Command("step"), and read
        node voltages at each timestep. These get written to a named
        pipe that a QEMU plugin reads to update ADC peripheral registers.

    Phase 3 — Bidirectional co-simulation:
        QEMU's ESP32-S3 GPIO outputs (e.g., PWM for LED drivers, enable
        signals for power stages) get captured via QEMU's chardev or
        custom machine hooks, fed back into ngspice as piecewise-linear
        voltage sources. This closes the loop for hardware-in-the-loop
        style simulation.

    Phase 4 — Socket-based real-time bridge:
        Replace pipes with a ZeroMQ or Unix socket protocol for
        deterministic lock-step co-simulation. Each QEMU CPU cycle
        boundary triggers a SPICE timestep advance, and vice versa.

Limitations:
    - ngspice batch mode is offline (no real-time feedback loop)
    - The AMS1117 model here is simplified (ideal source + Zout),
      not a full transistor-level model
    - ESP32-S3 ADC in QEMU (Espressif fork) has limited peripheral
      emulation — ADC registers exist but are not fully functional
    - Time domains differ: SPICE runs in continuous analog time,
      QEMU runs in discrete instruction cycles. A real bridge needs
      a synchronization protocol.
    - No libngspice shared library detected on this system; batch
      mode is the only option for now.

Dependencies:
    - ngspice (tested with ngspice-42)
    - Python 3.8+
    - No external Python packages required

Usage:
    python3 tools/sim/spice_bridge.py [--netlist path.sp] [--node VPWR]
    python3 tools/sim/spice_bridge.py --help
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

# ---------------------------------------------------------------------------
# Constants — ESP32-S3 electrical characteristics
# ---------------------------------------------------------------------------

# ESP32-S3 ADC1: 12-bit SAR, 0–3.3 V default attenuation (ADC_ATTEN_DB_12)
ADC_BITS = 12
ADC_MAX_CODE = (1 << ADC_BITS) - 1  # 4095
ADC_VREF = 3.3  # Volts (full-scale with 12 dB attenuation)

# ESP32-S3 brownout detector thresholds (from TRM Table 33)
# These are programmable; defaults shown.
BROWNOUT_THRESHOLDS = {
    "BOD_LEVEL_7": 2.43,  # Lowest threshold
    "BOD_LEVEL_6": 2.48,
    "BOD_LEVEL_5": 2.58,
    "BOD_LEVEL_4": 2.68,
    "BOD_LEVEL_3": 2.78,
    "BOD_LEVEL_2": 2.88,
    "BOD_LEVEL_1": 2.98,
    "BOD_LEVEL_0": 3.08,  # Highest threshold (default in ESP-IDF)
}
DEFAULT_BOD_LEVEL = "BOD_LEVEL_0"  # ESP-IDF default

# GPIO logic levels (3.3V CMOS)
GPIO_VIL_MAX = 0.25 * 3.3   # 0.825V — max voltage for logic LOW
GPIO_VIH_MIN = 0.75 * 3.3   # 2.475V — min voltage for logic HIGH

# Minimum operating voltage for ESP32-S3 (from datasheet)
VDD_MIN = 3.0   # Volts — below this, behavior is undefined
VDD_NOM = 3.3   # Nominal


# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------

@dataclass
class SpiceDataPoint:
    """One timestep from a SPICE transient simulation."""
    index: int
    time_s: float
    voltages: dict[str, float] = field(default_factory=dict)


@dataclass
class ESP32View:
    """What the ESP32-S3 firmware would observe at a given instant."""
    time_s: float
    time_ms: float
    vpwr: float                    # Raw voltage at VDD pin
    adc_code: int                  # 12-bit ADC reading (if sampled)
    adc_voltage: float             # ADC-reconstructed voltage
    brownout_active: bool          # True if below BOD threshold
    brownout_level: str            # Which BOD level applies
    gpio_state: str                # HIGH / LOW / UNDEFINED
    in_spec: bool                  # True if VDD >= VDD_MIN
    droop_pct: float               # Percentage below nominal


# ---------------------------------------------------------------------------
# SPICE output parser
# ---------------------------------------------------------------------------

def parse_ngspice_log(log_text: str) -> tuple[list[str], list[SpiceDataPoint]]:
    """
    Parse ngspice batch-mode tabular output.

    Expected format (from 'print V(VOUT) V(VPWR)' in .control block):
        Index   time            v(vout)         v(vpwr)
        ----------------------------------------------------------------
        0       0.000000e+00    3.291025e+00    3.290726e+00
        1       1.000000e-07    3.291025e+00    3.290726e+00
        ...

    Returns:
        (column_names, data_points)
    """
    data_points: list[SpiceDataPoint] = []
    col_names: list[str] = []
    header_re = re.compile(
        r"^Index\s+time\s+(.+)", re.IGNORECASE
    )
    data_re = re.compile(
        r"^(\d+)\s+([\d.eE+\-]+)\s+(.*)"
    )
    separator_re = re.compile(r"^-{10,}")

    in_table = False

    for line in log_text.splitlines():
        line = line.strip()
        if not line:
            continue

        # Detect header row
        hm = header_re.match(line)
        if hm:
            if not col_names:
                raw_cols = hm.group(1).split()
                col_names = [c.strip().lower() for c in raw_cols]
            in_table = True
            continue

        # Skip separator lines
        if separator_re.match(line):
            in_table = True
            continue

        # Parse data rows
        if in_table:
            dm = data_re.match(line)
            if dm:
                idx = int(dm.group(1))
                time_val = float(dm.group(2))
                rest = dm.group(3).split()
                voltages = {}
                for i, val_str in enumerate(rest):
                    try:
                        val = float(val_str)
                    except ValueError:
                        continue
                    name = col_names[i] if i < len(col_names) else f"col{i}"
                    voltages[name] = val
                data_points.append(SpiceDataPoint(
                    index=idx,
                    time_s=time_val,
                    voltages=voltages,
                ))
            else:
                # Non-data line while in table — might be a page break
                # or measurement output; keep going
                in_table = False

    return col_names, data_points


def parse_measurements(log_text: str) -> dict[str, float]:
    """Extract .meas results from ngspice output."""
    measurements: dict[str, float] = {}
    # Format: "v_droop             =  3.191805e+00 at=  1.215000e-03"
    # Format: "v_steady            =  3.269087e+00 from=  1.800000e-02 ..."
    meas_re = re.compile(
        r"^(\w+)\s*=\s*([-+]?\d[\d.eE+\-]+)", re.MULTILINE
    )
    for m in meas_re.finditer(log_text):
        name = m.group(1).lower()
        try:
            measurements[name] = float(m.group(2))
        except ValueError:
            pass
    return measurements


# ---------------------------------------------------------------------------
# Voltage-to-ESP32 mapping
# ---------------------------------------------------------------------------

def voltage_to_adc(v: float) -> tuple[int, float]:
    """
    Convert an analog voltage to an ESP32-S3 ADC1 12-bit code.

    The ESP32-S3 ADC is nonlinear in practice, but for this model we
    use a simple linear mapping (which matches the eFuse-calibrated
    behavior after ESP-IDF's adc_cali_scheme).

    Returns (adc_code, reconstructed_voltage).
    """
    clamped = max(0.0, min(v, ADC_VREF))
    code = int(round(clamped / ADC_VREF * ADC_MAX_CODE))
    code = max(0, min(code, ADC_MAX_CODE))
    reconstructed = code * ADC_VREF / ADC_MAX_CODE
    return code, reconstructed


def check_brownout(v: float, level: str = DEFAULT_BOD_LEVEL) -> bool:
    """Return True if voltage is below the brownout threshold."""
    threshold = BROWNOUT_THRESHOLDS.get(level, 3.08)
    return v < threshold


def classify_gpio(v: float) -> str:
    """Classify a voltage as GPIO logic level."""
    if v <= GPIO_VIL_MAX:
        return "LOW"
    elif v >= GPIO_VIH_MIN:
        return "HIGH"
    else:
        return "UNDEFINED"


def map_to_esp32(time_s: float, vpwr: float,
                 bod_level: str = DEFAULT_BOD_LEVEL) -> ESP32View:
    """Map a SPICE voltage to what the ESP32-S3 would observe."""
    adc_code, adc_v = voltage_to_adc(vpwr)
    bod_active = check_brownout(vpwr, bod_level)
    gpio = classify_gpio(vpwr)
    in_spec = vpwr >= VDD_MIN
    droop_pct = (VDD_NOM - vpwr) / VDD_NOM * 100.0

    return ESP32View(
        time_s=time_s,
        time_ms=time_s * 1000.0,
        vpwr=vpwr,
        adc_code=adc_code,
        adc_voltage=adc_v,
        brownout_active=bod_active,
        brownout_level=bod_level,
        gpio_state=gpio,
        in_spec=in_spec,
        droop_pct=droop_pct,
    )


# ---------------------------------------------------------------------------
# ngspice runner
# ---------------------------------------------------------------------------

def run_ngspice(netlist_path: str, timeout: int = 60) -> str:
    """
    Run ngspice in batch mode and return the combined log output.

    Uses -b (batch) and -o (log file) flags. The log file contains
    the 'print' output which is what we parse.
    """
    netlist_path = os.path.abspath(netlist_path)
    if not os.path.isfile(netlist_path):
        raise FileNotFoundError(f"Netlist not found: {netlist_path}")

    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".log", prefix="spice_bridge_", delete=False
    ) as logf:
        log_path = logf.name

    try:
        proc = subprocess.run(
            ["ngspice", "-b", "-o", log_path, netlist_path],
            capture_output=True,
            text=True,
            timeout=timeout,
        )

        log_content = ""
        try:
            log_content = Path(log_path).read_text(
                encoding="utf-8", errors="replace"
            )
        except OSError:
            pass

        if proc.returncode != 0:
            stderr_lines = (proc.stderr or "").strip()
            # ngspice sometimes returns non-zero but simulation completed
            if not log_content:
                raise RuntimeError(
                    f"ngspice failed (exit={proc.returncode}): {stderr_lines}"
                )

        return log_content

    except subprocess.TimeoutExpired:
        raise RuntimeError(f"ngspice timed out after {timeout}s")
    finally:
        try:
            os.unlink(log_path)
        except OSError:
            pass


# ---------------------------------------------------------------------------
# Report generation
# ---------------------------------------------------------------------------

def generate_report(
    netlist_path: str,
    col_names: list[str],
    data_points: list[SpiceDataPoint],
    measurements: dict[str, float],
    node: str = "v(vpwr)",
    bod_level: str = DEFAULT_BOD_LEVEL,
    downsample: int = 50,
) -> str:
    """
    Generate a human-readable report mapping SPICE results to ESP32 domain.

    Args:
        downsample: Show at most this many representative time steps.
                    The bridge selects evenly-spaced points plus any
                    that cross interesting thresholds (brownout, droop).
    """
    lines: list[str] = []
    hr = "=" * 78

    lines.append(hr)
    lines.append("  Kill_LIFE SPICE-QEMU Bridge — Simulation Report")
    lines.append(hr)
    lines.append(f"  Netlist:     {netlist_path}")
    lines.append(f"  Node:        {node}")
    lines.append(f"  Data points: {len(data_points)}")
    lines.append(f"  Time span:   0 .. {data_points[-1].time_s * 1000:.3f} ms")
    lines.append(f"  BOD level:   {bod_level} "
                 f"({BROWNOUT_THRESHOLDS.get(bod_level, '?')} V)")
    lines.append(hr)
    lines.append("")

    # --- Measurements from ngspice ---
    if measurements:
        lines.append("  ngspice .meas results:")
        for name, val in measurements.items():
            lines.append(f"    {name:20s} = {val:.6f}")
        lines.append("")

    # --- Determine which node column to use ---
    node_key = node.lower().replace("v(", "").replace(")", "")
    # Try exact match first, then partial
    actual_key = None
    for cn in col_names:
        clean = cn.replace("v(", "").replace(")", "")
        if clean == node_key:
            actual_key = cn
            break
    if actual_key is None and col_names:
        actual_key = col_names[-1]  # Default to last column
        lines.append(f"  [NOTE] Node '{node}' not found in columns {col_names}; "
                     f"using '{actual_key}'")
        lines.append("")

    # --- Map all points to ESP32 view ---
    esp_views: list[ESP32View] = []
    for dp in data_points:
        v = dp.voltages.get(actual_key, 0.0)
        esp_views.append(map_to_esp32(dp.time_s, v, bod_level))

    # --- Find key events ---
    min_v = min(ev.vpwr for ev in esp_views)
    max_v = max(ev.vpwr for ev in esp_views)
    max_droop = max(ev.droop_pct for ev in esp_views)
    any_brownout = any(ev.brownout_active for ev in esp_views)
    any_out_of_spec = any(not ev.in_spec for ev in esp_views)

    lines.append("  Summary:")
    lines.append(f"    Voltage range:   {min_v:.4f} V .. {max_v:.4f} V")
    lines.append(f"    Max droop:       {max_droop:.2f}% below nominal {VDD_NOM}V")
    lines.append(f"    ADC code range:  {voltage_to_adc(min_v)[0]} .. "
                 f"{voltage_to_adc(max_v)[0]} (of {ADC_MAX_CODE})")
    lines.append(f"    Brownout events: {'YES' if any_brownout else 'NONE'}")
    lines.append(f"    Out-of-spec:     {'YES' if any_out_of_spec else 'NONE'} "
                 f"(VDD < {VDD_MIN}V)")
    lines.append("")

    # --- Event log: transitions ---
    lines.append("  Events (threshold crossings):")
    prev_in_spec = True
    prev_bod = False
    event_count = 0
    for ev in esp_views:
        if ev.in_spec != prev_in_spec:
            direction = "ENTERED" if ev.in_spec else "LEFT"
            lines.append(f"    t={ev.time_ms:8.3f}ms  {direction} operating range "
                         f"(V={ev.vpwr:.4f}V)")
            event_count += 1
            prev_in_spec = ev.in_spec
        if ev.brownout_active != prev_bod:
            direction = "BROWNOUT TRIGGERED" if ev.brownout_active else "BROWNOUT CLEARED"
            lines.append(f"    t={ev.time_ms:8.3f}ms  {direction} "
                         f"(V={ev.vpwr:.4f}V, thresh="
                         f"{BROWNOUT_THRESHOLDS.get(bod_level, 0):.2f}V)")
            event_count += 1
            prev_bod = ev.brownout_active
    if event_count == 0:
        lines.append("    (none — voltage stayed within all thresholds)")
    lines.append("")

    # --- Downsampled waveform table ---
    lines.append("  Waveform (downsampled to ~{} points):".format(
        min(downsample, len(esp_views))))
    lines.append("")
    lines.append("  {:>10s}  {:>8s}  {:>6s}  {:>8s}  {:>7s}  {:>5s}  {:>5s}".format(
        "Time(ms)", "V(VDD)", "Droop%", "ADC code", "ADC(V)", "BOD", "Spec"))
    lines.append("  " + "-" * 62)

    # Select points: even spacing + threshold crossings
    step = max(1, len(esp_views) // downsample)
    indices = set(range(0, len(esp_views), step))
    indices.add(len(esp_views) - 1)  # Always include last

    # Add points near min voltage (interesting region)
    min_idx = min(range(len(esp_views)), key=lambda i: esp_views[i].vpwr)
    for offset in range(-3, 4):
        idx = min_idx + offset
        if 0 <= idx < len(esp_views):
            indices.add(idx)

    for i in sorted(indices):
        ev = esp_views[i]
        bod_str = "YES" if ev.brownout_active else "no"
        spec_str = "OK" if ev.in_spec else "FAIL"
        lines.append(
            "  {:>10.3f}  {:>8.4f}  {:>6.2f}  {:>8d}  {:>7.4f}  {:>5s}  {:>5s}"
            .format(
                ev.time_ms,
                ev.vpwr,
                ev.droop_pct,
                ev.adc_code,
                ev.adc_voltage,
                bod_str,
                spec_str,
            )
        )

    lines.append("")

    # --- QEMU integration notes ---
    lines.append(hr)
    lines.append("  QEMU Integration Notes")
    lines.append(hr)
    lines.append("""
  To feed these values into QEMU ESP32-S3 emulation:

  1. ADC injection (future):
     The Espressif QEMU fork (qemu-system-xtensa -machine esp32s3) emulates
     the SAR ADC peripheral at base address 0x60040000 (APB_SARADC). To inject
     SPICE voltages, a QEMU plugin or GDB script could write to the ADC data
     registers at each simulation timestep:
       - APB_SARADC_SAR1_DATA_STATUS_REG (0x60040004): write ADC code
       - Trigger: breakpoint on adc1_get_raw() or timer interrupt

  2. GPIO mapping (future):
     QEMU ESP32-S3 GPIO is at 0x60004000. Digital outputs from the firmware
     (e.g., GPIO that enables a power stage) can be read from:
       - GPIO_OUT_REG (0x60004004): current output state
     These bits map to SPICE voltage sources via piecewise-linear (PWL) inputs.

  3. Brownout detector (future):
     The RTC brownout detector (RTC_CNTL_BROWN_OUT_REG, 0x600080D4) could be
     triggered by writing to its status bit when SPICE voltage drops below
     the configured threshold — simulating a real power dip.

  4. Synchronization:
     QEMU runs at ~240MHz emulated clock. SPICE timesteps here are 10us.
     At 240MHz, 10us = 2400 CPU cycles. A co-simulation bridge would need
     to pause QEMU every 2400 cycles, read GPIO state, advance SPICE by
     10us, and inject new ADC/brownout values before resuming.
""")

    lines.append(hr)
    lines.append("  End of report")
    lines.append(hr)

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Kill_LIFE SPICE-QEMU Bridge: map ngspice simulation "
                    "results to ESP32-S3 firmware observables.",
        epilog="Example: python3 spice_bridge.py "
               "--netlist ../../spice/05_power_ldo_ams1117.sp --node VPWR",
    )
    parser.add_argument(
        "--netlist", "-n",
        default=None,
        help="Path to SPICE netlist (.sp file). "
             "Default: spice/05_power_ldo_ams1117.sp",
    )
    parser.add_argument(
        "--log", "-l",
        default=None,
        help="Path to pre-existing ngspice log file (skip running ngspice). "
             "Useful for testing the parser without re-running simulation.",
    )
    parser.add_argument(
        "--node",
        default="VPWR",
        help="SPICE node name to map to ESP32 VDD (default: VPWR)",
    )
    parser.add_argument(
        "--bod-level",
        default=DEFAULT_BOD_LEVEL,
        choices=list(BROWNOUT_THRESHOLDS.keys()),
        help=f"Brownout detector level (default: {DEFAULT_BOD_LEVEL})",
    )
    parser.add_argument(
        "--downsample",
        type=int,
        default=50,
        help="Max waveform rows in report (default: 50)",
    )
    parser.add_argument(
        "--output", "-o",
        default=None,
        help="Write report to file (default: stdout)",
    )

    args = parser.parse_args()

    # Resolve netlist path
    repo_root = Path(__file__).resolve().parents[2]
    default_netlist = repo_root / "spice" / "05_power_ldo_ams1117.sp"

    if args.log:
        # Use pre-existing log — do not run ngspice
        log_path = Path(args.log)
        if not log_path.is_file():
            print(f"ERROR: Log file not found: {args.log}", file=sys.stderr)
            return 1
        print(f"[bridge] Reading pre-existing log: {log_path}", file=sys.stderr)
        log_text = log_path.read_text(encoding="utf-8", errors="replace")
        netlist_label = f"(from log: {log_path})"
    else:
        netlist_path = Path(args.netlist) if args.netlist else default_netlist
        if not netlist_path.is_file():
            print(f"ERROR: Netlist not found: {netlist_path}", file=sys.stderr)
            print("Hint: run from repo root, or use --netlist <path>",
                  file=sys.stderr)
            return 1

        print(f"[bridge] Running ngspice on: {netlist_path}", file=sys.stderr)
        try:
            log_text = run_ngspice(str(netlist_path))
        except (FileNotFoundError, RuntimeError) as e:
            print(f"ERROR: {e}", file=sys.stderr)
            return 1
        netlist_label = str(netlist_path)

    # Parse
    col_names, data_points = parse_ngspice_log(log_text)
    measurements = parse_measurements(log_text)

    if not data_points:
        print("ERROR: No data points parsed from ngspice output.",
              file=sys.stderr)
        print("       Check that the netlist has 'print V(...)' in its "
              ".control block.", file=sys.stderr)
        return 1

    print(f"[bridge] Parsed {len(data_points)} timesteps, "
          f"columns: {col_names}", file=sys.stderr)

    # Build node key for lookup
    node_query = f"v({args.node.lower()})"

    # Generate report
    report = generate_report(
        netlist_path=netlist_label,
        col_names=col_names,
        data_points=data_points,
        measurements=measurements,
        node=node_query,
        bod_level=args.bod_level,
        downsample=args.downsample,
    )

    if args.output:
        Path(args.output).write_text(report, encoding="utf-8")
        print(f"[bridge] Report written to: {args.output}", file=sys.stderr)
    else:
        print(report)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
