#!/usr/bin/env python3
import argparse, subprocess, sys, time
from pathlib import Path

def run(cmd):
  p = subprocess.run(cmd, text=True)
  return p.returncode

def main():
  ap = argparse.ArgumentParser(description="Watch KiCad files and re-run hardware gate.")
  ap.add_argument("--root", default="hardware/kicad")
  ap.add_argument("--debounce", type=float, default=0.5)
  args = ap.parse_args()

  try:
    from watchfiles import watch
  except Exception:
    print("Missing dependency. Install: pip install watchfiles", file=sys.stderr)
    return 2

  paths = [args.root, "hardware/rules", "hardware/blocks"]
  print("Watching:", ", ".join(paths))
  last = 0.0

  for changes in watch(*paths):
    now = time.time()
    if now - last < args.debounce:
      continue
    last = now
    print("\n=== change detected ===")
    for c in changes:
      print(" -", c)
    rc = run(["bash", "tools/hw/hw_gate.sh", args.root])
    print("gate exit:", rc)

  return 0

if __name__ == "__main__":
  raise SystemExit(main())
