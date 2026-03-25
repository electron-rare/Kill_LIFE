#!/usr/bin/env python3
"""
build_datasets.py — Unified dataset builder for Mistral fine-tuning (Plans 23 & 24)

Generates template-based synthetic Q&A pairs in ChatML JSONL format
for 10 engineering domains.

Usage:
    python3 build_datasets.py --domain kicad --output datasets/kicad/train.jsonl
    python3 build_datasets.py --all --output-dir datasets/
    python3 build_datasets.py --validate datasets/kicad/train.jsonl
"""

import argparse
import json
import os
import random
import sys
from pathlib import Path
from typing import Optional

# ---------------------------------------------------------------------------
# Domain template definitions
# ---------------------------------------------------------------------------

DOMAINS = [
    "kicad", "spice", "freecad", "stm32", "embedded",
    "iot", "emc", "dsp", "power", "platformio",
]

# Each domain returns a list of {"user": ..., "assistant": ...} dicts.


def _kicad_templates() -> list[dict]:
    """PCB design, schematic review, DRC, footprint questions."""
    pairs = []

    # --- Schematic review ---
    components = [
        ("STM32F4", "microcontroller", "100nF decoupling caps on each VDD pin, ferrite bead on VDDA, bulk 10uF on main supply rail"),
        ("ESP32-S3", "WiFi/BLE SoC", "3.3V LDO with 10uF + 100nF, RF matching network (LC pi), USB-C with ESD protection"),
        ("LM2596", "buck converter", "input cap 680uF, output cap 220uF low-ESR, Schottky diode (SS34), inductor 33uH shielded"),
        ("ADS1256", "24-bit ADC", "separate AVDD/DVDD planes, 100nF + 10uF on each supply, guard ring around analog inputs"),
        ("TLV62569", "3.3V buck", "2.2uH inductor, 22uF ceramic output cap, 10uF input cap, feedback resistor divider 1%"),
        ("OLED SSD1306", "I2C display", "pull-up resistors 4.7k on SDA/SCL, 10uF + 100nF bypass caps, charge pump cap 1uF"),
    ]
    for comp, desc, answer in components:
        pairs.append({
            "user": f"I'm reviewing a schematic with a {comp} ({desc}). What are the critical passive components I should verify around it?",
            "assistant": f"For the {comp} ({desc}), verify these critical passives:\n\n{answer}\n\nAlso check that the component values match the datasheet recommendations and that tolerances are appropriate for the application.",
        })

    # --- DRC errors ---
    drc_errors = [
        ("clearance violation between a ground pour and a signal trace",
         "Increase the clearance rule in Board Setup > Design Rules > Net Classes. Typical minimum is 0.2mm for standard PCB, 0.15mm for fine-pitch. If the ground pour is causing issues, add a keepout zone or adjust the pour settings to increase thermal relief gap."),
        ("unconnected pad on U1 pin 37",
         "Check the schematic for the net assignment on U1 pin 37. Common causes: (1) pin not connected in schematic — add wire or no-connect flag, (2) footprint pin numbering mismatch — verify footprint-to-symbol pin mapping in footprint editor, (3) net name typo — compare schematic net label with PCB net."),
        ("track width too narrow for power net VCC_3V3",
         "Power nets need wider traces for current capacity. For 1A at 1oz copper: use minimum 0.5mm (20mil) trace. Set up a dedicated net class in Board Setup > Net Classes with appropriate width. For high-current nets (>2A), consider polygon pours instead of traces."),
        ("silk screen overlap with pad on J1",
         "Move or resize the silkscreen text in the footprint editor. Enable the 'Silk to pad clearance' DRC check (minimum 0.15mm). For connectors, place reference designator outside the component courtyard. You can also adjust silk layer globally in Board Setup."),
        ("courtyard overlap between C12 and R7",
         "Either increase spacing between components or reduce courtyard sizes. Standard courtyard expansion is 0.25mm for SMD, 0.5mm for through-hole. If space is tight, verify manufacturing constraints with your PCB fab — some accept 0.1mm courtyard overlap for hand-assembly."),
        ("minimum annular ring violation on via",
         "Increase via pad size or decrease drill size. For standard PCB: minimum annular ring is 0.15mm (IPC Class 2). A 0.3mm drill with 0.6mm pad gives 0.15mm ring. For HDI, consult your fab's capabilities. Adjust via defaults in Board Setup > Design Rules > Pre-defined Sizes."),
    ]
    for error, fix in drc_errors:
        pairs.append({
            "user": f"KiCad DRC reports a {error}. How do I fix this?",
            "assistant": fix,
        })

    # --- Footprint creation ---
    fp_types = [
        ("QFP-48 with 0.5mm pitch", "Use the Footprint Wizard: select QFP, set pin count=48, pitch=0.5mm, pad size 0.3x1.2mm, die pad if thermal (check datasheet). Verify IPC-7351 compliance. Add courtyard (0.25mm expansion), fabrication layer outline, and pin 1 marker on silkscreen. Test with 3D viewer."),
        ("SOT-23-5", "Pad layout: 3 pins on one side, 2 on the other, pitch 0.95mm. Pad size 0.6x1.1mm typical. Use KiCad Footprint Wizard or import from SnapEDA/Ultra Librarian. Verify pin numbering matches your schematic symbol. Add courtyard 0.25mm around body."),
        ("USB Type-C 16-pin receptacle", "Use manufacturer-provided footprint (GCT USB4105 or similar). Critical: verify mid-mount vs through-hole, check shield/ground pad connections, add alignment posts if mechanical. DRC custom rules for USB differential pairs (90 ohm impedance). Test 3D model alignment."),
        ("custom RF antenna trace", "Define as a footprint with copper pads on F.Cu. Import antenna geometry from simulation tool as edge cuts or copper zones. Add keepout zones for ground pour (per antenna datasheet). Mark courtyard to prevent component placement in radiation zone. Document impedance requirements in fab notes."),
    ]
    for fp, answer in fp_types:
        pairs.append({
            "user": f"How do I create a {fp} footprint in KiCad 8?",
            "assistant": answer,
        })

    # --- Layer stack / impedance ---
    stack_qs = [
        ("4-layer stack-up for a mixed-signal design with USB 2.0",
         "Recommended 4-layer stack:\n- L1 (Top): Signal + components\n- L2 (Inner 1): Ground plane (continuous, no splits)\n- L3 (Inner 2): Power plane (3.3V, 5V zones)\n- L4 (Bottom): Signal + components\n\nFor USB 2.0 differential pairs: target 90 ohm differential impedance. With standard 1.6mm board, ~0.2mm trace width, ~0.15mm gap. Use your fab's impedance calculator. Keep analog and digital ground planes separate but connected at a single star point near the ADC."),
        ("2-layer PCB for a simple sensor board with I2C",
         "For 2-layer with I2C:\n- Top: Components + signal routing\n- Bottom: Ground pour (as continuous as possible)\n\nI2C routing: keep SDA/SCL traces short (<10cm for 100kHz, <5cm for 400kHz). Route them adjacent with ground between if possible. Place 4.7k pull-ups near the master. Use 0.25mm traces for signals, 0.5mm+ for power. Add stitching vias around the board perimeter for the ground pour."),
    ]
    for q, a in stack_qs:
        pairs.append({"user": q, "assistant": a})

    # --- Net class / design rules ---
    rules = [
        ("set up net classes for a design with 3.3V, 5V, 12V, and USB differential pairs",
         "In Board Setup > Net Classes, create:\n\n1. **Default**: 0.25mm trace, 0.2mm clearance\n2. **Power_3V3**: 0.4mm trace, 0.2mm clearance — assign VCC_3V3, GND nets\n3. **Power_5V**: 0.5mm trace, 0.25mm clearance — assign VCC_5V, VBUS nets\n4. **Power_12V**: 0.8mm trace, 0.3mm clearance — assign VIN_12V net\n5. **USB_DP**: 0.2mm trace, 0.15mm clearance, differential pair with 90 ohm target — assign USB_D+, USB_D-\n\nFor differential pairs, also set the differential pair gap in the net class. Use 'Length tuning' tool to match USB pair lengths within 0.15mm."),
    ]
    for q, a in rules:
        pairs.append({"user": q, "assistant": a})

    # --- Gerber export / manufacturing ---
    gerber_qs = [
        ("What Gerber files do I need to send to JLCPCB for a 4-layer board?",
         "For JLCPCB 4-layer, export these Gerber/drill files from KiCad:\n\n**Gerber files:**\n- F.Cu (top copper)\n- In1.Cu (inner layer 1)\n- In2.Cu (inner layer 2)\n- B.Cu (bottom copper)\n- F.SilkS (top silkscreen)\n- B.SilkS (bottom silkscreen)\n- F.Mask (top solder mask)\n- B.Mask (bottom solder mask)\n- Edge.Cuts (board outline)\n- F.Paste (top paste — for stencil)\n\n**Drill files:**\n- PTH (plated through-hole)\n- NPTH (non-plated through-hole)\n\nExport settings: Gerber X2 format, 4.6 coordinate format, mm units. Zip all files together. Upload to JLCPCB and verify in their online Gerber viewer before ordering."),
        ("How do I prepare a BOM and position file for JLCPCB SMT assembly?",
         "1. **BOM**: In Schematic Editor > Tools > Edit Symbol Fields, ensure every SMD part has a valid LCSC part number in a 'LCSC' field. Then export BOM via Tools > Generate BOM (use JLCPCB plugin or CSV with columns: Comment, Designator, Footprint, LCSC Part Number).\n\n2. **Position file**: In PCB Editor > File > Fabrication Outputs > Component Placement. Export CSV with: Ref, Val, Package, PosX, PosY, Rot, Side. Select mm units, top side only (or both if needed).\n\n3. **Verify**: Cross-check BOM quantities with position file entries. Remove DNP components. Check LCSC stock availability before ordering. Upload BOM + CPL (position) files on JLCPCB along with Gerbers."),
    ]
    for q, a in gerber_qs:
        pairs.append({"user": q, "assistant": a})

    # --- Quick tips ---
    tips = [
        ("How do I add a logo to a KiCad PCB silkscreen?",
         "Use Image Converter (Tools > Image Converter in PCB editor, or standalone bitmap2component). Steps:\n1. Prepare a black/white PNG/BMP image\n2. Open Image Converter, load the image\n3. Set output layer to F.SilkS (or B.SilkS)\n4. Adjust size and DPI\n5. Export as footprint (.kicad_mod)\n6. Place the footprint on your PCB\n\nTip: Keep logo minimum feature size above 0.15mm for reliable silkscreen printing. For copper logos, output to F.Cu instead."),
        ("What is the difference between zones and tracks for power distribution in KiCad?",
         "**Tracks** (traces): Fixed-width copper paths. Good for point-to-point connections, controlled impedance, and signal routing. Use for power when current is moderate and path is direct.\n\n**Zones** (pours/planes): Filled copper areas. Better for power distribution (low impedance, heat dissipation), ground planes (EMI shielding, return paths), and high-current nets. Set zone priority to control overlap. Use thermal relief pads for soldering ease.\n\nRule of thumb: Use zones for GND and main power rails, tracks for signal and secondary power. In a 4-layer board, dedicate entire inner layers as zones for GND and VCC."),
        ("How do I set up bus routing in KiCad 8 for a parallel data bus?",
         "1. In schematic: Create a bus with net labels (D[0..7] or DATA[0..7]). Use bus entry symbols to connect wires to the bus line.\n2. Assign bus members to a net class with appropriate trace width.\n3. In PCB editor: Use 'Route Differential Pair' or 'Interactive Router' with the bus members selected.\n4. For length matching: Tools > Tune Track Length. Set target length and tolerance (typically +-5% for parallel buses, tighter for DDR).\n5. Route bus traces in parallel, maintain consistent spacing. Use 'Route Track Width' dropdown to switch between signal and bus net classes."),
    ]
    for q, a in tips:
        pairs.append({"user": q, "assistant": a})

    # --- Parametric variations ---
    cap_values = ["100nF", "1uF", "10uF", "22uF", "100uF"]
    packages = ["0402", "0603", "0805", "1206"]
    for cap in cap_values:
        for pkg in packages:
            pairs.append({
                "user": f"What is the typical use case for a {cap} {pkg} capacitor in PCB design?",
                "assistant": f"A {cap} capacitor in {pkg} package is commonly used as {'a high-frequency decoupling cap placed close to IC power pins' if cap == '100nF' else 'a bulk bypass capacitor for local power filtering' if cap in ('1uF','10uF') else 'a bulk storage capacitor for power rail stability' if cap in ('22uF','100uF') else 'general filtering'}. "
                f"The {pkg} package {'is very small — suitable for dense layouts but harder to hand-solder' if pkg == '0402' else 'offers a good balance of size and solderability for most designs' if pkg == '0603' else 'is easy to hand-solder and commonly available with good voltage ratings' if pkg == '0805' else 'provides higher voltage and current ratings, suitable for power applications'}. "
                f"Place decoupling caps as close as possible to the IC power pins, with short vias to the ground plane.",
            })

    # --- Parametric: trace width for current ---
    currents = [0.1, 0.5, 1.0, 2.0, 5.0, 10.0]
    copper_weights = ["1oz (35um)", "2oz (70um)"]
    for current in currents:
        for copper in copper_weights:
            oz = 1 if "1oz" in copper else 2
            # IPC-2221 approximation for external layer, 10C rise
            width_mm = (current / (0.048 * (10 ** 0.44) * ((oz * 35) ** 0.725))) ** (1/0.725) * 25.4 / 1000
            width_mm = max(0.1, round(width_mm, 2))
            pairs.append({
                "user": f"What trace width do I need for {current}A on a {copper} copper PCB in KiCad?",
                "assistant": f"For {current}A on {copper} copper (external layer, 10C temperature rise):\n\n"
                f"Minimum trace width: approximately {width_mm:.2f}mm ({width_mm/0.0254:.0f}mil)\n\n"
                f"Based on IPC-2221 guidelines. For internal layers, increase width by ~2x due to reduced heat dissipation.\n\n"
                f"In KiCad: Set up a net class in Board Setup > Design Rules > Net Classes with the appropriate width. "
                f"{'For very low current, the minimum manufacturing trace width (0.15-0.2mm) is usually the limiting factor, not current capacity.' if current <= 0.5 else 'Consider using a copper pour (zone) instead of a trace for better current handling and thermal performance.' if current >= 5.0 else 'This is a moderate current — a dedicated trace is appropriate.'}\n\n"
                f"Use an online trace width calculator (e.g., Saturn PCB Toolkit) for precise values considering your specific stackup and ambient temperature.",
            })

    return pairs


def _spice_templates() -> list[dict]:
    """Circuit analysis, simulation setup, component modeling."""
    pairs = []

    analyses = [
        ("DC operating point", ".op", "Calculates the DC bias point of the circuit with all sources at their DC values. Capacitors become open circuits, inductors become short circuits. Use this first to verify your circuit is biased correctly before running transient or AC analysis."),
        ("AC sweep from 1Hz to 10MHz", ".ac dec 100 1 10meg", "Performs small-signal AC analysis sweeping frequency logarithmically with 100 points per decade from 1Hz to 10MHz. The circuit is linearized around the DC operating point. Use voltage/current probes to plot magnitude (dB) and phase (degrees) — the Bode plot."),
        ("transient simulation for 10ms with 1us step", ".tran 1u 10m", "Runs time-domain simulation for 10ms with a maximum timestep of 1us. The simulator uses adaptive stepping internally. Add .uic (use initial conditions) if you want to skip the DC operating point calculation. Plot node voltages and branch currents vs time."),
        ("DC sweep of V1 from 0 to 5V", ".dc V1 0 5 0.01", "Sweeps the DC value of source V1 from 0V to 5V in 10mV steps. Useful for characterizing transfer functions (Vout vs Vin), I-V curves of transistors/diodes, and finding operating regions. Can sweep two sources simultaneously with nested syntax."),
        ("Monte Carlo analysis with 100 runs", ".step param tol list -5% 0% 5%\n.meas ...", "For Monte Carlo in LTspice: use .step with random distributions. Example: .param R1val mc(10k, tolR) where tolR is the tolerance. Run .step param run 1 100 1 with .param expressions using mc() or gauss() functions. Measure spread of output parameters with .meas directives."),
        ("noise analysis at output node", ".noise V(out) V1 dec 100 1 10meg", "Computes noise spectral density referred to the output node V(out), with V1 as the input source (for input-referred noise). Sweeps from 1Hz to 10MHz. Output is in V/sqrt(Hz). Integrates total RMS noise over the bandwidth. Essential for low-noise amplifier design."),
        ("parametric sweep of a resistor value", ".step param Rval 1k 100k 10k", "Steps the parameter Rval from 1k to 100k in 10k increments. Define the resistor value as {Rval} in the schematic. Each step runs a full simulation. Useful for optimization and sensitivity analysis. Combine with .meas to extract performance metrics at each step."),
    ]
    for name, cmd, desc in analyses:
        pairs.append({
            "user": f"How do I set up a {name} in LTspice/ngspice?",
            "assistant": f"Use the SPICE directive: `{cmd}`\n\n{desc}",
        })

    # --- Component models ---
    models = [
        ("NPN transistor 2N2222", ".model 2N2222 NPN(IS=14.34f BF=255 VAF=74.03 ...)", "The 2N2222 is a general-purpose NPN BJT. Key parameters: IS (saturation current), BF (forward current gain ~200-300), VAF (Early voltage). For simulation, use the manufacturer SPICE model from ON Semi. Place with 3 pins: C(collector), B(base), E(emitter). Bias for linear operation: VCE > 0.3V, IB sufficient for desired IC."),
        ("MOSFET IRF540N", ".model IRF540N NMOS(Level=3 ...)", "The IRF540N is an N-channel power MOSFET. Use the manufacturer Level 3 or subcircuit model from Infineon. Key params: VTH (~2-4V), RDS(on) (~44mohm at VGS=10V), Ciss/Coss/Crss for switching analysis. For switching sims, ensure gate driver provides adequate VGS (10V typical) and include gate resistor for ringing control."),
        ("op-amp LM358 subcircuit", ".subckt LM358 ... .ends", "Use the TI-provided subcircuit model for LM358. It models: input offset, bias current, GBW (~1MHz), slew rate (~0.5V/us), output swing limitations, and supply current. Include both supply pins (V+ and V-). For single-supply: connect V- to GND. The model captures rail-to-rail limitations (output doesn't reach rails)."),
        ("Zener diode 5.1V", ".model DZ5V1 D(BV=5.1 IBV=5m ...)", "Zener model uses the standard diode model with BV (breakdown voltage) = 5.1V and IBV (current at breakdown) = 5mA. For better accuracy, add RS (series resistance, ~5-30 ohm for typical Zeners). The dynamic impedance affects regulation. For simulation, bias in reverse with current limiting resistor."),
    ]
    for name, syntax, desc in models:
        pairs.append({
            "user": f"How do I model a {name} in SPICE simulation?",
            "assistant": f"SPICE syntax: `{syntax}`\n\n{desc}",
        })

    # --- Common circuits ---
    circuits = [
        ("inverting op-amp amplifier with gain of -10",
         "Circuit: V_in -> R1 (1k) -> inverting input (-) of op-amp. R2 (10k) from output to inverting input (feedback). Non-inverting input (+) to GND.\n\nGain = -R2/R1 = -10k/1k = -10\n\nSPICE netlist:\n```\nV1 in 0 AC 1 SIN(0 0.1 1k)\nR1 in inv 1k\nR2 out inv 10k\nXU1 0 inv vcc vee out LM358\nVcc vcc 0 12\nVee vee 0 -12\n.ac dec 100 1 1meg\n```\nVerify: flat gain of 20dB up to GBW/gain = 1MHz/10 = 100kHz, then -20dB/dec rolloff."),
        ("second-order low-pass Sallen-Key filter at 1kHz",
         "Sallen-Key Butterworth (Q=0.707) at fc=1kHz:\n\nR1 = R2 = 10k, C1 = 22nF, C2 = 10nF (adjust for exact fc)\nfc = 1/(2*pi*sqrt(R1*R2*C1*C2))\n\nCircuit: Vin -> R1 -> node_a -> R2 -> node_b -> C2 -> GND. C1 from node_a to output. Op-amp: non-inv=node_b, output=Vout, feedback: Vout to inv (unity gain buffer).\n\n.ac dec 100 10 100k — expect -3dB at 1kHz, -40dB/dec rolloff above fc."),
        ("voltage regulator with pass transistor and Zener reference",
         "Circuit:\n- Zener reference: Vin -> R_bias (1k) -> Zener (5.1V) -> GND\n- Pass transistor: Q1 (NPN) with collector to Vin, emitter to Vout (via R_sense if needed)\n- Error amp: Zener voltage to base of Q1 (or via resistor divider for adjustable output)\n- Load: R_load from Vout to GND\n\nVout ~= Vz - Vbe ~= 5.1 - 0.7 = 4.4V\n\nFor simulation: .dc V1 6 15 0.1 to plot line regulation. .tran 10m with pulsed load for transient response. Add output cap (10uF) for stability."),
        ("H-bridge motor driver with PWM input",
         "4 MOSFETs (2 NMOS low-side, 2 PMOS high-side) or 4 NMOS with bootstrap.\n\nLow-side: M1 (in_A -> gate), M2 (in_B -> gate), sources to GND\nHigh-side: M3 (in_A_bar -> gate), M4 (in_B_bar -> gate), sources to motor\n\nDead-time circuit prevents shoot-through. PWM on in_A, in_B for speed/direction.\n\nSPICE: Use PULSE sources for PWM (e.g., PULSE(0 5 0 10n 10n 50u 100u) for 10kHz 50% duty). Model motor as R+L series (R_winding + L_winding). Add freewheeling diodes across each MOSFET."),
    ]
    for name, desc in circuits:
        pairs.append({
            "user": f"How do I simulate a {name} in SPICE?",
            "assistant": desc,
        })

    # --- Convergence / troubleshooting ---
    issues = [
        ("SPICE simulation won't converge at DC operating point",
         "Common fixes for DC convergence:\n1. Add .options gmin=1e-12 (increase minimum conductance)\n2. Add .options abstol=1e-10 reltol=0.01 (relax tolerances)\n3. Check for floating nodes — every node needs a DC path to ground\n4. Add large resistors (1G) from floating nodes to ground\n5. Verify source polarities and initial conditions\n6. Start with simplified circuit, add complexity incrementally\n7. Use .nodeset to provide initial guess for problematic nodes\n8. Check for zero-valued voltage sources in loops"),
        ("transient simulation is extremely slow",
         "Speed up transient simulation:\n1. Increase maximum timestep: .tran 0 10m 0 10u (last param is max step)\n2. Use .options method=gear (better for stiff circuits)\n3. Reduce simulation stop time to minimum needed\n4. Simplify semiconductor models (Level 1 instead of Level 3 for MOSFETs)\n5. Replace subcircuits with behavioral sources where possible\n6. Check for very small time constants creating stiffness\n7. Use .options maxstep=10u to limit adaptation\n8. Remove unnecessary .meas and .probe directives"),
        ("getting ringing/oscillation in simulation that doesn't match reality",
         "Spurious oscillation fixes:\n1. Add parasitic elements: ESR on capacitors (series R), DCR on inductors\n2. Add stray capacitance (1-10pF) on high-impedance nodes\n3. Check op-amp model — ideal models lack output impedance and phase margin\n4. Add trace inductance for long PCB traces (~1nH/mm)\n5. Include gate resistance on MOSFETs (1-10 ohm)\n6. Verify decoupling caps are modeled (not just ideal capacitors)\n7. Use .options cshunt=1e-14 to add parasitic caps everywhere\n8. Compare with hand calculation of expected frequency response"),
    ]
    for q, a in issues:
        pairs.append({"user": q, "assistant": a})

    # --- Parametric: filter design ---
    for fc in [100, 500, 1000, 5000, 10000]:
        for ftype in ["low-pass", "high-pass", "band-pass"]:
            pairs.append({
                "user": f"Design a {ftype} RC filter with cutoff frequency {fc}Hz for SPICE simulation.",
                "assistant": f"For a first-order {ftype} RC filter at fc={fc}Hz:\n\n"
                f"{'R -> C to GND (output across C)' if ftype == 'low-pass' else 'C -> R to GND (output across R)' if ftype == 'high-pass' else 'R -> C1 in series, C2 to GND (output across C2)'}\n\n"
                f"fc = 1/(2*pi*R*C) = {fc}Hz\n"
                f"Choose R = 10k: C = 1/(2*pi*10000*{fc}) = {1/(2*3.14159*10000*fc)*1e9:.1f}nF\n\n"
                f"SPICE: .ac dec 100 {max(1,fc//100)} {fc*100}\n"
                f"Expect -3dB at {fc}Hz, {'rolloff -20dB/dec above fc' if ftype == 'low-pass' else 'rolloff -20dB/dec below fc' if ftype == 'high-pass' else 'peak at center frequency with Q-dependent bandwidth'}.",
            })

    # --- Parametric: op-amp configurations ---
    op_amp_configs = ["inverting", "non-inverting", "differential", "summing", "integrator"]
    gains = [1, 10, 100]
    for config in op_amp_configs:
        for gain in gains:
            pairs.append({
                "user": f"How do I simulate a {config} op-amp with gain {gain} in SPICE?",
                "assistant": f"SPICE simulation of {config} amplifier (gain = {gain}):\n\n"
                f"{'Inverting: R_in -> inverting input, R_f from output to inverting input. Non-inv to GND.' if config == 'inverting' else 'Non-inverting: signal to non-inv input. R1 from inv input to GND, R2 from output to inv input.' if config == 'non-inverting' else 'Differential: R1 from V1 to inv, R2 from V2 to non-inv, R3 feedback, R4 to GND on non-inv side.' if config == 'differential' else 'Summing: Multiple R_in to inverting input, R_f feedback. Each input contributes proportionally.' if config == 'summing' else 'Integrator: R_in to inv input, C feedback from output to inv input. Non-inv to GND.'}\n\n"
                f"Component values for gain = {gain}:\n"
                f"{'R_f/R_in = ' + str(gain) + '. Use R_in = 10k, R_f = ' + str(gain*10) + 'k.' if config == 'inverting' else '1 + R2/R1 = ' + str(gain) + '. Use R1 = 10k, R2 = ' + str((gain-1)*10) + 'k.' if config == 'non-inverting' else 'R3/R1 = ' + str(gain) + ' with matched resistor pairs. R1=R2=10k, R3=R4=' + str(gain*10) + 'k.' if config == 'differential' else 'R_f = ' + str(gain*10) + 'k with R_in = 10k per input.' if config == 'summing' else 'R_in = 10k, C = ' + str(round(1/(2*3.14159*10000*1000), 9)*1e9) + 'nF for 1kHz unity-gain frequency.'}\n\n"
                f".tran 10m for time-domain, .ac dec 100 1 10meg for frequency response.\n"
                f"Verify gain flatness up to GBW/{gain} = {'1MHz' if gain == 1 else str(1000//gain) + 'kHz'} (assuming 1MHz GBW op-amp).",
            })

    return pairs


def _freecad_templates() -> list[dict]:
    """3D modeling, parametric design, assembly."""
    pairs = []

    tasks = [
        ("create a parametric enclosure for a PCB",
         "In FreeCAD, use Part Design workbench:\n1. Create a Spreadsheet with parameters: length, width, height, wall_thickness, pcb_thickness, standoff_height\n2. Sketch the outer rectangle on XY plane, Pad to height\n3. Create inner Pocket: offset by wall_thickness on each side, depth = height - wall_thickness (bottom floor)\n4. Add PCB standoffs: Sketch circles at mounting hole positions, Pad to standoff_height from floor\n5. Add screw holes: Sketch smaller circles centered on standoffs, Pocket through\n6. For lid: create separate Body, sketch matching outer dimensions, Pad to lid_thickness, add snap-fit features\n\nLink all dimensions to Spreadsheet cells for parametric control. Export as STEP for manufacturing."),
        ("design a heat sink with fins",
         "Part Design approach:\n1. Base plate: Sketch rectangle, Pad to base_thickness (e.g., 3mm)\n2. Fins: Sketch single fin profile (rectangle), Pad to fin_height\n3. Use Linear Pattern to repeat fin across the base: count = number_of_fins, spacing = fin_pitch\n4. Add mounting holes: Sketch on base, Pocket through\n5. Fillet the fin tops (0.5mm radius) for manufacturing\n\nParametric: Link fin_count, fin_height, fin_thickness, fin_pitch to Spreadsheet. Surface area = 2 * fin_count * fin_height * base_length + base_area. For thermal analysis, export to Elmer FEM via FreeCAD FEM workbench."),
        ("model a gear for 3D printing",
         "Use the FCGear workbench (install via Addon Manager):\n1. Create InvoluteGear: module=1, teeth=20, pressure_angle=20deg, height=5mm\n2. Or manually: Part Design, Sketch involute profile using B-splines, Polar Pattern for teeth\n3. Add center bore: Sketch circle, Pocket through\n4. Add keyway: Sketch rectangle at bore edge, Pocket to gear height\n5. Add hub: Sketch larger circle around bore, Pad slightly beyond gear face\n6. Fillet edges for printability (0.3mm minimum for FDM)\n\nFor 3D printing: export as STL, verify mesh in Mesh workbench. Wall thickness > 1.2mm for FDM, > 0.8mm for SLA."),
        ("create an assembly of multiple parts",
         "Use Assembly4 workbench (recommended for FreeCAD 0.21+):\n1. Create each part in its own file (Body with origin features)\n2. In assembly file: Insert > Link to external file for each part\n3. Add Local Coordinate Systems (LCS) to each part at attachment points\n4. Use 'Place Link' to position parts: select LCS on part, select LCS on target\n5. Common constraints: Coincident (faces), Coaxial (cylinders), Fixed (ground part)\n\nAlternative: A2plus workbench has a simpler constraint solver. For Bill of Materials, use the TechDraw workbench spreadsheet integration. Export assembly as STEP for sharing."),
        ("generate 2D technical drawings from a 3D model",
         "Use TechDraw workbench:\n1. Switch to TechDraw, Insert > Page (choose A4/A3 template)\n2. Select your Body/Part, Insert > View: set Front/Top/Right projections\n3. Add Section View: select a view, draw section line, Insert > Section View\n4. Add Detail View: select region to magnify\n5. Dimensions: Insert > Dimension (length, diameter, angle, radius)\n6. Annotations: Insert > Annotation for notes, surface finish, tolerances\n7. Balloon/BOM: Insert > Balloon for part numbering\n\nExport as PDF or SVG. For ISO standard drawings, use the ISO 7200 title block template."),
        ("perform FEM stress analysis on a bracket",
         "Using FreeCAD FEM workbench:\n1. Create/import bracket geometry in Part Design\n2. Switch to FEM, create Analysis container\n3. Add Material: FEM > Material for Solid (steel: E=210GPa, nu=0.3)\n4. Add Constraints: Fixed (mounting holes), Force (load point + magnitude)\n5. Mesh: FEM > Gmsh mesh (element size ~2mm, refine near stress concentrations)\n6. Solver: CalculiX (built-in), or Elmer for thermal\n7. Run solver, view results: Von Mises stress, displacement, safety factor\n\nIterate: refine mesh in high-stress areas, add fillets to reduce stress concentrations. Target safety factor > 2 for static loads."),
    ]
    for q, a in tasks:
        pairs.append({"user": f"How do I {q} in FreeCAD?", "assistant": a})

    # --- FreeCAD scripting ---
    scripts = [
        ("automate box creation with Python",
         "FreeCAD Python console:\n```python\nimport FreeCAD, Part\ndoc = FreeCAD.newDocument('Box')\nbox = doc.addObject('Part::Box', 'MyBox')\nbox.Length = 50  # mm\nbox.Width = 30\nbox.Height = 20\ndoc.recompute()\nPart.export([box], '/path/to/output.step')\n```\nFor parametric: read dimensions from a CSV or command-line args. Use `FreeCAD.ActiveDocument.getObject('MyBox').Shape.Volume` to verify."),
        ("batch export multiple STEP files",
         "Script for batch export:\n```python\nimport FreeCAD, Part, glob\nfor f in glob.glob('*.FCStd'):\n    doc = FreeCAD.openDocument(f)\n    objs = [o for o in doc.Objects if hasattr(o, 'Shape')]\n    Part.export(objs, f.replace('.FCStd', '.step'))\n    FreeCAD.closeDocument(doc.Name)\n```\nRun headless: `freecadcmd script.py` (no GUI needed). Add error handling for corrupt files."),
        ("create a parametric model driven by spreadsheet",
         "```python\nimport FreeCAD\ndoc = FreeCAD.ActiveDocument\nss = doc.addObject('Spreadsheet::Sheet', 'Params')\nss.set('A1', 'length')\nss.set('B1', '100')\nss.set('A2', 'width')\nss.set('B2', '50')\n# In Sketch constraints, reference as: Params.B1\n# Or via Python:\nbody = doc.getObject('Body')\npad = doc.getObject('Pad')\npad.setExpression('Length', 'Params.B1')\ndoc.recompute()\n```"),
    ]
    for q, a in scripts:
        pairs.append({
            "user": f"How do I {q} in FreeCAD?",
            "assistant": a,
        })

    # --- Parametric: enclosure sizes ---
    for length in [50, 80, 100, 120, 150]:
        for width in [30, 50, 80]:
            if width >= length:
                continue
            pairs.append({
                "user": f"What wall thickness should I use for a {length}x{width}mm 3D-printed enclosure?",
                "assistant": f"For a {length}x{width}mm enclosure:\n\n"
                f"- FDM printing: 1.6-2.0mm walls (4-5 perimeters at 0.4mm nozzle). {'Use 2.0mm for larger side since {length}mm span needs more rigidity.' if length >= 100 else 'Standard 1.6mm is sufficient at this size.'}\n"
                f"- SLA printing: 1.0-1.5mm walls\n"
                f"- Injection molding: 1.5-2.5mm (uniform thickness critical)\n\n"
                f"Add ribs every ~30mm on walls longer than 60mm to prevent warping. "
                f"{'Consider adding ribs on the {length}mm walls.' if length > 60 else 'No ribs needed at this size.'} "
                f"Corner radius: minimum 0.5mm internal for FDM, helps with mold release for injection.",
            })

    # --- Parametric: file format conversions ---
    formats_from = ["STEP", "STL", "IGES", "OBJ", "FCStd"]
    formats_to = ["STEP", "STL", "IGES", "3MF", "DXF"]
    for f_from in formats_from:
        for f_to in formats_to:
            if f_from == f_to:
                continue
            pairs.append({
                "user": f"How do I convert a {f_from} file to {f_to} in FreeCAD?",
                "assistant": f"Converting {f_from} to {f_to} in FreeCAD:\n\n"
                f"1. Open the {f_from} file: File > Open (or Import for non-native formats)\n"
                f"2. Select the object(s) in the model tree\n"
                f"3. File > Export, choose {f_to} format\n"
                f"{'Note: STL export loses parametric data — only mesh geometry is preserved. Set mesh deviation in preferences for quality control.' if f_to == 'STL' else ''}"
                f"{'Note: STEP preserves solid geometry (B-rep) — preferred for CAD interchange and manufacturing.' if f_to == 'STEP' else ''}"
                f"{'Note: 3MF is preferred over STL for 3D printing — supports color, materials, and multi-body.' if f_to == '3MF' else ''}"
                f"{'Note: DXF export creates 2D projections. Use TechDraw workbench for proper 2D drawings.' if f_to == 'DXF' else ''}"
                f"{'Note: IGES is legacy format — use STEP when possible for better feature preservation.' if f_to == 'IGES' else ''}\n\n"
                f"Python: `Part.export([obj], 'output.{f_to.lower()}')`\n"
                f"Headless: `freecadcmd -c \"import Part; Part.open('input.{f_from.lower()}'); Part.export(FreeCAD.ActiveDocument.Objects, 'output.{f_to.lower()}')\"`",
            })

    # --- Parametric: tolerances by manufacturing ---
    processes = ["FDM 3D printing", "SLA 3D printing", "CNC milling", "laser cutting", "injection molding"]
    features = ["hole diameter", "wall thickness", "surface finish", "dimensional accuracy"]
    for proc in processes:
        for feat in features:
            pairs.append({
                "user": f"What {feat} tolerance should I design for with {proc} in FreeCAD?",
                "assistant": f"Tolerance for {feat} with {proc}:\n\n"
                f"{'Hole diameter: +0.2 to +0.4mm oversized (shrinkage + layer stepping). Design nominal -0.2mm for press-fit.' if feat == 'hole diameter' and 'FDM' in proc else ''}"
                f"{'Hole diameter: +0.05 to +0.1mm. Much better than FDM. Post-cure may cause slight shrinkage.' if feat == 'hole diameter' and 'SLA' in proc else ''}"
                f"{'Hole diameter: +-0.025mm achievable. Use H7/h6 for standard fits.' if feat == 'hole diameter' and 'CNC' in proc else ''}"
                f"{'Hole diameter: +-0.1mm for through-holes. Kerf compensation needed (0.1-0.3mm depending on material).' if feat == 'hole diameter' and 'laser' in proc else ''}"
                f"{'Hole diameter: +-0.05mm with proper mold design. Include draft angle (1-2 degrees) on core pins.' if feat == 'hole diameter' and 'injection' in proc else ''}"
                f"{'Wall thickness: minimum 1.2mm (3 perimeters at 0.4mm nozzle). Below 0.8mm risks layer adhesion failure.' if feat == 'wall thickness' and 'FDM' in proc else ''}"
                f"{'Wall thickness: minimum 0.5mm for small parts, 1.0mm for structural parts. Hollow shells need drain holes.' if feat == 'wall thickness' and 'SLA' in proc else ''}"
                f"{'Wall thickness: minimum 0.5mm for aluminum, 1.0mm for steel. Depends on tool reach and rigidity.' if feat == 'wall thickness' and 'CNC' in proc else ''}"
                f"{'Wall thickness: material dependent. Acrylic 2mm+, steel 0.5mm+, wood 3mm+. Kerf creates tapered edges.' if feat == 'wall thickness' and 'laser' in proc else ''}"
                f"{'Wall thickness: 1.0-2.5mm uniform. Thick sections cause sink marks. Use ribs instead of solid sections.' if feat == 'wall thickness' and 'injection' in proc else ''}"
                f"{'Surface finish: Layer lines visible (Ra 12-25um). Improve with smaller layer height (0.1mm) or post-processing (sanding, vapor smoothing).' if feat == 'surface finish' and 'FDM' in proc else ''}"
                f"{'Surface finish: Excellent (Ra 2-5um). Slight texture from support contact points. Post-cure for hardness.' if feat == 'surface finish' and 'SLA' in proc else ''}"
                f"{'Surface finish: Ra 0.8-3.2um standard. Ra 0.4um with finishing passes. Mirror finish possible with polishing.' if feat == 'surface finish' and 'CNC' in proc else ''}"
                f"{'Surface finish: Clean edges with slight taper. Heat-affected zone on metals. Acrylic gets flame-polished edge.' if feat == 'surface finish' and 'laser' in proc else ''}"
                f"{'Surface finish: Ra 0.4-1.6um from mold. Mirror polish mold for optical parts. Texture can be added (VDI 3400).' if feat == 'surface finish' and 'injection' in proc else ''}"
                f"{'Dimensional accuracy: +-0.3-0.5mm typical. Calibrate printer (flow rate, steps/mm). First layer adhesion affects Z accuracy.' if feat == 'dimensional accuracy' and 'FDM' in proc else ''}"
                f"{'Dimensional accuracy: +-0.05-0.15mm. Compensate for resin shrinkage in slicer settings.' if feat == 'dimensional accuracy' and 'SLA' in proc else ''}"
                f"{'Dimensional accuracy: +-0.025mm standard, +-0.005mm precision. Depends on machine rigidity and thermal stability.' if feat == 'dimensional accuracy' and 'CNC' in proc else ''}"
                f"{'Dimensional accuracy: +-0.1mm for metals, +-0.2mm for wood/acrylic. Kerf compensation essential.' if feat == 'dimensional accuracy' and 'laser' in proc else ''}"
                f"{'Dimensional accuracy: +-0.05mm achievable. Shrinkage (0.4-2%) must be compensated in mold design.' if feat == 'dimensional accuracy' and 'injection' in proc else ''}\n\n"
                f"In FreeCAD: Set tolerances in TechDraw dimensions. Use Spreadsheet to parameterize compensation offsets.",
            })

    return pairs


def _stm32_templates() -> list[dict]:
    """HAL programming, peripheral config, debugging."""
    pairs = []

    peripherals = [
        ("UART at 115200 baud on STM32F4",
         "```c\n// In CubeMX: Enable USART2, 115200 baud, 8N1\n// Generated code in main.c:\nUART_HandleTypeDef huart2;\nhuart2.Instance = USART2;\nhuart2.Init.BaudRate = 115200;\nhuart2.Init.WordLength = UART_WORDLENGTH_8B;\nhuart2.Init.StopBits = UART_STOPBITS_1;\nhuart2.Init.Parity = UART_PARITY_NONE;\nhuart2.Init.Mode = UART_MODE_TX_RX;\nhuart2.Init.HwFlowCtl = UART_HWCONTROL_NONE;\nHAL_UART_Init(&huart2);\n\n// Send:\nHAL_UART_Transmit(&huart2, (uint8_t*)\"Hello\\n\", 6, 100);\n// Receive with DMA (recommended):\nHAL_UART_Receive_DMA(&huart2, rx_buf, sizeof(rx_buf));\n```\nEnable USART2 clock in RCC. Configure GPIO pins (PA2=TX, PA3=RX) as AF7."),
        ("I2C master to read a sensor register",
         "```c\n// CubeMX: Enable I2C1, Standard Mode 100kHz\n// Read single register:\nuint8_t reg_addr = 0x0F; // WHO_AM_I\nuint8_t data;\nHAL_I2C_Mem_Read(&hi2c1, SENSOR_ADDR << 1, reg_addr, \n                  I2C_MEMADD_SIZE_8BIT, &data, 1, 100);\n\n// Write register:\nuint8_t config = 0x27; // enable XYZ axes\nHAL_I2C_Mem_Write(&hi2c1, SENSOR_ADDR << 1, CTRL_REG1,\n                   I2C_MEMADD_SIZE_8BIT, &config, 1, 100);\n```\nNote: HAL expects 8-bit address (shifted left by 1). Add 4.7k pull-ups on SDA/SCL. Check return value for HAL_OK."),
        ("SPI with DMA for an SD card or display",
         "```c\n// CubeMX: SPI1, Master, Full-Duplex, Prescaler for ~1MHz initial\n// Enable DMA for SPI1_TX and SPI1_RX\n\n// CS pin manual control:\nHAL_GPIO_WritePin(CS_GPIO_Port, CS_Pin, GPIO_PIN_RESET); // CS low\nHAL_SPI_TransmitReceive_DMA(&hspi1, tx_buf, rx_buf, len);\n// Wait for completion callback:\nvoid HAL_SPI_TxRxCpltCallback(SPI_HandleTypeDef *hspi) {\n    HAL_GPIO_WritePin(CS_GPIO_Port, CS_Pin, GPIO_PIN_SET); // CS high\n    transfer_complete = 1;\n}\n```\nFor SD card: start at 400kHz for init, then increase to 25MHz. Use FATFS middleware in CubeMX."),
        ("ADC with DMA for continuous sampling",
         "```c\n// CubeMX: ADC1, Continuous mode, DMA Circular\n// Scan mode if multiple channels, set rank order\nuint16_t adc_buf[256];\nHAL_ADC_Start_DMA(&hadc1, (uint32_t*)adc_buf, 256);\n\n// Half-complete callback (process first half while second fills):\nvoid HAL_ADC_ConvHalfCpltCallback(ADC_HandleTypeDef* hadc) {\n    process_samples(adc_buf, 128); // first half\n}\nvoid HAL_ADC_ConvCpltCallback(ADC_HandleTypeDef* hadc) {\n    process_samples(adc_buf + 128, 128); // second half\n}\n```\nSet sample time based on source impedance. 12-bit at 2.4Msps max on STM32F4."),
        ("PWM output for motor control or LED dimming",
         "```c\n// CubeMX: TIM3 CH1, PWM Generation, 1kHz frequency\n// APB1 = 84MHz, Prescaler = 83 -> 1MHz timer clock\n// ARR (Period) = 999 -> 1kHz PWM\nHAL_TIM_PWM_Start(&htim3, TIM_CHANNEL_1);\n\n// Set duty cycle (0-100%):\nvoid set_duty(uint8_t percent) {\n    uint32_t pulse = (htim3.Init.Period + 1) * percent / 100;\n    __HAL_TIM_SET_COMPARE(&htim3, TIM_CHANNEL_1, pulse);\n}\n// For complementary outputs (H-bridge): use TIM1 with dead-time\n```\nGPIO: Configure as AF (alternate function) for the timer channel."),
        ("timer interrupt every 1ms",
         "```c\n// CubeMX: TIM6, Internal Clock, Prescaler=83, Period=999\n// -> 84MHz / (83+1) / (999+1) = 1kHz = 1ms interrupt\n// Enable interrupt in NVIC\nHAL_TIM_Base_Start_IT(&htim6);\n\nvoid HAL_TIM_PeriodElapsedCallback(TIM_HandleTypeDef *htim) {\n    if (htim->Instance == TIM6) {\n        tick_1ms++;\n        // Toggle LED every 500ms:\n        if (tick_1ms % 500 == 0)\n            HAL_GPIO_TogglePin(LED_GPIO_Port, LED_Pin);\n    }\n}\n```\nNote: SysTick is already used by HAL (1ms). Use a separate timer for your own timing to avoid conflicts."),
    ]
    for name, code in peripherals:
        pairs.append({
            "user": f"How do I configure {name} using STM32 HAL?",
            "assistant": code,
        })

    # --- Debugging ---
    debug_qs = [
        ("HardFault on STM32",
         "Debugging HardFault:\n1. Enable HardFault handler with fault analysis:\n```c\nvoid HardFault_Handler(void) {\n    __asm volatile(\n        \"TST LR, #4\\n\"\n        \"ITE EQ\\n\"\n        \"MRSEQ R0, MSP\\n\"\n        \"MRSNE R0, PSP\\n\"\n        \"B hard_fault_handler_c\"\n    );\n}\nvoid hard_fault_handler_c(uint32_t *hardfault_args) {\n    volatile uint32_t pc = hardfault_args[6]; // faulting PC\n    volatile uint32_t lr = hardfault_args[5]; // link register\n    volatile uint32_t cfsr = SCB->CFSR; // fault status\n    __BKPT(0); // breakpoint here, inspect variables\n}\n```\n2. Check CFSR bits: MMFSR (memory), BFSR (bus), UFSR (usage)\n3. Common causes: null pointer dereference, stack overflow, unaligned access, division by zero"),
        ("STM32 stuck in infinite loop or not starting",
         "Checklist:\n1. **Clock config**: Verify HSE crystal matches CubeMX setting (8MHz typical). Check PLL configuration. If HSE fails, system may fall back to HSI (16MHz) or hang.\n2. **Boot pins**: BOOT0=0 for flash boot. If BOOT0=1, it boots to bootloader.\n3. **Power**: Verify VDD=3.3V on all pins, VDDA connected, decoupling caps in place.\n4. **Flash**: Erase and re-flash. Check that the linker script matches your specific chip variant.\n5. **Debugger**: Connect SWD (SWDIO+SWCLK), use 'Connect under Reset' in STM32CubeProgrammer.\n6. **Watchdog**: If IWDG is enabled in option bytes, it may reset before your code initializes.\n7. **Stack overflow**: Increase stack size in linker script (_Min_Stack_Size)."),
        ("DMA not working or data corruption",
         "DMA troubleshooting:\n1. **Cache**: On STM32F7/H7, DMA buffers must be in non-cacheable RAM or use cache maintenance:\n```c\nSCB_CleanDCache_by_Addr((uint32_t*)buf, size); // before DMA TX\nSCB_InvalidateDCache_by_Addr((uint32_t*)buf, size); // after DMA RX\n```\n2. **Alignment**: DMA buffers must be aligned to data width (word-aligned for 32-bit transfers)\n3. **Memory region**: Place buffers in SRAM1/SRAM2, not CCM (not DMA-accessible on some chips)\n4. **Priority**: Check DMA stream priority doesn't conflict\n5. **IRQ**: Ensure DMA IRQ is enabled in NVIC and handler calls HAL_DMA_IRQHandler()\n6. **Buffer overflow**: Verify NDTR (transfer count) matches buffer size\n7. **Circular mode**: Enable for continuous transfers (ADC, UART RX)"),
    ]
    for q, a in debug_qs:
        pairs.append({"user": q, "assistant": a})

    # --- CubeMX / project setup ---
    setup_qs = [
        ("set up a new STM32 project with CubeMX and PlatformIO",
         "1. Open STM32CubeMX, select your chip (e.g., STM32F411CEU6)\n2. Configure: RCC (HSE Crystal), SYS (Debug=Serial Wire), peripherals\n3. Project Manager: Toolchain=Makefile, Generate code\n4. In PlatformIO:\n```ini\n[env:blackpill]\nplatform = ststm32\nboard = blackpill_f411ce\nframework = stm32cube\n; Copy CubeMX generated files to src/ and include/\n```\n5. Copy Src/*.c to src/, Inc/*.h to include/\n6. Copy Drivers/ folder to lib/\n7. Build: `pio run` | Upload: `pio run -t upload`\n8. Debug: `pio debug` with ST-Link or Black Magic Probe"),
        ("optimize STM32 for low power consumption",
         "Low-power optimization:\n1. **Stop mode**: HAL_PWR_EnterSTOPMode() — wakes on EXTI interrupt, ~20uA\n2. **Standby mode**: HAL_PWR_EnterSTANDBYMode() — wakes on WKUP pin, ~2uA (RAM lost)\n3. **Clock gating**: Disable unused peripheral clocks: __HAL_RCC_GPIOx_CLK_DISABLE()\n4. **GPIO**: Set unused pins to Analog mode (lowest leakage)\n5. **Voltage scaling**: PWR_REGULATOR_VOLTAGE_SCALE3 for lower speed\n6. **Sleep-on-exit**: SCB->SCR |= SCB_SCR_SLEEPONEXIT_Msk — sleep after each ISR\n7. **Flash**: Enable prefetch, set wait states to minimum for your clock\n8. Measure: Use INA219 or ammeter on VDD pin. Target: <100uA in sleep, <10mA active at 16MHz"),
    ]
    for q, a in setup_qs:
        pairs.append({"user": q, "assistant": a})

    # --- Parametric: peripheral + chip combos ---
    chips = ["STM32F103", "STM32F411", "STM32F446", "STM32H743", "STM32L476"]
    periphs = ["UART", "SPI", "I2C", "CAN", "USB"]
    for chip in chips:
        for periph in periphs:
            pairs.append({
                "user": f"What is the maximum speed of {periph} on {chip}?",
                "assistant": f"The {periph} peripheral on {chip}:\n\n"
                f"{'UART: up to 4.5 Mbaud (USART1 on APB2)' if periph == 'UART' and 'F4' in chip else 'UART: up to 10.5 Mbaud (LPUART)' if periph == 'UART' and 'H7' in chip else 'UART: up to 4.5 Mbaud' if periph == 'UART' else ''}"
                f"{'SPI: up to 42 MHz (SPI1 on APB2) in master mode' if periph == 'SPI' and 'F4' in chip else 'SPI: up to 100 MHz (SPI1 with OCTOSPI)' if periph == 'SPI' and 'H7' in chip else 'SPI: up to 18 MHz' if periph == 'SPI' else ''}"
                f"{'I2C: Standard (100kHz), Fast (400kHz), Fast-Plus (1MHz)' if periph == 'I2C' and ('F4' in chip or 'H7' in chip or 'L4' in chip) else 'I2C: Standard (100kHz), Fast (400kHz)' if periph == 'I2C' else ''}"
                f"{'CAN: up to 1 Mbit/s (CAN 2.0B), FDCAN up to 8 Mbit/s data phase' if periph == 'CAN' and 'H7' in chip else 'CAN: up to 1 Mbit/s (CAN 2.0B)' if periph == 'CAN' and ('F4' in chip or 'F1' in chip) else 'CAN: available via bxCAN peripheral' if periph == 'CAN' else ''}"
                f"{'USB: Full-Speed (12 Mbit/s) device via USB OTG FS' if periph == 'USB' and 'F1' in chip else 'USB: Full-Speed + High-Speed (480 Mbit/s) via OTG HS' if periph == 'USB' and ('H7' in chip or 'F4' in chip) else 'USB: Full-Speed (12 Mbit/s)' if periph == 'USB' else ''}"
                f"\n\nConfigure the peripheral clock prescaler appropriately. Check the datasheet for your specific package variant, as not all peripherals may be available on all pin counts.",
            })

    # --- Parametric: clock configurations ---
    for chip in chips:
        for freq in ["8MHz HSI", "25MHz HSE", "maximum PLL"]:
            pairs.append({
                "user": f"How do I configure {chip} for {freq} clock?",
                "assistant": f"Clock configuration for {chip} at {freq}:\n\n"
                f"{'HSI (internal RC oscillator) at 8MHz: No external components needed. Set RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSI. Accuracy: +-1% (calibrated). Good for non-precision timing.' if 'HSI' in freq else ''}"
                f"{'HSE (external crystal) at 25MHz (or 8MHz depending on board): RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSE. Add 8-25MHz crystal with load capacitors (12-20pF typical). Better accuracy than HSI (~20ppm).' if 'HSE' in freq else ''}"
                f"{'Maximum PLL configuration: Start from HSE, multiply through PLL to reach max frequency. ' + ('STM32F103: HSE 8MHz -> PLL x9 = 72MHz max. Flash wait states = 2.' if 'F103' in chip else 'STM32F411: HSE 25MHz -> PLL M=25, N=192, P=2 = 96MHz. Flash wait states = 3.' if 'F411' in chip else 'STM32F446: HSE 8MHz -> PLL M=8, N=360, P=2 = 180MHz. Flash wait states = 5.' if 'F446' in chip else 'STM32H743: HSE 25MHz -> PLL1 to 480MHz. Uses dual-core, different clock domains.' if 'H743' in chip else 'STM32L476: HSE -> PLL to 80MHz. Ultra-low power, balance speed vs power consumption.') if 'PLL' in freq else ''}\n\n"
                f"In CubeMX: Use the Clock Configuration tab to set prescalers visually. Verify flash wait states match in FLASH_ACR register.",
            })

    return pairs


def _embedded_templates() -> list[dict]:
    """RTOS, interrupt handling, memory management."""
    pairs = []

    rtos_qs = [
        ("create a FreeRTOS task for sensor reading",
         "```c\n#include \"FreeRTOS.h\"\n#include \"task.h\"\n\nvoid vSensorTask(void *pvParameters) {\n    TickType_t xLastWakeTime = xTaskGetTickCount();\n    const TickType_t xPeriod = pdMS_TO_TICKS(100); // 100ms\n    \n    for (;;) {\n        float temp = read_temperature_sensor();\n        float humidity = read_humidity_sensor();\n        \n        // Send to queue for processing\n        SensorData_t data = {temp, humidity, xTaskGetTickCount()};\n        xQueueSend(xSensorQueue, &data, pdMS_TO_TICKS(10));\n        \n        vTaskDelayUntil(&xLastWakeTime, xPeriod);\n    }\n}\n\n// Create task (in main):\nxTaskCreate(vSensorTask, \"Sensor\", 256, NULL, 2, &xSensorHandle);\n```\nStack size 256 words (1KB) is typical for simple sensor tasks. Priority 2 (above idle, below critical)."),
        ("use a mutex to protect shared resource",
         "```c\nSemaphoreHandle_t xI2CMutex = xSemaphoreCreateMutex();\n\n// Task A:\nif (xSemaphoreTake(xI2CMutex, pdMS_TO_TICKS(100)) == pdTRUE) {\n    i2c_read_sensor_a(data_a);\n    xSemaphoreGive(xI2CMutex);\n} else {\n    // Timeout — handle error\n}\n\n// Task B:\nif (xSemaphoreTake(xI2CMutex, pdMS_TO_TICKS(100)) == pdTRUE) {\n    i2c_read_sensor_b(data_b);\n    xSemaphoreGive(xI2CMutex);\n}\n```\nMutex provides priority inheritance to prevent priority inversion. Always use timeout (not portMAX_DELAY) in production. Never take a mutex from an ISR — use binary semaphore instead."),
        ("implement a producer-consumer pattern with queues",
         "```c\n// Create queue: 10 items of SensorData_t\nQueueHandle_t xDataQueue = xQueueCreate(10, sizeof(SensorData_t));\n\n// Producer task:\nvoid vProducerTask(void *pv) {\n    for (;;) {\n        SensorData_t sample = acquire_sample();\n        if (xQueueSend(xDataQueue, &sample, pdMS_TO_TICKS(50)) != pdTRUE) {\n            // Queue full — log overflow, drop oldest or block\n            overflows++;\n        }\n        vTaskDelay(pdMS_TO_TICKS(10));\n    }\n}\n\n// Consumer task:\nvoid vConsumerTask(void *pv) {\n    SensorData_t received;\n    for (;;) {\n        if (xQueueReceive(xDataQueue, &received, portMAX_DELAY) == pdTRUE) {\n            process_and_transmit(received);\n        }\n    }\n}\n```\nQueue depth = burst_rate * max_processing_time. Monitor with uxQueueMessagesWaiting()."),
        ("implement software timer for periodic LED blink",
         "```c\nTimerHandle_t xBlinkTimer;\n\nvoid vBlinkCallback(TimerHandle_t xTimer) {\n    HAL_GPIO_TogglePin(LED_GPIO_Port, LED_Pin);\n}\n\n// In main, after scheduler init:\nxBlinkTimer = xTimerCreate(\"Blink\", pdMS_TO_TICKS(500), pdTRUE, NULL, vBlinkCallback);\nxTimerStart(xBlinkTimer, 0);\n```\nSoftware timers run in the timer daemon task context. Don't block in the callback. For variable timing, use xTimerChangePeriod(). For one-shot: set auto-reload to pdFALSE."),
    ]
    for q, a in rtos_qs:
        pairs.append({"user": f"How do I {q}?", "assistant": a})

    # --- Interrupt handling ---
    irq_qs = [
        ("best practices for interrupt handlers on Cortex-M",
         "ISR best practices:\n1. **Keep ISRs short**: Set flags or send to queue, process in task\n2. **No blocking calls**: Never use HAL_Delay(), malloc(), printf() in ISR\n3. **Volatile variables**: Declare shared variables as `volatile`\n4. **Priority levels**: NVIC priority 0=highest. FreeRTOS: set configMAX_SYSCALL_INTERRUPT_PRIORITY (default 5), ISRs above this can't call FreeRTOS API\n5. **Critical sections**: Use `__disable_irq()/__enable_irq()` sparingly, prefer BASEPRI masking\n6. **Tail-chaining**: Cortex-M optimizes back-to-back ISRs, no need to combine\n7. **DMA**: Prefer DMA over byte-by-byte ISR for bulk transfers\n8. **Atomic access**: Use LDREX/STREX or `__LDREXW()` for lock-free shared data"),
        ("nested interrupt priority configuration",
         "Cortex-M NVIC priority:\n```c\n// Set priority grouping: 4 bits preemption, 0 bits sub-priority\nHAL_NVIC_SetPriorityGrouping(NVIC_PRIORITYGROUP_4);\n\n// High priority (preempts others):\nHAL_NVIC_SetPriority(TIM2_IRQn, 1, 0);  // Motor control\nHAL_NVIC_SetPriority(EXTI0_IRQn, 2, 0); // Safety switch\n\n// Medium priority:\nHAL_NVIC_SetPriority(DMA1_Stream0_IRQn, 5, 0); // ADC DMA\nHAL_NVIC_SetPriority(USART2_IRQn, 6, 0); // Communication\n\n// Low priority (for FreeRTOS-compatible ISRs):\nHAL_NVIC_SetPriority(TIM6_IRQn, 10, 0); // Background timing\n```\nRule: Safety-critical > Real-time control > Communication > Background. FreeRTOS API only callable from priority >= configMAX_SYSCALL_INTERRUPT_PRIORITY."),
    ]
    for q, a in irq_qs:
        pairs.append({"user": q, "assistant": a})

    # --- Memory management ---
    mem_qs = [
        ("How do I debug a stack overflow on an embedded system?",
         "Stack overflow detection:\n1. **FreeRTOS**: Enable `configCHECK_FOR_STACK_OVERFLOW = 2` in FreeRTOSConfig.h. Implement `vApplicationStackOverflowHook()` to log task name.\n2. **Canary pattern**: FreeRTOS writes 0xA5A5A5A5 at stack bottom, checks on context switch.\n3. **MPU**: Configure MPU region at stack bottom as no-access. HardFault on overflow.\n4. **Static analysis**: Use `-fstack-usage` GCC flag to get per-function stack usage. Sum call chains.\n5. **Runtime**: Monitor `uxTaskGetStackHighWaterMark()` — returns minimum free stack words ever.\n6. **Fix**: Increase stack size in xTaskCreate(), reduce local variables (use static or heap), avoid recursive calls, reduce printf() buffer sizes.\n\nTypical stack sizes: Simple task 256-512 words, printf task 512-1024 words, TCP/IP task 1024+ words."),
        ("When should I use static vs dynamic memory allocation in embedded?",
         "**Static allocation** (preferred for safety-critical):\n- `static uint8_t buffer[256];` — lifetime of program, no fragmentation\n- FreeRTOS: `xTaskCreateStatic()`, `xQueueCreateStatic()`\n- Pros: deterministic, no heap fragmentation, MISRA compliant\n- Cons: memory reserved even when unused\n\n**Dynamic allocation** (use with care):\n- `pvPortMalloc()` / `pvPortFree()` in FreeRTOS\n- heap_1: allocate only (simplest, no free)\n- heap_4: coalescing free, best general-purpose\n- Pros: flexible, memory shared between features\n- Cons: fragmentation, non-deterministic timing, hard to debug leaks\n\n**Rule of thumb**: Allocate at startup, never at runtime. If you must use dynamic allocation, allocate during init phase and never free. Use memory pools for fixed-size objects."),
        ("How do I implement a ring buffer for UART reception?",
         "```c\n#define RING_BUF_SIZE 256 // must be power of 2\ntypedef struct {\n    volatile uint8_t buf[RING_BUF_SIZE];\n    volatile uint16_t head; // write index (ISR)\n    volatile uint16_t tail; // read index (task)\n} RingBuf_t;\n\nstatic RingBuf_t rx_ring = {0};\n\n// In UART ISR:\nvoid USART2_IRQHandler(void) {\n    if (USART2->SR & USART_SR_RXNE) {\n        uint16_t next = (rx_ring.head + 1) & (RING_BUF_SIZE - 1);\n        if (next != rx_ring.tail) { // not full\n            rx_ring.buf[rx_ring.head] = USART2->DR;\n            rx_ring.head = next;\n        }\n    }\n}\n\n// In task:\nint ring_read(uint8_t *byte) {\n    if (rx_ring.tail == rx_ring.head) return 0; // empty\n    *byte = rx_ring.buf[rx_ring.tail];\n    rx_ring.tail = (rx_ring.tail + 1) & (RING_BUF_SIZE - 1);\n    return 1;\n}\n```\nPower-of-2 size enables fast modulo via bitmask. No mutex needed if single producer (ISR) and single consumer (task)."),
    ]
    for q, a in mem_qs:
        pairs.append({"user": q, "assistant": a})

    # --- Parametric: RTOS task combos ---
    task_types = ["sensor reading", "motor control", "display update", "data logging", "communication"]
    priorities = [("high", 4), ("medium", 2), ("low", 1)]
    for task in task_types:
        for pname, pval in priorities:
            pairs.append({
                "user": f"What FreeRTOS priority and stack size should I use for a {pname}-priority {task} task?",
                "assistant": f"For a {pname}-priority {task} task:\n\n"
                f"Priority: {pval} (FreeRTOS range 0=idle to configMAX_PRIORITIES-1)\n"
                f"Stack: {'512-1024 words — needs buffer space for sensor data and I2C/SPI transactions' if task == 'sensor reading' else '256-512 words — tight timing, keep ISR-driven with minimal task logic' if task == 'motor control' else '1024-2048 words — display libraries (LVGL, u8g2) use significant stack for rendering' if task == 'display update' else '512-1024 words — depends on filesystem (FATFS) stack usage' if task == 'data logging' else '1024-2048 words — TCP/IP stack (lwIP) needs large buffers'}\n\n"
                f"{'Critical: use vTaskDelayUntil() for deterministic timing. Consider running in a timer ISR instead for sub-ms requirements.' if pname == 'high' else 'Standard periodic task pattern works well. Monitor stack high water mark during development.' if pname == 'medium' else 'Can use vTaskDelay() instead of vTaskDelayUntil(). Consider combining with other low-priority work to reduce task count.'}",
            })

    # --- Parametric: communication protocols ---
    protocols = ["UART", "SPI", "I2C", "CAN", "USB CDC"]
    data_sizes = ["1 byte", "16 bytes", "256 bytes", "1 KB"]
    for proto in protocols:
        for size in data_sizes:
            pairs.append({
                "user": f"How do I efficiently transfer {size} over {proto} on an embedded system?",
                "assistant": f"Transferring {size} over {proto}:\n\n"
                f"{'Use DMA for anything above a few bytes. Configure UART DMA TX channel, trigger with HAL_UART_Transmit_DMA(). For 1 byte, polling is fine (HAL_UART_Transmit with short timeout).' if proto == 'UART' else ''}"
                f"{'SPI is ideal for bulk transfers. Use DMA for {size} — set chip select manually (GPIO), call HAL_SPI_Transmit_DMA(), release CS in completion callback. SPI can easily handle multi-KB transfers at 10+ MHz.' if proto == 'SPI' else ''}"
                f"{'I2C is slower but simpler. For {size}: use HAL_I2C_Mem_Read/Write for register-based access. DMA worthwhile above 16 bytes. I2C limited to ~400kHz (fast mode), so large transfers are slow (~2.5KB/s).' if proto == 'I2C' else ''}"
                f"{'CAN frames are 8 bytes max (CAN 2.0B) or 64 bytes (CAN FD). For {size}: ' + ('single frame is sufficient.' if size == '1 byte' else 'single frame works, pad remaining bytes.' if size == '16 bytes' else 'use ISO-TP (ISO 15765-2) transport protocol for segmentation.' if size in ('256 bytes', '1 KB') else '') if proto == 'CAN' else ''}"
                f"{'USB CDC (virtual COM port) is best for bulk data. For {size}: buffer data and send in USB packet-sized chunks (64 bytes for FS). Use double-buffering for continuous streaming. Throughput up to ~1 MB/s on Full-Speed USB.' if proto == 'USB CDC' else ''}\n\n"
                f"General tips: Always use DMA for transfers > 4 bytes to free the CPU. Use double-buffering (ping-pong) for continuous data streams. Handle errors (timeout, NACK, bus errors) in the ISR callback.",
            })

    # --- Parametric: boot time optimization ---
    mcus = ["STM32F1", "STM32F4", "STM32H7", "ESP32", "nRF52840"]
    for mcu in mcus:
        pairs.append({
            "user": f"How do I minimize boot time on {mcu}?",
            "assistant": f"Boot time optimization for {mcu}:\n\n"
            f"{'1. Use HSI (internal 8MHz) initially, switch to PLL after critical init\n2. Skip HAL_Init() delay (remove HAL_Delay in SystemClock_Config)\n3. Initialize only needed peripherals\n4. Use __attribute__((section(\".fast\"))) for critical init code in SRAM' if 'STM32' in mcu else ''}"
            f"{'1. Reduce bootloader log level: CONFIG_BOOTLOADER_LOG_LEVEL_NONE\n2. Skip WiFi/BT init if not immediately needed\n3. Use fast boot mode: CONFIG_ESPTOOLPY_FLASHFREQ_80M\n4. Minimize partition table scanning\n5. Use ULP coprocessor for wake-from-sleep tasks' if mcu == 'ESP32' else ''}"
            f"{'1. Use HFXO (32MHz) instead of HFINT for faster PLL lock\n2. Enable DCDC converter early for power efficiency\n3. Pre-configure GPIO before enabling peripherals\n4. Use SoftDevice minimal config if BLE not needed at boot' if mcu == 'nRF52840' else ''}\n\n"
            f"General: Measure boot time with GPIO toggle + oscilloscope. Target: <50ms for sensor wake, <200ms for user-facing devices.",
        })

    return pairs


def _iot_templates() -> list[dict]:
    """MQTT, WiFi, BLE, OTA, provisioning."""
    pairs = []

    mqtt_qs = [
        ("set up MQTT on ESP32 with TLS",
         "```c\n#include \"mqtt_client.h\"\n\nesp_mqtt_client_config_t mqtt_cfg = {\n    .broker.address.uri = \"mqtts://broker.hivemq.com:8883\",\n    .broker.verification.certificate = server_cert_pem,\n    .credentials.username = \"device_001\",\n    .credentials.authentication.password = \"secret\",\n    .session.keepalive = 60,\n    .network.reconnect_timeout_ms = 5000,\n};\nesp_mqtt_client_handle_t client = esp_mqtt_client_init(&mqtt_cfg);\nesp_mqtt_client_register_event(client, ESP_EVENT_ANY_ID, mqtt_event_handler, NULL);\nesp_mqtt_client_start(client);\n```\nEmbed CA certificate in firmware using `EMBED_TXTFILES` in CMakeLists.txt. Use QoS 1 for sensor data, QoS 2 for commands. Keep payload compact (JSON or CBOR)."),
        ("implement MQTT topic structure for a fleet of IoT devices",
         "Recommended topic hierarchy:\n```\n{project}/{site}/{device_type}/{device_id}/{data_type}\n\nExamples:\nfarm/site-A/sensor/temp-001/telemetry    → {\"temp\": 22.5, \"ts\": 1711324800}\nfarm/site-A/sensor/temp-001/status        → {\"battery\": 85, \"rssi\": -67}\nfarm/site-A/sensor/temp-001/cmd           → {\"action\": \"recalibrate\"}\nfarm/site-A/+/+/telemetry                 → subscribe to all telemetry\nfarm/site-A/#                              → subscribe to everything on site A\n```\nRules:\n- No leading slash\n- Use retained messages for status/config\n- Separate telemetry (high-freq) from commands (low-freq)\n- Device subscribes to `cmd` topic, publishes to `telemetry`\n- Use `$SYS` topics for broker monitoring"),
        ("handle MQTT reconnection and offline buffering",
         "Robust MQTT pattern:\n```c\nvoid mqtt_event_handler(void *arg, esp_event_base_t base, int32_t id, void *data) {\n    switch (id) {\n    case MQTT_EVENT_CONNECTED:\n        is_connected = true;\n        flush_offline_buffer(); // send queued messages\n        resubscribe_topics();   // re-subscribe after reconnect\n        break;\n    case MQTT_EVENT_DISCONNECTED:\n        is_connected = false;\n        break;\n    case MQTT_EVENT_ERROR:\n        log_mqtt_error(data);\n        break;\n    }\n}\n\n// Offline buffer (ring buffer in RTC RAM survives deep sleep):\nRTC_DATA_ATTR OfflineMsg_t offline_buf[32];\nvoid publish_or_buffer(const char *topic, const char *payload) {\n    if (is_connected) {\n        esp_mqtt_client_publish(client, topic, payload, 0, 1, 0);\n    } else {\n        ring_push(&offline_buf, topic, payload);\n    }\n}\n```\nSet `clean_session=false` for persistent subscriptions. Use QoS 1+ for reliable delivery."),
    ]
    for q, a in mqtt_qs:
        pairs.append({"user": f"How do I {q}?", "assistant": a})

    # --- WiFi ---
    wifi_qs = [
        ("configure WiFi provisioning on ESP32 via BLE",
         "Using ESP-IDF wifi_provisioning:\n```c\n#include \"wifi_provisioning/manager.h\"\n#include \"wifi_provisioning/scheme_ble.h\"\n\nwifi_prov_mgr_config_t config = {\n    .scheme = wifi_prov_scheme_ble,\n    .scheme_event_handler = WIFI_PROV_SCHEME_BLE_EVENT_HANDLER_FREE_BT,\n};\nwifi_prov_mgr_init(config);\n\nbool provisioned = false;\nwifi_prov_mgr_is_provisioned(&provisioned);\nif (!provisioned) {\n    wifi_prov_mgr_start_provisioning(\n        WIFI_PROV_SECURITY_1, pop_string, service_name, NULL);\n} else {\n    wifi_prov_mgr_deinit();\n    connect_wifi();\n}\n```\nUser flow: Phone app scans BLE, discovers device, sends WiFi credentials securely. Credentials stored in NVS. Use SECURITY_1 (SRP6a + AES-CTR) for encrypted provisioning."),
        ("implement WiFi connection with retry and fallback to AP mode",
         "```c\nstatic int retry_count = 0;\n#define MAX_RETRIES 5\n\nvoid wifi_event_handler(void *arg, esp_event_base_t base, int32_t id, void *data) {\n    if (base == WIFI_EVENT && id == WIFI_EVENT_STA_DISCONNECTED) {\n        if (retry_count < MAX_RETRIES) {\n            esp_wifi_connect();\n            retry_count++;\n        } else {\n            start_ap_mode(); // fallback: open config portal\n        }\n    } else if (base == IP_EVENT && id == IP_EVENT_STA_GOT_IP) {\n        retry_count = 0;\n        // Connected — start MQTT, NTP sync, etc.\n    }\n}\n\nvoid start_ap_mode() {\n    wifi_config_t ap_config = {\n        .ap = {.ssid = \"MyDevice-Setup\", .password = \"12345678\",\n               .max_connection = 2, .authmode = WIFI_AUTH_WPA2_PSK}\n    };\n    esp_wifi_set_mode(WIFI_MODE_AP);\n    esp_wifi_set_config(WIFI_IF_AP, &ap_config);\n    start_captive_portal_http_server(); // serve config page\n}\n```"),
    ]
    for q, a in wifi_qs:
        pairs.append({"user": f"How do I {q}?", "assistant": a})

    # --- BLE ---
    ble_qs = [
        ("create a BLE GATT server for a custom sensor on ESP32",
         "```c\n// Define custom service UUID and characteristic\n#define SERVICE_UUID    0x00FF\n#define CHAR_UUID_TEMP  0xFF01\n\nstatic const esp_gatts_attr_db_t gatt_db[] = {\n    // Service declaration\n    [0] = {{ESP_GATT_AUTO_RSP}, {ESP_UUID_LEN_16, (uint8_t*)&primary_service_uuid, ...}},\n    // Characteristic: Temperature\n    [1] = {{ESP_GATT_AUTO_RSP}, {ESP_UUID_LEN_16, (uint8_t*)&char_temp_uuid, ...}},\n    // Characteristic value\n    [2] = {{ESP_GATT_RSP_BY_APP}, {ESP_UUID_LEN_16, ..., .max_length = 4}},\n    // CCCD (Client Characteristic Configuration Descriptor) for notifications\n    [3] = {{ESP_GATT_AUTO_RSP}, {ESP_UUID_LEN_16, (uint8_t*)&cccd_uuid, ...}},\n};\n\n// Send notification when temperature changes:\nesp_ble_gatts_send_indicate(gatts_if, conn_id, attr_handle, sizeof(float), (uint8_t*)&temp, false);\n```\nUse NimBLE stack (smaller footprint) for production. Advertise with service UUID for easy discovery. BLE 5.0 supports 2Mbps PHY for faster data transfer."),
    ]
    for q, a in ble_qs:
        pairs.append({"user": q, "assistant": a})

    # --- OTA ---
    ota_qs = [
        ("implement OTA firmware update over HTTPS on ESP32",
         "```c\n#include \"esp_https_ota.h\"\n\nesp_http_client_config_t http_config = {\n    .url = \"https://ota.example.com/firmware.bin\",\n    .cert_pem = server_cert_pem,\n    .timeout_ms = 30000,\n};\nesp_https_ota_config_t ota_config = {\n    .http_config = &http_config,\n};\nesp_err_t ret = esp_https_ota(&ota_config);\nif (ret == ESP_OK) {\n    esp_restart(); // boot into new firmware\n}\n```\nPartition table: Use 'factory + OTA0 + OTA1' scheme. The bootloader alternates between OTA partitions. Implement rollback: `esp_ota_mark_app_valid_cancel_rollback()` after verifying new firmware works. Add version check header to prevent downgrade attacks. Sign firmware with `espsecure.py`."),
        ("design a safe OTA update strategy for IoT fleet",
         "Fleet OTA best practices:\n1. **Staged rollout**: Update 1% -> 10% -> 50% -> 100% with health monitoring between stages\n2. **Automatic rollback**: Device reboots into old firmware if new one fails health check within 60s\n3. **Version manifest**: Server provides JSON with version, hash, min_battery, required_hw_rev\n4. **Delta updates**: Use bsdiff/bspatch for smaller OTA payloads (ESP-IDF supports compressed OTA)\n5. **Secure boot**: Sign firmware images, verify signature before flashing\n6. **Battery check**: Abort OTA if battery < 30% to prevent bricking during flash\n7. **Resume**: Support partial download resume for unreliable connections\n8. **Metrics**: Report OTA success/failure/version to MQTT topic `device/ota/status`\n9. **Scheduling**: Update during maintenance window (e.g., 2-4 AM local time)\n10. **Canary**: Flag first device per site as canary, monitor 24h before fleet-wide rollout"),
    ]
    for q, a in ota_qs:
        pairs.append({"user": q, "assistant": a})

    # --- Parametric: protocols ---
    protocols = ["MQTT", "CoAP", "HTTP REST", "WebSocket", "Modbus TCP"]
    use_cases = ["telemetry", "command/control", "firmware update", "configuration"]
    for proto in protocols:
        for use in use_cases:
            pairs.append({
                "user": f"Is {proto} suitable for {use} in IoT?",
                "assistant": f"{proto} for {use}:\n\n"
                f"{'Excellent choice. MQTT is the standard for IoT telemetry — lightweight, pub/sub, QoS levels, retained messages. Overhead ~2 bytes header.' if proto == 'MQTT' and use == 'telemetry' else ''}"
                f"{'Good. MQTT commands via dedicated topic (device/cmd). QoS 2 ensures exactly-once delivery. Response via separate topic.' if proto == 'MQTT' and use == 'command/control' else ''}"
                f"{'Not ideal. MQTT can transfer binary firmware but lacks built-in progress tracking. Use HTTP/HTTPS instead for OTA.' if proto == 'MQTT' and use == 'firmware update' else ''}"
                f"{'Good. Use retained messages for config. Device subscribes to config topic, applies on change.' if proto == 'MQTT' and use == 'configuration' else ''}"
                f"{'Good for constrained devices (UDP-based, ~4 bytes header). Observe pattern for telemetry push. Best with LwM2M.' if proto == 'CoAP' and use == 'telemetry' else ''}"
                f"{'Good. CoAP supports GET/PUT/POST/DELETE. Confirmable messages for reliable delivery.' if proto == 'CoAP' and use == 'command/control' else ''}"
                f"{'Possible with CoAP block transfers, but HTTP is more practical for large files.' if proto == 'CoAP' and use == 'firmware update' else ''}"
                f"{'Good. Use CoAP PUT to /config resource. LwM2M adds standardized object model.' if proto == 'CoAP' and use == 'configuration' else ''}"
                f"{'Works but high overhead per request. Use for cloud integrations, not device-to-device.' if proto == 'HTTP REST' else ''}"
                f"{'Good for real-time bidirectional communication. Higher resource usage than MQTT. Best for dashboards.' if proto == 'WebSocket' else ''}"
                f"{'Best for industrial equipment integration. Standard in SCADA/PLC environments. Not ideal for battery-powered devices.' if proto == 'Modbus TCP' else ''}"
                f"\n\nConsider: bandwidth constraints, battery life, network reliability, and existing infrastructure when choosing.",
            })

    # --- Parametric: sensor + connectivity combos ---
    sensors = ["temperature/humidity (DHT22)", "accelerometer (MPU6050)", "GPS (NEO-6M)", "air quality (BME680)", "load cell (HX711)"]
    connectivities = ["WiFi", "BLE", "LoRa", "NB-IoT", "Zigbee"]
    for sensor in sensors:
        for conn in connectivities:
            pairs.append({
                "user": f"How do I build an IoT node with {sensor} sensor and {conn} connectivity?",
                "assistant": f"IoT node with {sensor} + {conn}:\n\n"
                f"**Hardware:**\n"
                f"- MCU: {'ESP32 (built-in WiFi + BLE)' if conn in ('WiFi', 'BLE') else 'STM32L4 + SX1276 module' if conn == 'LoRa' else 'STM32L4 + BG96/Sara module' if conn == 'NB-IoT' else 'CC2652R (TI) or nRF52840 + Zigbee stack'}\n"
                f"- Sensor: {sensor.split('(')[0].strip()}\n"
                f"- Power: {'LiPo battery + solar panel' if conn in ('LoRa', 'NB-IoT', 'Zigbee') else 'USB-C powered or LiPo with charger'}\n\n"
                f"**Software stack:**\n"
                f"- {'ESP-IDF with WiFi station mode, MQTT over TLS' if conn == 'WiFi' else 'NimBLE stack, GATT server with custom service UUID' if conn == 'BLE' else 'LoRaWAN stack (LMIC or RadioLib), TTN/Chirpstack backend' if conn == 'LoRa' else 'AT commands or native driver, CoAP/LwM2M protocol' if conn == 'NB-IoT' else 'Zigbee 3.0 stack, ZCL clusters for sensor data'}\n"
                f"- Read sensor every {'30s-5min (battery-optimized)' if conn in ('LoRa', 'NB-IoT', 'Zigbee') else '1-10s (mains powered)'}\n"
                f"- Deep sleep between readings: {'essential — target <10uA sleep current' if conn in ('LoRa', 'NB-IoT') else 'recommended for battery operation' if conn in ('BLE', 'Zigbee') else 'optional if USB powered'}\n\n"
                f"**Data format:** Compact payload — {'CBOR or Cayenne LPP for LoRaWAN (max 51 bytes SF12)' if conn == 'LoRa' else 'JSON over MQTT' if conn == 'WiFi' else 'BLE GATT characteristic (max 512 bytes)' if conn == 'BLE' else 'CoAP with CBOR payload' if conn == 'NB-IoT' else 'ZCL standard attribute reports'}",
            })

    return pairs


def _emc_templates() -> list[dict]:
    """Shielding, filtering, grounding, compliance."""
    pairs = []

    topics = [
        ("reduce radiated emissions from a PCB with a switching power supply",
         "EMC mitigation for switching supplies:\n1. **Loop area**: Minimize the hot loop (switch → inductor → output cap → input cap → switch). Keep these components tight.\n2. **Ground plane**: Continuous ground plane under the switcher section. No slots or gaps that force return current detours.\n3. **Snubber**: RC snubber across the switch (100ohm + 100pF typical) to dampen ringing.\n4. **Input filter**: LC filter (ferrite bead + 10uF) between supply input and switcher input.\n5. **Shielded inductor**: Use shielded or semi-shielded inductors to contain magnetic field.\n6. **Slow down edges**: Increase gate resistance (10-100ohm) on MOSFET driver to reduce dV/dt.\n7. **Boot resistor**: Add series resistor on bootstrap capacitor charging path.\n8. **Spread spectrum**: Enable spread-spectrum modulation if supported by the IC (reduces peak emissions by ~6-10dB).\n9. **Copper pour**: Pour ground copper on all layers, stitch with vias every 2-3mm."),
        ("design a common-mode choke for a CAN bus interface",
         "CAN bus CM choke design:\n1. **Impedance target**: 100-1000 ohm at 30MHz-1GHz\n2. **Typical part**: WE-CNSW (Wurth), ACT45B (TDK), or similar SMD common-mode choke\n3. **Inductance**: 100uH-1mH common-mode, <1uH differential (low insertion loss for data)\n4. **Placement**: Between transceiver and connector, as close to connector as possible\n5. **Pinout**: CAN_H and CAN_L through the choke (not GND)\n6. **Additional filtering**: Add 100pF caps from each CAN line to chassis GND after the choke\n7. **TVS protection**: Add bidirectional TVS (PESD2CAN, NUP2114) between CAN lines after choke\n\nSchematic: MCU → CAN transceiver → CM choke → split termination (2x60ohm + 4.7nF to GND) → connector.\nThe choke blocks common-mode noise (EMI) while passing differential CAN signals transparently."),
        ("implement a Pi filter for power supply decoupling",
         "Pi filter topology: C1 → L → C2\n\n```\nVin ──┤C1├──┤L├──┤C2├── Vout\n      │       │       │\n     GND     GND     GND\n```\n\nDesign for -40dB attenuation at switching frequency:\n- C1 (input): 10-100uF bulk (electrolytic or ceramic)\n- L: Ferrite bead (for MHz noise) or inductor (for lower frequency)\n  - BLM18PG471 (470ohm @ 100MHz) for digital ICs\n  - 10uH inductor for analog sections\n- C2 (output): 10uF + 100nF ceramic (close to IC)\n\nCutoff frequency: fc = 1/(2*pi*sqrt(L*C))\nFor ferrite bead: treat as frequency-dependent resistor, provides dissipative filtering above 10MHz.\n\nPlace the Pi filter between noisy supply (switcher output) and sensitive circuit (ADC, PLL, clock)."),
        ("pass EN 55032 (CISPR 32) Class B radiated emissions",
         "Checklist for CISPR 32 Class B compliance:\n\n**PCB level:**\n1. 4-layer minimum with solid ground plane\n2. All signal traces referenced to adjacent ground plane\n3. No ground plane splits under high-speed signals\n4. Clock traces: shortest possible, series termination resistor (33ohm)\n5. Decoupling: 100nF on every IC power pin + 10uF per power rail section\n\n**Connector level:**\n6. Ferrite beads on all I/O lines at board edge\n7. TVS/ESD protection on external interfaces\n8. Shield ground connected to chassis via short, wide copper\n\n**Enclosure level:**\n9. Metal enclosure or conductive coating on plastic\n10. Seam length < lambda/20 at highest test frequency (1GHz → 15mm max gap)\n11. I/O panel: filtered connectors or ferrite sleeves on cables\n12. Ventilation holes: <3mm diameter, or use honeycomb waveguide filters\n\n**Pre-compliance testing:**\n13. Near-field probe scan (H-field) to identify hot spots\n14. Use spectrum analyzer + antenna at 3m to estimate emissions\n15. Budget 2-3 pre-compliance iterations before formal testing"),
        ("design ESD protection for USB and Ethernet ports",
         "ESD protection design:\n\n**USB:**\n- TVS array: USBLC6-2SC6 (ST) or TPD2E001 (TI) on D+/D-\n- Placement: as close to connector as possible, short traces to ground plane\n- Capacitance: <0.5pF per line for USB 2.0 HS, <0.2pF for USB 3.0\n- Clamp voltage: <18V for 3.3V I/O\n- Add ferrite bead on VBUS (600ohm @ 100MHz)\n\n**Ethernet:**\n- TVS: RCLAMP0524P (Semtech) on all 4 pairs\n- Place after magnetics (transformer) on the PHY side\n- Or use integrated RJ45+magnetics with built-in ESD (Pulse JXD1-0008NL)\n- Bob Smith termination: 75ohm from center tap to chassis GND via 1nF cap\n\n**General:**\n- IEC 61000-4-2: +-8kV contact, +-15kV air discharge\n- Ground ESD to chassis, not signal GND (avoid injecting ESD current into circuit)\n- Wide, short traces from TVS to ground pad — inductance degrades performance"),
        ("shield a sensitive analog circuit from digital noise",
         "Shielding strategies:\n\n1. **Guard ring**: Copper pour around analog section on same layer, connected to analog GND. Place via fence to ground plane below.\n\n2. **Split ground plane**: Separate analog GND and digital GND regions, connect at a single star point near the ADC. All analog components over analog GND pour.\n\n3. **Moat and bridge**: Cut a gap in the ground plane between analog and digital sections. Bridge only under the ADC (where analog meets digital). No traces cross the moat except at the bridge.\n\n4. **Physical shielding**: Metal can (stamped or soldered) over analog section. Ground the can to analog GND plane with multiple vias.\n\n5. **Power isolation**: Separate LDO for analog supply (ADP7118 or similar low-noise). Ferrite bead + LC filter between digital and analog power domains.\n\n6. **Routing**: Keep digital traces (clocks, SPI, buses) away from analog traces. Route analog signals on inner layers sandwiched between ground planes. Minimum 3x trace width separation."),
    ]
    for q, a in topics:
        pairs.append({"user": f"How do I {q}?", "assistant": a})

    # --- Standards & testing ---
    standards = [
        ("What EMC tests are required for CE marking of an industrial device?",
         "CE marking EMC tests per EN 61326-1 (industrial equipment):\n\n**Emissions (must not disturb):**\n- EN 55032: Conducted emissions (150kHz-30MHz)\n- EN 55032: Radiated emissions (30MHz-1GHz, potentially to 6GHz)\n- EN 61000-3-2: Harmonic current emissions (if >75W)\n- EN 61000-3-3: Voltage fluctuations/flicker\n\n**Immunity (must withstand):**\n- EN 61000-4-2: ESD (±4kV contact, ±8kV air)\n- EN 61000-4-3: Radiated immunity (3V/m, 80MHz-2.7GHz)\n- EN 61000-4-4: EFT/Burst (±2kV power, ±1kV signal)\n- EN 61000-4-5: Surge (±1kV line-to-line, ±2kV line-to-earth)\n- EN 61000-4-6: Conducted immunity (3Vrms, 150kHz-80MHz)\n- EN 61000-4-8: Magnetic field immunity (30A/m)\n- EN 61000-4-11: Voltage dips/interruptions\n\nPerformance criteria: A (no degradation), B (temporary degradation, self-recovery), C (temporary loss, operator intervention)."),
    ]
    for q, a in standards:
        pairs.append({"user": q, "assistant": a})

    # --- Parametric: filter types ---
    freq_ranges = [("100kHz", "switching noise"), ("10MHz", "digital clock harmonics"), ("100MHz", "high-speed digital"), ("1GHz", "RF/microwave")]
    filter_types = ["ferrite bead", "LC low-pass", "common-mode choke", "Pi filter"]
    for freq, noise in freq_ranges:
        for filt in filter_types:
            pairs.append({
                "user": f"Is a {filt} effective at {freq} for {noise}?",
                "assistant": f"{'Yes, ferrite beads are most effective at 10MHz-1GHz. At ' + freq + ' a ferrite bead ' + ('may be too low in impedance — use an inductor-based filter instead.' if freq == '100kHz' else 'is in its optimal range, providing 100-1000 ohm impedance with resistive dissipation.' if freq in ('10MHz','100MHz') else 'works well but choose a high-frequency type (e.g., BLM15HG) with peak impedance near target frequency.') if filt == 'ferrite bead' else ''}"
                f"{'LC low-pass filter at ' + freq + ': ' + ('Excellent — standard design. Use quality inductor (low DCR, rated for DC bias current) and ceramic caps.' if freq == '100kHz' else 'Good, but inductor self-resonant frequency must be above ' + freq + '. Use smaller inductance values.' if freq == '10MHz' else 'Challenging — parasitic effects dominate. Use multilayer chip inductors and small ceramic caps.' if freq == '100MHz' else 'Not practical at 1GHz — use microstrip filters or waveguide structures.') if filt == 'LC low-pass' else ''}"
                f"{'Common-mode choke at ' + freq + ': ' + ('Limited effectiveness — CM chokes typically start working above 1MHz. Use a larger core.' if freq == '100kHz' else 'Good range for CM chokes. Look for 100-1000 ohm CM impedance at this frequency.' if freq in ('10MHz','100MHz') else 'CM choke effectiveness drops at GHz — parasitic capacitance creates a self-resonance. Use multiple smaller chokes in series.') if filt == 'common-mode choke' else ''}"
                f"{'Pi filter at ' + freq + ': ' + ('Effective — provides double the rolloff of a single LC stage. Good for power supply filtering.' if freq == '100kHz' else 'Good, but use quality components. Parasitic inductance of capacitors limits performance.' if freq == '10MHz' else 'Marginal — layout parasitics dominate. Keep component leads/traces as short as possible.' if freq == '100MHz' else 'Impractical with discrete components. Use integrated EMI filter ICs or PCB-embedded filters.') if filt == 'Pi filter' else ''}",
            })

    # --- Parametric: PCB layer count vs EMC ---
    for layers in [1, 2, 4, 6]:
        for speed in ["low-speed (<10MHz)", "medium-speed (10-100MHz)", "high-speed (>100MHz)"]:
            pairs.append({
                "user": f"What EMC considerations apply to a {layers}-layer PCB with {speed} signals?",
                "assistant": f"EMC for {layers}-layer PCB with {speed} signals:\n\n"
                f"{'1-layer PCB: Very poor EMC. No ground plane — large loop areas for all return currents. Only suitable for very low-frequency, low-EMI applications (e.g., simple sensor boards). Add ground wire grid if possible.' if layers == 1 else ''}"
                f"{'2-layer PCB: Ground pour on bottom provides partial ground plane. Keep ground pour as continuous as possible. Route signals on top, ground on bottom. Use via stitching around board edges. Acceptable for ' + ('low-speed signals — adequate with careful routing.' if 'low' in speed else 'medium-speed with careful routing — minimize trace length, avoid crossing ground plane gaps.' if 'medium' in speed else 'high-speed ONLY if very few signals — strongly recommend 4+ layers.') if layers == 2 else ''}"
                f"{'4-layer PCB (recommended minimum for EMC): Stack: Sig/GND/PWR/Sig. Solid ground plane on L2 provides excellent return path for all top-layer signals. ' + ('Overkill for low-speed but gives best EMC margin.' if 'low' in speed else 'Ideal configuration. Route critical signals on L1 referenced to L2 ground.' if 'medium' in speed else 'Minimum for high-speed. Route controlled-impedance traces on L1/L4 referenced to adjacent planes. Consider 6-layer for complex designs.') if layers == 4 else ''}"
                f"{'6-layer PCB: Stack: Sig/GND/Sig/PWR/GND/Sig. Two solid ground planes provide excellent shielding. Inner signal layer (L3) is sandwiched between grounds — lowest radiation. ' + ('Excessive for low-speed — cost not justified.' if 'low' in speed else 'Excellent for medium-speed with many signals. Use inner layers for sensitive analog routing.' if 'medium' in speed else 'Recommended for high-speed digital (DDR, PCIe, USB 3.0). Dual ground planes provide stripline geometry for best signal integrity.') if layers == 6 else ''}",
            })

    # --- Parametric: cable shielding ---
    cable_types = ["unshielded twisted pair", "shielded twisted pair", "coaxial", "ribbon cable"]
    interfaces = ["I2C", "SPI", "UART", "CAN bus", "USB", "Ethernet"]
    for cable in cable_types:
        for iface in interfaces:
            pairs.append({
                "user": f"Can I use {cable} for {iface} connections in an EMC-sensitive environment?",
                "assistant": f"Using {cable} for {iface}:\n\n"
                f"{'Unshielded twisted pair: The twist reduces differential-mode coupling. ' + ('Acceptable for I2C at short distances (<0.5m) in low-noise environments. Add common-mode choke at each end for noisy environments.' if iface == 'I2C' else 'Not recommended for SPI — SPI has separate clock/data lines (not differential). Use shielded cable.' if iface == 'SPI' else 'Acceptable for UART at low baud rates (<115200) and short distances.' if iface == 'UART' else 'Standard for CAN bus. CAN is differential, so UTP works well. Add 120 ohm termination at each end.' if iface == 'CAN bus' else 'Not compliant — USB requires shielded cable per specification.' if iface == 'USB' else 'Standard for Ethernet (Cat5e/Cat6). Already optimized for EMC with specific twist rates per pair.') if 'unshielded' in cable else ''}"
                f"{'Shielded twisted pair (STP): Best balance of EMC protection and flexibility. ' + ('Excellent for I2C in industrial environments. Ground shield at one end only to avoid ground loops.' if iface == 'I2C' else 'Good for SPI if properly grounded. Connect shield to ground at the master end.' if iface == 'SPI' else 'Excellent for UART in noisy environments.' if iface == 'UART' else 'Recommended for CAN bus in high-EMI industrial environments (EN 50288).' if iface == 'CAN bus' else 'Meets USB spec requirements. Ensure shield continuity at connectors.' if iface == 'USB' else 'STP Ethernet (Cat6A/Cat7) required for 10GbE and noisy environments.') if 'shielded twisted' in cable else ''}"
                f"{'Coaxial cable: Single-ended, excellent shielding. ' + ('Not ideal for I2C (needs 2 signals). Use two coax cables or switch to STP.' if iface == 'I2C' else 'Not practical for multi-signal SPI bus.' if iface == 'SPI' else 'Good for single-direction UART (TX or RX). Overkill for most UART applications.' if iface == 'UART' else 'Not standard for CAN — CAN requires differential pair, not coax.' if iface == 'CAN bus' else 'Not standard — USB requires specific cable geometry for impedance matching.' if iface == 'USB' else 'Not standard for Ethernet — use proper Cat cable instead.') if 'coaxial' in cable else ''}"
                f"{'Ribbon cable: Convenient but poor EMC. ' + ('Acceptable for short I2C connections inside enclosure only. Alternate signal and ground wires.' if iface == 'I2C' else 'Acceptable for SPI inside enclosure. Use ground wire between each signal wire.' if iface == 'SPI' else 'OK for UART inside enclosure at low speeds.' if iface == 'UART' else 'Not recommended for CAN bus external connections.' if iface == 'CAN bus' else 'Not compliant with USB spec.' if iface == 'USB' else 'Not suitable for Ethernet.') if 'ribbon' in cable else ''}",
            })

    return pairs


def _dsp_templates() -> list[dict]:
    """FFT, filters, audio processing."""
    pairs = []

    topics = [
        ("implement a real-time FFT on a microcontroller",
         "Using CMSIS-DSP on Cortex-M4F:\n```c\n#include \"arm_math.h\"\n\n#define FFT_SIZE 1024\nfloat32_t fft_input[FFT_SIZE * 2]; // interleaved real/imag\nfloat32_t fft_output[FFT_SIZE];\narm_cfft_instance_f32 fft_inst;\n\nvoid compute_fft(float32_t *samples) {\n    // Prepare complex input (real samples, zero imaginary)\n    for (int i = 0; i < FFT_SIZE; i++) {\n        fft_input[2*i] = samples[i];     // real\n        fft_input[2*i+1] = 0.0f;         // imag\n    }\n    \n    // Apply window (Hanning)\n    for (int i = 0; i < FFT_SIZE; i++) {\n        float32_t w = 0.5f * (1.0f - cosf(2.0f * M_PI * i / (FFT_SIZE - 1)));\n        fft_input[2*i] *= w;\n    }\n    \n    arm_cfft_f32(&arm_cfft_sR_f32_len1024, fft_input, 0, 1); // FFT\n    arm_cmplx_mag_f32(fft_input, fft_output, FFT_SIZE);       // magnitude\n}\n```\n1024-point FFT on Cortex-M4F @ 168MHz takes ~0.3ms. Use DMA double-buffering for overlap-save. For fixed-point: use arm_cfft_q15 for lower memory and faster execution."),
        ("design an IIR biquad low-pass filter",
         "Second-order IIR (biquad) low-pass:\n```c\n// Coefficients for Butterworth LPF at fc/fs = 0.1 (e.g., 4.8kHz at 48kHz)\n// Use scipy.signal.butter(2, 0.1) to compute\nfloat32_t coeffs[5] = {\n    0.02008337f,  // b0\n    0.04016675f,  // b1\n    0.02008337f,  // b2\n    1.56101808f,  // -a1 (note: CMSIS uses negated a coefficients)\n    -0.64135154f  // -a2\n};\nfloat32_t state[4] = {0}; // 2 states per biquad section\n\narm_biquad_casd_df1_inst_f32 filter;\narm_biquad_cascade_df1_init_f32(&filter, 1, coeffs, state);\n\n// Process block:\narm_biquad_cascade_df1_f32(&filter, input_buf, output_buf, BLOCK_SIZE);\n```\nFor higher order: cascade multiple biquad sections. Design with scipy, MATLAB, or Iowa Hills filter designer. Always check stability: poles must be inside unit circle."),
        ("implement an FIR filter with CMSIS-DSP",
         "```c\n#include \"arm_math.h\"\n\n#define NUM_TAPS 64\n#define BLOCK_SIZE 256\n\nfloat32_t fir_coeffs[NUM_TAPS]; // designed externally\nfloat32_t fir_state[NUM_TAPS + BLOCK_SIZE - 1];\narm_fir_instance_f32 fir_inst;\n\nvoid init_fir(void) {\n    arm_fir_init_f32(&fir_inst, NUM_TAPS, fir_coeffs, fir_state, BLOCK_SIZE);\n}\n\nvoid process_block(float32_t *in, float32_t *out) {\n    arm_fir_f32(&fir_inst, in, out, BLOCK_SIZE);\n}\n```\nDesign coefficients with:\n```python\nfrom scipy.signal import firwin\ncoeffs = firwin(64, 0.2)  # 64 taps, cutoff at 0.2*Nyquist\nnp.savetxt('fir_coeffs.csv', coeffs)\n```\nFIR advantages: always stable, linear phase, easy to design. Disadvantage: more taps needed (CPU) than IIR for same rolloff."),
        ("process audio in real-time with double buffering",
         "Double-buffer pattern for audio:\n```c\n#define BLOCK_SIZE 256\nint16_t dma_buf[BLOCK_SIZE * 2]; // DMA fills both halves\nvolatile uint8_t buf_ready = 0; // 1=first half, 2=second half\n\nvoid HAL_I2S_RxHalfCpltCallback(I2S_HandleTypeDef *hi2s) {\n    buf_ready = 1; // first half full\n}\nvoid HAL_I2S_RxCpltCallback(I2S_HandleTypeDef *hi2s) {\n    buf_ready = 2; // second half full\n}\n\n// Main loop or RTOS task:\nwhile (1) {\n    if (buf_ready) {\n        int16_t *src = (buf_ready == 1) ? dma_buf : dma_buf + BLOCK_SIZE;\n        process_audio(src, BLOCK_SIZE); // filter, FFT, etc.\n        buf_ready = 0;\n    }\n}\n```\nLatency = BLOCK_SIZE / sample_rate. At 48kHz with 256 samples: 5.3ms latency. Use I2S for audio codec (WM8960, PCM5102) with DMA circular mode."),
        ("compute a spectrogram for frequency analysis",
         "Spectrogram = short-time FFT (STFT):\n```python\nimport numpy as np\nfrom scipy.signal import spectrogram\nimport matplotlib.pyplot as plt\n\n# Parameters\nfs = 48000  # sample rate\nnperseg = 1024  # FFT window size\nnoverlap = 512  # 50% overlap\n\nf, t, Sxx = spectrogram(signal, fs, nperseg=nperseg, noverlap=noverlap,\n                         window='hann', scaling='density')\n\nplt.pcolormesh(t, f, 10*np.log10(Sxx), shading='gouraud', vmin=-80)\nplt.ylabel('Frequency [Hz]')\nplt.xlabel('Time [s]')\nplt.colorbar(label='PSD [dB/Hz]')\n```\nFor embedded: compute overlapping FFT blocks, store magnitude. Trade-offs:\n- Longer window → better frequency resolution, worse time resolution\n- 50% overlap is standard, 75% for better visualization\n- Hanning window reduces spectral leakage"),
        ("implement a PID controller in C",
         "```c\ntypedef struct {\n    float Kp, Ki, Kd;\n    float integral;\n    float prev_error;\n    float output_min, output_max;\n    float dt; // sample period in seconds\n} PID_t;\n\nfloat pid_update(PID_t *pid, float setpoint, float measurement) {\n    float error = setpoint - measurement;\n    \n    // Proportional\n    float P = pid->Kp * error;\n    \n    // Integral with anti-windup\n    pid->integral += error * pid->dt;\n    float I = pid->Ki * pid->integral;\n    \n    // Derivative (on measurement to avoid kick)\n    float derivative = -(measurement - pid->prev_error) / pid->dt;\n    pid->prev_error = measurement;\n    float D = pid->Kd * derivative;\n    \n    // Output with clamping\n    float output = P + I + D;\n    if (output > pid->output_max) {\n        output = pid->output_max;\n        pid->integral -= error * pid->dt; // anti-windup\n    } else if (output < pid->output_min) {\n        output = pid->output_min;\n        pid->integral -= error * pid->dt;\n    }\n    \n    return output;\n}\n```\nTuning: Start with Kp only, then add Ki for steady-state error, then Kd for overshoot. Ziegler-Nichols method for initial values. dt must match actual sample rate."),
    ]
    for q, a in topics:
        pairs.append({"user": f"How do I {q}?", "assistant": a})

    # --- Parametric: FFT sizes ---
    for fft_size in [64, 128, 256, 512, 1024, 2048, 4096]:
        for fs in [8000, 16000, 44100, 48000]:
            pairs.append({
                "user": f"What is the frequency resolution of a {fft_size}-point FFT at {fs}Hz sample rate?",
                "assistant": f"Frequency resolution = fs / N = {fs} / {fft_size} = {fs/fft_size:.2f} Hz per bin.\n\n"
                f"Total bins: {fft_size//2 + 1} (DC to Nyquist)\n"
                f"Nyquist frequency: {fs//2} Hz\n"
                f"Frame duration: {fft_size/fs*1000:.1f} ms\n\n"
                f"{'Good for speech processing — captures formant structure.' if fft_size >= 256 and fs <= 16000 else 'Good for music analysis at this sample rate.' if fft_size >= 1024 and fs >= 44100 else 'Short frame — good time resolution but poor frequency resolution. Consider overlap-add.' if fft_size <= 128 else 'Balanced choice for general audio analysis.'}\n\n"
                f"Memory: {fft_size * 8} bytes (complex float32). Processing time on Cortex-M4F @ 168MHz: ~{fft_size * 0.0003:.2f}ms.",
            })

    # --- Parametric: window functions ---
    windows = [
        ("Hanning", "Good general-purpose. Main lobe width: 4 bins. Side lobe: -31dB. Use for narrowband signal detection."),
        ("Hamming", "Similar to Hanning but higher side lobes (-43dB first side lobe). Better frequency resolution, worse leakage rejection."),
        ("Blackman", "Excellent side lobe rejection (-58dB). Wider main lobe (6 bins). Use for signals with large dynamic range."),
        ("Flat-top", "Best amplitude accuracy (+-0.01dB). Very wide main lobe. Use for calibration and amplitude measurement."),
        ("Kaiser", "Adjustable trade-off via beta parameter. beta=0 (rectangular), beta=5 (similar to Hamming), beta=10 (similar to Blackman)."),
        ("Rectangular (no window)", "Narrowest main lobe (2 bins) but worst leakage (-13dB side lobes). Use only for transient analysis or when signal is exactly periodic in the frame."),
    ]
    applications = ["vibration analysis", "audio spectrum analyzer", "radar signal processing", "biomedical signal (ECG/EEG)"]
    for wname, wdesc in windows:
        for app in applications:
            pairs.append({
                "user": f"Should I use a {wname} window for {app} FFT analysis?",
                "assistant": f"{wname} window for {app}:\n\n"
                f"{wdesc}\n\n"
                f"{'Vibration analysis: ' + ('Hanning is the standard choice for vibration — good balance of resolution and leakage. Use with overlap processing.' if 'Hanning' in wname else 'Acceptable alternative. Side lobe behavior slightly different from Hanning.' if 'Hamming' in wname else 'Good for detecting small vibration components near large ones.' if 'Blackman' in wname else 'Use when precise vibration amplitude matters more than frequency resolution.' if 'Flat-top' in wname else 'Kaiser with beta=6-8 is common. Flexible choice.' if 'Kaiser' in wname else 'Avoid for vibration — spectral leakage obscures harmonics.') if 'vibration' in app else ''}"
                f"{'Audio spectrum: ' + ('Standard choice for audio analyzers. 50% overlap with Hanning gives COLA (Constant Overlap-Add) property.' if 'Hanning' in wname else 'Usable but Hanning preferred for audio due to COLA property.' if 'Hamming' in wname else 'Good for audio with wide dynamic range (music mastering, noise floor analysis).' if 'Blackman' in wname else 'Not typical for audio display — main lobe too wide for frequency discrimination.' if 'Flat-top' in wname else 'Good flexibility. Use beta=5-7 for audio applications.' if 'Kaiser' in wname else 'Not recommended — severe leakage makes spectrum hard to interpret.') if 'audio' in app else ''}"
                f"{'Radar: ' + ('Common in radar signal processing. Good for moving target detection.' if 'Hanning' in wname else 'Used in some radar systems for its first side lobe characteristics.' if 'Hamming' in wname else 'Good for radar with close targets at different power levels.' if 'Blackman' in wname else 'Not typical in radar — frequency resolution more important than amplitude accuracy.' if 'Flat-top' in wname else 'Preferred in radar — can optimize for specific side lobe requirements. Dolph-Chebyshev (related) also popular.' if 'Kaiser' in wname else 'Sometimes used in pulsed radar for maximum frequency resolution.') if 'radar' in app else ''}"
                f"{'Biomedical: ' + ('Standard for EEG/ECG spectral analysis. Use with 50% overlap.' if 'Hanning' in wname else 'Acceptable for biomedical. Similar performance to Hanning for EEG bands.' if 'Hamming' in wname else 'Good for detecting low-amplitude EEG rhythms near high-amplitude ones.' if 'Blackman' in wname else 'Use when precise power measurement in specific EEG bands matters.' if 'Flat-top' in wname else 'Good choice — beta can be tuned for specific clinical requirements.' if 'Kaiser' in wname else 'Avoid for clinical analysis — spectral leakage can mask important features.') if 'biomedical' in app else ''}",
            })

    return pairs


def _power_templates() -> list[dict]:
    """Regulation, battery management, efficiency."""
    pairs = []

    topics = [
        ("design a buck converter for 12V to 3.3V at 2A",
         "Buck converter design (12V→3.3V, 2A):\n\n**IC selection**: TPS54202 (TI), LM2596, or MP2359 for simple designs.\n\n**Key calculations:**\n- Duty cycle: D = Vout/Vin = 3.3/12 = 27.5%\n- Inductor: L = (Vin - Vout) * D / (fs * dI) = (12-3.3)*0.275 / (500kHz * 0.6A) = 7.9uH → use 10uH\n- Output cap: C = dI / (8 * fs * dVout) = 0.6 / (8 * 500k * 0.033) = 4.5uF → use 22uF ceramic\n- Input cap: 10uF ceramic minimum (RMS current = Iout * sqrt(D*(1-D)) = 0.89A)\n\n**Component selection:**\n- Inductor: 10uH, >2.5A saturation, shielded (Wurth WE-LHMI or Coilcraft XAL5030)\n- Output cap: 2x 22uF 10V X5R ceramic (0805)\n- Input cap: 2x 10uF 25V X5R ceramic\n- Schottky diode (if async): SS34 (3A, 40V)\n\n**Layout**: Keep switch node area small, input cap close to IC, continuous ground plane under inductor."),
        ("design a battery management system for a 2S Li-Ion pack",
         "2S Li-Ion BMS design (7.4V nominal):\n\n**Protection IC**: Use BQ77915 (TI) or S-8254A (Ablic) for 2S protection.\n\n**Functions:**\n1. **Overvoltage**: Trip at 4.25V/cell, release at 4.15V/cell\n2. **Undervoltage**: Trip at 2.8V/cell, release at 3.0V/cell\n3. **Overcurrent**: 5-10A threshold (set by sense resistor)\n4. **Short circuit**: Fast trip (<100us), higher threshold\n5. **Cell balancing**: Passive (bleed resistor per cell, 50-100mA) or active (inductor-based)\n\n**Charging:**\n- CC/CV charger IC: BQ25606 (TI) for USB input, or TP4056 per cell\n- CC phase: 1C (e.g., 2A for 2000mAh cells)\n- CV phase: 4.2V/cell, terminate at C/10 (200mA)\n- Pre-charge: 0.1C for deeply discharged cells (<2.8V)\n\n**Fuel gauge**: BQ27441 (TI) for accurate SoC estimation using Impedance Track. Communicates via I2C.\n\n**Safety**: Add PTC fuse (resettable) in series, NTC thermistor for temperature monitoring (charge cutoff at 45C, discharge cutoff at 60C)."),
        ("calculate power dissipation and efficiency of a linear regulator",
         "Linear regulator (LDO) power analysis:\n\n**Power dissipation:**\nP_diss = (Vin - Vout) * Iout + Vin * Iq\n\nExample: AMS1117-3.3 (Vin=5V, Vout=3.3V, Iout=800mA):\nP_diss = (5 - 3.3) * 0.8 + 5 * 0.005 = 1.36 + 0.025 = 1.385W\n\n**Efficiency:**\neta = Vout / Vin = 3.3 / 5 = 66% (max theoretical for LDO)\n\n**Thermal:**\nTj = Ta + P_diss * Rth_ja\nFor SOT-223: Rth_ja ≈ 80°C/W (with ground plane)\nTj = 25 + 1.385 * 80 = 135.8°C → TOO HOT (max 125°C)\n\n**Solutions:**\n1. Reduce Vin-Vout dropout (use 3.6V input from buck pre-regulator)\n2. Reduce load current\n3. Use a buck converter instead (90%+ efficiency)\n4. Add copper area for heat sinking (reduces Rth_ja)\n5. Use LDO with exposed pad (Rth_ja ≈ 30-40°C/W)\n\n**When to use LDO**: Vin - Vout < 1V (low dropout), Iout < 500mA, or noise-sensitive analog circuits (LDO output is much cleaner than switcher)."),
        ("design a solar-powered IoT device with battery backup",
         "Solar + battery IoT power design:\n\n**Solar panel**: 6V, 1W panel (for 3.7V Li-Ion charging). Oversized for cloudy conditions.\n\n**Power path:**\nSolar → MPPT charger → Battery → LDO/Buck → System\n\n**MPPT charger**: BQ25570 (TI) — ultra-low power, cold-start from 330mV, MPPT tracking.\nOr SPV1050 (ST) for simpler design.\n\n**Battery**: 18650 Li-Ion 3000mAh. Capacity for 3 days without sun at 10mA avg = 720mAh needed.\n\n**Power budget:**\n| Mode | Current | Duration | Energy/day |\n|------|---------|----------|------------|\n| Active (sensor + TX) | 80mA | 10s/15min | 0.53mAh |\n| Sleep (RTC only) | 10uA | 14m50s/15min | 0.24mAh |\n| **Total** | | | **~18.5mAh/day** |\n\n**Regulation**: TPS62740 (TI) ultra-low Iq buck (360nA) for 3.3V output.\n\n**Protection**: Battery undervoltage lockout (3.0V), reverse polarity diode on solar, TVS on solar input.\n\n**Energy harvesting tip**: Log solar voltage and battery voltage via ADC for long-term energy analysis."),
        ("select between buck, boost, and buck-boost for a design",
         "Topology selection guide:\n\n**Buck (step-down)**: Vin > Vout always\n- Use when: 12V battery → 3.3V MCU, USB 5V → 3.3V\n- Efficiency: 85-95%\n- Simple, lowest cost, most common\n\n**Boost (step-up)**: Vin < Vout always\n- Use when: 1S Li-Ion (3.0-4.2V) → 5V USB output, solar cell → 3.3V\n- Efficiency: 80-92%\n- Note: no input-output isolation, Vout >= Vin always\n\n**Buck-boost**: Vin can be above or below Vout\n- Use when: Battery voltage range crosses Vout (e.g., 2S Li-Ion 6-8.4V → 7V)\n- Types: Inverting (simple, negative output), SEPIC (positive output, isolated), 4-switch (best efficiency)\n- Efficiency: 80-90%\n- More complex, more components\n\n**Decision matrix:**\n| Condition | Topology |\n|-----------|----------|\n| Vin always > Vout + 1V | Buck |\n| Vin always < Vout - 1V | Boost |\n| Vin range overlaps Vout | Buck-boost |\n| Noise-sensitive load | LDO (if dropout allows) |\n| Isolated output needed | Flyback or SEPIC |"),
    ]
    for q, a in topics:
        pairs.append({"user": q, "assistant": a})

    # --- Parametric: efficiency calculations ---
    for vin in [5, 12, 24, 48]:
        for vout in [1.8, 3.3, 5.0]:
            if vout >= vin:
                continue
            for iout in [0.5, 1.0, 2.0]:
                duty = vout / vin
                p_out = vout * iout
                p_loss_ldo = (vin - vout) * iout
                eff_ldo = (p_out / (p_out + p_loss_ldo)) * 100
                pairs.append({
                    "user": f"Compare LDO vs buck converter efficiency for {vin}V to {vout}V at {iout}A.",
                    "assistant": f"Comparison for {vin}V → {vout}V at {iout}A:\n\n"
                    f"**LDO:**\n"
                    f"- Power dissipation: ({vin} - {vout}) x {iout} = {p_loss_ldo:.1f}W\n"
                    f"- Efficiency: {eff_ldo:.0f}%\n"
                    f"- {'CAUTION: {:.1f}W dissipation requires significant heatsinking or is impractical.'.format(p_loss_ldo) if p_loss_ldo > 1.5 else 'Manageable with good thermal design.' if p_loss_ldo > 0.5 else 'Acceptable thermal load.'}\n\n"
                    f"**Buck converter** (typical 90% efficiency):\n"
                    f"- Power dissipation: ~{p_out * 0.11:.2f}W\n"
                    f"- Efficiency: ~90%\n"
                    f"- Duty cycle: {duty*100:.1f}%\n\n"
                    f"**Recommendation**: {'Use a buck converter — LDO wastes too much power at this voltage difference.' if p_loss_ldo > 1.0 else 'Buck converter preferred for efficiency, but LDO acceptable if noise performance matters (e.g., analog/RF supply).' if p_loss_ldo > 0.3 else 'LDO is fine for this application — low dropout and good noise performance.'}",
                })

    # --- Parametric: battery chemistry comparison ---
    chemistries = [
        ("Li-Ion (18650)", "3.7V", "2000-3500mAh", "4.2V", "2.5V", "500-1000 cycles", "self-discharge ~2%/month"),
        ("LiFePO4", "3.2V", "1000-3000mAh", "3.65V", "2.5V", "2000-5000 cycles", "self-discharge ~1%/month"),
        ("Li-Po", "3.7V", "100-10000mAh", "4.2V", "3.0V", "300-500 cycles", "self-discharge ~5%/month"),
        ("NiMH (AA)", "1.2V", "1900-2700mAh", "1.45V", "1.0V", "500-1000 cycles", "self-discharge ~20%/month (standard), ~1%/month (LSD)"),
        ("LTO (Lithium Titanate)", "2.4V", "1000-2500mAh", "2.85V", "1.8V", "7000-20000 cycles", "self-discharge ~1%/month"),
    ]
    applications = ["IoT sensor node", "power tool", "solar energy storage", "medical device", "electric vehicle"]
    for chem_name, nom_v, cap, max_v, min_v, cycles, selfdisch in chemistries:
        for app in applications:
            pairs.append({
                "user": f"Is {chem_name} suitable for a {app} application?",
                "assistant": f"{chem_name} for {app}:\n\n"
                f"Specs: {nom_v} nominal, {cap} capacity, charge to {max_v}, discharge to {min_v}\n"
                f"Cycle life: {cycles}, {selfdisch}\n\n"
                f"{'IoT sensor: ' + ('Good choice — high energy density, widely available. Use BMS with deep sleep cutoff.' if 'Li-Ion' in chem_name else 'Excellent — very long cycle life, safer chemistry, flat discharge curve. Slightly lower voltage.' if 'LiFePO4' in chem_name else 'Best for compact/flat form factors. Custom sizes available. Handle with care (no puncture).' if 'Li-Po' in chem_name else 'OK for non-critical sensors. Easy to source (AA batteries). Higher self-discharge is a problem for long deployments.' if 'NiMH' in chem_name else 'Overkill for IoT — expensive. Use if extreme temperature range or very long life required.') if 'IoT' in app else ''}"
                f"{'Power tool: ' + ('Standard choice. High discharge rate cells (INR) needed. 20-30A continuous.' if 'Li-Ion' in chem_name else 'Good for tools needing long life. Lower voltage requires more cells in series.' if 'LiFePO4' in chem_name else 'Used in compact tools. High C-rate pouch cells available.' if 'Li-Po' in chem_name else 'Legacy technology — replaced by Li-Ion in most modern tools.' if 'NiMH' in chem_name else 'Excellent for fast charging (6C+) and extreme temperature operation.') if 'power tool' in app else ''}"
                f"{'Solar storage: ' + ('Cost-effective for small systems. Cycle life may limit long-term value.' if 'Li-Ion' in chem_name else 'Excellent — long cycle life critical for daily charge/discharge. Safest chemistry for unattended systems.' if 'LiFePO4' in chem_name else 'Not ideal — shorter cycle life and higher cost per Wh.' if 'Li-Po' in chem_name else 'Not recommended — low energy density, high self-discharge.' if 'NiMH' in chem_name else 'Premium choice for solar — extreme cycle life but high cost.') if 'solar' in app else ''}"
                f"{'Medical: ' + ('Widely used. Requires careful BMS and safety certification (IEC 62133).' if 'Li-Ion' in chem_name else 'Good — inherently safer (no thermal runaway). Easier to certify.' if 'LiFePO4' in chem_name else 'Common in wearable medical devices. Flexible form factor.' if 'Li-Po' in chem_name else 'Traditional choice for disposable medical devices. Well-understood safety profile.' if 'NiMH' in chem_name else 'Good for implantable devices needing extreme longevity.') if 'medical' in app else ''}"
                f"{'EV: ' + ('Standard in most EVs (NCA/NMC variants). Best energy density.' if 'Li-Ion' in chem_name else 'Used in buses and commercial EVs. Safer, longer life, but heavier.' if 'LiFePO4' in chem_name else 'Used in some lightweight EVs and drones.' if 'Li-Po' in chem_name else 'Obsolete for EVs — too low energy density.' if 'NiMH' in chem_name else 'Excellent for fast-charging EVs. Used in some electric buses (Toshiba SCiB).') if 'vehicle' in app else ''}",
            })

    return pairs


def _platformio_templates() -> list[dict]:
    """Build system, libraries, environments."""
    pairs = []

    topics = [
        ("set up a multi-environment platformio.ini for STM32 and ESP32",
         "```ini\n[platformio]\ndefault_envs = blackpill, esp32dev\n\n[common]\nmonitor_speed = 115200\nlib_deps =\n    Wire\n    SPI\n\n[env:blackpill]\nplatform = ststm32\nboard = blackpill_f411ce\nframework = arduino\nupload_protocol = stlink\ndebug_tool = stlink\nbuild_flags = -D BOARD_STM32\nlib_deps =\n    ${common.lib_deps}\n    stm32duino/STM32duino FreeRTOS\n\n[env:esp32dev]\nplatform = espressif32\nboard = esp32dev\nframework = arduino\nupload_speed = 921600\nbuild_flags = -D BOARD_ESP32\nlib_deps =\n    ${common.lib_deps}\n    knolleary/PubSubClient\n    bblanchon/ArduinoJson\n\n[env:native]\nplatform = native\nbuild_flags = -D UNIT_TEST\nlib_deps = throwtheswitch/Unity\n```\nRun: `pio run -e blackpill` to build specific env. `pio test -e native` for host tests."),
        ("create a custom PlatformIO board definition",
         "Create `boards/my_custom_board.json`:\n```json\n{\n  \"build\": {\n    \"core\": \"stm32\",\n    \"cpu\": \"cortex-m4\",\n    \"extra_flags\": \"-DSTM32F411xE\",\n    \"f_cpu\": \"100000000L\",\n    \"mcu\": \"stm32f411ceu6\",\n    \"variant\": \"BLACKPILL_F411CE\"\n  },\n  \"debug\": {\n    \"jlink_device\": \"STM32F411CE\",\n    \"openocd_target\": \"stm32f4x\",\n    \"svd_path\": \"STM32F411.svd\"\n  },\n  \"frameworks\": [\"arduino\", \"stm32cube\"],\n  \"name\": \"My Custom F411 Board\",\n  \"upload\": {\n    \"maximum_ram_size\": 131072,\n    \"maximum_size\": 524288,\n    \"protocol\": \"stlink\"\n  },\n  \"url\": \"https://myproject.com\",\n  \"vendor\": \"Custom\"\n}\n```\nIn platformio.ini: `board = my_custom_board` (auto-detected from boards/ dir). Add `board_build.ldscript = custom_linker.ld` for custom memory layout."),
        ("manage library dependencies and versioning",
         "Library management in platformio.ini:\n```ini\nlib_deps =\n    # From PlatformIO Registry (recommended)\n    bblanchon/ArduinoJson @ ^7.0.0        # semver compatible\n    knolleary/PubSubClient @ 2.8          # exact version\n    \n    # From GitHub\n    https://github.com/me/mylib.git       # latest\n    https://github.com/me/mylib.git#v1.2  # specific tag\n    https://github.com/me/mylib.git#develop # specific branch\n    \n    # Local library\n    symlink:///path/to/local/lib\n    \n    # From ZIP\n    https://example.com/lib-1.0.zip\n\nlib_extra_dirs =\n    ../shared_libs    # additional search paths\n```\nCommands:\n- `pio lib install \"ArduinoJson\"` — install interactively\n- `pio lib update` — update all libs\n- `pio lib list` — show installed libs\n- `pio pkg update` — update platforms and tools too\n\nLock file: `pio pkg lock` creates `package-lock.json` for reproducible builds."),
        ("set up unit testing with PlatformIO",
         "PlatformIO Unity testing:\n```\nproject/\n├── lib/\n│   └── mylib/\n│       ├── mylib.h\n│       └── mylib.cpp\n├── test/\n│   ├── test_native/        # runs on host PC\n│   │   └── test_math.cpp\n│   └── test_embedded/      # runs on target board\n│       └── test_gpio.cpp\n└── platformio.ini\n```\n\ntest/test_native/test_math.cpp:\n```c\n#include <unity.h>\n#include \"mylib.h\"\n\nvoid test_add(void) {\n    TEST_ASSERT_EQUAL(5, add(2, 3));\n}\n\nvoid test_multiply(void) {\n    TEST_ASSERT_EQUAL(6, multiply(2, 3));\n}\n\nint main(int argc, char **argv) {\n    UNITY_BEGIN();\n    RUN_TEST(test_add);\n    RUN_TEST(test_multiply);\n    return UNITY_END();\n}\n```\n\nRun: `pio test -e native` (host), `pio test -e blackpill` (on-target via serial). Add `test_filter = test_native` in env to limit test scope."),
        ("configure continuous integration with PlatformIO",
         "GitHub Actions workflow:\n```yaml\nname: PlatformIO CI\non: [push, pull_request]\n\njobs:\n  build:\n    runs-on: ubuntu-latest\n    strategy:\n      matrix:\n        env: [blackpill, esp32dev, native]\n    steps:\n      - uses: actions/checkout@v4\n      - uses: actions/setup-python@v5\n        with:\n          python-version: '3.11'\n      - name: Install PlatformIO\n        run: pip install platformio\n      - name: Build\n        run: pio run -e ${{ matrix.env }}\n      - name: Test\n        if: matrix.env == 'native'\n        run: pio test -e native\n      - name: Check\n        run: pio check -e ${{ matrix.env }} --fail-on-defect=high\n```\n`pio check` runs cppcheck + clangtidy static analysis. Add `check_tool = cppcheck, clangtidy` in platformio.ini. Cache `~/.platformio` for faster CI."),
        ("debug firmware with PlatformIO and GDB",
         "Debug configuration:\n```ini\n[env:blackpill]\nplatform = ststm32\nboard = blackpill_f411ce\nframework = arduino\ndebug_tool = stlink\ndebug_build_flags = -O0 -g3 -ggdb3  # no optimization for debug\ndebug_init_break = tbreak main       # break at main()\ndebug_extra_cmds =\n    set print pretty on\n    set pagination off\n```\n\nVSCode: Click the bug icon or press F5. Set breakpoints by clicking gutter.\n\nCLI:\n```bash\npio debug -e blackpill          # launch GDB\n(gdb) break main.cpp:42         # set breakpoint\n(gdb) continue                  # run to breakpoint\n(gdb) print variable_name       # inspect variable\n(gdb) info registers            # show CPU registers\n(gdb) x/16xw 0x20000000        # examine memory (SRAM)\n(gdb) monitor reset halt        # reset target\n```\n\nFor live variable watch: use PlatformIO debug console or Cortex Debug extension in VSCode. SWO/ITM trace for printf without UART: add `debug_extra_cmds = monitor tpiu config internal itm.log uart off 168000000`."),
    ]
    for q, a in topics:
        pairs.append({"user": q, "assistant": a})

    # --- Parametric: build flags ---
    optimizations = [
        ("-O0", "no optimization", "debugging — full symbol info, variables not optimized away"),
        ("-O1", "basic optimization", "balanced — good for debugging with some optimization"),
        ("-O2", "full optimization", "release builds — best speed without aggressive size changes"),
        ("-Os", "size optimization", "flash-constrained devices — minimizes code size"),
        ("-O3", "aggressive optimization", "maximum speed — may increase code size, use with caution"),
        ("-Og", "debug optimization", "debugging — optimizes without interfering with debug info"),
    ]
    for flag, name, use in optimizations:
        for framework in ["arduino", "stm32cube", "espidf"]:
            pairs.append({
                "user": f"When should I use `{flag}` ({name}) with PlatformIO and {framework} framework?",
                "assistant": f"`{flag}` ({name}) with {framework}:\n\n"
                f"Use for: {use}\n\n"
                f"In platformio.ini:\n```ini\nbuild_flags = {flag}\n```\n"
                f"{'Note: arduino framework defaults to -Os. Override with build_unflags = -Os and build_flags = ' + flag if framework == 'arduino' else 'Note: stm32cube defaults to -O0 in debug, -Os in release. Use build_type = release for optimized builds.' if framework == 'stm32cube' else 'Note: espidf uses -Og by default. Component-level flags in CMakeLists.txt override global settings.'}\n\n"
                f"Flash usage impact: {'minimal' if flag in ('-O0','-Og') else 'reduced by 10-30%' if flag == '-Os' else 'may increase 5-15%' if flag == '-O3' else 'moderate'}. "
                f"Debug experience: {'excellent — all variables visible' if flag in ('-O0','-Og') else 'good — most variables visible' if flag == '-O1' else 'degraded — variables may be optimized away, use volatile for critical debug variables'}.",
            })

    # --- Parametric: board + framework + library combos ---
    boards = [("esp32dev", "espressif32"), ("blackpill_f411ce", "ststm32"), ("nrf52840_dk", "nordicnrf52"), ("teensy41", "teensy"), ("nucleo_f446re", "ststm32")]
    libs = ["ArduinoJson", "PubSubClient (MQTT)", "Adafruit_NeoPixel", "TFT_eSPI", "FreeRTOS"]
    for board, platform in boards:
        for lib in libs:
            pairs.append({
                "user": f"How do I use {lib} library with PlatformIO on {board}?",
                "assistant": f"Using {lib} on {board} ({platform}):\n\n"
                f"```ini\n[env:{board}]\nplatform = {platform}\nboard = {board}\nframework = arduino\n"
                f"lib_deps =\n"
                f"{'    bblanchon/ArduinoJson @ ^7.0.0' if 'ArduinoJson' in lib else '    knolleary/PubSubClient @ ^2.8' if 'PubSubClient' in lib else '    adafruit/Adafruit NeoPixel @ ^1.12.0' if 'NeoPixel' in lib else '    bodmer/TFT_eSPI @ ^2.5.0' if 'TFT' in lib else '    '}\n"
                f"```\n\n"
                f"{'ArduinoJson works on all platforms. Use StaticJsonDocument for embedded (stack allocation, no fragmentation). DynamicJsonDocument for large payloads on ESP32 (more heap available).' if 'ArduinoJson' in lib else ''}"
                f"{'PubSubClient requires WiFi/Ethernet. ' + ('ESP32 has built-in WiFi — include <WiFi.h>.' if 'esp32' in board else 'STM32 needs external WiFi module (ESP-AT) or Ethernet (W5500).' if 'stm32' in platform else 'nRF52840 needs external WiFi or use BLE-to-MQTT gateway.' if 'nrf' in board else 'Teensy 4.1 has Ethernet jack — use QNEthernet library.' if 'teensy' in board else 'Requires network connectivity module.') if 'PubSubClient' in lib else ''}"
                f"{'NeoPixel: Connect data pin to any GPIO. ' + ('ESP32: use RMT peripheral (automatic via library). Any GPIO works.' if 'esp32' in board else 'STM32: uses DMA+timer for precise timing. Check pin compatibility with timer DMA.' if 'stm32' in platform else 'nRF52: uses PWM+DMA. Specify pin in constructor.' if 'nrf' in board else 'Teensy: uses DMA, very reliable. Multiple strips supported.') if 'NeoPixel' in lib else ''}"
                f"{'TFT_eSPI: Configure display in User_Setup.h (copy to lib/TFT_eSPI/). Set TFT_CS, TFT_DC, TFT_RST pins and display type (ILI9341, ST7789, etc.). ' + ('ESP32: SPI at 40-80MHz, DMA enabled by default.' if 'esp32' in board else 'STM32: SPI at up to 42MHz. Enable DMA for smooth rendering.' if 'stm32' in platform else 'May require porting — check library compatibility.') if 'TFT' in lib else ''}"
                f"{'FreeRTOS: ' + ('ESP-IDF includes FreeRTOS natively. Use xTaskCreate() directly.' if 'esp32' in board else 'Use stm32duino/STM32duino FreeRTOS library.' if 'stm32' in platform else 'nRF52 SoftDevice includes FreeRTOS-compatible scheduler.' if 'nrf' in board else 'Add FreeRTOS library from PlatformIO registry.') if 'FreeRTOS' in lib else ''}",
            })

    return pairs


# ---------------------------------------------------------------------------
# Domain registry
# ---------------------------------------------------------------------------

DOMAIN_GENERATORS = {
    "kicad": _kicad_templates,
    "spice": _spice_templates,
    "freecad": _freecad_templates,
    "stm32": _stm32_templates,
    "embedded": _embedded_templates,
    "iot": _iot_templates,
    "emc": _emc_templates,
    "dsp": _dsp_templates,
    "power": _power_templates,
    "platformio": _platformio_templates,
}


# ---------------------------------------------------------------------------
# Conversion to ChatML JSONL
# ---------------------------------------------------------------------------

def pairs_to_chatml(pairs: list[dict]) -> list[dict]:
    """Convert Q&A pairs to ChatML message format."""
    results = []
    for pair in pairs:
        results.append({
            "messages": [
                {"role": "user", "content": pair["user"]},
                {"role": "assistant", "content": pair["assistant"]},
            ]
        })
    return results


def write_jsonl(records: list[dict], output_path: str) -> int:
    """Write records as JSONL. Returns number of records written."""
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        for record in records:
            f.write(json.dumps(record, ensure_ascii=False) + "\n")
    return len(records)


# ---------------------------------------------------------------------------
# Validation (lightweight — full validation in validate_dataset.py)
# ---------------------------------------------------------------------------

def validate_jsonl(filepath: str) -> dict:
    """Quick validation of a JSONL file for Mistral fine-tuning format."""
    errors = []
    warnings = []
    line_count = 0
    total_estimated_tokens = 0

    if not os.path.exists(filepath):
        return {"valid": False, "errors": [f"File not found: {filepath}"], "warnings": [], "lines": 0, "estimated_tokens": 0}

    with open(filepath, "r", encoding="utf-8") as f:
        for i, line in enumerate(f, 1):
            line_count += 1
            line = line.strip()
            if not line:
                continue

            # Valid JSON
            try:
                obj = json.loads(line)
            except json.JSONDecodeError as e:
                errors.append(f"Line {i}: Invalid JSON — {e}")
                continue

            # messages array
            if "messages" not in obj:
                errors.append(f"Line {i}: Missing 'messages' key")
                continue
            msgs = obj["messages"]
            if not isinstance(msgs, list) or len(msgs) < 2:
                errors.append(f"Line {i}: 'messages' must be a list with at least 2 entries")
                continue

            # Role alternation
            expected_roles = ["user", "assistant"]
            for j, msg in enumerate(msgs):
                if "role" not in msg or "content" not in msg:
                    errors.append(f"Line {i}, message {j}: Missing 'role' or 'content'")
                    continue
                if msg["role"] == "system" and j == 0:
                    continue  # system prompt allowed as first message
                expected = expected_roles[(j if msgs[0].get("role") != "system" else j - 1) % 2]
                if msg["role"] != expected:
                    warnings.append(f"Line {i}, message {j}: Expected role '{expected}', got '{msg['role']}'")

                # Token estimate (~4 chars per token)
                total_estimated_tokens += len(msg["content"]) // 4

    return {
        "valid": len(errors) == 0,
        "errors": errors,
        "warnings": warnings,
        "lines": line_count,
        "estimated_tokens": total_estimated_tokens,
    }


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Build synthetic training datasets for Mistral fine-tuning (Plans 23 & 24)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 build_datasets.py --domain kicad --output datasets/kicad/train.jsonl
  python3 build_datasets.py --all --output-dir datasets/
  python3 build_datasets.py --validate datasets/kicad/train.jsonl
  python3 build_datasets.py --list-domains
        """,
    )
    parser.add_argument("--domain", choices=DOMAINS, help="Generate dataset for a single domain")
    parser.add_argument("--output", "-o", help="Output JSONL file path (with --domain)")
    parser.add_argument("--all", action="store_true", help="Generate datasets for all 10 domains")
    parser.add_argument("--output-dir", default="datasets", help="Output directory (with --all)")
    parser.add_argument("--validate", metavar="FILE", help="Validate a JSONL file for Mistral format")
    parser.add_argument("--list-domains", action="store_true", help="List available domains")
    parser.add_argument("--seed", type=int, default=42, help="Random seed for reproducibility")

    args = parser.parse_args()
    random.seed(args.seed)

    # --- List domains ---
    if args.list_domains:
        print("Available domains:")
        for d in DOMAINS:
            gen = DOMAIN_GENERATORS[d]
            count = len(gen())
            print(f"  {d:15s} — {count} examples")
        return

    # --- Validate ---
    if args.validate:
        result = validate_jsonl(args.validate)
        print(f"File: {args.validate}")
        print(f"Lines: {result['lines']}")
        print(f"Estimated tokens: {result['estimated_tokens']:,}")
        print(f"Valid: {'YES' if result['valid'] else 'NO'}")
        if result["errors"]:
            print(f"\nErrors ({len(result['errors'])}):")
            for e in result["errors"][:20]:
                print(f"  {e}")
        if result["warnings"]:
            print(f"\nWarnings ({len(result['warnings'])}):")
            for w in result["warnings"][:20]:
                print(f"  {w}")
        sys.exit(0 if result["valid"] else 1)

    # --- Generate single domain ---
    if args.domain:
        output = args.output or f"datasets/{args.domain}/train.jsonl"
        gen = DOMAIN_GENERATORS[args.domain]
        pairs = gen()
        records = pairs_to_chatml(pairs)
        count = write_jsonl(records, output)
        print(f"[{args.domain}] Generated {count} examples -> {output}")
        return

    # --- Generate all ---
    if args.all:
        total = 0
        for domain in DOMAINS:
            output = os.path.join(args.output_dir, domain, "train.jsonl")
            gen = DOMAIN_GENERATORS[domain]
            pairs = gen()
            records = pairs_to_chatml(pairs)
            count = write_jsonl(records, output)
            total += count
            print(f"[{domain:15s}] {count:4d} examples -> {output}")
        print(f"\nTotal: {total} examples across {len(DOMAINS)} domains")
        return

    parser.print_help()


if __name__ == "__main__":
    main()
