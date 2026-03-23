#!/usr/bin/env python3
"""Concrete YiACAD native CAD utilities for KiCad and FreeCAD surfaces."""

from __future__ import annotations

import argparse
import csv
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Iterable

try:
    from yiacad_backend import (
        artifact_entry,
        build_context_record,
        build_uiux_output,
        infer_surface,
        output_status_from_returncodes,
        write_context_record,
        write_uiux_output,
    )
except ImportError:
    from tools.cad.yiacad_backend import (
        artifact_entry,
        build_context_record,
        build_uiux_output,
        infer_surface,
        output_status_from_returncodes,
        write_context_record,
        write_uiux_output,
    )


ROOT = Path(__file__).resolve().parents[2]
ARTIFACTS_ROOT = ROOT / "artifacts" / "cad-ai-native"
FUSION_STATUS = ROOT / "artifacts" / "cad-fusion" / "yiacad-fusion-last-status.md"


def now_stamp() -> str:
    return time.strftime("%Y%m%dT%H%M%S")


def ensure_dir(path: Path) -> Path:
    path.mkdir(parents=True, exist_ok=True)
    return path


def make_run_dir(label: str) -> Path:
    return ensure_dir(ARTIFACTS_ROOT / f"{now_stamp()}-{label}")


def write_text(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8")


def write_json(path: Path, payload: object) -> None:
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def run(cmd: list[str], *, cwd: Path | None = None, ok_codes: Iterable[int] = (0,)) -> dict:
    proc = subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        text=True,
        capture_output=True,
    )
    payload = {
        "cmd": cmd,
        "returncode": proc.returncode,
        "stdout": proc.stdout,
        "stderr": proc.stderr,
        "ok": proc.returncode in set(ok_codes),
    }
    return payload


def resolve_kicad_cli() -> str:
    mac = Path("/Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli")
    if mac.exists():
        return str(mac)
    return "kicad-cli"


def resolve_freecad_cmd() -> str | None:
    candidates = (
        Path("/Applications/FreeCAD.app/Contents/MacOS/FreeCADCmd"),
        Path("/Applications/FreeCAD.app/Contents/MacOS/FreeCAD"),
    )
    for candidate in candidates:
        if candidate.exists():
            return str(candidate)
    for name in ("FreeCADCmd", "freecadcmd", "FreeCAD"):
        found = shutil.which(name)
        if found:
            return found
    return None


def guess_board_from_source(source_path: str | None) -> Path | None:
    if not source_path:
        return None
    source = Path(source_path).expanduser().resolve()
    if source.suffix == ".kicad_pcb" and source.exists():
        return source
    base = source.with_suffix(".kicad_pcb")
    if base.exists():
        return base
    for candidate in sorted(source.parent.glob("*.kicad_pcb")):
        return candidate.resolve()
    return None


def guess_schematic_from_source(source_path: str | None) -> Path | None:
    if not source_path:
        return None
    source = Path(source_path).expanduser().resolve()
    if source.suffix == ".kicad_sch" and source.exists():
        return source
    base = source.with_suffix(".kicad_sch")
    if base.exists():
        return base
    for candidate in sorted(source.parent.glob("*.kicad_sch")):
        return candidate.resolve()
    return None


def guess_freecad_document(source_path: str | None) -> Path | None:
    if not source_path:
        return None
    source = Path(source_path).expanduser().resolve()
    if source.suffix == ".FCStd" and source.exists():
        return source
    for candidate in sorted(source.parent.glob("*.FCStd")):
        return candidate.resolve()
    return None


def latest_native_summary() -> str:
    if not ARTIFACTS_ROOT.exists():
        return "No YiACAD native artifact has been generated yet."
    runs = sorted(ARTIFACTS_ROOT.iterdir(), reverse=True)
    for run_dir in runs:
        summary = run_dir / "summary.md"
        if summary.exists():
            return summary.read_text(encoding="utf-8").strip()
    return "No YiACAD native summary is available yet."


def print_contract_or_fallback(args: argparse.Namespace, payload: dict, fallback: str | Path) -> None:
    if getattr(args, "json_output", False):
        print(json.dumps(payload, indent=2, ensure_ascii=False))
    else:
        print(str(fallback))


def command_status(args: argparse.Namespace) -> int:
    lines = ["# YiACAD Native Status", ""]
    if FUSION_STATUS.exists():
        lines += ["## Fusion lane", "", FUSION_STATUS.read_text(encoding="utf-8").strip(), ""]
    else:
        lines += ["## Fusion lane", "", "No fusion status snapshot found.", ""]
    lines += ["## Native surfaces", "", latest_native_summary(), ""]
    status = "done" if FUSION_STATUS.exists() or ARTIFACTS_ROOT.exists() else "degraded"
    severity = "info" if status == "done" else "warning"
    output_payload = build_uiux_output(
        surface="tui",
        action="status.surface",
        execution_mode="batch",
        status=status,
        severity=severity,
        summary="YiACAD native status snapshot generated.",
        details="Fusion lane snapshot and latest native summaries were collected.",
        context_ref=None,
        artifacts=[
            artifact_entry(FUSION_STATUS, "report", "YiACAD fusion status"),
        ]
        if FUSION_STATUS.exists()
        else [],
        next_steps=[
            "open artifacts",
            "review latest native summary",
            "continue with backend or UX lot",
        ],
        latency_ms=None,
    )
    if getattr(args, "json_output", False):
        print(json.dumps(output_payload, indent=2, ensure_ascii=False))
        return 0
    print("\n".join(lines).strip())
    return 0


def command_kicad_erc_drc(args: argparse.Namespace) -> int:
    started_at = time.time()
    board = Path(args.board).expanduser().resolve() if args.board else guess_board_from_source(args.source_path)
    schematic = (
        Path(args.schematic).expanduser().resolve() if args.schematic else guess_schematic_from_source(args.source_path)
    )
    run_dir = make_run_dir("kicad-erc-drc")
    surface = infer_surface(board=board, schematic=schematic)
    context = build_context_record(
        surface,
        source_path=args.source_path,
        board=board,
        schematic=schematic,
        artifacts_dir=run_dir,
    )
    context_path = write_context_record(run_dir / "context.json", context)
    payload: dict[str, object] = {
        "action": "kicad-erc-drc",
        "board": str(board) if board else "",
        "schematic": str(schematic) if schematic else "",
        "artifacts_dir": str(run_dir),
        "context": context,
        "steps": [],
    }

    if not board and not schematic:
        payload["error"] = "No KiCad board or schematic could be resolved."
        output_payload = build_uiux_output(
            surface=surface,
            action="review.erc_drc",
            execution_mode="batch",
            status="blocked",
            severity="error",
            summary="YiACAD could not resolve a KiCad board or schematic.",
            details="Provide --board, --schematic or a valid --source-path with project files present.",
            context_ref=context["context_ref"],
            artifacts=[
                artifact_entry(context_path, "evidence", "YiACAD context record"),
                artifact_entry(run_dir / "result.json", "evidence", "YiACAD raw payload"),
            ],
            next_steps=[
                "provide --board or --schematic",
                "rerun with a loaded KiCad project",
            ],
            latency_ms=int((time.time() - started_at) * 1000),
        )
        output_path = write_uiux_output(run_dir / "uiux_output.json", output_payload)
        payload["uiux_output"] = str(output_path)
        write_json(run_dir / "result.json", payload)
        print_contract_or_fallback(args, output_payload, run_dir / "result.json")
        return 2

    kicad_cli = resolve_kicad_cli()
    summary_lines = ["# YiACAD ERC/DRC Assist", ""]
    rc_final = 0

    if schematic:
        erc_path = run_dir / "erc.json"
        step = run(
            [
                kicad_cli,
                "sch",
                "erc",
                "--format",
                "json",
                "--severity-all",
                "--exit-code-violations",
                "--output",
                str(erc_path),
                str(schematic),
            ],
            ok_codes=(0, 5),
        )
        write_text(run_dir / "erc.stdout.txt", step["stdout"])
        write_text(run_dir / "erc.stderr.txt", step["stderr"])
        payload["steps"].append(step)
        summary_lines += [f"- ERC: `{erc_path}` (rc={step['returncode']})"]
        if not step["ok"]:
            rc_final = step["returncode"]

    if board:
        drc_path = run_dir / "drc.json"
        step = run(
            [
                kicad_cli,
                "pcb",
                "drc",
                "--format",
                "json",
                "--severity-all",
                "--exit-code-violations",
                "--output",
                str(drc_path),
                str(board),
            ],
            ok_codes=(0, 5),
        )
        write_text(run_dir / "drc.stdout.txt", step["stdout"])
        write_text(run_dir / "drc.stderr.txt", step["stderr"])
        payload["steps"].append(step)
        summary_lines += [f"- DRC: `{drc_path}` (rc={step['returncode']})"]
        if not step["ok"] and rc_final == 0:
            rc_final = step["returncode"]

    summary_lines += ["", f"- Board: `{board}`" if board else "- Board: unresolved"]
    summary_lines += [f"- Schematic: `{schematic}`" if schematic else "- Schematic: unresolved"]
    write_text(run_dir / "summary.md", "\n".join(summary_lines) + "\n")
    payload["summary"] = str(run_dir / "summary.md")
    status, severity = output_status_from_returncodes([step["returncode"] for step in payload["steps"]])
    next_steps = {
        "done": ["open generated reports", "continue with BOM review or sync"],
        "degraded": ["open review center", "inspect generated reports", "rerun after fixes"],
        "blocked": ["verify KiCad CLI and project paths", "rerun with project loaded"],
    }[status]
    artifacts = [
        artifact_entry(run_dir / "summary.md", "report", "YiACAD ERC/DRC summary"),
        artifact_entry(context_path, "evidence", "YiACAD context record"),
        artifact_entry(run_dir / "result.json", "evidence", "YiACAD raw payload"),
    ]
    if (run_dir / "erc.json").exists():
        artifacts.append(artifact_entry(run_dir / "erc.json", "report", "ERC JSON report"))
    if (run_dir / "drc.json").exists():
        artifacts.append(artifact_entry(run_dir / "drc.json", "report", "DRC JSON report"))
    for name, label in (
        ("erc.stdout.txt", "ERC stdout"),
        ("erc.stderr.txt", "ERC stderr"),
        ("drc.stdout.txt", "DRC stdout"),
        ("drc.stderr.txt", "DRC stderr"),
    ):
        path = run_dir / name
        if path.exists():
            artifacts.append(artifact_entry(path, "log", label))
    output_payload = build_uiux_output(
        surface=surface,
        action="review.erc_drc",
        execution_mode="batch",
        status=status,
        severity=severity,
        summary="YiACAD ERC/DRC run completed.",
        details=f"Board={board or 'unresolved'} | Schematic={schematic or 'unresolved'} | Artifacts={run_dir}",
        context_ref=context["context_ref"],
        artifacts=artifacts,
        next_steps=next_steps,
        latency_ms=int((time.time() - started_at) * 1000),
    )
    output_path = write_uiux_output(run_dir / "uiux_output.json", output_payload)
    payload["uiux_output"] = str(output_path)
    write_json(run_dir / "result.json", payload)
    print_contract_or_fallback(args, output_payload, run_dir / "summary.md")
    return rc_final


def command_bom_review(args: argparse.Namespace) -> int:
    started_at = time.time()
    schematic = (
        Path(args.schematic).expanduser().resolve() if args.schematic else guess_schematic_from_source(args.source_path)
    )
    run_dir = make_run_dir("bom-review")
    surface = infer_surface(schematic=schematic)
    context = build_context_record(
        surface,
        source_path=args.source_path,
        schematic=schematic,
        artifacts_dir=run_dir,
    )
    context_path = write_context_record(run_dir / "context.json", context)
    if not schematic:
        payload = {
            "action": "bom-review",
            "error": "No KiCad schematic could be resolved.",
            "artifacts_dir": str(run_dir),
            "context": context,
        }
        output_payload = build_uiux_output(
            surface=surface,
            action="review.bom",
            execution_mode="batch",
            status="blocked",
            severity="error",
            summary="YiACAD could not resolve a KiCad schematic for BOM review.",
            details="Provide --schematic or a valid --source-path with .kicad_sch present.",
            context_ref=context["context_ref"],
            artifacts=[
                artifact_entry(context_path, "evidence", "YiACAD context record"),
                artifact_entry(run_dir / "result.json", "evidence", "YiACAD raw payload"),
            ],
            next_steps=[
                "provide --schematic",
                "rerun with a loaded KiCad project",
            ],
            latency_ms=int((time.time() - started_at) * 1000),
        )
        output_path = write_uiux_output(run_dir / "uiux_output.json", output_payload)
        payload["uiux_output"] = str(output_path)
        write_json(run_dir / "result.json", payload)
        print_contract_or_fallback(args, output_payload, run_dir / "result.json")
        return 2

    kicad_cli = resolve_kicad_cli()
    bom_path = run_dir / "bom.csv"
    step = run(
        [kicad_cli, "sch", "export", "bom", "--output", str(bom_path), str(schematic)],
        ok_codes=(0,),
    )
    write_text(run_dir / "bom.stdout.txt", step["stdout"])
    write_text(run_dir / "bom.stderr.txt", step["stderr"])

    row_count = 0
    columns: list[str] = []
    blank_counts: dict[str, int] = {}
    if bom_path.exists():
        with bom_path.open("r", encoding="utf-8", newline="") as handle:
            reader = csv.DictReader(handle)
            columns = reader.fieldnames or []
            blank_counts = {column: 0 for column in columns}
            for row in reader:
                row_count += 1
                for column in columns:
                    if not (row.get(column) or "").strip():
                        blank_counts[column] += 1

    summary_lines = [
        "# YiACAD BOM Review",
        "",
        f"- Schematic: `{schematic}`",
        f"- BOM: `{bom_path}`",
        f"- Rows: `{row_count}`",
        "",
        "## Empty field counts",
        "",
    ]
    if columns:
        for column in columns:
            summary_lines.append(f"- `{column}`: {blank_counts.get(column, 0)}")
    else:
        summary_lines.append("- No BOM columns were parsed.")
    write_text(run_dir / "summary.md", "\n".join(summary_lines) + "\n")
    payload = {
        "action": "bom-review",
        "schematic": str(schematic),
        "bom": str(bom_path),
        "rows": row_count,
        "columns": columns,
        "blank_counts": blank_counts,
        "step": step,
        "summary": str(run_dir / "summary.md"),
        "context": context,
    }
    status, severity = output_status_from_returncodes([step["returncode"]])
    next_steps = {
        "done": ["open BOM summary", "inspect blank field counts"],
        "degraded": ["open BOM summary", "inspect blank field counts"],
        "blocked": ["verify KiCad CLI and schematic path", "rerun BOM export"],
    }[status]
    artifacts = [
        artifact_entry(run_dir / "summary.md", "report", "YiACAD BOM review summary"),
        artifact_entry(context_path, "evidence", "YiACAD context record"),
        artifact_entry(run_dir / "result.json", "evidence", "YiACAD raw payload"),
    ]
    if bom_path.exists():
        artifacts.append(artifact_entry(bom_path, "export", "BOM CSV export"))
    for name, label in (("bom.stdout.txt", "BOM stdout"), ("bom.stderr.txt", "BOM stderr")):
        path = run_dir / name
        if path.exists():
            artifacts.append(artifact_entry(path, "log", label))
    output_payload = build_uiux_output(
        surface=surface,
        action="review.bom",
        execution_mode="batch",
        status=status,
        severity=severity,
        summary="YiACAD BOM review completed.",
        details=f"Schematic={schematic} | Rows={row_count} | Artifacts={run_dir}",
        context_ref=context["context_ref"],
        artifacts=artifacts,
        next_steps=next_steps,
        latency_ms=int((time.time() - started_at) * 1000),
    )
    output_path = write_uiux_output(run_dir / "uiux_output.json", output_payload)
    payload["uiux_output"] = str(output_path)
    write_json(run_dir / "result.json", payload)
    print_contract_or_fallback(args, output_payload, run_dir / "summary.md")
    return step["returncode"]


def export_freecad_document(document_path: Path, output_path: Path, run_dir: Path) -> dict:
    freecad_cmd = resolve_freecad_cmd()
    if not freecad_cmd:
        return {
            "cmd": [],
            "returncode": 127,
            "stdout": "",
            "stderr": "FreeCAD command runtime not found.",
            "ok": False,
        }

    script_path = run_dir / "freecad_export_step.py"
    write_text(
        script_path,
        "\n".join(
            [
                "import sys",
                "import FreeCAD",
                "import Import",
                "",
                "document_path = sys.argv[1]",
                "output_path = sys.argv[2]",
                "doc = FreeCAD.openDocument(document_path)",
                "doc.recompute()",
                "Import.export(doc.Objects, output_path)",
                'print(output_path)',
            ]
        )
        + "\n",
    )
    return run([freecad_cmd, str(script_path), str(document_path), str(output_path)], ok_codes=(0,))


def command_ecad_mcad_sync(args: argparse.Namespace) -> int:
    started_at = time.time()
    board = Path(args.board).expanduser().resolve() if args.board else guess_board_from_source(args.source_path)
    schematic = (
        Path(args.schematic).expanduser().resolve() if args.schematic else guess_schematic_from_source(args.source_path)
    )
    freecad_document = (
        Path(args.freecad_document).expanduser().resolve()
        if args.freecad_document
        else guess_freecad_document(args.source_path)
    )
    run_dir = make_run_dir("ecad-mcad-sync")
    surface = infer_surface(board=board, schematic=schematic, freecad_document=freecad_document)
    context = build_context_record(
        surface,
        source_path=args.source_path,
        board=board,
        schematic=schematic,
        freecad_document=freecad_document,
        artifacts_dir=run_dir,
    )
    context_path = write_context_record(run_dir / "context.json", context)
    kicad_cli = resolve_kicad_cli()
    sync_payload: dict[str, object] = {
        "action": "ecad-mcad-sync",
        "board": str(board) if board else "",
        "schematic": str(schematic) if schematic else "",
        "freecad_document": str(freecad_document) if freecad_document else "",
        "artifacts_dir": str(run_dir),
        "context": context,
        "steps": [],
    }
    summary_lines = ["# YiACAD ECAD/MCAD Sync", ""]
    rc_final = 0

    if board:
        board_step = run_dir / f"{board.stem}.step"
        step = run(
            [
                kicad_cli,
                "pcb",
                "export",
                "step",
                "--output",
                str(board_step),
                str(board),
            ],
            ok_codes=(0,),
        )
        write_text(run_dir / "kicad_step.stdout.txt", step["stdout"])
        write_text(run_dir / "kicad_step.stderr.txt", step["stderr"])
        sync_payload["steps"].append(step)
        summary_lines.append(f"- KiCad STEP export: `{board_step}` (rc={step['returncode']})")
        if not step["ok"]:
            rc_final = step["returncode"]

    if freecad_document:
        freecad_step = run_dir / f"{freecad_document.stem}.step"
        step = export_freecad_document(freecad_document, freecad_step, run_dir)
        write_text(run_dir / "freecad_step.stdout.txt", step["stdout"])
        write_text(run_dir / "freecad_step.stderr.txt", step["stderr"])
        sync_payload["steps"].append(step)
        summary_lines.append(f"- FreeCAD STEP export: `{freecad_step}` (rc={step['returncode']})")
        if not step["ok"] and rc_final == 0:
            rc_final = step["returncode"]

    if schematic:
        summary_lines.append(f"- Linked schematic: `{schematic}`")
    if board:
        summary_lines.append(f"- Linked board: `{board}`")
    if freecad_document:
        summary_lines.append(f"- Linked FreeCAD document: `{freecad_document}`")
    if not board and not freecad_document:
        summary_lines.append("- No board or FreeCAD document could be resolved.")
        rc_final = rc_final or 2

    write_text(run_dir / "summary.md", "\n".join(summary_lines) + "\n")
    sync_payload["summary"] = str(run_dir / "summary.md")
    status, severity = output_status_from_returncodes([step["returncode"] for step in sync_payload["steps"]])
    if not board and not freecad_document:
        status, severity = ("blocked", "error")
    next_steps = {
        "done": ["open exported STEP artifacts", "continue with physical fit review"],
        "degraded": ["inspect generated exports", "rerun with both ECAD and MCAD files present"],
        "blocked": ["verify KiCad and FreeCAD project files", "rerun sync with complete context"],
    }[status]
    artifacts = [
        artifact_entry(run_dir / "summary.md", "report", "YiACAD ECAD/MCAD sync summary"),
        artifact_entry(context_path, "evidence", "YiACAD context record"),
        artifact_entry(run_dir / "result.json", "evidence", "YiACAD raw payload"),
    ]
    for name, label, kind in (
        ("kicad_step.stdout.txt", "KiCad STEP stdout", "log"),
        ("kicad_step.stderr.txt", "KiCad STEP stderr", "log"),
        ("freecad_step.stdout.txt", "FreeCAD STEP stdout", "log"),
        ("freecad_step.stderr.txt", "FreeCAD STEP stderr", "log"),
    ):
        path = run_dir / name
        if path.exists():
            artifacts.append(artifact_entry(path, kind, label))
    for step_path in run_dir.glob("*.step"):
        artifacts.append(artifact_entry(step_path, "export", f"STEP export: {step_path.name}"))
    output_payload = build_uiux_output(
        surface=surface,
        action="sync.ecad_mcad",
        execution_mode="batch",
        status=status,
        severity=severity,
        summary="YiACAD ECAD/MCAD sync completed.",
        details=f"Board={board or 'unresolved'} | FreeCAD={freecad_document or 'unresolved'} | Artifacts={run_dir}",
        context_ref=context["context_ref"],
        artifacts=artifacts,
        next_steps=next_steps,
        latency_ms=int((time.time() - started_at) * 1000),
    )
    output_path = write_uiux_output(run_dir / "uiux_output.json", output_payload)
    sync_payload["uiux_output"] = str(output_path)
    write_json(run_dir / "result.json", sync_payload)
    print_contract_or_fallback(args, output_payload, run_dir / "summary.md")
    return rc_final


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="YiACAD native concrete CAD utilities")
    subparsers = parser.add_subparsers(dest="command", required=True)
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument(
        "--json-output",
        action="store_true",
        help="Emit the normalized YiACAD UI/UX output JSON instead of the default path output",
    )

    status = subparsers.add_parser("status", parents=[common], help="Show YiACAD fusion and native surface status")
    status.set_defaults(func=command_status)

    erc_drc = subparsers.add_parser("kicad-erc-drc", parents=[common], help="Run KiCad ERC and DRC reports")
    erc_drc.add_argument("--source-path", default="", help="Any project path to infer KiCad files from")
    erc_drc.add_argument("--board", default="", help="Path to .kicad_pcb")
    erc_drc.add_argument("--schematic", default="", help="Path to .kicad_sch")
    erc_drc.set_defaults(func=command_kicad_erc_drc)

    bom = subparsers.add_parser("bom-review", parents=[common], help="Export and summarize a KiCad BOM")
    bom.add_argument("--source-path", default="", help="Any project path to infer schematic from")
    bom.add_argument("--schematic", default="", help="Path to .kicad_sch")
    bom.set_defaults(func=command_bom_review)

    sync = subparsers.add_parser("ecad-mcad-sync", parents=[common], help="Export KiCad and FreeCAD STEP artifacts for sync")
    sync.add_argument("--source-path", default="", help="Any project path to infer paired files from")
    sync.add_argument("--board", default="", help="Path to .kicad_pcb")
    sync.add_argument("--schematic", default="", help="Path to .kicad_sch")
    sync.add_argument("--freecad-document", default="", help="Path to .FCStd")
    sync.set_defaults(func=command_ecad_mcad_sync)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
