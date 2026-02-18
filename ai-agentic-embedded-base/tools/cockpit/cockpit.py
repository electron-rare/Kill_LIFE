#!/usr/bin/env python3
import argparse
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def sh(cmd, cwd=None):
  p = subprocess.run(cmd, cwd=cwd, text=True)
  return p.returncode

def menu():
  print("=== cockpit ===")
  print("1) gate S0 (spec ready)")
  print("2) firmware build+test")
  print("3) hardware check (ERC/netlist/BOM)")
  print("4) exit")
  choice = input("> ").strip()
  if choice == "1":
    return gate_s0()
  if choice == "2":
    return firmware()
  if choice == "3":
    schem = input("Path to .kicad_sch: ").strip()
    return hardware(schem)
  return 0

def gate_s0():
  needed = [
    "specs/01_spec.md",
    "specs/02_arch.md",
    "specs/03_plan.md",
    "specs/constraints.yaml",
  ]
  missing = [p for p in needed if not (ROOT / p).exists()]
  if missing:
    print("Missing:", missing)
    return 2
  print("S0: ok (basic files present). Review bmad/gates/gate_s0.md")
  return 0

def firmware():
  fw = ROOT / "firmware"
  rc = sh(["python", "-m", "pip", "install", "-U", "platformio"])
  if rc != 0:
    return rc
  rc = sh(["pio", "run", "-e", "esp32s3_arduino"], cwd=str(fw))
  if rc != 0:
    return rc
  return sh(["pio", "test", "-e", "native"], cwd=str(fw))

def hardware(schematic):
  return sh(["bash", "tools/hw/hw_check.sh", schematic], cwd=str(ROOT))

def main():
  ap = argparse.ArgumentParser()
  sub = ap.add_subparsers(dest="cmd", required=True)
  sub.add_parser("menu")
  sub.add_parser("gate_s0")
  sub.add_parser("fw")
  p = sub.add_parser("hw")
  p.add_argument("--schematic", required=True)
  args = ap.parse_args()

  if args.cmd == "menu":
    return menu()
  if args.cmd == "gate_s0":
    return gate_s0()
  if args.cmd == "fw":
    return firmware()
  if args.cmd == "hw":
    return hardware(args.schematic)
  return 0

if __name__ == "__main__":
  raise SystemExit(main())
