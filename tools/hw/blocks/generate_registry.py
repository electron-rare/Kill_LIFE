#!/usr/bin/env python3
import argparse, json
from pathlib import Path

def main():
  ap = argparse.ArgumentParser()
  ap.add_argument("--blocks-dir", default="hardware/blocks")
  ap.add_argument("--out", default="hardware/blocks/REGISTRY.md")
  args = ap.parse_args()

  root = Path(args.blocks_dir)
  out = Path(args.out)
  out.parent.mkdir(parents=True, exist_ok=True)

  blocks = []
  for b in sorted(root.rglob("*.kicad_block")):
    sch = next(b.glob("*.kicad_sch"), None)
    meta = next(b.glob("*.json"), None)
    meta_obj = {}
    if meta and meta.exists():
      try:
        meta_obj = json.loads(meta.read_text(encoding="utf-8"))
      except Exception:
        meta_obj = {}
    blocks.append({
      "path": str(b),
      "name": b.stem,
      "schematic": str(sch) if sch else "",
      "meta": meta_obj
    })

  lines = ["# Design Blocks registry", ""]
  lines.append(f"- Total: **{len(blocks)}**")
  lines.append("")
  for blk in blocks:
    lines.append(f"## {blk['name']}")
    lines.append(f"- Path: `{blk['path']}`")
    if blk["schematic"]:
      lines.append(f"- Schematic: `{blk['schematic']}`")
    desc = blk["meta"].get("description","")
    if desc:
      lines.append(f"- Description: {desc}")
    kws = blk["meta"].get("keywords", [])
    if kws:
      lines.append(f"- Keywords: {', '.join(kws)}")
    lines.append("")
  out.write_text("\n".join(lines), encoding="utf-8")
  print(str(out))
  return 0

if __name__ == "__main__":
  raise SystemExit(main())
