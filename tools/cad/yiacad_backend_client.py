#!/usr/bin/env python3
"""YiACAD backend client with service-first transport and direct fallback."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

from kill_life.yiacad_action_registry import (
    INPUT_ARGUMENTS,
    yiacad_action_inputs,
    yiacad_actions,
)


ROOT = Path(__file__).resolve().parents[2]
SERVICE_SCRIPT = ROOT / "tools" / "cad" / "yiacad_backend_service.py"
NATIVE_OPS = ROOT / "tools" / "cad" / "yiacad_native_ops.py"
SERVICE_ARTIFACTS = ROOT / "artifacts" / "cad-ai-native" / "service"
DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 38435


def ensure_dir(path: Path) -> Path:
    path.mkdir(parents=True, exist_ok=True)
    return path


def service_url(host: str, port: int, suffix: str) -> str:
    return f"http://{host}:{port}{suffix}"


def http_json(url: str, payload: dict | None = None, timeout: float = 1.5) -> dict:
    data = None
    method = "GET"
    headers = {}
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        method = "POST"
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def service_health(host: str, port: int) -> dict | None:
    try:
        return http_json(service_url(host, port, "/health"))
    except Exception:  # noqa: BLE001
        return None


def start_service(host: str, port: int) -> None:
    ensure_dir(SERVICE_ARTIFACTS)
    stamp = time.strftime("%Y%m%d_%H%M%S")
    log_path = SERVICE_ARTIFACTS / f"backend_service_{stamp}.log"
    with log_path.open("a", encoding="utf-8") as handle:
        subprocess.Popen(
            [sys.executable, str(SERVICE_SCRIPT), "--host", host, "--port", str(port)],
            stdout=handle,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )


def ensure_service(host: str, port: int) -> bool:
    if service_health(host, port):
        return True
    start_service(host, port)
    for _ in range(10):
        time.sleep(0.25)
        if service_health(host, port):
            return True
    return False


def direct_fallback(argv: list[str]) -> int:
    proc = subprocess.run([sys.executable, str(NATIVE_OPS), *argv], text=True, capture_output=True)
    if proc.stdout:
        print(proc.stdout.strip())
    elif proc.stderr:
        print(proc.stderr.strip())
    return proc.returncode


def add_registry_arguments(parser: argparse.ArgumentParser, command: str) -> None:
    for name in yiacad_action_inputs(command):
        spec = INPUT_ARGUMENTS[name]
        parser.add_argument(spec["flag"], default="", help=spec["help"])


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="YiACAD backend client")
    parser.add_argument("--host", default=DEFAULT_HOST, help="Service host")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="Service port")
    parser.add_argument("--json-output", action="store_true", help="Emit JSON output")
    parser.add_argument(
        "--surface",
        default="yiacad-api",
        help="Canonical YiACAD client surface (e.g. yiacad-api, yiacad-web, yiacad-desktop, tui)",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("health", help="Check YiACAD backend service health")
    subparsers.add_parser("projects-current", help="Read the latest YiACAD context snapshot")
    subparsers.add_parser("artifacts", help="Read the latest YiACAD artifact index")
    for entry in yiacad_actions():
        subparser = subparsers.add_parser(
            entry["transport_command"],
            help=entry["description"],
        )
        add_registry_arguments(subparser, entry["transport_command"])
    return parser.parse_args()


def payload_from_args(args: argparse.Namespace) -> dict:
    payload = {"command": args.command, "surface": args.surface}
    for key in yiacad_action_inputs(args.command):
        if hasattr(args, key):
            payload[key] = getattr(args, key)
    return payload


def main() -> int:
    args = parse_args()
    if args.command == "health":
        payload = service_health(args.host, args.port)
        if payload:
            print(json.dumps(payload, indent=2, ensure_ascii=False))
            return 0
        return 1
    if args.command == "projects-current":
        payload = service_health(args.host, args.port)
        if not payload and not ensure_service(args.host, args.port):
            return 1
        response = http_json(service_url(args.host, args.port, "/projects/current"))
        print(json.dumps(response, indent=2, ensure_ascii=False))
        return 0 if response.get("status") != "blocked" else 1
    if args.command == "artifacts":
        payload = service_health(args.host, args.port)
        if not payload and not ensure_service(args.host, args.port):
            return 1
        response = http_json(service_url(args.host, args.port, "/artifacts"))
        print(json.dumps(response, indent=2, ensure_ascii=False))
        return 0 if response.get("status") != "blocked" else 1

    payload = payload_from_args(args)
    direct_argv = [args.command]
    if args.surface:
        direct_argv.extend(["--surface", args.surface])
    for key in yiacad_action_inputs(args.command):
        if key in payload and payload[key]:
            direct_argv.extend([f"--{key.replace('_', '-')}", payload[key]])
    if args.json_output:
        direct_argv.append("--json-output")

    if not ensure_service(args.host, args.port):
        return direct_fallback(direct_argv)

    try:
        response = http_json(service_url(args.host, args.port, "/run"), payload)
        if args.json_output:
            print(json.dumps(response, indent=2, ensure_ascii=False))
        else:
            print(response.get("summary", json.dumps(response, ensure_ascii=False)))
        return 0 if response.get("status") != "blocked" else 1
    except urllib.error.HTTPError:
        return direct_fallback(direct_argv)
    except Exception:  # noqa: BLE001
        return direct_fallback(direct_argv)


if __name__ == "__main__":
    raise SystemExit(main())
