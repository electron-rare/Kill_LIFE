#!/usr/bin/env bash
# infra_vps_healthcheck.sh — Check DNS/TLS/TCP/HTTP for VPS services
# Usage: bash tools/cockpit/infra_vps_healthcheck.sh [--service <id>] [--json] [--inventory <path>]
# Output: cockpit-v1 JSON (--json) or markdown digest
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INVENTORY="${ROOT_DIR}/artifacts/cockpit/infra_vps_inventory.json"
JSON=0
FILTER_SERVICE=""
CURL_TIMEOUT=8
NC_TIMEOUT=4
DIG_TIMEOUT=4

usage() {
  cat <<'EOF'
Usage: bash tools/cockpit/infra_vps_healthcheck.sh [options]

Options:
  --service <id>       Check only this service id (e.g. mascarade, ragflow)
  --json               Output cockpit-v1 JSON
  --inventory <path>   Path to infra_vps_inventory.json (default: artifacts/cockpit/infra_vps_inventory.json)
  -h, --help           Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --service)   FILTER_SERVICE="$2"; shift 2 ;;
    --json)      JSON=1; shift ;;
    --inventory) INVENTORY="$2"; shift 2 ;;
    -h|--help)   usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ ! -f "${INVENTORY}" ]]; then
  echo "ERROR: inventory not found: ${INVENTORY}" >&2
  exit 1
fi

STAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Emit checks via Python for JSON assembly (bash is used for system tool calls)
python3 - "${INVENTORY}" "${FILTER_SERVICE}" "${STAMP}" "${JSON}" "${CURL_TIMEOUT}" "${NC_TIMEOUT}" "${DIG_TIMEOUT}" <<'PY'
from __future__ import annotations
import json, subprocess, sys, shutil
from datetime import datetime, timezone

inventory_path = sys.argv[1]
filter_svc = sys.argv[2]
stamp = sys.argv[3]
output_json = sys.argv[4] == "1"
curl_t = int(sys.argv[5])
nc_t = int(sys.argv[6])
dig_t = int(sys.argv[7])

with open(inventory_path) as f:
    inventory = json.load(f)

services = inventory.get("services", [])
if filter_svc:
    services = [s for s in services if s["id"] == filter_svc]
    if not services:
        print(f"ERROR: service '{filter_svc}' not found in inventory", file=sys.stderr)
        sys.exit(1)

def run(*cmd, timeout=8) -> tuple[int, str, str]:
    try:
        r = subprocess.run(list(cmd), capture_output=True, text=True, timeout=timeout)
        return r.returncode, r.stdout.strip(), r.stderr.strip()
    except subprocess.TimeoutExpired:
        return 124, "", "timeout"
    except FileNotFoundError:
        return 127, "", f"command not found: {cmd[0]}"

def check_dns(domain: str) -> tuple[bool, str]:
    if not shutil.which("dig"):
        # fallback: getaddrinfo
        import socket
        try:
            socket.getaddrinfo(domain, None)
            return True, "resolved-via-getaddrinfo"
        except socket.gaierror as e:
            return False, str(e)
    code, out, err = run("dig", "+short", domain, timeout=dig_t)
    if code == 0 and out:
        return True, out.split("\n")[0]
    return False, err or "no-answer"

def check_tcp(domain: str, port: int) -> tuple[bool, str]:
    if not shutil.which("nc"):
        import socket
        try:
            s = socket.create_connection((domain, port), timeout=nc_t)
            s.close()
            return True, "tcp-ok"
        except Exception as e:
            return False, str(e)
    code, _, err = run("nc", "-z", "-w", str(nc_t), domain, str(port), timeout=nc_t + 2)
    return code == 0, ("tcp-ok" if code == 0 else (err or f"tcp-refused"))

def check_http(domain: str, protocol: str, port: int) -> tuple[bool, int | None, str]:
    url = f"{protocol}://{domain}"
    if port not in (80, 443):
        url = f"{protocol}://{domain}:{port}"
    code, out, err = run(
        "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}",
        "--max-time", str(curl_t),
        "--location", "--max-redirs", "3",
        "-k",  # TLS errors are reported separately
        url,
        timeout=curl_t + 4,
    )
    if code == 0:
        try:
            http_code = int(out)
            ok = http_code < 500
            return ok, http_code, ("http-ok" if ok else f"http-{http_code}")
        except ValueError:
            return False, None, f"unexpected-output:{out!r}"
    if code == 124:
        return False, None, "curl-timeout"
    return False, None, f"curl-exit-{code}"

def check_tls(domain: str) -> tuple[bool, str]:
    code, out, err = run(
        "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}",
        "--max-time", str(curl_t),
        f"https://{domain}",
        timeout=curl_t + 4,
    )
    if code == 60 or "certificate" in err.lower():
        return False, "tls-cert-error"
    if code == 35:
        return False, "tls-handshake-error"
    return True, "tls-ok"

results = []
overall_ok = True
degraded_reasons: list[str] = []

for svc in services:
    svc_id = svc["id"]
    domain = svc.get("domain")
    protocol = svc.get("protocol", "https")
    port = svc.get("port", 443)
    svc_status = svc.get("status", "unknown")
    checks: dict[str, object] = {}
    reasons: list[str] = []

    # Parked or internal services: skip live checks
    if svc_status == "parked" or protocol == "internal" or not domain:
        result = {
            "id": svc_id,
            "domain": domain,
            "service": svc["service"],
            "status": "skipped",
            "reason": "parked or internal",
            "checks": {},
            "checked_at": stamp,
        }
        results.append(result)
        continue

    # DNS
    dns_ok, dns_info = check_dns(domain)
    checks["dns"] = {"ok": dns_ok, "info": dns_info}
    if not dns_ok:
        reasons.append(f"dns-fail:{dns_info}")

    # TCP
    tcp_ok, tcp_info = check_tcp(domain, port)
    checks["tcp"] = {"ok": tcp_ok, "port": port, "info": tcp_info}
    if not tcp_ok:
        reasons.append(f"tcp-fail:{tcp_info}")

    # TLS (only for https)
    if protocol == "https" and dns_ok:
        tls_ok, tls_info = check_tls(domain)
        checks["tls"] = {"ok": tls_ok, "info": tls_info}
        if not tls_ok:
            reasons.append(f"tls-fail:{tls_info}")
    else:
        tls_ok = True

    # HTTP
    if dns_ok and tcp_ok:
        http_ok, http_code, http_info = check_http(domain, protocol, port)
        checks["http"] = {"ok": http_ok, "code": http_code, "info": http_info}
        if not http_ok:
            reasons.append(f"http-fail:{http_info}")
    else:
        http_ok = False
        checks["http"] = {"ok": False, "code": None, "info": "skipped-no-connectivity"}

    svc_live_status = "ok" if (dns_ok and tcp_ok and tls_ok and http_ok) else "degraded"
    if svc_live_status != "ok":
        overall_ok = False
        for r in reasons:
            if r not in degraded_reasons:
                degraded_reasons.append(f"{svc_id}:{r}")

    notes: list[str] = []
    if svc.get("sec_audit"):
        notes.append(f"sec_audit: {svc['sec_audit']}")

    result = {
        "id": svc_id,
        "domain": domain,
        "service": svc["service"],
        "user": svc.get("user"),
        "status": svc_live_status,
        "checks": checks,
        "degraded_reasons": reasons,
        "checked_at": stamp,
    }
    if notes:
        result["notes"] = notes
    results.append(result)

ok_count = sum(1 for r in results if r["status"] == "ok")
skip_count = sum(1 for r in results if r["status"] == "skipped")
total = len(results)
live_total = total - skip_count

overall_status = "ok" if overall_ok else "degraded"

if output_json:
    payload = {
        "contract_version": "infra-vps-inventory/v1",
        "component": "infra-vps-healthcheck",
        "generated_at": stamp,
        "status": overall_status,
        "summary_short": f"infra-vps {overall_status}; {ok_count}/{live_total} services up; {skip_count} skipped",
        "degraded_reasons": degraded_reasons,
        "services": results,
        "owner_repo": "Kill_LIFE",
        "evidence": ["artifacts/cockpit/infra_vps_inventory.json"],
    }
    print(json.dumps(payload, ensure_ascii=False, indent=2))
else:
    # Markdown digest
    icon = {"ok": "✅", "degraded": "❌", "blocked": "🚫", "skipped": "⏭️", "unknown": "❓"}
    print(f"## Infra VPS Healthcheck — {stamp}")
    print()
    print(f"**Status**: {icon.get(overall_status, '?')} {overall_status}  |  {ok_count}/{live_total} up  |  {skip_count} skipped")
    print()
    print("| Service | Domaine | DNS | TCP | TLS | HTTP | Statut |")
    print("|---------|---------|-----|-----|-----|------|--------|")
    for r in results:
        c = r.get("checks", {})
        dns = "✅" if c.get("dns", {}).get("ok") else ("⏭️" if r["status"] == "skipped" else "❌")
        tcp = "✅" if c.get("tcp", {}).get("ok") else ("⏭️" if r["status"] == "skipped" else "❌")
        tls = "✅" if c.get("tls", {}).get("ok") else ("⏭️" if r["status"] == "skipped" or "tls" not in c else "❌")
        http_ok = c.get("http", {}).get("ok")
        http_code = c.get("http", {}).get("code")
        http_cell = ("✅" if http_ok else ("⏭️" if r["status"] == "skipped" else f"❌ {http_code or ''}")).strip()
        svc_icon = icon.get(r["status"], "?")
        print(f"| {r['service']} | {r.get('domain') or '--'} | {dns} | {tcp} | {tls} | {http_cell} | {svc_icon} {r['status']} |")

    if degraded_reasons:
        print()
        print("### Degraded reasons")
        for reason in degraded_reasons:
            print(f"- {reason}")
PY
