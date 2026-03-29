#!/usr/bin/env python3
"""Validate repo specs as a CLI and as a minimal MCP stdio server."""

from __future__ import annotations

import argparse
import importlib
import importlib.util
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict


ROOT = Path(__file__).resolve().parents[1]
CANONICAL_SPECS_DIR = ROOT / "specs"
MIRROR_SPECS_DIR = ROOT / "ai-agentic-embedded-base" / "specs"
RFC2119_TERMS = ("MUST", "SHOULD", "MAY")
RFC2119_FORBIDDEN = ("must", "should", "may", "Must", "Should", "May")


def run_repo_command(args: list[str]) -> Dict[str, Any]:
    proc = subprocess.run(
        args,
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    return {
        "ok": proc.returncode == 0,
        "returncode": proc.returncode,
        "stdout": proc.stdout.strip(),
        "stderr": proc.stderr.strip(),
    }


def check_runtime_dependencies() -> Dict[str, Any]:
    has_yaml = importlib.util.find_spec("yaml") is not None
    import_error = ""
    if has_yaml:
        try:
            importlib.import_module("yaml")
        except Exception as exc:  # pragma: no cover - runtime environment specific
            has_yaml = False
            import_error = str(exc)
    return {
        "pyyaml": {
            "ok": has_yaml,
            "hint": "Install with: python3 -m pip install PyYAML",
            "import_error": import_error,
        }
    }


def scan_rfc2119() -> Dict[str, Any]:
    files = sorted(CANONICAL_SPECS_DIR.rglob("*.md"))
    counts = {term: 0 for term in RFC2119_TERMS}
    forbidden_matches: list[str] = []
    file_summary: Dict[str, Dict[str, Any]] = {}

    for file_path in files:
        text = file_path.read_text(encoding="utf-8")
        relative = file_path.relative_to(ROOT).as_posix()
        file_summary[relative] = {
            term: len(re.findall(rf"\b{term}\b", text)) for term in RFC2119_TERMS
        }
        file_summary[relative]["forbidden"] = []

        for term in RFC2119_TERMS:
            counts[term] += file_summary[relative][term]

        for forbidden in RFC2119_FORBIDDEN:
            matches = re.findall(rf"\b{forbidden}\b", text)
            if matches:
                forbidden_matches.extend(matches)
                file_summary[relative]["forbidden"].extend(matches)

    return {
        "spec_file_count": len(files),
        "counts": counts,
        "forbidden": forbidden_matches,
        "files": file_summary,
        "ok": len(files) > 0 and not forbidden_matches,
    }


def compare_spec_mirror() -> Dict[str, Any]:
    if not MIRROR_SPECS_DIR.exists():
        return {
            "ok": False,
            "mirror_exists": False,
            "missing_in_mirror": [],
            "extra_in_mirror": [],
            "content_mismatch": [],
        }

    canonical_files = {p.relative_to(CANONICAL_SPECS_DIR).as_posix(): p for p in CANONICAL_SPECS_DIR.rglob("*") if p.is_file()}
    mirror_files = {p.relative_to(MIRROR_SPECS_DIR).as_posix(): p for p in MIRROR_SPECS_DIR.rglob("*") if p.is_file()}

    missing_in_mirror = sorted(set(canonical_files) - set(mirror_files))
    extra_in_mirror = sorted(set(mirror_files) - set(canonical_files))
    shared = sorted(set(canonical_files) & set(mirror_files))

    content_mismatch: list[str] = []
    for relative in shared:
        if canonical_files[relative].read_bytes() != mirror_files[relative].read_bytes():
            content_mismatch.append(relative)

    return {
        "ok": not missing_in_mirror and not extra_in_mirror and not content_mismatch,
        "mirror_exists": True,
        "missing_in_mirror": missing_in_mirror,
        "extra_in_mirror": extra_in_mirror,
        "content_mismatch": content_mismatch,
        "canonical_file_count": len(canonical_files),
        "mirror_file_count": len(mirror_files),
    }


def validate_agent_catalog_contract() -> Dict[str, Any]:
    module_path = ROOT / "tools" / "specs" / "validate_agent_catalog.py"
    spec = importlib.util.spec_from_file_location("validate_agent_catalog", module_path)
    if spec is None or spec.loader is None:
        return {
            "ok": False,
            "errors": ["agent-catalog-validator-load-failed"],
        }
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.validate_agent_catalog(repo_root=ROOT)


def validate_specs(
    strict: bool = False, require_mirror_sync: bool = False
) -> Dict[str, Any]:
    required_files = [
        "specs/03_plan.md",
        "specs/04_tasks.md",
        "compliance/plan.yaml",
    ]
    missing_files = [path for path in required_files if not (ROOT / path).exists()]

    dependencies = check_runtime_dependencies()
    if dependencies["pyyaml"]["ok"]:
        compliance_cmd = [sys.executable, str(ROOT / "tools/compliance/validate.py")]
        if strict:
            compliance_cmd.append("--strict")
        compliance = run_repo_command(compliance_cmd)
    else:
        dep_hint = dependencies["pyyaml"]["hint"]
        dep_err = dependencies["pyyaml"].get("import_error", "")
        details = f" ({dep_err})" if dep_err else ""
        compliance = {
            "ok": False,
            "returncode": 127,
            "stdout": "",
            "stderr": f"PyYAML dependency missing; cannot run compliance validator. {dep_hint}{details}",
        }

    rfc2119 = scan_rfc2119()
    mirror_sync = compare_spec_mirror()
    agent_catalog = validate_agent_catalog_contract()

    ok = (
        not missing_files
        and compliance["ok"]
        and rfc2119["ok"]
        and (mirror_sync["ok"] or not require_mirror_sync)
        and agent_catalog["ok"]
    )
    return {
        "ok": ok,
        "missing_files": missing_files,
        "strict": strict,
        "require_mirror_sync": require_mirror_sync,
        "compliance": compliance,
        "dependencies": dependencies,
        "rfc2119": rfc2119,
        "mirror_sync": mirror_sync,
        "agent_catalog": agent_catalog,
    }


def format_cli_summary(result: Dict[str, Any]) -> str:
    status = "OK" if result["ok"] else "FAIL"
    compliance = result["compliance"]
    rfc2119 = result["rfc2119"]
    mirror_sync = result["mirror_sync"]
    lines = [
        f"{status}: spec validation",
        f"- missing files: {len(result['missing_files'])}",
        f"- compliance ok: {compliance['ok']}",
        f"- PyYAML available: {result.get('dependencies', {}).get('pyyaml', {}).get('ok', True)}",
        (
            "- RFC2119 counts: "
            f"MUST={rfc2119['counts']['MUST']} "
            f"SHOULD={rfc2119['counts']['SHOULD']} "
            f"MAY={rfc2119['counts']['MAY']}"
        ),
        f"- RFC2119 forbidden terms: {len(rfc2119['forbidden'])}",
        (
            "- mirror sync: "
            f"missing={len(mirror_sync['missing_in_mirror'])} "
            f"extra={len(mirror_sync['extra_in_mirror'])} "
            f"mismatch={len(mirror_sync['content_mismatch'])}"
        ),
        (
            "- agent catalog: "
            f"ok={result['agent_catalog']['ok']} "
            f"agents={result['agent_catalog']['agent_count']} "
            f"missing_files={len(result['agent_catalog']['missing_files'])} "
            f"invalid_owner_refs={len(result['agent_catalog']['invalid_owner_refs'])}"
        ),
    ]

    if result["missing_files"]:
        lines.append("- missing: " + ", ".join(result["missing_files"]))
    if mirror_sync["missing_in_mirror"]:
        lines.append("- mirror missing: " + ", ".join(mirror_sync["missing_in_mirror"]))
    if mirror_sync["extra_in_mirror"]:
        lines.append("- mirror extra: " + ", ".join(mirror_sync["extra_in_mirror"]))
    if mirror_sync["content_mismatch"]:
        lines.append("- mirror mismatch: " + ", ".join(mirror_sync["content_mismatch"]))
    if compliance["stdout"]:
        lines.append("- compliance stdout: " + compliance["stdout"])
    if compliance["stderr"]:
        lines.append("- compliance stderr: " + compliance["stderr"])
    if result["agent_catalog"]["errors"]:
        lines.append("- agent catalog errors: " + ", ".join(result["agent_catalog"]["errors"]))

    return "\n".join(lines)


def tool_validate_specs(arguments: Dict[str, Any]) -> Dict[str, Any]:
    strict = bool(arguments.get("strict", False))
    require_mirror_sync = bool(arguments.get("require_mirror_sync", False))
    result = validate_specs(
        strict=strict, require_mirror_sync=require_mirror_sync
    )
    return {
        "content": [{"type": "text", "text": format_cli_summary(result)}],
        "structuredContent": result,
        "isError": not result["ok"],
    }


def tool_scan_rfc2119(_: Dict[str, Any]) -> Dict[str, Any]:
    result = scan_rfc2119()
    summary = (
        "RFC2119 summary: "
        f"MUST={result['counts']['MUST']} "
        f"SHOULD={result['counts']['SHOULD']} "
        f"MAY={result['counts']['MAY']} "
        f"forbidden={len(result['forbidden'])}"
    )
    return {
        "content": [{"type": "text", "text": summary}],
        "structuredContent": result,
        "isError": not result["ok"],
    }


TOOLS = [
    {
        "name": "validate_specs",
        "description": "Validate Kill_LIFE spec structure, compliance profile and RFC2119 usage.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "strict": {
                    "type": "boolean",
                    "description": "Enable strict evidence checks from tools/compliance/validate.py.",
                    "default": False,
                },
                "require_mirror_sync": {
                    "type": "boolean",
                    "description": "Fail if ai-agentic-embedded-base/specs is not synced with specs/.",
                    "default": False,
                }
            },
        },
    },
    {
        "name": "scan_rfc2119",
        "description": "Summarize RFC2119 keywords across specs/*.md without writing files.",
        "inputSchema": {"type": "object", "properties": {}},
    },
]


def make_response(request_id: Any, result: Dict[str, Any]) -> Dict[str, Any]:
    return {"jsonrpc": "2.0", "id": request_id, "result": result}


def make_error(request_id: Any, code: int, message: str) -> Dict[str, Any]:
    return {"jsonrpc": "2.0", "id": request_id, "error": {"code": code, "message": message}}


def read_message() -> Dict[str, Any] | None:
    headers: Dict[str, str] = {}
    while True:
        line = sys.stdin.buffer.readline()
        if not line:
            return None
        if line in (b"\r\n", b"\n"):
            break
        key, _, value = line.decode("utf-8").partition(":")
        headers[key.strip().lower()] = value.strip()

    content_length = int(headers.get("content-length", "0"))
    if content_length <= 0:
        return None

    body = sys.stdin.buffer.read(content_length)
    if not body:
        return None

    return json.loads(body.decode("utf-8"))


def write_message(message: Dict[str, Any]) -> None:
    payload = json.dumps(message).encode("utf-8")
    sys.stdout.buffer.write(f"Content-Length: {len(payload)}\r\n\r\n".encode("utf-8"))
    sys.stdout.buffer.write(payload)
    sys.stdout.buffer.flush()


def serve_mcp() -> int:
    while True:
        request = read_message()
        if request is None:
            return 0

        method = request.get("method")
        request_id = request.get("id")
        params = request.get("params") or {}

        if method == "initialize":
            write_message(
                make_response(
                    request_id,
                    {
                        "protocolVersion": "2025-03-26",
                        "capabilities": {"tools": {"listChanged": False}},
                        "serverInfo": {
                            "name": "validate-specs",
                            "version": "1.0.0",
                        },
                    },
                )
            )
            continue

        if method == "notifications/initialized":
            continue

        if method == "ping":
            write_message(make_response(request_id, {}))
            continue

        if method == "tools/list":
            write_message(make_response(request_id, {"tools": TOOLS}))
            continue

        if method == "tools/call":
            tool_name = params.get("name")
            arguments = params.get("arguments") or {}

            if tool_name == "validate_specs":
                write_message(make_response(request_id, tool_validate_specs(arguments)))
                continue

            if tool_name == "scan_rfc2119":
                write_message(make_response(request_id, tool_scan_rfc2119(arguments)))
                continue

            write_message(make_error(request_id, -32602, f"Unknown tool: {tool_name}"))
            continue

        if request_id is not None:
            write_message(make_error(request_id, -32601, f"Method not found: {method}"))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate Kill_LIFE specs")
    parser.add_argument("--strict", action="store_true", help="Enable strict compliance evidence validation.")
    parser.add_argument(
        "--require-mirror-sync",
        action="store_true",
        help="Fail if ai-agentic-embedded-base/specs is not synchronized with specs/.",
    )
    parser.add_argument("--json", action="store_true", help="Print JSON output in CLI mode.")
    parser.add_argument("--mcp", action="store_true", help="Run as an MCP stdio server.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.mcp:
        return serve_mcp()

    result = validate_specs(
        strict=args.strict, require_mirror_sync=args.require_mirror_sync
    )
    if args.json:
        print(json.dumps(result, indent=2, ensure_ascii=False))
    else:
        print(format_cli_summary(result))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
