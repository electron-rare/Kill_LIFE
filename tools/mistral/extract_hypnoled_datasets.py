#!/usr/bin/env python3
"""
Extract Hypnoled KiCad schematics and SPICE simulations into ChatML JSONL
datasets for Mistral fine-tuning.

Parses .kicad_sch files (s-expression format) from a local clone of
https://github.com/electron-rare/hypnoled and generates Q&A pairs about
the Hypnoled project's hardware design.

Outputs:
  tools/mistral/datasets/hypnoled_kicad/train.jsonl  — KiCad Q&A pairs
  tools/mistral/datasets/hypnoled_spice/train.jsonl  — SPICE Q&A pairs (if .asc files exist)

Usage:
  python tools/mistral/extract_hypnoled_datasets.py [--clone-dir /tmp/hypnoled-datasets]
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Tuple


# ---------------------------------------------------------------------------
# KiCad S-Expression parser (minimal, tailored for .kicad_sch)
# ---------------------------------------------------------------------------

@dataclass
class Component:
    reference: str = ""
    value: str = ""
    footprint: str = ""
    datasheet: str = ""
    manufacturer: str = ""
    description: str = ""
    lib_id: str = ""
    pins: List[str] = field(default_factory=list)
    nets: List[str] = field(default_factory=list)
    properties: Dict[str, str] = field(default_factory=dict)


@dataclass
class SchematicSheet:
    filename: str = ""
    title: str = ""
    revision: str = ""
    company: str = ""
    components: List[Component] = field(default_factory=list)
    wires: int = 0
    labels: List[str] = field(default_factory=list)
    power_symbols: List[str] = field(default_factory=list)
    hierarchical_labels: List[str] = field(default_factory=list)


def _tokenize_sexpr(text: str):
    """Tokenize a KiCad s-expression into a nested list structure."""
    tokens = []
    stack = [tokens]
    i = 0
    n = len(text)
    while i < n:
        c = text[i]
        if c == '(':
            new_list = []
            stack[-1].append(new_list)
            stack.append(new_list)
            i += 1
        elif c == ')':
            if len(stack) > 1:
                stack.pop()
            i += 1
        elif c == '"':
            # Quoted string
            j = i + 1
            while j < n and text[j] != '"':
                if text[j] == '\\':
                    j += 1
                j += 1
            stack[-1].append(text[i + 1:j])
            i = j + 1
        elif c in (' ', '\t', '\n', '\r'):
            i += 1
        else:
            j = i
            while j < n and text[j] not in ('(', ')', ' ', '\t', '\n', '\r', '"'):
                j += 1
            stack[-1].append(text[i:j])
            i = j
    return tokens


def _find_nodes(tree, tag: str) -> list:
    """Recursively find all nodes with a given tag in the s-expression tree."""
    results = []
    if isinstance(tree, list):
        if len(tree) > 0 and tree[0] == tag:
            results.append(tree)
        for child in tree:
            results.extend(_find_nodes(child, tag))
    return results


def _get_property(node: list, key: str) -> str:
    """Extract a property value from a symbol node."""
    for child in node:
        if isinstance(child, list) and len(child) >= 3:
            if child[0] == "property" and child[1] == key:
                return child[2]
    return ""


def parse_kicad_sch(filepath: Path) -> SchematicSheet:
    """Parse a .kicad_sch file and extract component/connection information."""
    text = filepath.read_text(encoding="utf-8", errors="replace")
    tree = _tokenize_sexpr(text)

    sheet = SchematicSheet(filename=filepath.name)

    # Title block
    for tb in _find_nodes(tree, "title_block"):
        for child in tb:
            if isinstance(child, list) and len(child) >= 2:
                if child[0] == "title":
                    sheet.title = child[1]
                elif child[0] == "rev":
                    sheet.revision = child[1]
                elif child[0] == "company":
                    sheet.company = child[1]

    # Symbols (components)
    for sym_node in _find_nodes(tree, "symbol"):
        # Skip lib_symbols definitions (they are inside a lib_symbols node)
        # We want instance symbols which have a "lib_id" property
        lib_id = ""
        for child in sym_node:
            if isinstance(child, list) and len(child) >= 2 and child[0] == "lib_id":
                lib_id = child[1]
                break
        if not lib_id:
            continue

        comp = Component(lib_id=lib_id)
        comp.reference = _get_property(sym_node, "Reference")
        comp.value = _get_property(sym_node, "Value")
        comp.footprint = _get_property(sym_node, "Footprint")
        comp.datasheet = _get_property(sym_node, "Datasheet")
        comp.manufacturer = _get_property(sym_node, "MANUFACTURER")
        comp.description = _get_property(sym_node, "Description")

        # Collect all custom properties
        for child in sym_node:
            if isinstance(child, list) and len(child) >= 3 and child[0] == "property":
                comp.properties[child[1]] = child[2]

        # Pin connections
        for pin_node in _find_nodes(sym_node, "pin"):
            if len(pin_node) >= 2:
                comp.pins.append(pin_node[1] if isinstance(pin_node[1], str) else str(pin_node[1]))

        sheet.components.append(comp)

    # Wires
    sheet.wires = len(_find_nodes(tree, "wire"))

    # Labels (net names)
    for label_node in _find_nodes(tree, "label"):
        if len(label_node) >= 2 and isinstance(label_node[1], str):
            sheet.labels.append(label_node[1])

    # Global labels
    for gl_node in _find_nodes(tree, "global_label"):
        if len(gl_node) >= 2 and isinstance(gl_node[1], str):
            sheet.labels.append(gl_node[1])

    # Hierarchical labels
    for hl_node in _find_nodes(tree, "hierarchical_label"):
        if len(hl_node) >= 2 and isinstance(hl_node[1], str):
            sheet.hierarchical_labels.append(hl_node[1])

    # Power symbols (components whose lib_id starts with "power:")
    for comp in sheet.components:
        if comp.lib_id.startswith("power:") or comp.value in (
            "GND", "VCC", "VDD", "+3V3", "+5V", "+12V", "+3.3V", "VBUS",
        ):
            sheet.power_symbols.append(comp.value)

    return sheet


# ---------------------------------------------------------------------------
# SPICE / LTspice .asc parser
# ---------------------------------------------------------------------------

@dataclass
class SpiceCircuit:
    filename: str = ""
    components: List[Dict[str, str]] = field(default_factory=list)
    nets: List[str] = field(default_factory=list)
    directives: List[str] = field(default_factory=list)


def parse_ltspice_asc(filepath: Path) -> Optional[SpiceCircuit]:
    """Parse a LTspice .asc file and extract components and directives."""
    try:
        text = filepath.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return None

    circuit = SpiceCircuit(filename=filepath.name)

    current_symbol = None
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("SYMBOL"):
            parts = line.split()
            current_symbol = {"type": parts[1] if len(parts) > 1 else "unknown"}
        elif line.startswith("SYMATTR") and current_symbol is not None:
            parts = line.split(None, 2)
            if len(parts) >= 3:
                current_symbol[parts[1]] = parts[2]
            if parts[1] == "Value":
                circuit.components.append(current_symbol)
                current_symbol = None
        elif line.startswith("WIRE"):
            pass  # wire count
        elif line.startswith("TEXT") and ".tran" in line.lower():
            circuit.directives.append(line)
        elif line.startswith("TEXT") and any(d in line.lower() for d in [".ac", ".dc", ".param", ".model", ".include"]):
            circuit.directives.append(line)

    return circuit if circuit.components else None


# ---------------------------------------------------------------------------
# ChatML JSONL generation
# ---------------------------------------------------------------------------

def _msg(role: str, content: str) -> dict:
    return {"role": role, "content": content.strip()}


def _qa(question: str, answer: str) -> dict:
    return {"messages": [_msg("user", question), _msg("assistant", answer)]}


def generate_kicad_qa_pairs(sheets: List[SchematicSheet]) -> List[dict]:
    """Generate ChatML Q&A pairs from parsed KiCad schematics."""
    pairs = []

    # Build cross-sheet data structures
    all_components: Dict[str, List[Component]] = {}  # sheet_name -> components
    all_labels: Dict[str, List[str]] = {}
    component_by_ref: Dict[str, Tuple[Component, str]] = {}

    for sheet in sheets:
        sheet_name = sheet.filename.replace(".kicad_sch", "")
        all_components[sheet_name] = sheet.components
        all_labels[sheet_name] = sheet.labels
        for comp in sheet.components:
            if comp.reference:
                component_by_ref[comp.reference] = (comp, sheet_name)

    # --- Per-sheet component listing ---
    for sheet in sheets:
        sheet_name = sheet.filename.replace(".kicad_sch", "")
        if not sheet.components:
            continue

        # Filter out power symbols for component questions
        real_components = [c for c in sheet.components if not c.lib_id.startswith("power:")]
        if not real_components:
            continue

        comp_list = "\n".join(
            f"- {c.reference}: {c.value} ({c.footprint})"
            for c in real_components if c.reference
        )

        pairs.append(_qa(
            f"What components are used in the Hypnoled {sheet_name} circuit?",
            f"The Hypnoled {sheet_name} sub-schematic contains the following components:\n\n{comp_list}\n\n"
            f"Total: {len(real_components)} components in {sheet_name}.kicad_sch."
        ))

        # Component count question
        pairs.append(_qa(
            f"How many components are in the Hypnoled {sheet_name} schematic?",
            f"The {sheet_name} sub-schematic contains {len(real_components)} active components "
            f"and {len(sheet.power_symbols)} power symbols, "
            f"with {sheet.wires} wire connections."
        ))

    # --- DALI-specific questions ---
    dali_comps = all_components.get("DALI", [])
    if dali_comps:
        dali_real = [c for c in dali_comps if not c.lib_id.startswith("power:")]
        comp_summary = ", ".join(f"{c.reference} ({c.value})" for c in dali_real if c.reference)
        pairs.append(_qa(
            "What components are used in the DALI bus interface circuit of Hypnoled?",
            f"The DALI bus interface circuit uses these components: {comp_summary}.\n\n"
            "Key elements include:\n"
            "- 1SMA4746 Zener diode for voltage protection\n"
            "- BSS123 N-MOSFET for DALI bus TX signaling\n"
            "- EL357N optocoupler for galvanic isolation on RX\n"
            "- MB10S bridge rectifier for DALI 16V bus rectification\n"
            "- STN1HNK60 high-voltage MOSFET (600V) for DALI driver\n"
            "- Resistor dividers for bus voltage sensing"
        ))

        pairs.append(_qa(
            "How does the Hypnoled DALI transmitter work?",
            "The Hypnoled DALI TX uses Manchester encoding through an N-MOSFET (BSS123) "
            "that modulates the DALI bus voltage. The ESP32 GPIO drives the MOSFET gate "
            "to pull the bus low (logical 1) or release it high (logical 0). "
            "A high-voltage MOSFET (STN1HNK60, 600V rated) provides the bus driver stage. "
            "The bus is protected by a 1SMA4746 Zener diode for overvoltage transients."
        ))

        pairs.append(_qa(
            "How does the Hypnoled DALI receiver work?",
            "The DALI RX circuit uses an EL357N optocoupler for galvanic isolation between "
            "the DALI bus (up to 22.5V) and the ESP32 3.3V logic. A resistor divider feeds "
            "the bus voltage to the optocoupler LED side. The phototransistor output connects "
            "to an ESP32 GPIO configured as an interrupt input for Manchester decoding. "
            "BC857 PNP transistor and STN93003 provide signal conditioning."
        ))

    # --- ESP32 questions ---
    esp32_comps = all_components.get("esp32", [])
    if esp32_comps:
        esp32_real = [c for c in esp32_comps if not c.lib_id.startswith("power:")]
        comp_list = "\n".join(f"- {c.reference}: {c.value}" for c in esp32_real if c.reference)
        pairs.append(_qa(
            "How is the ESP32 connected in the Hypnoled project?",
            f"The ESP32 sub-schematic in Hypnoled contains:\n\n{comp_list}\n\n"
            "The ESP32 serves as the main MCU, handling:\n"
            "- DALI bus communication (TX via GPIO + MOSFET, RX via optocoupler ISR)\n"
            "- I2C bus for UI (MPR121 touch sensor) and audio (PCM5122 DAC)\n"
            "- WiFi connectivity for MQTT remote control\n"
            "- UART for debug and programming\n"
            "- USB-C for power and data"
        ))

        pairs.append(_qa(
            "What peripherals does the Hypnoled ESP32 drive?",
            "The ESP32 in Hypnoled drives several peripherals:\n"
            "1. DALI bus interface (GPIO for TX Manchester encoding, interrupt for RX)\n"
            "2. I2C bus shared between MPR121 touch controller (UI) and PCM5122 audio DAC\n"
            "3. LED strip output through audio2led reactive driver (IRF3415 MOSFET)\n"
            "4. WiFi for MQTT-based remote control\n"
            "5. USB-C interface for programming and power delivery"
        ))

    # --- Power supply questions ---
    power_comps = all_components.get("MCP_power", [])
    if power_comps:
        power_real = [c for c in power_comps if not c.lib_id.startswith("power:")]
        comp_list = "\n".join(f"- {c.reference}: {c.value}" for c in power_real if c.reference)
        pairs.append(_qa(
            "What is the power supply architecture of the Hypnoled project?",
            f"The MCP_power sub-schematic handles power distribution:\n\n{comp_list}\n\n"
            "The power architecture provides multiple voltage rails:\n"
            "- Main input from DALI bus (rectified via MB10S bridge)\n"
            "- 3.3V rail for ESP32 and digital logic\n"
            "- 5V rail for USB and LED driver\n"
            "- Analog supply for audio DAC (PCM5122)\n\n"
            "Note: Forge review identified the power chain as potentially incoherent — "
            "verify the cascade regulation stages match the load requirements."
        ))

        pairs.append(_qa(
            "What voltage regulators are used in Hypnoled's power supply?",
            f"The MCP_power schematic includes these power components:\n\n{comp_list}\n\n"
            "The power supply converts the DALI bus voltage (16V typical) down to "
            "the required logic and analog levels through a multi-stage regulation chain."
        ))

    # --- Audio questions ---
    audio_comps = all_components.get("audio", [])
    if audio_comps:
        audio_real = [c for c in audio_comps if not c.lib_id.startswith("power:")]
        comp_list = "\n".join(f"- {c.reference}: {c.value}" for c in audio_real if c.reference)
        pairs.append(_qa(
            "What audio components are in the Hypnoled project?",
            f"The audio sub-schematic contains:\n\n{comp_list}\n\n"
            "The audio path uses a PCM5122 DAC connected to the ESP32 via I2C for control "
            "and I2S for audio data. The DAC output feeds an amplifier stage for the "
            "hypnotherapy audio output. Forge review flagged the PCM5122 power supply as "
            "a critical point to verify."
        ))

    # --- Audio2LED questions ---
    a2l_comps = all_components.get("audio2led", [])
    if a2l_comps:
        a2l_real = [c for c in a2l_comps if not c.lib_id.startswith("power:")]
        comp_list = "\n".join(f"- {c.reference}: {c.value}" for c in a2l_real if c.reference)
        pairs.append(_qa(
            "How does the Hypnoled audio-reactive LED driver work?",
            f"The audio2led sub-schematic contains:\n\n{comp_list}\n\n"
            "The audio2led circuit converts audio signals into LED brightness modulation. "
            "An IRF3415 MOSFET drives the LED strip based on audio amplitude. "
            "Forge review noted the IRF3415 may be over-dimensioned for the application — "
            "consider a logic-level MOSFET if the gate drive voltage is limited to 3.3V."
        ))

    # --- UI questions ---
    ui_comps = all_components.get("UI", [])
    if ui_comps:
        ui_real = [c for c in ui_comps if not c.lib_id.startswith("power:")]
        comp_list = "\n".join(f"- {c.reference}: {c.value}" for c in ui_real if c.reference)
        pairs.append(_qa(
            "What user interface components does Hypnoled use?",
            f"The UI sub-schematic contains:\n\n{comp_list}\n\n"
            "The UI is based on an MPR121 capacitive touch sensor connected via I2C. "
            "This provides up to 12 touch-sensitive electrodes for user interaction "
            "(mode selection, brightness, audio volume). Forge review flagged that "
            "the MPR121 I2C address must be explicitly configured to avoid bus conflicts."
        ))

    # --- Cross-schematic / architecture questions ---
    total_comps = sum(
        len([c for c in comps if not c.lib_id.startswith("power:")])
        for comps in all_components.values()
    )
    sheet_names = [s.filename.replace(".kicad_sch", "") for s in sheets if s.components]

    pairs.append(_qa(
        "What is the overall architecture of the Hypnoled PCB project?",
        f"Hypnoled is a multi-sheet KiCad design with {len(sheets)} sub-schematics:\n"
        f"{', '.join(sheet_names)}.\n\n"
        f"Total component count: {total_comps} active components.\n\n"
        "Architecture overview:\n"
        "- **DALI**: Bus interface with Manchester encoding TX/RX, optocoupler isolation\n"
        "- **esp32**: Main MCU with WiFi, I2C, UART, USB-C\n"
        "- **audio**: PCM5122 DAC for hypnotherapy audio output\n"
        "- **audio2led**: Audio-reactive LED strip driver (MOSFET-based)\n"
        "- **MCP_power**: Multi-rail power supply from DALI bus input\n"
        "- **UI**: MPR121 capacitive touch interface\n\n"
        "The project was designed by L'electron rare for client Richard Garnier."
    ))

    pairs.append(_qa(
        "What are the main design issues found in the Hypnoled hardware review?",
        "A Forge (Codestral) review of all 6 Hypnoled sub-schematics identified:\n\n"
        "**8 Critical issues:**\n"
        "1. Zener diode voltage (15V) may be insufficient for DALI bus transients\n"
        "2. Double ESP32 in schematic not justified — remove redundant instance\n"
        "3. USB-C CC resistors missing or misconfigured\n"
        "4. PCM5122 analog power supply filtering inadequate\n"
        "5. IRF3415 MOSFET over-dimensioned for 3.3V gate drive\n"
        "6. Power chain architecture incoherent (MCP_power stage cascade)\n"
        "7. MPR121 I2C address not configured (potential bus conflict)\n"
        "8. Second power regulation incoherence in MCP_power\n\n"
        "**7 Warnings** about component tolerances and thermal considerations.\n"
        "**18 Recommendations** for improved EMC, reliability, and manufacturability."
    ))

    # --- Net / label questions ---
    all_label_set = set()
    for labels in all_labels.values():
        all_label_set.update(labels)
    if all_label_set:
        label_list = ", ".join(sorted(all_label_set)[:30])
        pairs.append(_qa(
            "What are the main signal nets in the Hypnoled schematic?",
            f"The Hypnoled schematics use these signal labels across sub-sheets:\n"
            f"{label_list}\n\n"
            "These nets connect the sub-schematics through hierarchical labels, "
            "enabling the ESP32 to communicate with the DALI interface, audio DAC, "
            "LED driver, touch UI, and power management sections."
        ))

    # --- Footprint / manufacturing questions ---
    footprints = set()
    for sheet in sheets:
        for comp in sheet.components:
            if comp.footprint and not comp.lib_id.startswith("power:"):
                footprints.add(comp.footprint)
    if footprints:
        fp_list = "\n".join(f"- {fp}" for fp in sorted(footprints)[:25])
        pairs.append(_qa(
            "What PCB footprints are used in the Hypnoled design?",
            f"The Hypnoled design uses these footprints:\n\n{fp_list}\n\n"
            "The mix of SMD and through-hole footprints indicates a design that "
            "balances automated assembly (SMD) with manual soldering for connectors "
            "and power components."
        ))

    # --- General project info ---
    pairs.append(_qa(
        "What is the Hypnoled project?",
        "Hypnoled is an IoT-connected LED hypnotherapy device designed by L'electron rare "
        "for client Richard Garnier. It combines:\n"
        "- DALI bus integration for professional lighting control\n"
        "- ESP32 WiFi/BLE MCU for smart control via MQTT\n"
        "- Audio output (PCM5122 DAC) for hypnotherapy sessions\n"
        "- Audio-reactive LED effects (audio2led MOSFET driver)\n"
        "- Capacitive touch UI (MPR121)\n\n"
        "The hardware is designed in KiCad 9.0 with 6 hierarchical sub-schematics "
        "and uses a custom DALI interface with Manchester encoding."
    ))

    pairs.append(_qa(
        "What KiCad version is the Hypnoled project designed in?",
        "Hypnoled is designed in KiCad 9.0 (generator version 9.0, schema version 20250114). "
        "The project uses hierarchical schematics with 6 sub-sheets: "
        "DALI, esp32, audio, audio2led, MCP_power, and UI. "
        "The design is revision 0.1 dated 2026-02-10."
    ))

    return pairs


def generate_spice_qa_pairs(circuits: List[SpiceCircuit]) -> List[dict]:
    """Generate ChatML Q&A pairs from parsed SPICE/LTspice simulations."""
    pairs = []

    for circuit in circuits:
        name = circuit.filename.replace(".asc", "")

        comp_list = "\n".join(
            f"- {c.get('InstName', 'unknown')}: {c.get('type', '?')} = {c.get('Value', '?')}"
            for c in circuit.components
        )

        pairs.append(_qa(
            f"What components are in the Hypnoled '{name}' SPICE simulation?",
            f"The LTspice simulation '{name}' contains:\n\n{comp_list}"
        ))

        if circuit.directives:
            dir_list = "\n".join(f"- {d}" for d in circuit.directives)
            pairs.append(_qa(
                f"What simulation directives are used in the Hypnoled '{name}' circuit?",
                f"The '{name}' simulation uses these directives:\n\n{dir_list}"
            ))

        pairs.append(_qa(
            f"What does the Hypnoled '{name}' simulation model?",
            f"The '{name}' LTspice simulation models the Hypnoled LED driver circuit. "
            f"It contains {len(circuit.components)} components and is used to verify "
            "the LED driving waveforms, power dissipation, and transient behavior "
            "before PCB fabrication."
        ))

    # General SPICE question if we have any circuits
    if circuits:
        pairs.append(_qa(
            "What simulations exist for the Hypnoled project?",
            f"The Hypnoled project includes {len(circuits)} LTspice simulation(s):\n"
            + "\n".join(f"- {c.filename}: {len(c.components)} components" for c in circuits)
            + "\n\nThese simulations validate the LED driver circuit design before PCB fabrication."
        ))

    return pairs


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Extract Hypnoled datasets for Mistral fine-tuning")
    parser.add_argument(
        "--clone-dir",
        type=Path,
        default=Path("/tmp/hypnoled-datasets"),
        help="Path to local clone of electron-rare/hypnoled",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=None,
        help="Output base directory (default: auto-detect tools/mistral/datasets/)",
    )
    args = parser.parse_args()

    clone_dir = args.clone_dir
    if not clone_dir.exists():
        print(f"ERROR: Clone directory not found: {clone_dir}", file=sys.stderr)
        print("Run: git clone https://github.com/electron-rare/hypnoled.git /tmp/hypnoled-datasets", file=sys.stderr)
        sys.exit(1)

    # Auto-detect output dir relative to this script
    if args.output_dir:
        output_base = args.output_dir
    else:
        script_dir = Path(__file__).resolve().parent
        output_base = script_dir / "datasets"

    kicad_out = output_base / "hypnoled_kicad"
    spice_out = output_base / "hypnoled_spice"

    # --- Parse KiCad schematics ---
    pcb_dir = clone_dir / "hardware" / "pcb"
    kicad_files = sorted(pcb_dir.glob("*.kicad_sch")) if pcb_dir.exists() else []

    if not kicad_files:
        print(f"WARNING: No .kicad_sch files found in {pcb_dir}", file=sys.stderr)
    else:
        print(f"Found {len(kicad_files)} KiCad schematics:")
        for f in kicad_files:
            print(f"  - {f.name}")

    sheets = []
    for kf in kicad_files:
        try:
            sheet = parse_kicad_sch(kf)
            sheets.append(sheet)
            print(f"  Parsed {kf.name}: {len(sheet.components)} components, "
                  f"{sheet.wires} wires, {len(sheet.labels)} labels")
        except Exception as e:
            print(f"  ERROR parsing {kf.name}: {e}", file=sys.stderr)

    # Generate KiCad Q&A
    kicad_pairs = generate_kicad_qa_pairs(sheets)
    kicad_out.mkdir(parents=True, exist_ok=True)
    kicad_jsonl = kicad_out / "train.jsonl"
    with open(kicad_jsonl, "w", encoding="utf-8") as f:
        for pair in kicad_pairs:
            f.write(json.dumps(pair, ensure_ascii=False) + "\n")
    print(f"\nKiCad dataset: {len(kicad_pairs)} Q&A pairs -> {kicad_jsonl}")

    # --- Parse SPICE simulations ---
    sim_dir = clone_dir / "hardware" / "simulation"
    asc_files = sorted(sim_dir.glob("*.asc")) if sim_dir.exists() else []

    # Also check for .spice / .cir files
    for ext in ("*.spice", "*.cir"):
        if sim_dir.exists():
            asc_files.extend(sorted(sim_dir.glob(ext)))

    circuits = []
    if asc_files:
        print(f"\nFound {len(asc_files)} SPICE simulation files:")
        for af in asc_files:
            print(f"  - {af.name}")
            circuit = parse_ltspice_asc(af)
            if circuit:
                circuits.append(circuit)
                print(f"    Parsed: {len(circuit.components)} components, "
                      f"{len(circuit.directives)} directives")
    else:
        print("\nNo SPICE simulation files found (no .asc/.spice/.cir in hardware/simulation/).")

    # Generate SPICE Q&A (even if empty, create the file)
    spice_pairs = generate_spice_qa_pairs(circuits)
    spice_out.mkdir(parents=True, exist_ok=True)
    spice_jsonl = spice_out / "train.jsonl"
    if spice_pairs:
        with open(spice_jsonl, "w", encoding="utf-8") as f:
            for pair in spice_pairs:
                f.write(json.dumps(pair, ensure_ascii=False) + "\n")
        print(f"SPICE dataset: {len(spice_pairs)} Q&A pairs -> {spice_jsonl}")
    else:
        # Write empty file with a note
        with open(spice_jsonl, "w", encoding="utf-8") as f:
            f.write("")  # Empty — no SPICE files found in clone
        print(f"SPICE dataset: 0 Q&A pairs (no simulation files found) -> {spice_jsonl}")

    # --- Summary ---
    print(f"\n{'='*60}")
    print(f"SUMMARY")
    print(f"{'='*60}")
    print(f"  KiCad schematics parsed : {len(sheets)}")
    print(f"  KiCad Q&A pairs        : {len(kicad_pairs)}")
    print(f"  SPICE simulations parsed: {len(circuits)}")
    print(f"  SPICE Q&A pairs         : {len(spice_pairs)}")
    print(f"  Total training examples  : {len(kicad_pairs) + len(spice_pairs)}")
    print(f"{'='*60}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
