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
        collect_engine_reasons,
        detect_integrated_engines,
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
        collect_engine_reasons,
        detect_integrated_engines,
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


def requested_surface(args: argparse.Namespace, fallback: str) -> str:
    return getattr(args, "surface", "") or fallback


def blocked_output_from_runtime(
    *,
    args: argparse.Namespace,
    run_dir: Path,
    context_path: Path,
    surface: str,
    action: str,
    summary: str,
    details: str,
    context_ref: str | None,
    next_steps: list[str],
    engine_status: dict,
    degraded_reasons: list[str],
) -> tuple[int, dict]:
    output_payload = build_uiux_output(
        surface=surface,
        action=action,
        execution_mode="batch",
        status="blocked",
        severity="error",
        summary=summary,
        details=details,
        context_ref=context_ref,
        artifacts=[
            artifact_entry(context_path, "evidence", "YiACAD context record"),
            artifact_entry(run_dir / "result.json", "evidence", "YiACAD raw payload"),
        ],
        next_steps=next_steps,
        latency_ms=None,
        degraded_reasons=degraded_reasons,
        engine_status=engine_status,
    )
    output_path = write_uiux_output(run_dir / "uiux_output.json", output_payload)
    return 2, {"output_payload": output_payload, "output_path": str(output_path)}


def parse_json_text(raw: str) -> dict | None:
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        return None
    return parsed if isinstance(parsed, dict) else None


def append_unique(items: list[str], value: str | None) -> None:
    if value and value not in items:
        items.append(value)


def extend_unique(items: list[str], values: Iterable[str]) -> None:
    for value in values:
        append_unique(items, value)


def normalize_fab_status(status: str | None) -> tuple[str, str]:
    mapping = {
        "ready": ("done", "info"),
        "degraded": ("degraded", "warning"),
        "blocked": ("blocked", "error"),
    }
    return mapping.get(status or "", ("blocked", "error"))


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
    engine_status = detect_integrated_engines()
    degraded_reasons = collect_engine_reasons(engine_status)
    lines = ["# YiACAD Native Status", ""]
    if FUSION_STATUS.exists():
        lines += ["## Fusion lane", "", FUSION_STATUS.read_text(encoding="utf-8").strip(), ""]
    else:
        lines += ["## Fusion lane", "", "No fusion status snapshot found.", ""]
    lines += ["## Integrated engines", ""]
    for key, entry in engine_status.items():
        lines.append(
            f"- {entry['name']}: status={entry['status']} version={entry.get('detected_version') or 'unknown'} "
            f"required={entry.get('required_version') or 'n/a'}"
        )
    lines += [""]
    lines += ["## Native surfaces", "", latest_native_summary(), ""]
    status = "done" if (FUSION_STATUS.exists() or ARTIFACTS_ROOT.exists()) and not degraded_reasons else "degraded"
    severity = "info" if status == "done" else "warning"
    output_payload = build_uiux_output(
        surface=requested_surface(args, "tui"),
        action="status.surface",
        execution_mode="batch",
        status=status,
        severity=severity,
        summary="YiACAD native status snapshot generated.",
        details="Fusion lane snapshot, latest native summaries and integrated engine health were collected.",
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
        degraded_reasons=degraded_reasons,
        engine_status=engine_status,
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
    surface = requested_surface(args, infer_surface(board=board, schematic=schematic))
    engine_status = detect_integrated_engines()
    relevant_engines = {"kicad"}
    degraded_reasons = collect_engine_reasons(engine_status, relevant_engines)
    context = build_context_record(
        surface,
        source_path=args.source_path,
        board=board,
        schematic=schematic,
        artifacts_dir=run_dir,
        integrated_engines=engine_status,
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
    if engine_status["kicad"]["status"] == "blocked":
        rc, blocked = blocked_output_from_runtime(
            args=args,
            run_dir=run_dir,
            context_path=context_path,
            surface=surface,
            action="review.erc_drc",
            summary="YiACAD could not start KiCad review because the KiCad runtime baseline is not met.",
            details="Install KiCad 10+ with the YiACAD AI layer available to the local runtime, then rerun the review.",
            context_ref=context["context_ref"],
            next_steps=[
                "install or upgrade KiCad to 10+",
                "verify kicad-cli is available",
                "rerun the review",
            ],
            engine_status=engine_status,
            degraded_reasons=degraded_reasons or ["kicad-runtime-unavailable"],
        )
        payload["uiux_output"] = blocked["output_path"]
        write_json(run_dir / "result.json", payload)
        print_contract_or_fallback(args, blocked["output_payload"], run_dir / "result.json")
        return rc

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
            degraded_reasons=(degraded_reasons + ["missing-kicad-input"]),
            engine_status=engine_status,
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
    degraded_reasons = collect_engine_reasons(engine_status, relevant_engines)
    if status == "degraded":
        degraded_reasons.append("kicad-violations-present")
    elif status == "blocked":
        degraded_reasons.append("kicad-command-failed")
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
        degraded_reasons=degraded_reasons,
        engine_status=engine_status,
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
    surface = requested_surface(args, infer_surface(schematic=schematic))
    engine_status = detect_integrated_engines()
    relevant_engines = {"kicad", "kibot"}
    degraded_reasons = collect_engine_reasons(engine_status, relevant_engines)
    context = build_context_record(
        surface,
        source_path=args.source_path,
        schematic=schematic,
        artifacts_dir=run_dir,
        integrated_engines=engine_status,
    )
    context_path = write_context_record(run_dir / "context.json", context)
    if engine_status["kicad"]["status"] == "blocked":
        rc, blocked = blocked_output_from_runtime(
            args=args,
            run_dir=run_dir,
            context_path=context_path,
            surface=surface,
            action="review.bom",
            summary="YiACAD could not start BOM review because the KiCad runtime baseline is not met.",
            details="Install or upgrade KiCad 10+ before running YiACAD BOM review.",
            context_ref=context["context_ref"],
            next_steps=[
                "install or upgrade KiCad to 10+",
                "verify kicad-cli is available",
                "rerun BOM review",
            ],
            engine_status=engine_status,
            degraded_reasons=degraded_reasons or ["kicad-runtime-unavailable"],
        )
        write_json(run_dir / "result.json", {"action": "bom-review", "context": context, "uiux_output": blocked["output_path"]})
        print_contract_or_fallback(args, blocked["output_payload"], run_dir / "result.json")
        return rc

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
            degraded_reasons=(degraded_reasons + ["missing-kicad-schematic"]),
            engine_status=engine_status,
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
    degraded_reasons = collect_engine_reasons(engine_status, relevant_engines)
    if engine_status["kibot"]["status"] != "done":
        degraded_reasons.append("kibot-runtime-not-ready")
    if status == "blocked":
        degraded_reasons.append("bom-export-failed")
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
        degraded_reasons=degraded_reasons,
        engine_status=engine_status,
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
    surface = requested_surface(args, infer_surface(board=board, schematic=schematic, freecad_document=freecad_document))
    engine_status = detect_integrated_engines()
    relevant_engines = {"kicad", "freecad"}
    degraded_reasons = collect_engine_reasons(engine_status, relevant_engines)
    context = build_context_record(
        surface,
        source_path=args.source_path,
        board=board,
        schematic=schematic,
        freecad_document=freecad_document,
        artifacts_dir=run_dir,
        integrated_engines=engine_status,
    )
    context_path = write_context_record(run_dir / "context.json", context)
    if board and engine_status["kicad"]["status"] == "blocked":
        rc, blocked = blocked_output_from_runtime(
            args=args,
            run_dir=run_dir,
            context_path=context_path,
            surface=surface,
            action="sync.ecad_mcad",
            summary="YiACAD could not export the ECAD side because the KiCad runtime baseline is not met.",
            details="Install or upgrade KiCad 10+ before running ECAD/MCAD sync with board exports.",
            context_ref=context["context_ref"],
            next_steps=[
                "install or upgrade KiCad to 10+",
                "verify kicad-cli is available",
                "rerun sync",
            ],
            engine_status=engine_status,
            degraded_reasons=degraded_reasons or ["kicad-runtime-unavailable"],
        )
        write_json(run_dir / "result.json", {"action": "ecad-mcad-sync", "context": context, "uiux_output": blocked["output_path"]})
        print_contract_or_fallback(args, blocked["output_payload"], run_dir / "result.json")
        return rc
    if freecad_document and engine_status["freecad"]["status"] == "blocked":
        rc, blocked = blocked_output_from_runtime(
            args=args,
            run_dir=run_dir,
            context_path=context_path,
            surface=surface,
            action="sync.ecad_mcad",
            summary="YiACAD could not export the MCAD side because the FreeCAD runtime baseline is not met.",
            details="Install or upgrade FreeCAD 1.1+ before running ECAD/MCAD sync with MCAD exports.",
            context_ref=context["context_ref"],
            next_steps=[
                "install or upgrade FreeCAD to 1.1+",
                "verify FreeCADCmd is available",
                "rerun sync",
            ],
            engine_status=engine_status,
            degraded_reasons=degraded_reasons or ["freecad-runtime-unavailable"],
        )
        write_json(run_dir / "result.json", {"action": "ecad-mcad-sync", "context": context, "uiux_output": blocked["output_path"]})
        print_contract_or_fallback(args, blocked["output_payload"], run_dir / "result.json")
        return rc
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
        degraded_reasons.append("missing-ecad-mcad-input")
    elif status == "degraded":
        degraded_reasons.append("partial-sync-artifacts")
    elif status == "blocked":
        degraded_reasons.append("sync-command-failed")
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
        degraded_reasons=degraded_reasons,
        engine_status=engine_status,
    )
    output_path = write_uiux_output(run_dir / "uiux_output.json", output_payload)
    sync_payload["uiux_output"] = str(output_path)
    write_json(run_dir / "result.json", sync_payload)
    print_contract_or_fallback(args, output_payload, run_dir / "summary.md")
    return rc_final


def command_manufacturing_package(args: argparse.Namespace) -> int:
    started_at = time.time()
    board = Path(args.board).expanduser().resolve() if args.board else guess_board_from_source(args.source_path)
    schematic = (
        Path(args.schematic).expanduser().resolve() if args.schematic else guess_schematic_from_source(args.source_path)
    )
    kibot_config = Path(args.kibot_config).expanduser().resolve() if getattr(args, "kibot_config", "") else None
    run_dir = make_run_dir("manufacturing-package")
    surface = requested_surface(args, infer_surface(board=board, schematic=schematic))
    engine_status = detect_integrated_engines()
    relevant_engines = {"kicad", "kibot"}
    degraded_reasons = collect_engine_reasons(engine_status, relevant_engines)
    context = build_context_record(
        surface,
        source_path=args.source_path,
        board=board,
        schematic=schematic,
        artifacts_dir=run_dir,
        integrated_engines=engine_status,
    )
    context_path = write_context_record(run_dir / "context.json", context)
    payload: dict[str, object] = {
        "action": "manufacturing-package",
        "board": str(board) if board else "",
        "schematic": str(schematic) if schematic else "",
        "kibot_config": str(kibot_config) if kibot_config else "",
        "artifacts_dir": str(run_dir),
        "context": context,
        "steps": [],
    }

    if not board and not schematic:
        rc, blocked = blocked_output_from_runtime(
            args=args,
            run_dir=run_dir,
            context_path=context_path,
            surface=surface,
            action="manufacturing.export",
            summary="YiACAD could not build a manufacturing package because no KiCad inputs were resolved.",
            details="Provide --board, --schematic or a valid --source-path with KiCad project files present.",
            context_ref=context["context_ref"],
            next_steps=[
                "provide --board or --schematic",
                "rerun manufacturing export",
            ],
            engine_status=engine_status,
            degraded_reasons=degraded_reasons + ["missing-manufacturing-input"],
        )
        payload["uiux_output"] = blocked["output_path"]
        write_json(run_dir / "result.json", payload)
        print_contract_or_fallback(args, blocked["output_payload"], run_dir / "result.json")
        return rc

    if engine_status["kicad"]["status"] == "blocked":
        rc, blocked = blocked_output_from_runtime(
            args=args,
            run_dir=run_dir,
            context_path=context_path,
            surface=surface,
            action="manufacturing.export",
            summary="YiACAD could not build a manufacturing package because the KiCad runtime baseline is not met.",
            details="Install or upgrade KiCad 10+ before running YiACAD manufacturing export.",
            context_ref=context["context_ref"],
            next_steps=[
                "install or upgrade KiCad to 10+",
                "verify kicad-cli is available",
                "rerun manufacturing export",
            ],
            engine_status=engine_status,
            degraded_reasons=degraded_reasons or ["kicad-runtime-unavailable"],
        )
        payload["uiux_output"] = blocked["output_path"]
        write_json(run_dir / "result.json", payload)
        print_contract_or_fallback(args, blocked["output_payload"], run_dir / "result.json")
        return rc

    summary_lines = ["# YiACAD Manufacturing Package", ""]
    direct_kibot_dir = run_dir / "kibot"
    direct_kibot_step: dict | None = None

    if board and engine_status["kibot"]["available"] and kibot_config and kibot_config.exists():
        ensure_dir(direct_kibot_dir)
        direct_kibot_step = run(
            [
                str(engine_status["kibot"]["binary"]),
                "-b",
                str(board),
                "-c",
                str(kibot_config),
                "-d",
                str(direct_kibot_dir),
            ],
            ok_codes=(0,),
        )
        write_text(run_dir / "kibot.stdout.txt", direct_kibot_step["stdout"])
        write_text(run_dir / "kibot.stderr.txt", direct_kibot_step["stderr"])
        payload["steps"].append(direct_kibot_step)
        summary_lines.append(
            f"- KiBot direct export: `{direct_kibot_dir}` (rc={direct_kibot_step['returncode']})"
        )
        if not direct_kibot_step["ok"]:
            append_unique(degraded_reasons, "kibot-direct-run-failed")
    elif board and engine_status["kibot"]["available"] and kibot_config and not kibot_config.exists():
        append_unique(degraded_reasons, "kibot-config-missing")
    elif board and engine_status["kibot"]["available"] and not kibot_config:
        append_unique(degraded_reasons, "kibot-config-missing")

    fab_step = run(
        [
            "bash",
            str(ROOT / "tools" / "cockpit" / "fab_package_tui.sh"),
            "--action",
            "build",
            "--json",
            "--mode",
            "live",
            "--schematic",
            str(schematic) if schematic else "",
            "--board",
            str(board) if board else "",
        ],
        ok_codes=(0,),
    )
    write_text(run_dir / "fab_package.stdout.txt", fab_step["stdout"])
    write_text(run_dir / "fab_package.stderr.txt", fab_step["stderr"])
    payload["steps"].append(fab_step)
    fab_payload = parse_json_text(fab_step["stdout"])
    if fab_payload:
        payload["fab_package"] = fab_payload
        summary_lines.append(f"- Fab package status: `{fab_payload.get('status', 'unknown')}`")
        summary_lines.append(f"- Fab route origin: `{fab_payload.get('route_origin', 'local')}`")
    else:
        append_unique(degraded_reasons, "fab-package-unparseable")

    status = "blocked"
    severity = "error"
    if fab_step["ok"] and fab_payload:
        status, severity = normalize_fab_status(str(fab_payload.get("status")))
        extend_unique(degraded_reasons, list(fab_payload.get("degraded_reasons") or []))
        if status == "done" and degraded_reasons:
            status, severity = ("degraded", "warning")
    else:
        append_unique(degraded_reasons, "fab-package-command-failed")

    next_steps: list[str] = []
    if fab_payload:
        extend_unique(next_steps, list(fab_payload.get("next_steps") or []))
    if not next_steps:
        next_steps = [
            "open manufacturing artifacts",
            "inspect package acceptance gates",
            "rerun manufacturing export after fixing blockers",
        ]

    for resolved in (("board", board), ("schematic", schematic), ("kibot_config", kibot_config)):
        label, path = resolved
        summary_lines.append(f"- {label}: `{path}`" if path else f"- {label}: unresolved")
    write_text(run_dir / "summary.md", "\n".join(summary_lines) + "\n")
    payload["summary"] = str(run_dir / "summary.md")

    artifacts = [
        artifact_entry(run_dir / "summary.md", "report", "YiACAD manufacturing package summary"),
        artifact_entry(context_path, "evidence", "YiACAD context record"),
        artifact_entry(run_dir / "result.json", "evidence", "YiACAD raw payload"),
        artifact_entry(run_dir / "fab_package.stdout.txt", "log", "Fab package stdout"),
        artifact_entry(run_dir / "fab_package.stderr.txt", "log", "Fab package stderr"),
    ]
    if direct_kibot_step:
        artifacts.append(artifact_entry(run_dir / "kibot.stdout.txt", "log", "KiBot stdout"))
        artifacts.append(artifact_entry(run_dir / "kibot.stderr.txt", "log", "KiBot stderr"))
    if direct_kibot_dir.exists():
        artifacts.append(artifact_entry(direct_kibot_dir, "export", "KiBot output directory"))
    if fab_payload:
        for key, label, kind in (
            ("bom_file", "BOM export", "export"),
            ("cpl_file", "CPL export", "export"),
            ("gerber_dir", "Gerber bundle", "export"),
            ("drill_file", "Drill export", "export"),
            ("drc_report", "Manufacturing review report", "report"),
            ("netlist_file", "Netlist export", "export"),
        ):
            value = fab_payload.get(key)
            if value:
                artifacts.append(artifact_entry(value, kind, label))
        for path in fab_payload.get("review_artifacts") or []:
            artifacts.append(artifact_entry(path, "report", "Review artifact"))
        for item in fab_payload.get("artifacts") or []:
            path = item.get("path") if isinstance(item, dict) else None
            if path:
                artifacts.append(artifact_entry(path, "export", "Fab package artifact"))

    output_payload = build_uiux_output(
        surface=surface,
        action="manufacturing.export",
        execution_mode="batch",
        status=status,
        severity=severity,
        summary="YiACAD manufacturing package run completed.",
        details=f"Board={board or 'unresolved'} | Schematic={schematic or 'unresolved'} | Artifacts={run_dir}",
        context_ref=context["context_ref"],
        artifacts=artifacts,
        next_steps=next_steps,
        latency_ms=int((time.time() - started_at) * 1000),
        degraded_reasons=degraded_reasons,
        engine_status=engine_status,
    )
    output_path = write_uiux_output(run_dir / "uiux_output.json", output_payload)
    payload["uiux_output"] = str(output_path)
    write_json(run_dir / "result.json", payload)
    print_contract_or_fallback(args, output_payload, run_dir / "summary.md")
    return 0 if status != "blocked" else 1


def command_kiauto_checks(args: argparse.Namespace) -> int:
    started_at = time.time()
    board = Path(args.board).expanduser().resolve() if args.board else guess_board_from_source(args.source_path)
    schematic = (
        Path(args.schematic).expanduser().resolve() if args.schematic else guess_schematic_from_source(args.source_path)
    )
    run_dir = make_run_dir("kiauto-checks")
    surface = requested_surface(args, infer_surface(board=board, schematic=schematic))
    engine_status = detect_integrated_engines()
    relevant_engines = {"kicad", "kiauto"}
    degraded_reasons = collect_engine_reasons(engine_status, relevant_engines)
    context = build_context_record(
        surface,
        source_path=args.source_path,
        board=board,
        schematic=schematic,
        artifacts_dir=run_dir,
        integrated_engines=engine_status,
    )
    context_path = write_context_record(run_dir / "context.json", context)
    payload: dict[str, object] = {
        "action": "kiauto-checks",
        "board": str(board) if board else "",
        "schematic": str(schematic) if schematic else "",
        "artifacts_dir": str(run_dir),
        "context": context,
        "steps": [],
    }

    if not board:
        rc, blocked = blocked_output_from_runtime(
            args=args,
            run_dir=run_dir,
            context_path=context_path,
            surface=surface,
            action="manufacturing.validate",
            summary="YiACAD could not run KiAuto checks because no board was resolved.",
            details="Provide --board or a valid --source-path with a .kicad_pcb present.",
            context_ref=context["context_ref"],
            next_steps=[
                "provide --board",
                "rerun KiAuto checks",
            ],
            engine_status=engine_status,
            degraded_reasons=degraded_reasons + ["missing-kiauto-board"],
        )
        payload["uiux_output"] = blocked["output_path"]
        write_json(run_dir / "result.json", payload)
        print_contract_or_fallback(args, blocked["output_payload"], run_dir / "result.json")
        return rc

    if engine_status["kicad"]["status"] == "blocked" or engine_status["kiauto"]["status"] == "blocked":
        rc, blocked = blocked_output_from_runtime(
            args=args,
            run_dir=run_dir,
            context_path=context_path,
            surface=surface,
            action="manufacturing.validate",
            summary="YiACAD could not run KiAuto checks because the KiCad or KiAuto runtime baseline is not met.",
            details="Install KiCad 10+ and a working KiAuto runtime before rerunning manufacturing validation.",
            context_ref=context["context_ref"],
            next_steps=[
                "install or upgrade KiCad to 10+",
                "install KiAuto in the active environment",
                "rerun KiAuto checks",
            ],
            engine_status=engine_status,
            degraded_reasons=degraded_reasons or ["kiauto-runtime-unavailable"],
        )
        payload["uiux_output"] = blocked["output_path"]
        write_json(run_dir / "result.json", payload)
        print_contract_or_fallback(args, blocked["output_payload"], run_dir / "result.json")
        return rc

    step = run([str(engine_status["kiauto"]["binary"]), "--help"], ok_codes=(0,))
    write_text(run_dir / "kiauto.stdout.txt", step["stdout"])
    write_text(run_dir / "kiauto.stderr.txt", step["stderr"])
    payload["steps"].append(step)

    status, severity = output_status_from_returncodes([step["returncode"]])
    if status == "done" and degraded_reasons:
        status, severity = ("degraded", "warning")
    if status == "blocked":
        append_unique(degraded_reasons, "kiauto-command-failed")

    summary_lines = [
        "# YiACAD KiAuto Checks",
        "",
        f"- board: `{board}`",
        f"- schematic: `{schematic}`" if schematic else "- schematic: unresolved",
        f"- kiauto binary: `{engine_status['kiauto']['binary']}`",
        f"- invocation: `--help` (runtime smoke for service-first validation)",
    ]
    write_text(run_dir / "summary.md", "\n".join(summary_lines) + "\n")
    payload["summary"] = str(run_dir / "summary.md")

    next_steps = {
        "done": ["inspect KiAuto runtime logs", "extend validation with board-specific KiAuto flows"],
        "degraded": ["inspect KiAuto runtime logs", "stabilize KiAuto runtime and rerun"],
        "blocked": ["verify KiAuto installation", "rerun manufacturing validation"],
    }[status]
    artifacts = [
        artifact_entry(run_dir / "summary.md", "report", "YiACAD KiAuto checks summary"),
        artifact_entry(context_path, "evidence", "YiACAD context record"),
        artifact_entry(run_dir / "result.json", "evidence", "YiACAD raw payload"),
        artifact_entry(run_dir / "kiauto.stdout.txt", "log", "KiAuto stdout"),
        artifact_entry(run_dir / "kiauto.stderr.txt", "log", "KiAuto stderr"),
    ]
    output_payload = build_uiux_output(
        surface=surface,
        action="manufacturing.validate",
        execution_mode="batch",
        status=status,
        severity=severity,
        summary="YiACAD KiAuto checks completed.",
        details=f"Board={board} | KiAuto={engine_status['kiauto']['binary']} | Artifacts={run_dir}",
        context_ref=context["context_ref"],
        artifacts=artifacts,
        next_steps=next_steps,
        latency_ms=int((time.time() - started_at) * 1000),
        degraded_reasons=degraded_reasons,
        engine_status=engine_status,
    )
    output_path = write_uiux_output(run_dir / "uiux_output.json", output_payload)
    payload["uiux_output"] = str(output_path)
    write_json(run_dir / "result.json", payload)
    print_contract_or_fallback(args, output_payload, run_dir / "summary.md")
    return 0 if status != "blocked" else 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="YiACAD native concrete CAD utilities")
    subparsers = parser.add_subparsers(dest="command", required=True)
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument(
        "--json-output",
        action="store_true",
        help="Emit the normalized YiACAD UI/UX output JSON instead of the default path output",
    )
    common.add_argument(
        "--surface",
        default="",
        help="Canonical YiACAD client surface override (e.g. yiacad-web, yiacad-desktop, tui)",
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

    package = subparsers.add_parser(
        "manufacturing-package",
        parents=[common],
        help="Build a YiACAD manufacturing package with KiBot/fab outputs",
    )
    package.add_argument("--source-path", default="", help="Any project path to infer KiCad files from")
    package.add_argument("--board", default="", help="Path to .kicad_pcb")
    package.add_argument("--schematic", default="", help="Path to .kicad_sch")
    package.add_argument("--kibot-config", default="", help="Optional path to a KiBot config for direct exports")
    package.set_defaults(func=command_manufacturing_package)

    kiauto = subparsers.add_parser(
        "kiauto-checks",
        parents=[common],
        help="Run YiACAD KiAuto runtime checks",
    )
    kiauto.add_argument("--source-path", default="", help="Any project path to infer KiCad files from")
    kiauto.add_argument("--board", default="", help="Path to .kicad_pcb")
    kiauto.add_argument("--schematic", default="", help="Path to .kicad_sch")
    kiauto.set_defaults(func=command_kiauto_checks)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
