#!/usr/bin/env python3
import argparse, subprocess, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def sh(cmd):
  p = subprocess.run(cmd, text=True, capture_output=True)
  return p.returncode, p.stdout, p.stderr

def mk_outdir(base="artifacts/hw_previews"):
  ts = time.strftime("%Y%m%dT%H%M%S")
  d = ROOT / base / ts
  d.mkdir(parents=True, exist_ok=True)
  return d

def main():
  ap = argparse.ArgumentParser(description="Export KiCad previews (SVG) + reports.")
  ap.add_argument("--schematic", help="Path to .kicad_sch")
  ap.add_argument("--pcb", help="Path to .kicad_pcb")
  ap.add_argument("--outdir", help="Output directory. Default: artifacts/hw_previews/<ts>/")
  ap.add_argument("--pcb-layers", default="F.Cu,F.SilkS,Edge.Cuts,B.Cu,B.SilkS",
                  help="Comma-separated PCB layers for svg export.")
  ap.add_argument("--theme", default="", help="Theme name (optional).")
  args = ap.parse_args()

  outdir = Path(args.outdir) if args.outdir else mk_outdir()
  logs = outdir / "logs"
  logs.mkdir(parents=True, exist_ok=True)

  def run_kicad(args_list, log_name):
    cmd = ["bash", str(ROOT / "tools/hw/kicad_cli.sh")] + args_list
    rc, so, se = sh(cmd)
    (logs / f"{log_name}.stdout.txt").write_text(so, encoding="utf-8")
    (logs / f"{log_name}.stderr.txt").write_text(se, encoding="utf-8")
    return rc

  # schematic SVG (each sheet -> own file)
  if args.schematic:
    svg_dir = outdir / "schematic_svg"
    svg_dir.mkdir(parents=True, exist_ok=True)
    cmd = ["sch", "export", "svg", "--output", str(svg_dir)]
    if args.theme:
      cmd += ["--theme", args.theme]
    cmd += [args.schematic]
    rc = run_kicad(cmd, "sch_export_svg")
    if rc != 0:
      return rc

    # ERC (json)
    erc_json = outdir / "erc.json"
    rc = run_kicad(["sch", "erc", "--format", "json", "--severity-all", "--exit-code-violations",
                    "--output", str(erc_json), args.schematic], "sch_erc")
    if rc not in (0, 5):  # 5 = violations
      return rc

    # BOM + netlist
    rc = run_kicad(["sch", "export", "bom", "--output", str(outdir / "bom.csv"), args.schematic], "sch_bom")
    if rc != 0:
      return rc
    rc = run_kicad(["sch", "export", "netlist", "--format", "kicadxml",
                    "--output", str(outdir / "netlist.xml"), args.schematic], "sch_netlist")
    if rc != 0:
      return rc

  # PCB SVG + DRC json
  if args.pcb:
    pcb_svg = outdir / "pcb.svg"
    cmd = ["pcb", "export", "svg", "--output", str(pcb_svg), "--layers", args.pcb_layers]
    if args.theme:
      cmd += ["--theme", args.theme]
    cmd += [args.pcb]
    rc = run_kicad(cmd, "pcb_export_svg")
    if rc != 0:
      return rc

    drc_json = outdir / "drc.json"
    rc = run_kicad(["pcb", "drc", "--format", "json", "--severity-all", "--exit-code-violations",
                    "--output", str(drc_json), args.pcb], "pcb_drc")
    if rc not in (0, 5):
      return rc

  # small index for PR artifact browsing
  index = outdir / "INDEX.md"
  lines = ["# Hardware Previews", ""]
  if (outdir / "schematic_svg").exists():
    lines += ["## Schematic (SVG)", ""]
    for p in sorted((outdir / "schematic_svg").glob("*.svg")):
      lines.append(f"- {p.relative_to(outdir)}")
    lines.append("")
  if (outdir / "pcb.svg").exists():
    lines += ["## PCB", "", f"- {Path('pcb.svg')}", ""]
  lines += ["## Reports", ""]
  for name in ["erc.json","drc.json","bom.csv","netlist.xml"]:
    p = outdir / name
    if p.exists():
      lines.append(f"- {name}")
  lines.append("")
  index.write_text("\n".join(lines), encoding="utf-8")

  print(str(outdir))
  return 0

if __name__ == "__main__":
  raise SystemExit(main())
