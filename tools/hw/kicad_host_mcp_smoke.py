#!/usr/bin/env python3
"""Host-native smoke readiness helper for the KiCad MCP launcher."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
LAUNCHER = ROOT / 'tools' / 'hw' / 'run_kicad_mcp.sh'
BASE_SMOKE = ROOT / 'tools' / 'hw' / 'mcp_smoke.py'


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument('--timeout', type=float, default=30.0)
    parser.add_argument('--json', action='store_true')
    parser.add_argument('--quick', action='store_true')
    return parser.parse_args()


def parse_doctor_output() -> dict[str, str]:
    proc = subprocess.run(
        ['bash', str(LAUNCHER), '--runtime', 'host', '--doctor'],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    values: dict[str, str] = {}
    for line in proc.stdout.splitlines():
        if '=' not in line:
            continue
        key, value = line.split('=', 1)
        values[key] = value
    return values


def emit(payload: dict[str, Any], *, json_output: bool) -> int:
    status = payload.get('status')
    if json_output:
        print(json.dumps(payload, ensure_ascii=True))
    elif status == 'ready':
        print(
            'OK: '
            f"runtime={payload.get('runtime_mode', 'unknown')} "
            f"protocol={payload.get('protocol_version', 'unknown')} "
            f"tools={payload.get('tool_count', 0)}"
        )
    else:
        print(
            'WARN: '
            f"runtime={payload.get('runtime_mode', 'unknown')} "
            f"status={status} "
            f"error={payload.get('error', 'unknown error')}"
        )
    return 0 if status == 'ready' else 1


def main() -> int:
    args = parse_args()
    doctor = parse_doctor_output()
    host_status = doctor.get('HOST_PCBNEW_IMPORT', 'missing')
    payload: dict[str, Any] = {
        'status': 'degraded',
        'requested_runtime': 'host',
        'runtime_mode': 'host',
        'quick': args.quick,
        'host_pcbnew_import': host_status,
        'error': None,
    }

    if host_status != 'ok':
        payload['error'] = 'pcbnew not importable on host runtime'
        return emit(payload, json_output=args.json)

    cmd = ['python3', str(BASE_SMOKE), '--runtime', 'host', '--json', '--timeout', str(args.timeout)]
    if args.quick:
        cmd.append('--quick')
    proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, check=False)
    try:
        result = json.loads(proc.stdout.strip() or '{}')
    except json.JSONDecodeError as exc:
        payload['status'] = 'failed'
        payload['error'] = f'invalid JSON from base smoke: {exc}'
        return emit(payload, json_output=args.json)

    if 'host_pcbnew_import' not in result:
        result['host_pcbnew_import'] = host_status
    return emit(result, json_output=args.json)


if __name__ == '__main__':
    raise SystemExit(main())
