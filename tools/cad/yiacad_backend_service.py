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

from kill_life.yiacad_action_registry import get_yiacad_action, yiacad_action_id, yiacad_action_inputs

try:
    import yiacad_native_ops as native_ops
    from yiacad_backend import (
        artifact_entry,
        build_uiux_output,
        collect_engine_reasons,
        detect_integrated_engines,
        overall_engine_health,
        utc_timestamp,
        write_json,
    )
except ImportError:
    from tools.cad import yiacad_native_ops as native_ops
    from tools.cad.yiacad_backend import (
        artifact_entry,
        build_uiux_output,
        collect_engine_reasons,
        detect_integrated_engines,
        overall_engine_health,
        utc_timestamp,
        write_json,
    )


ROOT = Path(__file__).resolve().parents[2]
SERVICE_ARTIFACTS = ROOT / "artifacts" / "cad-ai-native" / "service"
DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 38435


def ensure_dir(path: Path) -> Path:
    path.mkdir(parents=True, exist_ok=True)
    return path


def uiux_contract_from_failure(
    command: str,
    error_text: str,
    request_path: Path | None = None,
    surface: str = "yiacad-api",
) -> dict:
    artifacts = []
    if request_path:
        artifacts.append(artifact_entry(request_path, "evidence", "YiACAD backend request"))
    return build_uiux_output(
        surface=surface,
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
        degraded_reasons=["backend-dispatch-failed"],
        engine_status=detect_integrated_engines(),
    )


def build_args(command: str, payload: dict) -> argparse.Namespace:
    common = {"command": command, "json_output": True, "surface": payload.get("surface", "yiacad-api")}
    common.update({name: payload.get(name, "") for name in yiacad_action_inputs(command)})
    return argparse.Namespace(**common)


def latest_context_payload() -> dict | None:
    candidates = sorted(ROOT.glob("artifacts/cad-ai-native/*/context.json"), key=lambda path: path.stat().st_mtime, reverse=True)
    for candidate in candidates:
        try:
            return json.loads(candidate.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            continue
    return None


def latest_artifacts_payload() -> dict:
    response_path = SERVICE_ARTIFACTS / "latest_response.json"
    items: list[dict] = []
    source = None
    if response_path.exists():
        try:
            response = json.loads(response_path.read_text(encoding="utf-8"))
            payload_items = response.get("artifacts")
            if isinstance(payload_items, list):
                items = payload_items
                source = str(response_path)
        except json.JSONDecodeError:
            items = []
    return {
        "status": "done" if items else "degraded",
        "component": "yiacad-backend-service",
        "generated_at": utc_timestamp(),
        "artifacts": items,
        "source": source,
        "next_steps": ["open artifacts", "rerun a YiACAD action to refresh the index"] if not items else ["open artifacts"],
    }


def dispatch_command(command: str, payload: dict) -> tuple[int, dict]:
    entry = get_yiacad_action(command)
    handler = getattr(native_ops, entry["native_handler"])
    args = build_args(command, payload)
    stdout = io.StringIO()
    with contextlib.redirect_stdout(stdout):
        rc = handler(args)
    body = stdout.getvalue().strip()
    if body:
        try:
            parsed = json.loads(body)
            if isinstance(parsed, dict):
                parsed.setdefault("surface", payload.get("surface", parsed.get("surface", "yiacad-api")))
                return rc, parsed
        except json.JSONDecodeError:
            pass
    contract = build_uiux_output(
        surface=payload.get("surface", "yiacad-api"),
        action=yiacad_action_id(command),
        execution_mode="background",
        status="done" if rc == 0 else "blocked",
        severity="info" if rc == 0 else "error",
        summary=f"YiACAD backend service executed `{command}`.",
        details=body or "No structured response body was returned.",
        context_ref=None,
        artifacts=[],
        next_steps=["inspect service response", "retry via direct runner if needed"],
        latency_ms=None,
        degraded_reasons=[] if rc == 0 else ["backend-unstructured-response"],
        engine_status=detect_integrated_engines(),
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
        if self.path == "/health":
            engine_status = detect_integrated_engines()
            payload = {
                "status": overall_engine_health(engine_status),
                "component": "yiacad-backend-service",
                "generated_at": utc_timestamp(),
                "pid": os.getpid(),
                "host": self.server.server_address[0],
                "port": self.server.server_address[1],
                "artifacts_dir": str(SERVICE_ARTIFACTS),
                "engine_status": engine_status,
                "degraded_reasons": collect_engine_reasons(engine_status),
            }
            ensure_dir(SERVICE_ARTIFACTS)
            write_json(SERVICE_ARTIFACTS / "latest_health.json", payload)
            self._json_response(200, payload)
            return
        if self.path == "/projects/current":
            payload = latest_context_payload()
            if payload is None:
                self._json_response(
                    404,
                    {
                        "status": "blocked",
                        "component": "yiacad-backend-service",
                        "generated_at": utc_timestamp(),
                        "reason": "no-context",
                    },
                )
                return
            self._json_response(200, payload)
            return
        if self.path == "/artifacts":
            self._json_response(200, latest_artifacts_payload())
            return
        self._json_response(404, {"status": "not_found"})

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
            response = uiux_contract_from_failure(
                "service.dispatch",
                str(exc),
                request_path,
                payload.get("surface", "yiacad-api") if "payload" in locals() and isinstance(payload, dict) else "yiacad-api",
            )
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
