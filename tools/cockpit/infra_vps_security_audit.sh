#!/usr/bin/env bash
# infra_vps_security_audit.sh — non-intrusive edge security checks for external VPS services
# Usage: bash tools/cockpit/infra_vps_security_audit.sh [--json] [--out <path>]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_PATH="${ROOT_DIR}/artifacts/cockpit/infra_vps_security_audit_latest.json"
OUTPUT_JSON=0

usage() {
  cat <<'EOF'
Usage: bash tools/cockpit/infra_vps_security_audit.sh [options]

Options:
  --json               Print resulting JSON payload to stdout
  --out <path>         Override output path (default: artifacts/cockpit/infra_vps_security_audit_latest.json)
  -h, --help           Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      OUTPUT_JSON=1
      shift
      ;;
    --out)
      OUT_PATH="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

python3 - "$OUT_PATH" "$OUTPUT_JSON" <<'PY'
from __future__ import annotations

import json
import subprocess
import sys
from datetime import datetime, UTC
from pathlib import Path

out_path = Path(sys.argv[1])
emit_json = sys.argv[2] == "1"

def run(cmd: list[str], timeout: int = 15) -> tuple[int, str, str]:
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return proc.returncode, proc.stdout.strip(), proc.stderr.strip()
    except subprocess.TimeoutExpired:
        return 124, "", "timeout"
    except FileNotFoundError:
        return 127, "", f"command-not-found:{cmd[0]}"


def head_request(url: str) -> dict[str, object]:
    rc, out, err = run(["curl", "-k", "-sS", "-I", "--max-time", "12", url], timeout=20)
    lines = [ln for ln in out.splitlines() if ln.strip()]
    status_line = lines[0] if lines else ""
    headers = lines[1:21] if len(lines) > 1 else []
    status = None
    if status_line.startswith("HTTP/"):
        parts = status_line.split()
        if len(parts) > 1 and parts[1].isdigit():
            status = int(parts[1])
    return {
        "curl_head_rc": rc,
        "http_status": status,
        "status_line": status_line,
        "headers": headers,
        "curl_error": err,
    }


def probe_ports(host: str, ports: list[int]) -> dict[str, str]:
    result: dict[str, str] = {}
    for port in ports:
        rc, _, _ = run(["nc", "-z", "-w", "2", host, str(port)], timeout=6)
        result[str(port)] = "open" if rc == 0 else "closed"
    return result


targets = {
    "ragflow": "https://rag.saillant.cc",
    "browser_use": "https://browser.saillant.cc",
}

payload: dict[str, object] = {
    "generated_at_utc": datetime.now(UTC).isoformat(),
    "component": "infra-vps-security-audit",
    "targets": {},
}

for name, url in targets.items():
    host = url.split("//", 1)[1]
    req = head_request(url)
    req["url"] = url
    req["port_probe"] = probe_ports(host, [80, 443, 2375, 2376, 3000, 8080])
    payload["targets"][name] = req

out_path.parent.mkdir(parents=True, exist_ok=True)
out_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

if emit_json:
    print(json.dumps(payload, ensure_ascii=False, indent=2))
else:
    print(str(out_path))
PY
