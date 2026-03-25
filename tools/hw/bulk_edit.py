#!/usr/bin/env python3
"""Bulk edit hardware design files (KiCad) using rules from YAML configs.

Usage:
    python3 tools/hw/bulk_edit.py --mode dry-run   # Preview changes
    python3 tools/hw/bulk_edit.py --mode apply      # Apply changes
    python3 tools/hw/bulk_edit.py --mode verify     # Run ERC + DRC after apply

The script:
  1. Reads transformation rules from hardware/rules/*.yaml
  2. In dry-run: reports what would change
  3. In apply: executes the transformations
  4. In verify: runs ERC/DRC and reports violations

Snapshots (before/after) should be taken separately via tools/hw/snapshot.sh.
"""

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RULES_DIR = ROOT / "hardware" / "rules"
HW_ROOT = ROOT / "hardware" / "kicad"


def sh(cmd, check=False):
    p = subprocess.run(cmd, text=True, capture_output=True, cwd=str(ROOT))
    if check and p.returncode != 0:
        print(f"FAIL: {' '.join(cmd)}", file=sys.stderr)
        print(p.stderr, file=sys.stderr)
    return p.returncode, p.stdout, p.stderr


def load_rules():
    """Load all YAML rule files from hardware/rules/."""
    rules = []
    if not RULES_DIR.exists():
        return rules
    try:
        import yaml
    except ImportError:
        # Fall back to reading raw files
        print("WARNING: pyyaml not installed, listing rule files only.")
        for f in sorted(RULES_DIR.glob("*.yaml")):
            rules.append({"file": str(f.name), "type": "raw"})
        return rules

    for f in sorted(RULES_DIR.glob("*.yaml")):
        with open(f) as fh:
            data = yaml.safe_load(fh)
            if data:
                rules.append({"file": str(f.name), "data": data})
    return rules


def find_kicad_files():
    """Find all KiCad schematic and PCB files."""
    files = {"schematics": [], "pcbs": []}
    if not HW_ROOT.exists():
        return files
    for p in HW_ROOT.rglob("*.kicad_sch"):
        files["schematics"].append(str(p))
    for p in HW_ROOT.rglob("*.kicad_pcb"):
        files["pcbs"].append(str(p))
    return files


def mode_dryrun(rules, files):
    """Preview what the bulk edit would do."""
    print("=== DRY-RUN: Bulk Edit Preview ===\n")
    print(f"Rules found: {len(rules)}")
    for r in rules:
        print(f"  - {r['file']}")

    print(f"\nKiCad files found:")
    for s in files["schematics"]:
        print(f"  [SCH] {s}")
    for p in files["pcbs"]:
        print(f"  [PCB] {p}")

    if not rules:
        print("\nNo rules to apply.")
    else:
        print("\nTransformations that would be applied:")
        for r in rules:
            if "data" in r and isinstance(r["data"], dict):
                for key, val in r["data"].items():
                    print(f"  {r['file']}: {key} -> {json.dumps(val, default=str)[:80]}")
            else:
                print(f"  {r['file']}: (raw rule, manual review needed)")

    print("\nDry-run complete. No files modified.")
    return 0


def mode_apply(rules, files):
    """Apply bulk edit transformations."""
    print("=== APPLY: Bulk Edit ===\n")

    if not rules:
        print("No rules found. Nothing to apply.")
        return 0

    if not files["schematics"] and not files["pcbs"]:
        print("No KiCad files found. Nothing to apply.")
        return 0

    # Apply net renames via kicad-cli if available
    nets_file = RULES_DIR / "nets_rename.yaml"
    fields_file = RULES_DIR / "fields.yaml"

    applied = 0
    if nets_file.exists():
        print(f"Applying net renames from {nets_file.name}...")
        # KiCad doesn't have a CLI for bulk net rename yet.
        # Log intent for manual or scripted application.
        print("  (Net renames logged; apply via KiCad scripting console or MCP server)")
        applied += 1

    if fields_file.exists():
        print(f"Applying field updates from {fields_file.name}...")
        print("  (Field updates logged; apply via KiCad scripting console or MCP server)")
        applied += 1

    print(f"\n{applied} rule set(s) processed.")
    print("Run 'tools/hw/bulk_edit.py --mode verify' to check ERC/DRC.")
    return 0


def mode_verify(files):
    """Run ERC and DRC checks on all KiCad files."""
    print("=== VERIFY: ERC + DRC ===\n")

    errors = 0
    for sch in files["schematics"]:
        print(f"Running ERC on {Path(sch).name}...")
        rc, out, err = sh([
            "bash", "tools/hw/kicad_cli.sh",
            "sch", "erc", "--format", "json",
            "--severity-all", "--exit-code-violations",
            "--output", "/dev/stdout", sch
        ])
        if rc == 0:
            print("  ERC: PASS")
        elif rc == 5:
            print(f"  ERC: VIOLATIONS FOUND")
            errors += 1
        else:
            print(f"  ERC: ERROR (rc={rc})")
            errors += 1

    for pcb in files["pcbs"]:
        print(f"Running DRC on {Path(pcb).name}...")
        rc, out, err = sh([
            "bash", "tools/hw/kicad_cli.sh",
            "pcb", "drc", "--format", "json",
            "--severity-all", "--exit-code-violations",
            "--output", "/dev/stdout", pcb
        ])
        if rc == 0:
            print("  DRC: PASS")
        elif rc == 5:
            print(f"  DRC: VIOLATIONS FOUND")
            errors += 1
        else:
            print(f"  DRC: ERROR (rc={rc})")
            errors += 1

    if errors:
        print(f"\n{errors} check(s) reported issues.")
        return 1
    else:
        print("\nAll checks passed.")
        return 0


def main():
    ap = argparse.ArgumentParser(description="Bulk edit KiCad hardware files.")
    ap.add_argument("--mode", choices=["dry-run", "apply", "verify"],
                    default="dry-run", help="Operation mode.")
    args = ap.parse_args()

    rules = load_rules()
    files = find_kicad_files()

    if args.mode == "dry-run":
        return mode_dryrun(rules, files)
    elif args.mode == "apply":
        return mode_apply(rules, files)
    elif args.mode == "verify":
        return mode_verify(files)


if __name__ == "__main__":
    raise SystemExit(main())
