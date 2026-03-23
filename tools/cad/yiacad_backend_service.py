#!/usr/bin/env python3
"""YiACAD local backend service for native surfaces and TUI clients."""

from __future__ import annotations

import argparse
import contextlib
import io
import json
import os
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

try:
    import yiacad_native_ops as native_ops
    from yiacad_backend import artifact_entry, build_uiux_output, utc_timestamp, write_json
except ImportError:
    from tools.cad import yiacad_native_ops as native_ops
    from tools.cad.yiacad_backend import artifact_entry, build_uiux_output, utc_timestamp, write_json


ROOT = Path(__file__).resolve().parents[2]
SERVICE_ARTIFACTS = ROOT / "artifacts" / "cad-ai-native" / "service"
DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 38435


def ensure_dir(path: Path) -> Path:
    path.mkdir(parents=True, exist_ok=True)
    return path


def uiux_contract_from_failure(command: str, error_text: str, request_path: Path | None = None) -> dict:
    artifacts = []
    if request_path:
        artifacts.append(artifact_entry(request_path, "evidence", "YiACAD backend request"))
    return build_uiux_output(
        surface="service",
        action=command,
        execution_mode="background",
        status="blocked",
        severity="error",
        summary="YiACAD backend service could not fulfill the request.",
        details=error_text,
        context_ref=None,
        artifacts=artifacts,
        next_steps=["inspect backend request", "retry the action", "fallback to direct runner"],
        latency_ms=None,
    )


def build_args(command: str, payload: dict) -> argparse.Namespace:
    common = {"command": command, "json_output": True}
    if command == "status":
        return argparse.Namespace(**common)
    if command == "kicad-erc-drc":
        return argparse.Namespace(
            **common,
            source_path=payload.get("source_path", ""),
            board=payload.get("board", ""),
            schematic=payload.get("schematic", ""),
        )
    if command == "bom-review":
        return argparse.Namespace(
            **common,
            source_path=payload.get("source_path", ""),
            schematic=payload.get("schematic", ""),
        )
    if command == "ecad-mcad-sync":
        return argparse.Namespace(
            **common,
            source_path=payload.get("source_path", ""),
            board=payload.get("board", ""),
            schematic=payload.get("schematic", ""),
            freecad_document=payload.get("freecad_document", ""),
        )
    raise KeyError(f"Unsupported YiACAD command: {command}")


def dispatch_command(command: str, payload: dict) -> tuple[int, dict]:
    mapping = {
        "status": native_ops.command_status,
        "kicad-erc-drc": native_ops.command_kicad_erc_drc,
        "bom-review": native_ops.command_bom_review,
        "ecad-mcad-sync": native_ops.command_ecad_mcad_sync,
    }
    handler = mapping[command]
    args = build_args(command, payload)
    stdout = io.StringIO()
    with contextlib.redirect_stdout(stdout):
        rc = handler(args)
    body = stdout.getvalue().strip()
    if body:
        try:
            parsed = json.loads(body)
            if isinstance(parsed, dict):
                return rc, parsed
        except json.JSONDecodeError:
            pass
    contract = build_uiux_output(
        surface="service",
        action=command,
        execution_mode="background",
        status="done" if rc == 0 else "blocked",
        severity="info" if rc == 0 else "error",
        summary=f"YiACAD backend service executed `{command}`.",
        details=body or "No structured response body was returned.",
        context_ref=None,
        artifacts=[],
        next_steps=["inspect service response", "retry via direct runner if needed"],
        latency_ms=None,
    )
    return rc, contract


class YiacadBackendHandler(BaseHTTPRequestHandler):
    server_version = "YiACADBackend/0.1"

    def _json_response(self, status_code: int, payload: dict) -> None:
        raw = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self) -> None:
        if self.path != "/health":
            self._json_response(404, {"status": "not_found"})
            return
        payload = {
            "status": "done",
            "component": "yiacad-backend-service",
            "generated_at": utc_timestamp(),
            "pid": os.getpid(),
            "host": self.server.server_address[0],
            "port": self.server.server_address[1],
            "artifacts_dir": str(SERVICE_ARTIFACTS),
        }
        write_json(SERVICE_ARTIFACTS / "latest_health.json", payload)
        self._json_response(200, payload)

    def do_POST(self) -> None:
        if self.path != "/run":
            self._json_response(404, {"status": "not_found"})
            return
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length).decode("utf-8") if length > 0 else "{}"
        started_at = time.time()
        request_path = ensure_dir(SERVICE_ARTIFACTS) / f"request_{int(started_at)}.json"
        try:
            payload = json.loads(raw)
            write_json(request_path, payload)
            command = payload["command"]
            rc, response = dispatch_command(command, payload)
            response["service"] = {
                "mode": "http",
                "generated_at": utc_timestamp(),
                "latency_ms": int((time.time() - started_at) * 1000),
            }
            response.setdefault("artifacts", []).append(
                artifact_entry(request_path, "evidence", "YiACAD backend request")
            )
            write_json(SERVICE_ARTIFACTS / "latest_response.json", response)
            self._json_response(200 if rc == 0 else 207, response)
        except Exception as exc:  # noqa: BLE001
            response = uiux_contract_from_failure("service.dispatch", str(exc), request_path)
            response["service"] = {
                "mode": "http",
                "generated_at": utc_timestamp(),
                "latency_ms": int((time.time() - started_at) * 1000),
            }
            write_json(SERVICE_ARTIFACTS / "latest_response.json", response)
            self._json_response(500, response)

    def log_message(self, format: str, *args) -> None:  # noqa: A003
        log_path = ensure_dir(SERVICE_ARTIFACTS) / "server.log"
        with log_path.open("a", encoding="utf-8") as handle:
            handle.write("%s - %s\n" % (self.log_date_time_string(), format % args))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="YiACAD backend HTTP service")
    parser.add_argument("--host", default=DEFAULT_HOST, help="Bind host")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="Bind port")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    ensure_dir(SERVICE_ARTIFACTS)
    server = ThreadingHTTPServer((args.host, args.port), YiacadBackendHandler)
    write_json(
        SERVICE_ARTIFACTS / "latest_server.json",
        {
            "status": "done",
            "component": "yiacad-backend-service",
            "generated_at": utc_timestamp(),
            "pid": os.getpid(),
            "host": args.host,
            "port": args.port,
            "artifacts_dir": str(SERVICE_ARTIFACTS),
        },
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        return 0
    finally:
        server.server_close()


if __name__ == "__main__":
    raise SystemExit(main())
