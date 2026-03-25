#!/usr/bin/env python3
"""
bom_analyzer.py — Generic BOM parser, normalizer, and alternative suggester.

Reads CSV BOMs (KiCad, Altium, generic), normalizes columns, deduplicates,
and suggests LCSC/JLCPCB alternatives with assembly category classification.

Usage:
    python3 bom_analyzer.py parse  input.csv [--output normalized.csv]
    python3 bom_analyzer.py suggest input.csv [--output suggestions.csv]
    python3 bom_analyzer.py report  input.csv [--output report.md]
    python3 bom_analyzer.py batch   dir/      [--output report.md]

Part of Kill_LIFE tools/industrial — usable standalone for any project.
"""

import argparse
import csv
import hashlib
import json
import os
import re
import sys
from collections import defaultdict
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Optional


# ---------------------------------------------------------------------------
# Column name normalization map
# Covers KiCad, Altium, Eagle, generic EDA exports
# ---------------------------------------------------------------------------
COLUMN_ALIASES = {
    # Reference designator
    "reference": "reference",
    "ref": "reference",
    "designator": "reference",
    "ref des": "reference",
    "refdes": "reference",
    # Value
    "value": "value",
    "val": "value",
    "comment": "value",
    # Footprint
    "footprint": "footprint",
    "package": "footprint",
    "case": "footprint",
    "case/package": "footprint",
    "fp": "footprint",
    # Quantity
    "quantity": "quantity",
    "qty": "quantity",
    "count": "quantity",
    "qte": "quantity",
    # MPN (manufacturer part number)
    "mpn": "mpn",
    "manufacturer part number": "mpn",
    "mfr part": "mpn",
    "mfr. part": "mpn",
    "part number": "mpn",
    "manufacturer_part": "mpn",
    "mfg part": "mpn",
    # Manufacturer
    "manufacturer": "manufacturer",
    "mfr": "manufacturer",
    "mfg": "manufacturer",
    "mfr.": "manufacturer",
    # Description
    "description": "description",
    "desc": "description",
    "part description": "description",
    # Supplier references
    "lcsc": "lcsc",
    "lcsc part": "lcsc",
    "lcsc part#": "lcsc",
    "lcsc#": "lcsc",
    "jlcpcb": "lcsc",  # JLCPCB uses LCSC catalog
    "jlcpcb part#": "lcsc",
    "digikey": "digikey",
    "digikey part#": "digikey",
    "mouser": "mouser",
    "mouser part#": "mouser",
}

# JLCPCB assembly categories
JLCPCB_BASIC = "basic"
JLCPCB_EXTENDED = "extended"
JLCPCB_UNAVAILABLE = "unavailable"

# Common passives that are typically JLCPCB basic parts
BASIC_PATTERNS = [
    (r"^[0-9.]+[munpf]?[FOHhf]$", "passive"),           # 10K, 100nF, 4.7uH
    (r"^[0-9.]+\s*[kKmMuUnNpP]?\s*[oOhHfF]", "passive"),
    (r"LED", "led"),
    (r"^GND$|^VCC$|^VDD$|^PWR$", "power_symbol"),
]

# Known LCSC part number patterns
LCSC_PATTERN = re.compile(r"C\d{4,8}")


@dataclass
class BomLine:
    """A single normalized BOM line (may represent multiple references)."""
    reference: str = ""
    value: str = ""
    footprint: str = ""
    quantity: int = 1
    mpn: str = ""
    manufacturer: str = ""
    description: str = ""
    lcsc: str = ""
    digikey: str = ""
    mouser: str = ""
    # Computed fields
    assembly_category: str = ""
    suggestion: str = ""
    notes: str = ""

    def fingerprint(self) -> str:
        """Dedup key: value + footprint + mpn."""
        raw = f"{self.value.strip().lower()}|{self.footprint.strip().lower()}|{self.mpn.strip().lower()}"
        return hashlib.md5(raw.encode()).hexdigest()[:12]


# ---------------------------------------------------------------------------
# Parser
# ---------------------------------------------------------------------------

def detect_delimiter(filepath: str) -> str:
    """Sniff CSV delimiter."""
    with open(filepath, "r", encoding="utf-8-sig") as f:
        sample = f.read(4096)
    for delim in [",", ";", "\t"]:
        if delim in sample:
            # crude heuristic: pick the one with most occurrences in first line
            pass
    sniffer = csv.Sniffer()
    try:
        dialect = sniffer.sniff(sample, delimiters=",;\t|")
        return dialect.delimiter
    except csv.Error:
        return ","


def normalize_column_name(raw: str) -> str:
    """Map raw column header to canonical name."""
    cleaned = raw.strip().lower().replace("_", " ").replace("#", "")
    return COLUMN_ALIASES.get(cleaned, cleaned)


def parse_bom(filepath: str) -> list[BomLine]:
    """Parse a CSV BOM file into normalized BomLine list."""
    delimiter = detect_delimiter(filepath)
    lines: list[BomLine] = []

    with open(filepath, "r", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f, delimiter=delimiter)
        if reader.fieldnames is None:
            return lines

        # Build column mapping
        col_map: dict[str, str] = {}
        for raw_col in reader.fieldnames:
            canonical = normalize_column_name(raw_col)
            col_map[raw_col] = canonical

        for row in reader:
            bl = BomLine()
            for raw_col, canonical in col_map.items():
                val = (row.get(raw_col) or "").strip()
                if hasattr(bl, canonical):
                    if canonical == "quantity":
                        try:
                            bl.quantity = int(val) if val else 1
                        except ValueError:
                            # Reference list as quantity (KiCad style)
                            bl.quantity = len(val.split(",")) if val else 1
                    else:
                        setattr(bl, canonical, val)

            # If quantity is still 1 but reference has commas, count refs
            if bl.reference and "," in bl.reference:
                ref_count = len([r for r in bl.reference.split(",") if r.strip()])
                if ref_count > bl.quantity:
                    bl.quantity = ref_count

            # Skip empty lines, power symbols, mounting holes
            if not bl.value and not bl.mpn:
                continue
            if bl.value.upper() in ("GND", "VCC", "VDD", "PWR", "+3V3", "+5V", "+12V"):
                continue
            if "mounting" in bl.footprint.lower() or "fiducial" in bl.footprint.lower():
                continue

            lines.append(bl)

    return lines


def deduplicate(lines: list[BomLine]) -> list[BomLine]:
    """Merge lines with identical value+footprint+mpn, sum quantities."""
    groups: dict[str, BomLine] = {}
    for bl in lines:
        fp = bl.fingerprint()
        if fp in groups:
            existing = groups[fp]
            # Merge references
            refs = set(existing.reference.split(",")) | set(bl.reference.split(","))
            existing.reference = ",".join(sorted(r.strip() for r in refs if r.strip()))
            existing.quantity += bl.quantity
            # Prefer non-empty fields
            if not existing.mpn and bl.mpn:
                existing.mpn = bl.mpn
            if not existing.manufacturer and bl.manufacturer:
                existing.manufacturer = bl.manufacturer
            if not existing.lcsc and bl.lcsc:
                existing.lcsc = bl.lcsc
            if not existing.description and bl.description:
                existing.description = bl.description
        else:
            groups[fp] = bl
    return list(groups.values())


# ---------------------------------------------------------------------------
# LCSC / JLCPCB suggestion engine
# ---------------------------------------------------------------------------

# Known component families -> typical LCSC part numbers
# This is a static knowledge base. A real implementation would query the LCSC API.
LCSC_KNOWLEDGE_BASE = {
    # Resistors (0402, 0603, 0805)
    "10k_0402": {"lcsc": "C25744", "category": JLCPCB_BASIC, "price_1k": 0.002},
    "10k_0603": {"lcsc": "C25804", "category": JLCPCB_BASIC, "price_1k": 0.001},
    "10k_0805": {"lcsc": "C17414", "category": JLCPCB_BASIC, "price_1k": 0.001},
    "4.7k_0603": {"lcsc": "C25890", "category": JLCPCB_BASIC, "price_1k": 0.001},
    "100r_0603": {"lcsc": "C22775", "category": JLCPCB_BASIC, "price_1k": 0.001},
    "1k_0603": {"lcsc": "C21190", "category": JLCPCB_BASIC, "price_1k": 0.001},
    # Capacitors
    "100nf_0402": {"lcsc": "C1525", "category": JLCPCB_BASIC, "price_1k": 0.002},
    "100nf_0603": {"lcsc": "C14663", "category": JLCPCB_BASIC, "price_1k": 0.001},
    "100nf_0805": {"lcsc": "C49678", "category": JLCPCB_BASIC, "price_1k": 0.002},
    "10uf_0805": {"lcsc": "C15850", "category": JLCPCB_BASIC, "price_1k": 0.004},
    "1uf_0603": {"lcsc": "C15849", "category": JLCPCB_BASIC, "price_1k": 0.002},
    "4.7uf_0805": {"lcsc": "C1779", "category": JLCPCB_BASIC, "price_1k": 0.003},
    # Common ICs
    "esp32-wroom-32": {"lcsc": "C701341", "category": JLCPCB_EXTENDED, "price_1k": 2.50},
    "stm32f103c8t6": {"lcsc": "C8734", "category": JLCPCB_EXTENDED, "price_1k": 1.80},
    # Discrete
    "bss123": {"lcsc": "C82439", "category": JLCPCB_EXTENDED, "price_1k": 0.02},
    "bc857": {"lcsc": "C8586", "category": JLCPCB_BASIC, "price_1k": 0.01},
    "1n4148": {"lcsc": "C81598", "category": JLCPCB_BASIC, "price_1k": 0.005},
    # Zener
    "1sma4746": {"lcsc": "C191363", "category": JLCPCB_EXTENDED, "price_1k": 0.03},
    # Opto
    "el357n": {"lcsc": "C60693", "category": JLCPCB_EXTENDED, "price_1k": 0.05},
    # Bridge rectifier
    "mb10s": {"lcsc": "C80907", "category": JLCPCB_EXTENDED, "price_1k": 0.04},
}


def normalize_value_for_lookup(value: str, footprint: str) -> str:
    """Create a lookup key from value and footprint."""
    val = value.strip().lower()
    fp = footprint.strip().lower()

    # Extract package size from footprint (0402, 0603, 0805, etc.)
    pkg_match = re.search(r"(0201|0402|0603|0805|1206|1210|2512)", fp)
    pkg = pkg_match.group(1) if pkg_match else ""

    # Normalize value
    val = val.replace(" ", "").replace("ohm", "r").replace("ohms", "r")
    val = re.sub(r"(\d)r(\d)", r"\1.\2", val)  # 4r7 -> 4.7

    if pkg:
        return f"{val}_{pkg}"
    return val


def classify_assembly(bl: BomLine) -> str:
    """Classify a component for JLCPCB assembly."""
    if bl.lcsc and LCSC_PATTERN.match(bl.lcsc):
        return JLCPCB_EXTENDED  # Has part, assume extended unless known basic
    for pattern, _ in BASIC_PATTERNS:
        if re.search(pattern, bl.value, re.IGNORECASE):
            return JLCPCB_BASIC
    if bl.mpn:
        key = bl.mpn.strip().lower()
        if key in LCSC_KNOWLEDGE_BASE:
            return LCSC_KNOWLEDGE_BASE[key].get("category", JLCPCB_EXTENDED)
    return JLCPCB_UNAVAILABLE


def suggest_alternatives(bl: BomLine) -> BomLine:
    """Suggest LCSC alternatives if not already specified."""
    bl.assembly_category = classify_assembly(bl)

    # Already has LCSC part
    if bl.lcsc and LCSC_PATTERN.match(bl.lcsc):
        bl.suggestion = f"LCSC {bl.lcsc} already specified"
        return bl

    # Try MPN lookup
    if bl.mpn:
        key = bl.mpn.strip().lower()
        if key in LCSC_KNOWLEDGE_BASE:
            info = LCSC_KNOWLEDGE_BASE[key]
            bl.lcsc = info["lcsc"]
            bl.assembly_category = info["category"]
            bl.suggestion = f"Matched MPN -> LCSC {info['lcsc']} ({info['category']}, ~${info['price_1k']}/pc @1k)"
            return bl

    # Try value+footprint lookup
    lookup = normalize_value_for_lookup(bl.value, bl.footprint)
    if lookup in LCSC_KNOWLEDGE_BASE:
        info = LCSC_KNOWLEDGE_BASE[lookup]
        bl.lcsc = info["lcsc"]
        bl.assembly_category = info["category"]
        bl.suggestion = f"Matched value+pkg -> LCSC {info['lcsc']} ({info['category']}, ~${info['price_1k']}/pc @1k)"
        return bl

    # No match
    bl.suggestion = "No automatic match — manual sourcing required"
    bl.notes = f"Search https://www.lcsc.com/search?q={bl.mpn or bl.value} or https://jlcpcb.com/parts"
    return bl


# ---------------------------------------------------------------------------
# Report generation
# ---------------------------------------------------------------------------

def generate_report(lines: list[BomLine], source_file: str) -> str:
    """Generate a Markdown report from analyzed BOM lines."""
    total = len(lines)
    total_qty = sum(bl.quantity for bl in lines)
    with_lcsc = sum(1 for bl in lines if bl.lcsc and LCSC_PATTERN.match(bl.lcsc))
    basic = sum(1 for bl in lines if bl.assembly_category == JLCPCB_BASIC)
    extended = sum(1 for bl in lines if bl.assembly_category == JLCPCB_EXTENDED)
    unavail = sum(1 for bl in lines if bl.assembly_category == JLCPCB_UNAVAILABLE)

    coverage = (with_lcsc / total * 100) if total > 0 else 0
    assembly_ready = unavail == 0

    report = []
    report.append(f"# BOM Analysis Report")
    report.append(f"")
    report.append(f"> Source: `{source_file}`")
    report.append(f"> Generated: 2026-03-25")
    report.append(f"")
    report.append(f"## Summary")
    report.append(f"")
    report.append(f"| Metric | Value |")
    report.append(f"|--------|-------|")
    report.append(f"| Unique line items | {total} |")
    report.append(f"| Total component count | {total_qty} |")
    report.append(f"| LCSC coverage | {with_lcsc}/{total} ({coverage:.0f}%) |")
    report.append(f"| JLCPCB Basic parts | {basic} |")
    report.append(f"| JLCPCB Extended parts | {extended} |")
    report.append(f"| Unavailable/manual | {unavail} |")
    report.append(f"| Assembly status | {'READY' if assembly_ready else 'BLOCKED — manual sourcing needed'} |")
    report.append(f"")

    # Components table
    report.append(f"## Component Details")
    report.append(f"")
    report.append(f"| Ref | Value | Footprint | Qty | MPN | LCSC | Category | Suggestion |")
    report.append(f"|-----|-------|-----------|-----|-----|------|----------|------------|")
    for bl in sorted(lines, key=lambda x: x.reference):
        ref_short = bl.reference[:20] + "..." if len(bl.reference) > 20 else bl.reference
        report.append(
            f"| {ref_short} | {bl.value} | {bl.footprint} | {bl.quantity} "
            f"| {bl.mpn} | {bl.lcsc} | {bl.assembly_category} | {bl.suggestion} |"
        )

    # Issues section
    report.append(f"")
    report.append(f"## Issues")
    report.append(f"")
    issues = [bl for bl in lines if bl.assembly_category == JLCPCB_UNAVAILABLE]
    if issues:
        report.append(f"The following {len(issues)} component(s) need manual LCSC sourcing:")
        report.append(f"")
        for bl in issues:
            report.append(f"- **{bl.value}** ({bl.reference}) — {bl.notes or 'no suggestion'}")
    else:
        report.append(f"All components have LCSC part numbers. BOM is assembly-ready.")

    report.append(f"")
    return "\n".join(report)


def write_csv(lines: list[BomLine], output_path: str):
    """Write normalized BOM to CSV."""
    fields = ["reference", "value", "footprint", "quantity", "mpn", "manufacturer",
              "description", "lcsc", "digikey", "mouser", "assembly_category", "suggestion", "notes"]
    with open(output_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        for bl in sorted(lines, key=lambda x: x.reference):
            writer.writerow({k: getattr(bl, k) for k in fields})


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def cmd_parse(args):
    """Parse and normalize a BOM CSV."""
    lines = parse_bom(args.input)
    lines = deduplicate(lines)
    print(f"Parsed {len(lines)} unique line items from {args.input}")
    if args.output:
        write_csv(lines, args.output)
        print(f"Written to {args.output}")
    else:
        for bl in lines:
            print(f"  {bl.reference:20s} {bl.value:15s} {bl.footprint:20s} x{bl.quantity}")


def cmd_suggest(args):
    """Parse BOM and suggest LCSC/JLCPCB alternatives."""
    lines = parse_bom(args.input)
    lines = deduplicate(lines)
    for bl in lines:
        suggest_alternatives(bl)

    with_lcsc = sum(1 for bl in lines if bl.lcsc)
    print(f"Analyzed {len(lines)} items: {with_lcsc} with LCSC, {len(lines) - with_lcsc} need manual sourcing")

    if args.output:
        write_csv(lines, args.output)
        print(f"Written to {args.output}")
    else:
        for bl in lines:
            status = "OK" if bl.lcsc else "MISSING"
            print(f"  [{status:7s}] {bl.value:15s} {bl.lcsc or '???':10s} {bl.suggestion}")


def cmd_report(args):
    """Generate full Markdown report."""
    lines = parse_bom(args.input)
    lines = deduplicate(lines)
    for bl in lines:
        suggest_alternatives(bl)

    report = generate_report(lines, args.input)

    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(report)
        print(f"Report written to {args.output}")
    else:
        print(report)


def cmd_batch(args):
    """Process all CSV BOMs in a directory."""
    input_dir = Path(args.input)
    if not input_dir.is_dir():
        print(f"Error: {args.input} is not a directory", file=sys.stderr)
        sys.exit(1)

    csv_files = sorted(input_dir.glob("**/*.csv"))
    if not csv_files:
        print(f"No CSV files found in {args.input}", file=sys.stderr)
        sys.exit(1)

    all_reports = []
    for csv_file in csv_files:
        print(f"Processing {csv_file}...")
        lines = parse_bom(str(csv_file))
        lines = deduplicate(lines)
        for bl in lines:
            suggest_alternatives(bl)
        all_reports.append(generate_report(lines, str(csv_file)))

    combined = "\n\n---\n\n".join(all_reports)
    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(combined)
        print(f"Combined report written to {args.output}")
    else:
        print(combined)


def main():
    parser = argparse.ArgumentParser(
        description="BOM Analyzer — parse, normalize, suggest LCSC/JLCPCB alternatives"
    )
    sub = parser.add_subparsers(dest="command", required=True)

    p_parse = sub.add_parser("parse", help="Parse and normalize a BOM CSV")
    p_parse.add_argument("input", help="Input CSV file")
    p_parse.add_argument("--output", "-o", help="Output normalized CSV")
    p_parse.set_defaults(func=cmd_parse)

    p_suggest = sub.add_parser("suggest", help="Suggest LCSC/JLCPCB alternatives")
    p_suggest.add_argument("input", help="Input CSV file")
    p_suggest.add_argument("--output", "-o", help="Output CSV with suggestions")
    p_suggest.set_defaults(func=cmd_suggest)

    p_report = sub.add_parser("report", help="Generate Markdown analysis report")
    p_report.add_argument("input", help="Input CSV file")
    p_report.add_argument("--output", "-o", help="Output Markdown file")
    p_report.set_defaults(func=cmd_report)

    p_batch = sub.add_parser("batch", help="Process all BOMs in a directory")
    p_batch.add_argument("input", help="Input directory containing CSV BOMs")
    p_batch.add_argument("--output", "-o", help="Output combined Markdown report")
    p_batch.set_defaults(func=cmd_batch)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
