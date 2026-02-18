#!/usr/bin/env python3
"""Very small diff helper for BOM/netlist exports (placeholder)."""
import sys
from pathlib import Path
import difflib

def main():
  if len(sys.argv) != 4:
    print("usage: hw_diff.py <before> <after> <out.md>", file=sys.stderr)
    return 2
  before = Path(sys.argv[1]).read_text(encoding="utf-8", errors="ignore").splitlines()
  after = Path(sys.argv[2]).read_text(encoding="utf-8", errors="ignore").splitlines()
  diff = difflib.unified_diff(before, after, fromfile="before", tofile="after", lineterm="")
  Path(sys.argv[3]).write_text("\n".join(diff) + "\n", encoding="utf-8")
  return 0

if __name__ == "__main__":
  raise SystemExit(main())
