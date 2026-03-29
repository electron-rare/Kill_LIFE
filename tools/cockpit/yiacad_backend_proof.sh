#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts/yiacad_backend_proof"
PROOF_FIXTURES_DIR="${ROOT_DIR}/tools/cad/proof_fixtures/yiacad_backend_proof"
mkdir -p "${ARTIFACTS_DIR}"

ACTION=""
JSON_MODE=0
VERBOSE=0
YES=0
DAYS=14
LINES=80

usage() {
  cat <<'EOF'
Usage: yiacad_backend_proof.sh --action <run|status|logs-summary|logs-list|logs-latest|purge-logs> [options]

Options:
  --action <name>   Action to run
  --days <N>        Retention window for purge-logs (default: 14)
  --lines <N>       Number of lines for logs-latest (default: 80)
  --json            Emit JSON for run/status/logs-summary
  --yes             Confirm destructive purge in non-interactive mode
  --verbose         Print executed commands
  --help            Show this help
EOF
}

have_tty() {
  [[ -t 0 && -t 1 ]]
}

log_cmd() {
  if [[ "${VERBOSE}" -eq 1 ]]; then
    printf '[cmd] %s\n' "$*"
  fi
}

collect_log_files() {
  find "${ARTIFACTS_DIR}" -type f 2>/dev/null
}

latest_summary_json() {
  if [[ -f "${ARTIFACTS_DIR}/latest.json" ]]; then
    printf '%s\n' "${ARTIFACTS_DIR}/latest.json"
    return 0
  fi
  find "${ARTIFACTS_DIR}" -type f -name 'summary.json' 2>/dev/null | sort | tail -n 1
}

latest_summary_md() {
  if [[ -f "${ARTIFACTS_DIR}/latest.md" ]]; then
    printf '%s\n' "${ARTIFACTS_DIR}/latest.md"
    return 0
  fi
  find "${ARTIFACTS_DIR}" -type f -name 'summary.md' 2>/dev/null | sort | tail -n 1
}

setup_log_stream() {
  : > "${LOG_FILE}"
  if [[ "${JSON_MODE}" -eq 1 ]]; then
    return 0
  fi

  set +e
  exec > >(tee -a "${LOG_FILE}") 2>&1
  local rc="$?"
  set -e
  if [[ "${rc}" -ne 0 ]]; then
    exec >> "${LOG_FILE}" 2>&1
  fi
}

run_proof() {
  local stamp run_dir proof_status
  stamp="$(date +%Y%m%d_%H%M%S)"
  run_dir="${ARTIFACTS_DIR}/${stamp}"
  mkdir -p "${run_dir}"

  log_cmd python3 "${ROOT_DIR}/tools/cad/yiacad_backend_client.py" --json-output status
  python3 "${ROOT_DIR}/tools/cad/yiacad_backend_client.py" --json-output status > "${run_dir}/backend_status.json"

  log_cmd python3 "${ROOT_DIR}/tools/cad/yiacad_backend_client.py" --json-output status
  python3 "${ROOT_DIR}/tools/cad/yiacad_backend_client.py" --json-output status > "${run_dir}/backend_invoke_status.json"

  log_cmd python3 "${ROOT_DIR}/tools/hw/kicad_seeed_mcp_smoke.py" --json --quick
  python3 "${ROOT_DIR}/tools/hw/kicad_seeed_mcp_smoke.py" --json --quick > "${run_dir}/kicad_mcp_smoke.json"

  log_cmd python3 kicad transport proof
  ROOT_DIR="${ROOT_DIR}" python3 - <<'PY' > "${run_dir}/kicad_transport.json"
import importlib.util
import json
import os
from pathlib import Path

root = Path(os.environ["ROOT_DIR"])
mod_path = root / ".runtime-home" / "cad-ai-native-forks" / "kicad-ki" / "scripting" / "plugins" / "yiacad_kicad_plugin" / "_native_common.py"
if not mod_path.exists():
    print(json.dumps({
        "transport": "kicad-shell",
        "status": "blocked",
        "returncode": 127,
        "payload_status": None,
        "contract_ok": False,
        "missing_fields": ["plugin_entrypoint"],
        "error": f"missing plugin entrypoint: {mod_path}",
        "payload": {},
    }, indent=2, ensure_ascii=False))
    raise SystemExit(0)
spec = importlib.util.spec_from_file_location("yiacad_kicad_native_common_proof", mod_path)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)
result = module.run_native_action("bom-review", "--source-path", "/tmp/nonexistent.kicad_pcb", "--json-output")
proof_source = str(root / "tools" / "cad" / "proof_fixtures" / "yiacad_backend_proof" / "probe_board.kicad_pcb")
result = module.run_native_action("bom-review", "--source-path", proof_source, "--json-output")
payload = json.loads((result.stdout or "{}").strip() or "{}")
required = ["component", "surface", "action", "execution_mode", "status", "severity", "summary", "artifacts", "next_steps"]
missing = [field for field in required if field not in payload]
payload_status = payload.get("status")
proof = {
    "transport": "kicad-shell",
    "status": "done" if not missing and payload_status in {"done", "degraded", "blocked"} else "blocked",
    "returncode": result.returncode,
    "payload_status": payload_status,
    "contract_ok": not missing,
    "missing_fields": missing,
    "payload": payload,
}
print(json.dumps(proof, indent=2, ensure_ascii=False))
PY

  log_cmd python3 freecad transport proof
  ROOT_DIR="${ROOT_DIR}" python3 - <<'PY' > "${run_dir}/freecad_transport.json"
import importlib.util
import json
import os
import sys
import types
from pathlib import Path

root = Path(os.environ["ROOT_DIR"])
mod_path = root / ".runtime-home" / "cad-ai-native-forks" / "freecad-ki" / "src" / "Mod" / "YiACADWorkbench" / "yiacad_freecad_gui.py"
if not mod_path.exists():
    print(json.dumps({
        "transport": "freecad-workbench",
        "status": "blocked",
        "contract_ok": False,
        "missing_fields": ["workbench_entrypoint"],
        "error": f"missing workbench entrypoint: {mod_path}",
        "payload": {},
    }, indent=2, ensure_ascii=False))
    raise SystemExit(0)

freecad = types.ModuleType("FreeCAD")
freecad.ActiveDocument = None
freecad_gui = types.ModuleType("FreeCADGui")
freecad_gui.runCommand = lambda *args, **kwargs: None
freecad_gui.addCommand = lambda *args, **kwargs: None
pyside = types.ModuleType("PySide")
qtcore = types.ModuleType("QtCore")
qtgui = types.ModuleType("QtGui")
pyside.QtCore = qtcore
pyside.QtGui = qtgui
sys.modules["FreeCAD"] = freecad
sys.modules["FreeCADGui"] = freecad_gui
sys.modules["PySide"] = pyside
sys.modules["PySide.QtCore"] = qtcore
sys.modules["PySide.QtGui"] = qtgui

spec = importlib.util.spec_from_file_location("yiacad_freecad_gui_proof", mod_path)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)
payload = module.run_native_json_action("bom-review", "--source-path", "/tmp/nonexistent.FCStd")
proof_source = str(root / "tools" / "cad" / "proof_fixtures" / "yiacad_backend_proof" / "probe_model.FCStd")
payload = module.run_native_json_action("bom-review", "--source-path", proof_source)
required = ["component", "surface", "action", "execution_mode", "status", "severity", "summary", "artifacts", "next_steps"]
missing = [field for field in required if field not in payload]
proof = {
    "transport": "freecad-workbench",
    "status": "done" if not missing else "blocked",
    "contract_ok": not missing,
    "missing_fields": missing,
    "payload": payload,
}
print(json.dumps(proof, indent=2, ensure_ascii=False))
PY

  log_cmd python3 build backend proof summary
  ROOT_DIR="${ROOT_DIR}" RUN_DIR="${run_dir}" python3 - <<'PY'
import json
import os
from pathlib import Path

run_dir = Path(os.environ["RUN_DIR"])
backend_status = json.loads((run_dir / "backend_status.json").read_text(encoding="utf-8"))
backend_invoke = json.loads((run_dir / "backend_invoke_status.json").read_text(encoding="utf-8"))
kicad_mcp = json.loads((run_dir / "kicad_mcp_smoke.json").read_text(encoding="utf-8"))
kicad = json.loads((run_dir / "kicad_transport.json").read_text(encoding="utf-8"))
freecad = json.loads((run_dir / "freecad_transport.json").read_text(encoding="utf-8"))

backend_ok = backend_status.get("status") in {"done", "degraded"}
invoke_ok = backend_invoke.get("status") in {"done", "degraded"}
kicad_mcp_ok = kicad_mcp.get("status") == "ready"
kicad_ok = bool(kicad.get("contract_ok")) and kicad.get("status") == "done"
freecad_ok = bool(freecad.get("contract_ok")) and freecad.get("status") == "done"
overall_status = "done" if backend_ok and invoke_ok and kicad_mcp_ok and kicad_ok and freecad_ok else "blocked"

degraded_reasons = []
if backend_status.get("status") == "degraded":
    degraded_reasons.append("backend-facade-no-recent-runs")
if backend_invoke.get("status") == "degraded":
    degraded_reasons.append("backend-invoke-status-degraded")
if kicad_mcp.get("status") != "ready":
    degraded_reasons.append("kicad-mcp-smoke-not-ready")

summary = {
    "component": "yiacad-backend-proof",
    "action": "run",
    "status": overall_status,
    "transport": "local-facade",
    "backend_status": backend_status.get("status"),
    "backend_invoke_status": backend_invoke.get("status"),
    "kicad_mcp_status": kicad_mcp.get("status"),
    "kicad_transport_status": kicad.get("status"),
    "freecad_transport_status": freecad.get("status"),
    "contract_ok": bool(kicad_mcp_ok) and bool(kicad.get("contract_ok")) and bool(freecad.get("contract_ok")),
    "degraded_reasons": degraded_reasons,
    "artifacts": [
        {"kind": "report", "path": str(run_dir / "backend_status.json"), "label": "Backend facade status"},
        {"kind": "report", "path": str(run_dir / "backend_invoke_status.json"), "label": "Backend facade invoke status"},
        {"kind": "evidence", "path": str(run_dir / "kicad_mcp_smoke.json"), "label": "KiCad MCP Seeed smoke"},
        {"kind": "evidence", "path": str(run_dir / "kicad_transport.json"), "label": "KiCad shell transport proof"},
        {"kind": "evidence", "path": str(run_dir / "freecad_transport.json"), "label": "FreeCAD workbench transport proof"},
        {"kind": "report", "path": str(run_dir / "summary.md"), "label": "Unified operator proof summary"},
    ],
    "next_steps": [
        "promote the proof runbook via yiacad_operator_index.sh",
        "bind review center and inspector to uiux_output.json everywhere",
        "keep yiacad-fusion aligned with the KiCad MCP Seeed smoke and isolate pcbnew API limits separately from MCP startup",
    ],
}

summary_json = run_dir / "summary.json"
summary_json.write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

md = [
    "# YiACAD Backend Operator Proof",
    "",
    f"- status: {summary['status']}",
    f"- transport: {summary['transport']}",
    f"- backend_status: {summary['backend_status']}",
    f"- backend_invoke_status: {summary['backend_invoke_status']}",
    f"- kicad_mcp_status: {summary['kicad_mcp_status']}",
    f"- kicad_transport_status: {summary['kicad_transport_status']}",
    f"- freecad_transport_status: {summary['freecad_transport_status']}",
    f"- contract_ok: {'yes' if summary['contract_ok'] else 'no'}",
    "",
    "## Artifacts",
]
for artifact in summary["artifacts"]:
    md.append(f"- {artifact['label']}: {artifact['path']}")
md.extend(["", "## Next steps"])
for step in summary["next_steps"]:
    md.append(f"- {step}")
(run_dir / "summary.md").write_text("\n".join(md) + "\n", encoding="utf-8")
PY

  cp "${run_dir}/summary.json" "${ARTIFACTS_DIR}/latest.json"
  cp "${run_dir}/summary.md" "${ARTIFACTS_DIR}/latest.md"

  if [[ "${JSON_MODE}" -eq 1 ]]; then
    cat "${run_dir}/summary.json"
  else
    cat "${run_dir}/summary.md"
  fi

  proof_status="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["status"])' "${run_dir}/summary.json")"
  [[ "${proof_status}" == "done" ]]
}

show_status() {
  local latest_json latest_md
  latest_json="$(latest_summary_json)"
  latest_md="$(latest_summary_md)"
  if [[ -z "${latest_json}" || -z "${latest_md}" ]]; then
    if [[ "${JSON_MODE}" -eq 1 ]]; then
      python3 - <<PY
import json
print(json.dumps({
  "component": "yiacad-backend-proof",
  "action": "status",
  "status": "degraded",
  "summary": "No unified backend proof has been generated yet.",
  "artifacts_dir": "${ARTIFACTS_DIR}",
}, ensure_ascii=False))
PY
    else
      cat <<EOF
# YiACAD Backend Operator Proof

- status: degraded
- summary: No unified backend proof has been generated yet.
- artifacts_dir: ${ARTIFACTS_DIR}
EOF
    fi
    return 0
  fi

  if [[ "${JSON_MODE}" -eq 1 ]]; then
    cat "${latest_json}"
  else
    cat "${latest_md}"
  fi
}

logs_list() {
  local found=0
  local path=""

  while IFS= read -r path; do
    [[ -n "${path}" ]] || continue
    [[ "${path}" == "${LOG_FILE:-}" ]] && continue
    printf '%s\n' "${path}"
    found=1
  done < <(collect_log_files | sort)

  if [[ "${found}" -eq 0 ]]; then
    if [[ -n "${LOG_FILE:-}" ]]; then
      printf '%s\n' "${LOG_FILE}"
    else
      printf 'no logs found\n'
    fi
  fi
}

logs_latest() {
  local latest=""
  local path=""

  while IFS= read -r path; do
    [[ -n "${path}" ]] || continue
    [[ "${path}" == "${LOG_FILE:-}" ]] && continue
    latest="${path}"
  done < <(collect_log_files | sort)

  if [[ -z "${latest}" ]]; then
    if [[ -n "${LOG_FILE:-}" ]]; then
      latest="${LOG_FILE}"
    else
      printf 'no logs found\n'
      return 1
    fi
  fi

  printf '# Latest log\n\n'
  printf -- '- path: %s\n' "${latest}"
  printf -- '- lines: %s\n\n' "${LINES}"
  tail -n "${LINES}" "${latest}"
}

logs_summary() {
  local log_count
  log_count="$(find "${ARTIFACTS_DIR}" -type f | wc -l | tr -d ' ')"

  if [[ "${JSON_MODE}" -eq 1 ]]; then
    python3 - <<PY
import json
print(json.dumps({
  "status": "done",
  "component": "yiacad-backend-proof",
  "log_files": int("${log_count}"),
  "artifacts_dir": "${ARTIFACTS_DIR}",
  "latest_summary": "${ARTIFACTS_DIR}/latest.json",
}, ensure_ascii=False))
PY
    return 0
  fi

  cat <<EOF
# YiACAD backend proof logs summary

- log files: ${log_count}
- artifacts dir: ${ARTIFACTS_DIR}
- latest summary: ${ARTIFACTS_DIR}/latest.json
EOF
}

purge_logs() {
  if [[ "${YES}" -ne 1 ]]; then
    if command -v gum >/dev/null 2>&1 && have_tty; then
      if ! gum confirm "Purger les preuves/logs backend YiACAD de plus de ${DAYS} jours ?"; then
        printf 'purge cancelled\n'
        return 0
      fi
    else
      printf 'Refusing purge without --yes outside interactive confirm\n' >&2
      return 2
    fi
  fi

  find "${ARTIFACTS_DIR}" -type f -mtime +"${DAYS}" -delete
  find "${ARTIFACTS_DIR}" -mindepth 1 -type d -empty -delete
  printf 'purged yiacad backend proof logs older than %s days in %s\n' "${DAYS}" "${ARTIFACTS_DIR}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --action)
      ACTION="${2:-}"
      shift 2
      ;;
    --days)
      DAYS="${2:-}"
      shift 2
      ;;
    --lines)
      LINES="${2:-}"
      shift 2
      ;;
    --json)
      JSON_MODE=1
      shift
      ;;
    --yes)
      YES=1
      shift
      ;;
    --verbose)
      VERBOSE=1
      shift
      ;;
    --help)
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

if [[ -z "${ACTION}" ]]; then
  printf 'Missing --action\n' >&2
  usage >&2
  exit 2
fi

if ! [[ "${DAYS}" =~ ^[0-9]+$ ]]; then
  printf -- '--days requires an integer\n' >&2
  exit 2
fi

if ! [[ "${LINES}" =~ ^[0-9]+$ ]]; then
  printf -- '--lines requires an integer\n' >&2
  exit 2
fi

STAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${ARTIFACTS_DIR}/yiacad_backend_proof_${STAMP}.log"
setup_log_stream

if [[ "${JSON_MODE}" -ne 1 ]]; then
  printf '[yiacad-backend-proof] action=%s timestamp=%s\n' "${ACTION}" "${STAMP}"
fi

case "${ACTION}" in
  run)
    run_proof
    ;;
  status)
    show_status
    ;;
  logs-summary)
    logs_summary
    ;;
  logs-list)
    logs_list
    ;;
  logs-latest)
    logs_latest
    ;;
  purge-logs)
    purge_logs
    ;;
  *)
    printf 'Unknown action: %s\n' "${ACTION}" >&2
    exit 2
    ;;
esac
