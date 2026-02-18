#!/usr/bin/env python3
"""schops — Schematic Ops (KiCad)

Goals:
  - deterministic exports via kicad-cli (ERC / netlist / BOM)
  - safe bulk edits via kicad-sch-api (fields / footprints / net labels)
  - Design Blocks (KiCad 9) helpers

This tool is intentionally conservative:
  - it always writes an artifacts report
  - it creates a backup before modifying a schematic (unless --no-backup)
  - it supports --dry-run for review-only runs
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple

try:
    import yaml  # type: ignore
except Exception:
    yaml = None


# ---------------------------
# Helpers
# ---------------------------


def kicad_cli_path() -> str:
    """Best-effort path resolution for macOS + fallback."""
    mac = "/Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli"
    if os.path.exists(mac):
        return mac
    return "kicad-cli"


def run(cmd: List[str], cwd: Optional[str] = None) -> Tuple[int, str, str]:
    p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    return p.returncode, p.stdout, p.stderr


def ensure_artifacts(root: str = "artifacts/hw") -> Path:
    ts = time.strftime("%Y%m%dT%H%M%S")
    d = Path(root) / ts
    d.mkdir(parents=True, exist_ok=True)
    return d


def die(msg: str, code: int = 2) -> int:
    print(msg, file=sys.stderr)
    return code


def need_yaml() -> bool:
    if yaml is None:
        print("PyYAML missing. Install: pip install -r tools/hw/schops/requirements.txt", file=sys.stderr)
        return False
    return True


def need_sch_api():
    try:
        import kicad_sch_api as ksa  # type: ignore

        return ksa
    except Exception:
        print(
            "kicad-sch-api not installed. Run: pip install -r tools/hw/schops/requirements.txt",
            file=sys.stderr,
        )
        return None


def backup_file(path: Path, suffix: str = ".bak") -> Path:
    dst = path.with_suffix(path.suffix + suffix)
    shutil.copy2(path, dst)
    return dst


def write_json(p: Path, obj: Any) -> None:
    p.write_text(json.dumps(obj, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


# ---------------------------
# Rules engine (match + apply)
# ---------------------------


@dataclass
class RuleMatch:
    ref_prefix: Optional[str] = None
    lib_id_prefix: Optional[str] = None
    value_regex: Optional[str] = None

    def matches(self, ref: str, lib_id: str, value: str) -> bool:
        if self.ref_prefix and not ref.startswith(self.ref_prefix):
            return False
        if self.lib_id_prefix and not lib_id.startswith(self.lib_id_prefix):
            return False
        if self.value_regex and not re.search(self.value_regex, value or ""):
            return False
        return True


def _normalize_str(v: Any) -> str:
    if v is None:
        return ""
    if isinstance(v, str):
        return v
    return str(v)


def load_fields_rules(path: Path) -> Dict[str, Any]:
    if not need_yaml():
        raise RuntimeError("PyYAML missing")
    obj = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(obj, dict):
        raise ValueError("fields.yaml must be a mapping")
    obj.setdefault("defaults", {})
    obj.setdefault("rules", [])
    return obj


def load_nets_rename(path: Path) -> Dict[str, str]:
    if not need_yaml():
        raise RuntimeError("PyYAML missing")
    obj = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(obj, dict) or "rename" not in obj or not isinstance(obj["rename"], dict):
        raise ValueError("nets_rename.yaml must contain a 'rename' mapping")
    return {str(k): str(v) for k, v in obj["rename"].items()}


def load_footprints_csv(path: Path) -> List[Tuple[str, str]]:
    rows: List[Tuple[str, str]] = []
    with path.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for r in reader:
            lib_id = (r.get("lib_id") or "").strip()
            fp = (r.get("footprint") or "").strip()
            if not lib_id or not fp:
                continue
            rows.append((lib_id, fp))
    return rows


# ---------------------------
# kicad-cli commands
# ---------------------------


def cmd_erc(args) -> int:
    outdir = ensure_artifacts(args.artifacts)
    out = outdir / "erc.json"
    cli = kicad_cli_path()
    cmd = [
        cli,
        "sch",
        "erc",
        "--format",
        "json",
        "--severity-all",
        "--exit-code-violations",
        "-o",
        str(out),
        args.schematic,
    ]
    rc, so, se = run(cmd)
    (outdir / "erc.stdout.txt").write_text(so, encoding="utf-8")
    (outdir / "erc.stderr.txt").write_text(se, encoding="utf-8")
    print(str(out))
    return rc


def cmd_netlist(args) -> int:
    outdir = ensure_artifacts(args.artifacts)
    out = outdir / "netlist.xml"
    cli = kicad_cli_path()
    cmd = [cli, "sch", "export", "netlist", "--format", "kicadxml", "-o", str(out), args.schematic]
    rc, so, se = run(cmd)
    (outdir / "netlist.stdout.txt").write_text(so, encoding="utf-8")
    (outdir / "netlist.stderr.txt").write_text(se, encoding="utf-8")
    print(str(out))
    return rc


def cmd_bom(args) -> int:
    outdir = ensure_artifacts(args.artifacts)
    out = outdir / "bom.csv"
    cli = kicad_cli_path()
    cmd = [cli, "sch", "export", "bom", "-o", str(out)]
    if args.fields:
        cmd += ["--fields", args.fields]
    if args.group_by:
        cmd += ["--group-by", args.group_by]
    if args.exclude_dnp:
        cmd += ["--exclude-dnp"]
    cmd += [args.schematic]
    rc, so, se = run(cmd)
    (outdir / "bom.stdout.txt").write_text(so, encoding="utf-8")
    (outdir / "bom.stderr.txt").write_text(se, encoding="utf-8")
    print(str(out))
    return rc


# ---------------------------
# kicad-sch-api bulk edits
# ---------------------------


def _component_get(component: Any) -> Tuple[str, str, str, str, Dict[str, str]]:
    ref = _normalize_str(getattr(component, "reference", ""))
    lib_id = _normalize_str(getattr(component, "lib_id", ""))
    value = _normalize_str(getattr(component, "value", ""))
    footprint = _normalize_str(getattr(component, "footprint", ""))
    props = getattr(component, "properties", {})
    props_norm: Dict[str, str] = {}
    if isinstance(props, dict):
        for k, v in props.items():
            props_norm[str(k)] = _normalize_str(v)
    return ref, lib_id, value, footprint, props_norm


def _component_set_fields(component: Any, fields: Dict[str, str]) -> Dict[str, Tuple[str, str]]:
    """Set multiple properties. Returns changed map {field: (old, new)}."""
    changed: Dict[str, Tuple[str, str]] = {}
    props = getattr(component, "properties", None)
    if not isinstance(props, dict):
        # fallback: if API changes, try set_property
        props = {}
    for k, v in fields.items():
        k_s = str(k)
        v_s = _normalize_str(v)
        old = _normalize_str(props.get(k_s))
        if old != v_s:
            try:
                props[k_s] = v_s
                # if dict is a PropertyDict wrapper, mutation marks modified.
            except Exception:
                try:
                    component.set_property(k_s, v_s)  # type: ignore
                except Exception:
                    # last resort: setattr
                    setattr(component, k_s, v_s)
            changed[k_s] = (old, v_s)
    return changed


def _component_set_footprint(component: Any, fp: str) -> Optional[Tuple[str, str]]:
    fp_s = _normalize_str(fp)
    old = _normalize_str(getattr(component, "footprint", ""))
    if old == fp_s:
        return None
    try:
        component.footprint = fp_s
    except Exception:
        setattr(component, "footprint", fp_s)
    return (old, fp_s)


def _save_or_report(sch: Any, schematic_path: Path, dry_run: bool, no_backup: bool, backup_suffix: str) -> Dict[str, Any]:
    backup_path: Optional[str] = None
    if not dry_run:
        if not no_backup:
            backup_path = str(backup_file(schematic_path, backup_suffix))
        sch.save()  # exact format preservation is handled by kicad-sch-api
    return {"dry_run": dry_run, "backup": backup_path}


def cmd_apply_fields(args) -> int:
    if not need_yaml():
        return 2
    ksa = need_sch_api()
    if ksa is None:
        return 2

    schematic_path = Path(args.schematic)
    if not schematic_path.exists():
        return die(f"schematic not found: {schematic_path}")

    rules_obj = load_fields_rules(Path(args.rules))
    defaults_fields = rules_obj.get("defaults", {}).get("fields", {}) or {}
    if not isinstance(defaults_fields, dict):
        return die("defaults.fields must be a mapping")

    parsed_rules: List[Tuple[RuleMatch, Dict[str, str]]] = []
    for r in rules_obj.get("rules", []) or []:
        if not isinstance(r, dict):
            continue
        m = r.get("match", {}) or {}
        s = r.get("set", {}) or {}
        set_fields = (s.get("fields", {}) or {}) if isinstance(s, dict) else {}
        if not isinstance(m, dict) or not isinstance(set_fields, dict):
            continue
        parsed_rules.append(
            (
                RuleMatch(
                    ref_prefix=_normalize_str(m.get("ref_prefix")) or None,
                    lib_id_prefix=_normalize_str(m.get("lib_id_prefix")) or None,
                    value_regex=_normalize_str(m.get("value_regex")) or None,
                ),
                {str(k): _normalize_str(v) for k, v in set_fields.items()},
            )
        )

    outdir = ensure_artifacts(args.artifacts)
    sch = ksa.Schematic.load(str(schematic_path))

    changes: List[Dict[str, Any]] = []
    for c in sch.components:
        ref, lib_id, value, _, props = _component_get(c)
        to_set: Dict[str, str] = {}

        # ensure defaults exist (but do not overwrite non-empty values unless --force-defaults)
        for k, v in defaults_fields.items():
            k_s = str(k)
            v_s = _normalize_str(v)
            cur = _normalize_str(props.get(k_s))
            if args.force_defaults:
                if cur != v_s:
                    to_set[k_s] = v_s
            else:
                if cur == "" and v_s != "":
                    to_set[k_s] = v_s
                elif cur == "" and v_s == "" and args.ensure_empty_fields:
                    # create field with empty value
                    to_set[k_s] = v_s

        # rules overlays
        for rm, set_fields in parsed_rules:
            if rm.matches(ref=ref, lib_id=lib_id, value=value):
                to_set.update(set_fields)

        if not to_set:
            continue
        changed = _component_set_fields(c, to_set)
        if changed:
            changes.append({"ref": ref, "lib_id": lib_id, "value": value, "changed_fields": changed})

    meta = _save_or_report(
        sch,
        schematic_path,
        dry_run=args.dry_run,
        no_backup=args.no_backup,
        backup_suffix=args.backup_suffix,
    )

    report = {
        "op": "apply-fields",
        "schematic": str(schematic_path),
        "rules": str(Path(args.rules)),
        "changed_components": len(changes),
        "changes": changes,
        **meta,
    }
    write_json(outdir / "apply_fields.report.json", report)
    print(str(outdir / "apply_fields.report.json"))
    return 0


def cmd_apply_footprints(args) -> int:
    ksa = need_sch_api()
    if ksa is None:
        return 2
    schematic_path = Path(args.schematic)
    if not schematic_path.exists():
        return die(f"schematic not found: {schematic_path}")
    mapping = load_footprints_csv(Path(args.map))
    if not mapping:
        return die("footprints map is empty")

    outdir = ensure_artifacts(args.artifacts)
    sch = ksa.Schematic.load(str(schematic_path))

    changes: List[Dict[str, Any]] = []
    for c in sch.components:
        ref, lib_id, value, footprint, _ = _component_get(c)
        new_fp: Optional[str] = None
        for lib_prefix, fp in mapping:
            if lib_id == lib_prefix or lib_id.startswith(lib_prefix):
                new_fp = fp
                break
        if not new_fp:
            continue
        ch = _component_set_footprint(c, new_fp)
        if ch:
            old_fp, new_fp2 = ch
            changes.append(
                {
                    "ref": ref,
                    "lib_id": lib_id,
                    "value": value,
                    "footprint": {"old": old_fp, "new": new_fp2},
                }
            )

    meta = _save_or_report(
        sch,
        schematic_path,
        dry_run=args.dry_run,
        no_backup=args.no_backup,
        backup_suffix=args.backup_suffix,
    )

    report = {
        "op": "apply-footprints",
        "schematic": str(schematic_path),
        "map": str(Path(args.map)),
        "changed_components": len(changes),
        "changes": changes,
        **meta,
    }
    write_json(outdir / "apply_footprints.report.json", report)
    print(str(outdir / "apply_footprints.report.json"))
    return 0


def cmd_rename_nets(args) -> int:
    if not need_yaml():
        return 2
    ksa = need_sch_api()
    if ksa is None:
        return 2
    schematic_path = Path(args.schematic)
    if not schematic_path.exists():
        return die(f"schematic not found: {schematic_path}")
    rename = load_nets_rename(Path(args.rules))

    outdir = ensure_artifacts(args.artifacts)
    sch = ksa.Schematic.load(str(schematic_path))

    changes: List[Dict[str, Any]] = []

    def _apply_to_labels(label_collection: Any, kind: str) -> None:
        nonlocal changes
        for lab in label_collection:
            old = _normalize_str(getattr(lab, "text", ""))
            if old in rename:
                new = rename[old]
                if new != old:
                    try:
                        lab.text = new
                    except Exception:
                        setattr(lab, "text", new)
                    changes.append({"kind": kind, "old": old, "new": new, "uuid": _normalize_str(getattr(lab, "uuid", ""))})

    _apply_to_labels(sch.labels, "label")
    _apply_to_labels(sch.hierarchical_labels, "hierarchical_label")

    meta = _save_or_report(
        sch,
        schematic_path,
        dry_run=args.dry_run,
        no_backup=args.no_backup,
        backup_suffix=args.backup_suffix,
    )

    report = {
        "op": "rename-nets",
        "schematic": str(schematic_path),
        "rules": str(Path(args.rules)),
        "changed_labels": len(changes),
        "changes": changes,
        **meta,
    }
    write_json(outdir / "rename_nets.report.json", report)
    print(str(outdir / "rename_nets.report.json"))
    return 0


def cmd_snapshot(args) -> int:
    ksa = need_sch_api()
    if ksa is None:
        return 2
    schematic_path = Path(args.schematic)
    if not schematic_path.exists():
        return die(f"schematic not found: {schematic_path}")

    outdir = ensure_artifacts(args.artifacts)
    sch = ksa.Schematic.load(str(schematic_path))

    comps: List[Dict[str, Any]] = []
    for c in sch.components:
        ref, lib_id, value, footprint, props = _component_get(c)
        comps.append({"ref": ref, "lib_id": lib_id, "value": value, "footprint": footprint, "fields": props})

    labels = [{"text": l.text, "uuid": l.uuid} for l in sch.labels]
    hlabels = [{"text": l.text, "uuid": l.uuid} for l in sch.hierarchical_labels]

    snap = {
        "schematic": str(schematic_path),
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "components": sorted(comps, key=lambda x: x.get("ref", "")),
        "labels": sorted(labels, key=lambda x: x.get("text", "")),
        "hierarchical_labels": sorted(hlabels, key=lambda x: x.get("text", "")),
    }
    out = outdir / (args.name or "snapshot.json")
    write_json(out, snap)
    print(str(out))
    return 0


# ---------------------------
# Design Blocks (KiCad 9)
# ---------------------------


def cmd_block_make(args) -> int:
    """Create a KiCad design block folder.

    KiCad expects:
      <LIB>.kicad_blocks/        (library folder)
        <BLOCK>.kicad_block/     (block folder)
          <anything>.kicad_sch
          <anything>.json
    """
    outdir = ensure_artifacts(args.artifacts)
    lib = Path(args.lib)
    lib.mkdir(parents=True, exist_ok=True)

    # encourage correct naming
    if not lib.name.endswith(".kicad_blocks"):
        (outdir / "block_make.warning.txt").write_text(
            f"Warning: design block libraries usually end with .kicad_blocks (got: {lib.name})\n",
            encoding="utf-8",
        )

    block_dir = lib / f"{args.name}.kicad_block"
    block_dir.mkdir(parents=True, exist_ok=True)

    src = Path(args.from_sheet)
    if not src.exists():
        return die(f"source schematic not found: {src}")

    dst_sch = block_dir / f"{args.name}.kicad_sch"
    dst_sch.write_text(src.read_text(encoding="utf-8"), encoding="utf-8")

    meta = {
        "description": args.description or "",
        "keywords": [k.strip() for k in (args.keywords or "").split(",") if k.strip()],
        "fields": args.fields or {},
    }
    (block_dir / f"{args.name}.json").write_text(json.dumps(meta, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    (outdir / "block_make.md").write_text(f"Created block: {block_dir}\n", encoding="utf-8")
    print(str(block_dir))
    return 0


def cmd_block_ls(args) -> int:
    lib = Path(args.lib)
    if not lib.exists():
        return die(f"lib not found: {lib}")
    blocks = sorted([p for p in lib.glob("*.kicad_block") if p.is_dir()])
    rows: List[Dict[str, Any]] = []
    for b in blocks:
        json_files = list(b.glob("*.json"))
        meta: Dict[str, Any] = {}
        if json_files:
            try:
                meta = json.loads(json_files[0].read_text(encoding="utf-8"))
            except Exception:
                meta = {}
        rows.append(
            {
                "block": b.name,
                "description": _normalize_str(meta.get("description")),
                "keywords": meta.get("keywords", []),
            }
        )
    print(json.dumps({"lib": str(lib), "blocks": rows}, indent=2, ensure_ascii=False))
    return 0


# ---------------------------
# CLI
# ---------------------------


def build_parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(prog="schops")
    ap.add_argument("--artifacts", default="artifacts/hw", help="artifacts root (default: artifacts/hw)")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("erc", help="Run ERC via kicad-cli")
    p.add_argument("--schematic", required=True)
    p.set_defaults(fn=cmd_erc)

    p = sub.add_parser("netlist", help="Export netlist via kicad-cli")
    p.add_argument("--schematic", required=True)
    p.set_defaults(fn=cmd_netlist)

    p = sub.add_parser("bom", help="Export BOM via kicad-cli")
    p.add_argument("--schematic", required=True)
    p.add_argument("--fields", help='Comma-separated list, e.g. "Reference,Value,Footprint"')
    p.add_argument("--group-by", help='Group-by expression, e.g. "Value,Footprint"')
    p.add_argument("--exclude-dnp", action="store_true", help="Exclude DNP parts")
    p.set_defaults(fn=cmd_bom)

    p = sub.add_parser("apply-fields", help="Apply fields defaults + rules (kicad-sch-api)")
    p.add_argument("--schematic", required=True)
    p.add_argument("--rules", required=True, help="YAML rules file (see hardware/rules/fields.yaml)")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--no-backup", action="store_true")
    p.add_argument("--backup-suffix", default=".bak")
    p.add_argument("--force-defaults", action="store_true", help="Overwrite existing fields with defaults")
    p.add_argument(
        "--ensure-empty-fields",
        action="store_true",
        help="Also create default fields even when default value is empty",
    )
    p.set_defaults(fn=cmd_apply_fields)

    p = sub.add_parser("apply-footprints", help="Apply footprint mapping (kicad-sch-api)")
    p.add_argument("--schematic", required=True)
    p.add_argument("--map", required=True, help="CSV mapping file (see hardware/rules/footprints.csv)")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--no-backup", action="store_true")
    p.add_argument("--backup-suffix", default=".bak")
    p.set_defaults(fn=cmd_apply_footprints)

    p = sub.add_parser("rename-nets", help="Rename net labels using a YAML map (kicad-sch-api)")
    p.add_argument("--schematic", required=True)
    p.add_argument("--rules", required=True, help="YAML rules file (see hardware/rules/nets_rename.yaml)")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--no-backup", action="store_true")
    p.add_argument("--backup-suffix", default=".bak")
    p.set_defaults(fn=cmd_rename_nets)

    p = sub.add_parser("snapshot", help="Dump components/labels snapshot to JSON (kicad-sch-api)")
    p.add_argument("--schematic", required=True)
    p.add_argument("--name", help="output filename (default snapshot.json)")
    p.set_defaults(fn=cmd_snapshot)

    p = sub.add_parser("block-make", help="Create a KiCad 9 design block folder")
    p.add_argument("--name", required=True)
    p.add_argument("--from-sheet", required=True, help=".kicad_sch file to package as a block")
    p.add_argument("--lib", required=True, help="Design blocks library folder (usually *.kicad_blocks)")
    p.add_argument("--description")
    p.add_argument("--keywords")
    p.add_argument(
        "--fields",
        type=json.loads,
        help='JSON dict of default fields for this block, e.g. "{\"Variant\":\"A\"}"',
    )
    p.set_defaults(fn=cmd_block_make)

    p = sub.add_parser("block-ls", help="List blocks in a design block library")
    p.add_argument("--lib", required=True)
    p.set_defaults(fn=cmd_block_ls)

    return ap


def main() -> int:
    ap = build_parser()
    args = ap.parse_args()
    return int(args.fn(args))


if __name__ == "__main__":
    raise SystemExit(main())
