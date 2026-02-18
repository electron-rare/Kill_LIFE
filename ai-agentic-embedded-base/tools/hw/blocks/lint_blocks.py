#!/usr/bin/env python3
import argparse, json, sys
from pathlib import Path

def main():
  ap = argparse.ArgumentParser()
  ap.add_argument("--blocks-dir", default="hardware/blocks", help="Root of blocks directory")
  ap.add_argument("--strict", action="store_true")
  args = ap.parse_args()

  root = Path(args.blocks_dir)
  if not root.exists():
    print("No blocks dir.")
    return 0

  problems = []
  blocks = list(root.rglob("*.kicad_block"))
  for b in blocks:
    # must contain a .kicad_sch and .json metadata
    sch = next(b.glob("*.kicad_sch"), None)
    meta = next(b.glob("*.json"), None)
    if sch is None:
      problems.append((str(b), "missing *.kicad_sch"))
    if meta is None:
      problems.append((str(b), "missing *.json metadata"))
    else:
      try:
        obj = json.loads(meta.read_text(encoding="utf-8"))
        if args.strict:
          if not obj.get("description"):
            problems.append((str(b), "metadata missing description"))
      except Exception as e:
        problems.append((str(b), f"metadata json invalid: {e}"))

  if problems:
    for p, msg in problems:
      print(f"BLOCK_PROBLEM: {p}: {msg}", file=sys.stderr)
    return 2
  print(f"OK: {len(blocks)} blocks")
  return 0

if __name__ == "__main__":
  raise SystemExit(main())
