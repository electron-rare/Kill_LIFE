#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/tools/cockpit/json_contract.sh"

COMPONENT="runtime-mcp-ia-gateway"
ARTIFACT_DIR="${ROOT_DIR}/artifacts/cockpit/runtime_ai_gateway"
mkdir -p "${ARTIFACT_DIR}"

STAMP="$(date +%Y%m%d-%H%M%S)"
RUN_LOG="${ARTIFACT_DIR}/runtime_ai_gateway-${STAMP}.log"

ACTION="status"
JSON=0
REFRESH=0
LOAD_PROFILE="tower-first"
INTELLIGENCE_REPORT="${ROOT_DIR}/artifacts/cockpit/intelligence_program/latest.json"
MASCARADE_REPORT="${ROOT_DIR}/artifacts/ops/mascarade_runtime_health/latest.json"
MESH_REPORT=""
INTELLIGENCE_SCRIPT="${RUNTIME_GATEWAY_INTELLIGENCE_SCRIPT:-${ROOT_DIR}/tools/cockpit/intelligence_tui.sh}"
MESH_SCRIPT="${RUNTIME_GATEWAY_MESH_SCRIPT:-${ROOT_DIR}/tools/cockpit/mesh_health_check.sh}"
MASCARADE_SCRIPT="${RUNTIME_GATEWAY_MASCARADE_SCRIPT:-${ROOT_DIR}/tools/cockpit/mascarade_runtime_health.sh}"
INTELLIGENCE_TIMEOUT_SEC="${RUNTIME_GATEWAY_INTELLIGENCE_TIMEOUT_SEC:-15}"
MESH_TIMEOUT_SEC="${RUNTIME_GATEWAY_MESH_TIMEOUT_SEC:-15}"
MASCARADE_TIMEOUT_SEC="${RUNTIME_GATEWAY_MASCARADE_TIMEOUT_SEC:-15}"

usage() {
  cat <<'EOF'
Usage: bash tools/cockpit/runtime_ai_gateway.sh [options]

Options:
  --action <status|sources>
  --json
  --refresh
  --load-profile <tower-first|photon-safe>
  --intelligence-report <path>
  --mesh-report <path>
  --mascarade-report <path>
  -h, --help
EOF
}

log_line() {
  local level="$1"
  shift
  printf '[%s] [%s] %s\n' "$(date '+%H:%M:%S')" "${level}" "$*" | tee -a "${RUN_LOG}" >&2
}

latest_mesh_report() {
  find "${ROOT_DIR}/artifacts/cockpit/health_reports" -type f -name 'mesh_health_check_mesh_*.json' 2>/dev/null | sort | tail -n 1
}

run_refresh_probe() {
  local label="$1"
  local timeout_sec="$2"
  local output_file="$3"
  local load_profile="$4"
  shift 4

  python3 - "${label}" "${timeout_sec}" "${output_file}" "${RUN_LOG}" "${load_profile}" "$@" <<'PY'
from __future__ import annotations

import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path

label = sys.argv[1]
timeout_sec = float(sys.argv[2])
output_file = Path(sys.argv[3])
run_log = Path(sys.argv[4])
load_profile = sys.argv[5]
command = sys.argv[6:]


def now_iso() -> str:
    return datetime.now().astimezone().isoformat()


def log(message: str) -> None:
    run_log.parent.mkdir(parents=True, exist_ok=True)
    with run_log.open("a", encoding="utf-8") as handle:
        handle.write(message.rstrip() + "\n")


def fallback(reason: str, detail: str) -> dict[str, object]:
    payload: dict[str, object] = {
        "generated_at": now_iso(),
        "status": "degraded",
        "contract_status": "degraded",
        "refresh_timeout": reason == "refresh-timeout",
        "degraded_reasons": [f"{label}-{reason}"],
        "next_steps": [detail],
    }
    if label == "intelligence":
        payload.update(
            {
                "contract_version": "summary-short/v1",
                "summary_short": "Intelligence refresh degraded during gateway refresh.",
                "open_task_count": 0,
            }
        )
    elif label == "mesh":
        payload.update(
            {
                "mesh_status": "degraded",
                "load_profile": load_profile,
                "host_order": [],
            }
        )
    elif label == "mascarade":
        payload.update(
            {
                "provider": "unknown",
                "model": "unknown",
                "host": "unknown",
            }
        )
    return payload


def write_payload(payload: dict[str, object]) -> None:
    output_file.parent.mkdir(parents=True, exist_ok=True)
    output_file.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


try:
    result = subprocess.run(command, capture_output=True, text=True, timeout=timeout_sec, check=False)
    if result.stdout.strip():
        output_file.write_text(result.stdout, encoding="utf-8")
    else:
        write_payload(
            fallback(
                "refresh-empty",
                f"Refresh {label} produced no JSON payload; inspect the source command.",
            )
        )
    if result.stderr.strip():
        log(f"[refresh:{label}:stderr]\n{result.stderr.rstrip()}")
    log(f"[refresh:{label}] returncode={result.returncode} timeout={timeout_sec}s")
    if result.returncode != 0:
        write_payload(
            fallback(
                "refresh-failed",
                f"Refresh {label} failed; inspect the source command and its artifacts.",
            )
        )
except subprocess.TimeoutExpired as exc:
    stdout = exc.stdout or ""
    stderr = exc.stderr or ""
    if stdout.strip():
        log(f"[refresh:{label}:partial-stdout]\n{stdout.rstrip()}")
    if stderr.strip():
        log(f"[refresh:{label}:partial-stderr]\n{stderr.rstrip()}")
    log(f"[refresh:{label}] timeout after {timeout_sec}s")
    write_payload(
        fallback(
            "refresh-timeout",
            f"Refresh {label} timed out after {timeout_sec}s; reduce probe cost or inspect the upstream source.",
        )
    )
PY
}

refresh_sources() {
  local intelligence_out="${ARTIFACT_DIR}/intelligence-${STAMP}.json"
  local mesh_out="${ARTIFACT_DIR}/mesh-${STAMP}.json"
  local mascarade_out="${ARTIFACT_DIR}/mascarade-${STAMP}.json"

  log_line "INFO" "refreshing intelligence memory"
  run_refresh_probe intelligence "${INTELLIGENCE_TIMEOUT_SEC}" "${intelligence_out}" "${LOAD_PROFILE}" \
    bash "${INTELLIGENCE_SCRIPT}" --action memory --json
  INTELLIGENCE_REPORT="${intelligence_out}"

  log_line "INFO" "refreshing mesh health"
  run_refresh_probe mesh "${MESH_TIMEOUT_SEC}" "${mesh_out}" "${LOAD_PROFILE}" \
    bash "${MESH_SCRIPT}" --json --load-profile "${LOAD_PROFILE}"
  MESH_REPORT="${mesh_out}"

  log_line "INFO" "refreshing Mascarade runtime health"
  run_refresh_probe mascarade "${MASCARADE_TIMEOUT_SEC}" "${mascarade_out}" "${LOAD_PROFILE}" \
    bash "${MASCARADE_SCRIPT}" --json
  MASCARADE_REPORT="${mascarade_out}"
}

emit_status_json() {
  python3 - "${ROOT_DIR}" "${INTELLIGENCE_REPORT}" "${MESH_REPORT}" "${MASCARADE_REPORT}" "${RUN_LOG}" <<'PY'
from __future__ import annotations

import json
import sys
from datetime import datetime
from pathlib import Path

root = Path(sys.argv[1])
intelligence_path = Path(sys.argv[2]) if sys.argv[2] else None
mesh_path = Path(sys.argv[3]) if sys.argv[3] else None
mascarade_path = Path(sys.argv[4]) if sys.argv[4] else None
run_log = Path(sys.argv[5])


def read_json(path: Path | None) -> dict[str, object] | None:
    if path is None or not path.exists():
        return None
    text = path.read_text(encoding="utf-8")
    try:
        return json.loads(text)
    except Exception:
        decoder = json.JSONDecoder()
        lines = text.splitlines()
        for index, line in enumerate(lines):
            if line.lstrip().startswith("{"):
                try:
                    candidate = "\n".join(lines[index:])
                    payload, _ = decoder.raw_decode(candidate)
                    if isinstance(payload, dict):
                        return payload
                except Exception:
                    continue
    return None


def relative_path(path: Path | None) -> str | None:
    if path is None:
        return None
    try:
        return str(path.resolve().relative_to(root))
    except Exception:
        return str(path)


def normalize(value: object) -> str:
    text = str(value or "").strip().lower()
    if text in {"ok", "ready", "done", "success"}:
        return "ready"
    if text in {"degraded", "warn", "warning", "pending", "running", "unknown", "missing"}:
        return "degraded"
    if text in {"blocked", "error", "fail", "failed", "unreachable", "invalid"}:
        return "blocked"
    return "degraded"


def collect_next_steps(payload: dict[str, object] | None) -> list[str]:
    if not payload:
        return []
    raw = payload.get("next_steps")
    if isinstance(raw, list):
        return [str(item) for item in raw if item]
    return []


def compact(value: object, max_len: int = 220) -> str:
    text = " ".join(str(value or "").split())
    if not text:
        return "none"
    if len(text) <= max_len:
        return text
    return text[: max_len - 3].rstrip() + "..."


def listify(value: object) -> list[str]:
    if isinstance(value, list):
        return [str(item) for item in value if item]
    return []


def merge_unique(values: list[str], additions: list[str]) -> list[str]:
    for item in additions:
        if item and item not in values:
            values.append(item)
    return values


def path_evidence(label: str, path: Path | None) -> list[str]:
    rel = relative_path(path)
    if rel:
        return [rel]
    return [f"missing:{label}"]


def build_runtime_surface(payload: dict[str, object] | None, path: Path | None) -> tuple[dict[str, object], list[str]]:
    status = normalize((payload or {}).get("status") or (payload or {}).get("runtime_status") or (payload or {}).get("contract_status"))
    provider = (payload or {}).get("provider") or (payload or {}).get("mascarade_provider") or "unknown"
    model = (payload or {}).get("model") or (payload or {}).get("mascarade_model") or "unknown"
    host = (payload or {}).get("host") or "unknown"
    degraded = listify((payload or {}).get("degraded_reasons"))
    if status != "ready" and not degraded:
        degraded = [f"runtime-{status}"]
    next_steps = collect_next_steps(payload)
    if status != "ready" and not next_steps:
        next_steps = ["Refresh Mascarade runtime health and inspect provider/model availability."]
    surface = {
        "status": status,
        "summary_short": compact(
            f"Mascarade runtime {status}; provider={provider}; model={model}; host={host}.",
            220,
        ),
        "evidence": path_evidence("runtime", path),
        "degraded_reasons": degraded,
        "upstreams": ["tools/cockpit/mascarade_runtime_health.sh"],
        "provider": provider,
        "model": model,
        "host": host,
        "path": relative_path(path),
    }
    return surface, next_steps


def build_mcp_surface(payload: dict[str, object] | None, path: Path | None) -> tuple[dict[str, object], list[str]]:
    host_order_raw = (payload or {}).get("host_order") or (payload or {}).get("mesh_host_order") or []
    if isinstance(host_order_raw, str):
        try:
            host_order = json.loads(host_order_raw)
        except Exception:
            host_order = [item.strip() for item in host_order_raw.split(",") if item.strip()]
    else:
        host_order = [str(item) for item in host_order_raw if item]
    load_profile = (payload or {}).get("load_profile") or "unknown"
    registry_status_raw = (payload or {}).get("registry_status")
    registry_status = normalize(registry_status_raw) if registry_status_raw else "unknown"
    status = normalize((payload or {}).get("status") or (payload or {}).get("mesh_status") or registry_status_raw)
    degraded = listify((payload or {}).get("degraded_reasons"))
    if (payload or {}).get("mesh_status") and normalize((payload or {}).get("mesh_status")) != "ready":
        degraded = merge_unique(degraded, [f"mesh-{normalize((payload or {}).get('mesh_status'))}"])
    if status != "ready" and not degraded:
        degraded = [f"mcp-{status}"]
    next_steps = collect_next_steps(payload)
    if status != "ready" and not next_steps:
        next_steps = ["Refresh mesh health and inspect machine registry / host order."]
    surface = {
        "status": status,
        "summary_short": compact(
            f"Mesh/MCP {status}; load_profile={load_profile}; host_order={len(host_order)}; registry={registry_status}.",
            220,
        ),
        "evidence": path_evidence("mcp", path),
        "degraded_reasons": degraded,
        "upstreams": ["tools/cockpit/mesh_health_check.sh", "specs/contracts/machine_registry.mesh.json"],
        "load_profile": load_profile,
        "host_order": host_order,
        "path": relative_path(path),
    }
    return surface, next_steps


def build_ia_surface(payload: dict[str, object] | None, path: Path | None) -> tuple[dict[str, object], list[str]]:
    status = normalize((payload or {}).get("status"))
    degraded = listify((payload or {}).get("degraded_reasons"))
    if status != "ready" and not degraded:
        degraded = [f"ia-{status}"]
    next_steps = collect_next_steps(payload)
    if status != "ready" and not next_steps:
        next_steps = ["Refresh intelligence memory and update the open governance tasks."]
    summary = (payload or {}).get("summary_short")
    if not summary:
        summary = compact(
            f"Intelligence lane {status}; open_tasks={(payload or {}).get('open_task_count', 0)}; "
            f"next={(next_steps[0] if next_steps else 'none')}.",
            220,
        )
    evidence = listify((payload or {}).get("evidence"))
    if evidence:
        evidence = [str(item) for item in evidence]
    else:
        evidence = path_evidence("ia", path)
    surface = {
        "status": status,
        "summary_short": compact(summary, 220),
        "evidence": evidence,
        "degraded_reasons": degraded,
        "upstreams": ["tools/cockpit/intelligence_tui.sh"],
        "open_task_count": (payload or {}).get("open_task_count", 0),
        "path": relative_path(path),
    }
    return surface, next_steps


def build_firmware_cad_surface(root: Path) -> tuple[dict[str, object], dict[str, object], list[str]]:
    firmware_main = root / "firmware" / "src" / "main.cpp"
    firmware_platformio = root / "firmware" / "platformio.ini"
    firmware_voice = root / "firmware" / "src" / "voice_controller.cpp"
    firmware_build_dir = root / "firmware" / ".pio" / "build" / "esp32s3_arduino"
    firmware_bin = firmware_build_dir / "firmware.bin"
    firmware_elf = firmware_build_dir / "firmware.elf"
    firmware_build_result = root / "docs" / "evidence" / "esp" / "build.result.json"
    firmware_build_stderr = root / "docs" / "evidence" / "esp" / "build.stderr.txt"
    firmware_test_result = root / "docs" / "evidence" / "linux" / "test.result.json"
    firmware_test_stderr = root / "docs" / "evidence" / "linux" / "test.stderr.txt"
    cad_proof = root / "artifacts" / "yiacad_backend_proof" / "latest.json"
    cad_fusion = root / "artifacts" / "cad-fusion" / "yiacad-fusion-last-status.md"

    firmware_exists = firmware_main.exists() and firmware_platformio.exists()
    firmware_build_ready = firmware_bin.exists() and firmware_elf.exists()
    firmware_build_payload = read_json(firmware_build_result)
    firmware_test_payload = read_json(firmware_test_result)
    firmware_build_rc = (firmware_build_payload or {}).get("returncode")
    firmware_test_rc = (firmware_test_payload or {}).get("returncode")
    has_failed_run = firmware_build_rc not in (None, 0) or firmware_test_rc not in (None, 0)
    if firmware_build_ready:
        firmware_status = "ready"
    elif firmware_exists and has_failed_run:
        firmware_status = "degraded"
    elif firmware_exists:
        firmware_status = "degraded"
    else:
        firmware_status = "blocked"

    firmware_reasons: list[str] = []
    firmware_next: list[str] = []
    if not firmware_exists:
        firmware_reasons.append("firmware-root-missing")
        firmware_next.append("Restore the canonical firmware root files before publishing firmware status.")
    elif has_failed_run:
        if firmware_build_rc not in (None, 0):
            firmware_reasons.append("firmware-build-last-run-failed")
        if firmware_test_rc not in (None, 0):
            firmware_reasons.append("firmware-test-last-run-failed")
        firmware_next.append("Resolve the current PlatformIO dependency/network error, then rerun `python3 tools/build_firmware.py esp`.")
        firmware_next.append("Rerun `python3 tools/test_firmware.py linux` after the PlatformIO dependency issue is cleared.")
    elif not firmware_build_ready:
        firmware_reasons.append("firmware-build-evidence-missing")
        firmware_next.append("Run `python3 tools/build_firmware.py esp` to publish root firmware build evidence.")
        firmware_next.append("Run `python3 tools/test_firmware.py linux` when native test evidence is needed.")

    cad_payload = read_json(cad_proof)
    cad_status_raw = (cad_payload or {}).get("status")
    if cad_status_raw in {"done", "ok", "ready"}:
        cad_status = "ready"
    elif cad_status_raw in {"degraded", "warn", "warning"}:
        cad_status = "degraded"
    elif cad_status_raw in {"blocked", "error", "fail", "failed"}:
        cad_status = "blocked"
    else:
        cad_status = "degraded"

    cad_reasons = listify((cad_payload or {}).get("degraded_reasons"))
    cad_next = collect_next_steps(cad_payload)
    if not cad_payload:
        cad_reasons = merge_unique(cad_reasons, ["cad-proof-missing"])
        cad_next = merge_unique(cad_next, ["Run `bash tools/cockpit/yiacad_backend_proof.sh --action run --json` to publish CAD operator proof."])

    combined_statuses = [firmware_status, cad_status]
    if any(item == "blocked" for item in combined_statuses):
        overall = "blocked"
    elif any(item == "degraded" for item in combined_statuses):
        overall = "degraded"
    else:
        overall = "ready"

    evidence: list[str] = []
    for candidate in (
        firmware_main,
        firmware_platformio,
        firmware_bin,
        firmware_elf,
        firmware_build_result,
        firmware_build_stderr,
        firmware_test_result,
        firmware_test_stderr,
        firmware_voice,
        cad_proof,
        cad_fusion,
    ):
        rel = relative_path(candidate) if candidate.exists() else None
        if rel and rel not in evidence:
            evidence.append(rel)

    next_steps = firmware_next[:]
    for item in cad_next:
        if item not in next_steps:
            next_steps.append(item)

    surface = {
        "status": overall,
        "summary_short": compact(
            f"firmware={firmware_status} main={'yes' if firmware_main.exists() else 'no'} build={'yes' if firmware_build_ready else 'no'} "
            f"build_rc={firmware_build_rc if firmware_build_rc is not None else 'n/a'} test_rc={firmware_test_rc if firmware_test_rc is not None else 'n/a'}; "
            f"cad={cad_status} proof={'yes' if cad_payload else 'no'}.",
            220,
        ),
        "evidence": evidence or ["missing:firmware-cad"],
        "degraded_reasons": firmware_reasons + [item for item in cad_reasons if item not in firmware_reasons],
        "upstreams": [
            "firmware/platformio.ini",
            "firmware/src/main.cpp",
            "tools/build_firmware.py",
            "tools/test_firmware.py",
            "tools/cockpit/yiacad_backend_proof.sh",
        ],
        "firmware_status": firmware_status,
        "cad_status": cad_status,
        "firmware_entrypoint": relative_path(firmware_main) if firmware_main.exists() else None,
        "firmware_build_dir": relative_path(firmware_build_dir) if firmware_build_dir.exists() else None,
        "firmware_build_result": relative_path(firmware_build_result) if firmware_build_result.exists() else None,
        "firmware_test_result": relative_path(firmware_test_result) if firmware_test_result.exists() else None,
        "cad_proof_path": relative_path(cad_proof) if cad_proof.exists() else None,
    }

    summary_payload = {
        "contract_version": "summary-short/v1",
        "generated_at": datetime.now().astimezone().isoformat(),
        "component": "firmware-cad-bridge",
        "lot_id": "firmware-cad-bridge",
        "owner_repo": "Kill_LIFE",
        "owner_agent": "Arch-Mesh",
        "owner_subagent": "CAD-Bridge",
        "write_set": [
            "firmware/platformio.ini",
            "firmware/src/main.cpp",
            "firmware/src/voice_controller.cpp",
            "tools/build_firmware.py",
            "tools/test_firmware.py",
            "tools/cockpit/yiacad_backend_proof.sh",
        ],
        "status": overall,
        "summary_short": compact(
            f"Firmware/CAD bridge {overall}; firmware={firmware_status}; cad={cad_status}; "
            f"next={(next_steps[0] if next_steps else 'none')}.",
            320,
        ),
        "evidence": surface["evidence"],
        "degraded_reasons": surface["degraded_reasons"],
        "next_steps": next_steps[:5],
    }
    return surface, summary_payload, next_steps


intelligence = read_json(intelligence_path)
mesh = read_json(mesh_path)
mascarade = read_json(mascarade_path)

runtime_surface, runtime_next = build_runtime_surface(mascarade, mascarade_path)
mcp_surface, mcp_next = build_mcp_surface(mesh, mesh_path)
ia_surface, ia_next = build_ia_surface(intelligence, intelligence_path)
firmware_cad_surface, firmware_cad_summary, firmware_cad_next = build_firmware_cad_surface(root)

source_states = [runtime_surface["status"], mcp_surface["status"], ia_surface["status"]]
if any(state == "blocked" for state in source_states):
    overall = "blocked"
elif any(state == "degraded" for state in source_states):
    overall = "degraded"
else:
    overall = "ready"

degraded_reasons: list[str] = []
next_steps: list[str] = []
evidence = [relative_path(run_log) or str(run_log)]

for label, path, surface, extra_next in (
    ("runtime", mascarade_path, runtime_surface, runtime_next),
    ("mcp", mesh_path, mcp_surface, mcp_next),
    ("ia", intelligence_path, ia_surface, ia_next),
):
    if path and path.exists():
        rel = relative_path(path)
        if rel and rel not in evidence:
            evidence.append(rel)
    else:
        degraded_reasons.append(f"{label}-missing")
        next_steps.append(f"Provide a {label} report or run the source command.")
    for reason in listify(surface.get("degraded_reasons")):
        if reason not in degraded_reasons:
            degraded_reasons.append(reason)
    for step in extra_next:
        if step not in next_steps:
            next_steps.append(step)

for reason in listify(firmware_cad_surface.get("degraded_reasons")):
    if reason not in degraded_reasons:
        degraded_reasons.append(reason)
for step in firmware_cad_next:
    if step not in next_steps:
        next_steps.append(step)
for item in listify(firmware_cad_surface.get("evidence")):
    if item not in evidence:
        evidence.append(item)

summary_short = compact(
    f"runtime={runtime_surface['status']} ({runtime_surface['summary_short']}) | "
    f"mcp={mcp_surface['status']} ({mcp_surface['summary_short']}) | "
    f"ia={ia_surface['status']} ({ia_surface['summary_short']}) | "
    f"firmware_cad={firmware_cad_surface['status']} ({firmware_cad_surface['summary_short']})",
    320,
)

payload = {
    "contract_version": "runtime-mcp-ia-gateway/v1",
    "component": "runtime-mcp-ia-gateway",
    "action": "status",
    "status": overall,
    "generated_at": datetime.now().astimezone().isoformat(),
    "owner_repo": "Kill_LIFE",
    "owner_agent": "Runtime-Companion",
    "owner_subagent": "MCP-Health",
    "write_set": [
        "tools/cockpit/runtime_ai_gateway.sh",
        "tools/cockpit/intelligence_tui.sh",
        "tools/cockpit/mesh_health_check.sh",
        "tools/cockpit/mascarade_runtime_health.sh",
        "docs/AI_WORKFLOWS.md",
    ],
    "summary_short": summary_short,
    "evidence": evidence,
    "degraded_reasons": degraded_reasons,
    "next_steps": next_steps[:5],
    "goal": "Publier une sante canonique runtime/MCP/IA exploitable par cockpit, docs et extensions.",
    "state": f"runtime={runtime_surface['status']} mcp={mcp_surface['status']} ia={ia_surface['status']}",
    "blockers": degraded_reasons,
    "next": next_steps[:3],
    "owner": "Runtime-Companion/MCP-Health",
    "contract_status": "ok" if overall == "ready" else ("error" if overall == "blocked" else "degraded"),
    "log_file": str(run_log),
    "artifacts": evidence,
    "surfaces": {
        "runtime": runtime_surface,
        "mcp": mcp_surface,
        "ia": ia_surface,
        "firmware_cad": firmware_cad_surface,
    },
    "sources": {
        "intelligence": {
            "path": relative_path(intelligence_path),
            "status": ia_surface["status"],
            "open_task_count": (intelligence or {}).get("open_task_count", 0),
            "refresh_timeout": bool((intelligence or {}).get("refresh_timeout")),
        },
        "mesh": {
            "path": relative_path(mesh_path),
            "status": mcp_surface["status"],
            "load_profile": (mesh or {}).get("load_profile", "unknown"),
            "host_order": mcp_surface.get("host_order", []),
            "refresh_timeout": bool((mesh or {}).get("refresh_timeout")),
        },
        "mascarade": {
            "path": relative_path(mascarade_path),
            "status": runtime_surface["status"],
            "provider": (mascarade or {}).get("provider") or (mascarade or {}).get("mascarade_provider"),
            "model": (mascarade or {}).get("model") or (mascarade or {}).get("mascarade_model"),
            "refresh_timeout": bool((mascarade or {}).get("refresh_timeout")),
        },
        "firmware_cad": {
            "status": firmware_cad_surface["status"],
            "firmware_status": firmware_cad_surface["firmware_status"],
            "cad_status": firmware_cad_surface["cad_status"],
            "cad_proof_path": firmware_cad_surface["cad_proof_path"],
        },
    },
    "summary_short_artifacts": {
        "firmware_cad": {
            "json": "artifacts/cockpit/runtime_ai_gateway/firmware_cad_summary_short_latest.json",
            "markdown": "artifacts/cockpit/runtime_ai_gateway/firmware_cad_summary_short_latest.md",
        }
    },
    "firmware_cad_summary_short": firmware_cad_summary,
}

print(json.dumps(payload, ensure_ascii=False, indent=2))
PY
}

render_status_text() {
  python3 - "${1}" <<'PY'
from __future__ import annotations

import json
import sys

payload = json.loads(sys.argv[1])
print("# Runtime / MCP / IA gateway")
print()
print(f"- status: {payload.get('status')}")
for name, source in (payload.get("surfaces") or {}).items():
    print(f"- {name}: {source.get('status')} ({source.get('path') or 'missing'})")
if payload.get("next_steps"):
    print("- next_steps:")
    for step in payload["next_steps"]:
        print(f"  - {step}")
PY
}

persist_status_snapshot() {
  python3 - "${1}" "${ARTIFACT_DIR}" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

payload = json.loads(sys.argv[1])
artifact_dir = Path(sys.argv[2])
latest_json = artifact_dir / "latest.json"
latest_md = artifact_dir / "latest.md"
firmware_cad_summary_json = artifact_dir / "firmware_cad_summary_short_latest.json"
firmware_cad_summary_md = artifact_dir / "firmware_cad_summary_short_latest.md"

surface_lines = []
for name, surface in (payload.get("surfaces") or {}).items():
    surface_lines.append(
        f"- {name}: status={surface.get('status')} summary={surface.get('summary_short')}"
    )

md_lines = [
    "# Runtime / MCP / IA gateway snapshot",
    "",
    f"- generated_at: {payload.get('generated_at')}",
    f"- status: {payload.get('status')}",
    f"- owner: {payload.get('owner')}",
    f"- summary_short: {payload.get('summary_short')}",
    "",
    "## Surfaces",
    *surface_lines,
    "",
    "## Next steps",
]

for step in payload.get("next_steps") or []:
    md_lines.append(f"- {step}")

if not (payload.get("next_steps") or []):
    md_lines.append("- none")

latest_json.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
latest_md.write_text("\n".join(md_lines) + "\n", encoding="utf-8")

firmware_cad_summary = payload.get("firmware_cad_summary_short")
if isinstance(firmware_cad_summary, dict):
    firmware_cad_summary_json.write_text(
        json.dumps(firmware_cad_summary, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    summary_md_lines = [
        "# Firmware / CAD bridge summary",
        "",
        f"- generated_at: {firmware_cad_summary.get('generated_at')}",
        f"- status: {firmware_cad_summary.get('status')}",
        f"- owner: {firmware_cad_summary.get('owner_agent')}/{firmware_cad_summary.get('owner_subagent')}",
        f"- summary_short: {firmware_cad_summary.get('summary_short')}",
        "",
        "## Evidence",
    ]
    for item in firmware_cad_summary.get("evidence") or []:
        summary_md_lines.append(f"- {item}")
    if not (firmware_cad_summary.get("evidence") or []):
        summary_md_lines.append("- none")
    summary_md_lines.extend(["", "## Next steps"])
    for item in firmware_cad_summary.get("next_steps") or []:
        summary_md_lines.append(f"- {item}")
    if not (firmware_cad_summary.get("next_steps") or []):
        summary_md_lines.append("- none")
    firmware_cad_summary_md.write_text("\n".join(summary_md_lines) + "\n", encoding="utf-8")
PY
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --action)
      ACTION="${2:-}"
      shift 2
      ;;
    --json)
      JSON=1
      shift
      ;;
    --refresh)
      REFRESH=1
      shift
      ;;
    --load-profile)
      LOAD_PROFILE="${2:-tower-first}"
      shift 2
      ;;
    --intelligence-report)
      INTELLIGENCE_REPORT="${2:-}"
      shift 2
      ;;
    --mesh-report)
      MESH_REPORT="${2:-}"
      shift 2
      ;;
    --mascarade-report)
      MASCARADE_REPORT="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "${MESH_REPORT}" ]; then
  MESH_REPORT="$(latest_mesh_report || true)"
fi

if [ "${REFRESH}" -eq 1 ]; then
  refresh_sources
fi

case "${ACTION}" in
  status)
    log_line "INFO" "action=status refresh=${REFRESH}"
    STATUS_JSON="$(emit_status_json)"
    persist_status_snapshot "${STATUS_JSON}"
    if [ "${JSON}" -eq 1 ]; then
      printf '%s\n' "${STATUS_JSON}"
    else
      render_status_text "${STATUS_JSON}"
    fi
    ;;
  sources)
    log_line "INFO" "action=sources"
    if [ "${JSON}" -eq 1 ]; then
      printf '{\n'
      printf '  "contract_version": "cockpit-v1",\n'
      printf '  "component": "%s",\n' "${COMPONENT}"
      printf '  "action": "sources",\n'
      printf '  "status": "done",\n'
      printf '  "contract_status": "ok",\n'
      printf '  "log_file": "%s",\n' "${RUN_LOG}"
      printf '  "artifacts": %s,\n' "$(json_contract_array_from_args "${RUN_LOG}" "${INTELLIGENCE_REPORT}" "${MESH_REPORT}" "${MASCARADE_REPORT}")"
      printf '  "degraded_reasons": [],\n'
      printf '  "next_steps": [],\n'
      printf '  "intelligence_report": "%s",\n' "${INTELLIGENCE_REPORT}"
      if [ -n "${MESH_REPORT}" ]; then
        printf '  "mesh_report": "%s",\n' "${MESH_REPORT}"
      else
        printf '  "mesh_report": null,\n'
      fi
      printf '  "mascarade_report": "%s"\n' "${MASCARADE_REPORT}"
      printf '}\n'
    else
      printf '# Runtime / MCP / IA sources\n\n'
      printf -- '- intelligence: %s\n' "${INTELLIGENCE_REPORT}"
      printf -- '- mesh: %s\n' "${MESH_REPORT:-missing}"
      printf -- '- mascarade: %s\n' "${MASCARADE_REPORT}"
    fi
    ;;
  *)
    printf 'Unsupported action: %s\n' "${ACTION}" >&2
    usage >&2
    exit 2
    ;;
esac
