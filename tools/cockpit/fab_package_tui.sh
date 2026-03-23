#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARTIFACTS_ROOT="${ROOT_DIR}/artifacts/cockpit/fab_package"
SCHEMA_PATH="${ROOT_DIR}/specs/contracts/fab_package.schema.json"
SCHOPS="${ROOT_DIR}/tools/hw/schops/schops.py"
YIACAD="${ROOT_DIR}/tools/cad/yiacad_native_ops.py"

ACTION="summary"
JSON_MODE=0
BOARD_ID=""
SOURCE_SCHEMATIC=""
SOURCE_BOARD=""
ROUTE_ORIGIN="local"
MODE="dry"

usage() {
  cat <<'EOF'
Usage: fab_package_tui.sh [--action summary|build|validate|artifacts] [--json]
                          [--board-id ID] [--schematic PATH] [--board PATH]
                          [--route-origin local|quilter|pcbdesigner] [--mode dry|live]
EOF
}

now_stamp() {
  date '+%Y%m%d_%H%M%S'
}

ensure_dir() {
  mkdir -p "$1"
}

json_escape() {
  python3 - "$1" <<'PY'
import json
import sys
print(json.dumps(sys.argv[1]))
PY
}

resolve_kicad_cli() {
  if [[ -n "${KICAD_CLI:-}" && -x "${KICAD_CLI}" ]]; then
    printf '%s\n' "${KICAD_CLI}"
    return 0
  fi
  if [[ -x /Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli ]]; then
    printf '%s\n' /Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli
    return 0
  fi
  command -v kicad-cli 2>/dev/null || true
}

derive_board_id() {
  if [[ -n "${BOARD_ID}" ]]; then
    printf '%s\n' "${BOARD_ID}"
    return
  fi
  if [[ -n "${SOURCE_BOARD}" ]]; then
    basename "${SOURCE_BOARD}" .kicad_pcb
    return
  fi
  if [[ -n "${SOURCE_SCHEMATIC}" ]]; then
    basename "${SOURCE_SCHEMATIC}" .kicad_sch
    return
  fi
  printf '%s\n' unknown-board
}

abs_or_empty() {
  local path="$1"
  if [[ -n "${path}" && -e "${path}" ]]; then
    python3 - "${path}" <<'PY'
from pathlib import Path
import sys
print(Path(sys.argv[1]).resolve())
PY
  else
    printf '%s' ""
  fi
}

latest_json_path() {
  printf '%s\n' "${ARTIFACTS_ROOT}/latest.json"
}

latest_md_path() {
  printf '%s\n' "${ARTIFACTS_ROOT}/latest.md"
}

write_latest() {
  local json_path="$1"
  local md_path="$2"
  ensure_dir "${ARTIFACTS_ROOT}"
  cp "${json_path}" "$(latest_json_path)"
  cp "${md_path}" "$(latest_md_path)"
}

emit_no_latest() {
  local status="degraded"
  local reason="no fab package artifact has been generated yet"
  if [[ "${JSON_MODE}" -eq 1 ]]; then
    cat <<EOF
{
  "contract_version": "fab-package-v1",
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "${status}",
  "board_id": "",
  "source_schematic": null,
  "source_board": null,
  "route_origin": "local",
  "bom_file": null,
  "cpl_file": null,
  "gerber_dir": null,
  "drill_file": null,
  "drc_report": null,
  "review_artifacts": [],
  "provenance": {
    "producer": "fab_package_tui.sh",
    "tool": "cockpit",
    "mode": "dry",
    "route_origin": "local"
  },
  "acceptance_gates": {
    "erc_ok": false,
    "drc_ok": false,
    "bom_review_ok": false,
    "artifacts_complete": false
  },
  "degraded_reasons": [$(json_escape "${reason}")],
  "next_steps": [
    "run fab_package_tui.sh --action build with a valid KiCad schematic or board",
    "materialize Hypnoled assets in the current checkout before running T-HP lots"
  ],
  "artifacts": []
}
EOF
  else
    printf 'Fab package status: %s\n' "${status}"
    printf -- '- reason: %s\n' "${reason}"
  fi
}

run_capture() {
  local log_prefix="$1"
  shift
  set +e
  "$@" >"${log_prefix}.stdout.log" 2>"${log_prefix}.stderr.log"
  local rc=$?
  set -e
  return "${rc}"
}

build_package() {
  local board_id run_stamp run_dir hw_root hw_latest kicad_cli
  local bom_file="" cpl_file="" gerber_dir="" drill_file="" drc_report="" netlist_file=""
  local yiacad_erc_drc="" yiacad_bom_review=""
  local status="blocked"
  local erc_ok=0 drc_ok=0 bom_review_ok=0 artifacts_complete=0
  local reasons=()
  local next_steps=()
  local artifacts=()

  board_id="$(derive_board_id)"
  run_stamp="$(now_stamp)"
  run_dir="${ARTIFACTS_ROOT}/${run_stamp}-${board_id}"
  hw_root="${run_dir}/hw"

  ensure_dir "${run_dir}"
  ensure_dir "${hw_root}"

  if [[ -z "${SOURCE_SCHEMATIC}" && -z "${SOURCE_BOARD}" ]]; then
    reasons+=("missing-source-files")
    next_steps+=("provide --schematic and/or --board")
  fi

  if [[ -n "${SOURCE_SCHEMATIC}" && ! -f "${SOURCE_SCHEMATIC}" ]]; then
    reasons+=("schematic-not-found")
    next_steps+=("provide an existing .kicad_sch file")
    SOURCE_SCHEMATIC=""
  fi

  if [[ -n "${SOURCE_BOARD}" && ! -f "${SOURCE_BOARD}" ]]; then
    reasons+=("board-not-found")
    next_steps+=("provide an existing .kicad_pcb file")
    SOURCE_BOARD=""
  fi

  if [[ -n "${SOURCE_SCHEMATIC}" ]]; then
    if run_capture "${run_dir}/erc" python3 "${SCHOPS}" --artifacts "${hw_root}" erc --schematic "${SOURCE_SCHEMATIC}"; then
      erc_ok=1
    else
      reasons+=("schops-erc-failed")
    fi

    if ! run_capture "${run_dir}/netlist" python3 "${SCHOPS}" --artifacts "${hw_root}" netlist --schematic "${SOURCE_SCHEMATIC}"; then
      reasons+=("schops-netlist-failed")
    fi

    if run_capture "${run_dir}/bom" python3 "${SCHOPS}" --artifacts "${hw_root}" bom --schematic "${SOURCE_SCHEMATIC}"; then
      :
    else
      reasons+=("schops-bom-failed")
    fi

    hw_latest="$(find "${hw_root}" -mindepth 1 -maxdepth 1 -type d | sort | tail -n 1 || true)"
    if [[ -n "${hw_latest}" ]]; then
      bom_file="$(find "${hw_latest}" -type f \( -name '*.csv' -o -name '*bom*' \) | sort | head -n 1 || true)"
      netlist_file="$(find "${hw_latest}" -type f \( -name '*.net' -o -name '*.xml' -o -name '*netlist*' \) | sort | head -n 1 || true)"
      artifacts+=("${hw_latest}")
    fi

    if run_capture "${run_dir}/yiacad_erc_drc" python3 "${YIACAD}" kicad-erc-drc --source-path "${SOURCE_SCHEMATIC}" --json-output; then
      drc_ok=1
      yiacad_erc_drc="${run_dir}/yiacad_erc_drc.stdout.log"
    else
      reasons+=("yiacad-erc-drc-failed")
      yiacad_erc_drc="${run_dir}/yiacad_erc_drc.stderr.log"
    fi

    if run_capture "${run_dir}/yiacad_bom_review" python3 "${YIACAD}" bom-review --source-path "${SOURCE_SCHEMATIC}" --json-output; then
      bom_review_ok=1
      yiacad_bom_review="${run_dir}/yiacad_bom_review.stdout.log"
    else
      reasons+=("yiacad-bom-review-failed")
      yiacad_bom_review="${run_dir}/yiacad_bom_review.stderr.log"
    fi
  fi

  if [[ -n "${SOURCE_BOARD}" ]]; then
    kicad_cli="$(resolve_kicad_cli)"
    if [[ -n "${kicad_cli}" ]]; then
      ensure_dir "${run_dir}/gerbers"
      ensure_dir "${run_dir}/drill"
      if run_capture "${run_dir}/gerber_export" "${kicad_cli}" pcb export gerbers -o "${run_dir}/gerbers" "${SOURCE_BOARD}"; then
        gerber_dir="${run_dir}/gerbers"
      else
        reasons+=("gerber-export-failed")
      fi
      if run_capture "${run_dir}/drill_export" "${kicad_cli}" pcb export drill -o "${run_dir}/drill" "${SOURCE_BOARD}"; then
        drill_file="$(find "${run_dir}/drill" -type f | sort | head -n 1 || true)"
      else
        reasons+=("drill-export-failed")
      fi
    else
      reasons+=("kicad-cli-unavailable")
      next_steps+=("install KiCad CLI or use a machine with host KiCad access")
    fi
  fi

  if [[ -z "${cpl_file}" ]]; then
    reasons+=("cpl-export-missing")
    next_steps+=("add a canonical local CPL export before assembly-ready handoff")
  fi

  if [[ -n "${bom_file}" && -n "${gerber_dir}" && -n "${drill_file}" && -n "${cpl_file}" ]]; then
    artifacts_complete=1
  fi

  if [[ ${erc_ok} -eq 1 && ${drc_ok} -eq 1 && ${bom_review_ok} -eq 1 && ${artifacts_complete} -eq 1 ]]; then
    status="ready"
  elif [[ -n "${SOURCE_SCHEMATIC}" || -n "${SOURCE_BOARD}" ]]; then
    status="degraded"
  fi

  local json_path="${run_dir}/fab_package_${run_stamp}.json"
  local md_path="${run_dir}/fab_package_${run_stamp}.md"

  python3 - "${json_path}" "${md_path}" <<'PY'
import json
import os
import pathlib
import sys

json_path = pathlib.Path(sys.argv[1])
md_path = pathlib.Path(sys.argv[2])

def env(name, default=""):
    return os.environ.get(name, default)

reasons = [item for item in env("FAB_REASONS", "").split("\n") if item]
next_steps = [item for item in env("FAB_NEXT_STEPS", "").split("\n") if item]
review_artifacts = [item for item in env("FAB_REVIEW_ARTIFACTS", "").split("\n") if item]
artifacts = []
for item in [x for x in env("FAB_ARTIFACTS", "").split("\n") if x]:
    artifacts.append({"path": item})

payload = {
    "contract_version": "fab-package-v1",
    "generated_at": env("FAB_GENERATED_AT"),
    "status": env("FAB_STATUS"),
    "board_id": env("FAB_BOARD_ID"),
    "source_schematic": env("FAB_SOURCE_SCHEMATIC") or None,
    "source_board": env("FAB_SOURCE_BOARD") or None,
    "route_origin": env("FAB_ROUTE_ORIGIN"),
    "bom_file": env("FAB_BOM_FILE") or None,
    "cpl_file": env("FAB_CPL_FILE") or None,
    "gerber_dir": env("FAB_GERBER_DIR") or None,
    "drill_file": env("FAB_DRILL_FILE") or None,
    "drc_report": env("FAB_DRC_REPORT") or None,
    "netlist_file": env("FAB_NETLIST_FILE") or None,
    "review_artifacts": review_artifacts,
    "provenance": {
        "producer": "tools/cockpit/fab_package_tui.sh",
        "tool": "fab-package-local-chain",
        "mode": env("FAB_MODE"),
        "route_origin": env("FAB_ROUTE_ORIGIN"),
    },
    "acceptance_gates": {
        "erc_ok": env("FAB_ERC_OK") == "1",
        "drc_ok": env("FAB_DRC_OK") == "1",
        "bom_review_ok": env("FAB_BOM_REVIEW_OK") == "1",
        "artifacts_complete": env("FAB_ARTIFACTS_COMPLETE") == "1",
    },
    "degraded_reasons": reasons,
    "next_steps": next_steps,
    "artifacts": artifacts,
}

json_path.write_text(json.dumps(payload, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")

lines = [
    "# Fab package",
    "",
    f"- status: {payload['status']}",
    f"- board_id: {payload['board_id']}",
    f"- route_origin: {payload['route_origin']}",
    f"- source_schematic: {payload['source_schematic'] or ''}",
    f"- source_board: {payload['source_board'] or ''}",
    f"- bom_file: {payload['bom_file'] or ''}",
    f"- cpl_file: {payload['cpl_file'] or ''}",
    f"- gerber_dir: {payload['gerber_dir'] or ''}",
    f"- drill_file: {payload['drill_file'] or ''}",
    f"- drc_report: {payload['drc_report'] or ''}",
    "",
    "## Acceptance gates",
    "",
]
for key, value in payload["acceptance_gates"].items():
    lines.append(f"- {key}: {str(value).lower()}")
lines += ["", "## Reasons", ""]
if reasons:
    lines.extend(f"- {item}" for item in reasons)
else:
    lines.append("- none")
lines += ["", "## Next steps", ""]
if next_steps:
    lines.extend(f"- {item}" for item in next_steps)
else:
    lines.append("- none")

md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

  FAB_GENERATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  FAB_STATUS="${status}" \
  FAB_BOARD_ID="${board_id}" \
  FAB_SOURCE_SCHEMATIC="$(abs_or_empty "${SOURCE_SCHEMATIC}")" \
  FAB_SOURCE_BOARD="$(abs_or_empty "${SOURCE_BOARD}")" \
  FAB_ROUTE_ORIGIN="${ROUTE_ORIGIN}" \
  FAB_BOM_FILE="$(abs_or_empty "${bom_file}")" \
  FAB_CPL_FILE="$(abs_or_empty "${cpl_file}")" \
  FAB_GERBER_DIR="$(abs_or_empty "${gerber_dir}")" \
  FAB_DRILL_FILE="$(abs_or_empty "${drill_file}")" \
  FAB_DRC_REPORT="$(abs_or_empty "${yiacad_erc_drc}")" \
  FAB_NETLIST_FILE="$(abs_or_empty "${netlist_file}")" \
  FAB_MODE="${MODE}" \
  FAB_ERC_OK="${erc_ok}" \
  FAB_DRC_OK="${drc_ok}" \
  FAB_BOM_REVIEW_OK="${bom_review_ok}" \
  FAB_ARTIFACTS_COMPLETE="${artifacts_complete}" \
  FAB_REASONS="$(printf '%s\n' "${reasons[@]-}")" \
  FAB_NEXT_STEPS="$(printf '%s\n' "${next_steps[@]-}")" \
  FAB_REVIEW_ARTIFACTS="$(printf '%s\n' "${yiacad_erc_drc}" "${yiacad_bom_review}")" \
  FAB_ARTIFACTS="$(printf '%s\n' "${artifacts[@]-}")" \
  python3 - "${json_path}" "${md_path}" <<'PY'
import json
import os
import pathlib
import sys

json_path = pathlib.Path(sys.argv[1])
md_path = pathlib.Path(sys.argv[2])

def env(name, default=""):
    return os.environ.get(name, default)

reasons = [item for item in env("FAB_REASONS", "").split("\n") if item]
next_steps = [item for item in env("FAB_NEXT_STEPS", "").split("\n") if item]
review_artifacts = [item for item in env("FAB_REVIEW_ARTIFACTS", "").split("\n") if item]
artifacts = []
for item in [x for x in env("FAB_ARTIFACTS", "").split("\n") if x]:
    artifacts.append({"path": item})

payload = {
    "contract_version": "fab-package-v1",
    "generated_at": env("FAB_GENERATED_AT"),
    "status": env("FAB_STATUS"),
    "board_id": env("FAB_BOARD_ID"),
    "source_schematic": env("FAB_SOURCE_SCHEMATIC") or None,
    "source_board": env("FAB_SOURCE_BOARD") or None,
    "route_origin": env("FAB_ROUTE_ORIGIN"),
    "bom_file": env("FAB_BOM_FILE") or None,
    "cpl_file": env("FAB_CPL_FILE") or None,
    "gerber_dir": env("FAB_GERBER_DIR") or None,
    "drill_file": env("FAB_DRILL_FILE") or None,
    "drc_report": env("FAB_DRC_REPORT") or None,
    "netlist_file": env("FAB_NETLIST_FILE") or None,
    "review_artifacts": review_artifacts,
    "provenance": {
        "producer": "tools/cockpit/fab_package_tui.sh",
        "tool": "fab-package-local-chain",
        "mode": env("FAB_MODE"),
        "route_origin": env("FAB_ROUTE_ORIGIN"),
    },
    "acceptance_gates": {
        "erc_ok": env("FAB_ERC_OK") == "1",
        "drc_ok": env("FAB_DRC_OK") == "1",
        "bom_review_ok": env("FAB_BOM_REVIEW_OK") == "1",
        "artifacts_complete": env("FAB_ARTIFACTS_COMPLETE") == "1",
    },
    "degraded_reasons": reasons,
    "next_steps": next_steps,
    "artifacts": artifacts,
}

json_path.write_text(json.dumps(payload, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")

lines = [
    "# Fab package",
    "",
    f"- status: {payload['status']}",
    f"- board_id: {payload['board_id']}",
    f"- route_origin: {payload['route_origin']}",
    f"- source_schematic: {payload['source_schematic'] or ''}",
    f"- source_board: {payload['source_board'] or ''}",
    f"- bom_file: {payload['bom_file'] or ''}",
    f"- cpl_file: {payload['cpl_file'] or ''}",
    f"- gerber_dir: {payload['gerber_dir'] or ''}",
    f"- drill_file: {payload['drill_file'] or ''}",
    f"- drc_report: {payload['drc_report'] or ''}",
    "",
    "## Acceptance gates",
    "",
]
for key, value in payload["acceptance_gates"].items():
    lines.append(f"- {key}: {str(value).lower()}")
lines += ["", "## Reasons", ""]
if reasons:
    lines.extend(f"- {item}" for item in reasons)
else:
    lines.append("- none")
lines += ["", "## Next steps", ""]
if next_steps:
    lines.extend(f"- {item}" for item in next_steps)
else:
    lines.append("- none")

md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

  write_latest "${json_path}" "${md_path}"

  if [[ "${JSON_MODE}" -eq 1 ]]; then
    cat "${json_path}"
  else
    cat "${md_path}"
  fi
}

validate_package() {
  local latest
  latest="$(latest_json_path)"
  if [[ ! -f "${latest}" ]]; then
    emit_no_latest
    return 1
  fi

  python3 - "${latest}" "${SCHEMA_PATH}" "${JSON_MODE}" <<'PY'
import json
import pathlib
import sys

latest = pathlib.Path(sys.argv[1])
schema = pathlib.Path(sys.argv[2])
as_json = sys.argv[3] == "1"

payload = json.loads(latest.read_text(encoding="utf-8"))
schema_payload = json.loads(schema.read_text(encoding="utf-8"))
required = schema_payload.get("required", [])
missing = [field for field in required if field not in payload]

paths_to_check = {
    "bom_file": payload.get("bom_file"),
    "cpl_file": payload.get("cpl_file"),
    "gerber_dir": payload.get("gerber_dir"),
    "drill_file": payload.get("drill_file"),
    "drc_report": payload.get("drc_report"),
}
missing_paths = []
for key, value in paths_to_check.items():
    if value and not pathlib.Path(value).exists():
      missing_paths.append(key)

result = {
    "status": "ok" if not missing and not missing_paths else "degraded",
    "latest_json": str(latest),
    "missing_fields": missing,
    "missing_paths": missing_paths,
    "acceptance_gates": payload.get("acceptance_gates", {}),
}

if as_json:
    print(json.dumps(result, indent=2, ensure_ascii=True))
else:
    print("Fab package validation")
    print(f"- status: {result['status']}")
    print("- missing_fields: " + (", ".join(result["missing_fields"]) or "none"))
    print("- missing_paths: " + (", ".join(result["missing_paths"]) or "none"))
PY
}

summary_package() {
  local latest
  latest="$(latest_json_path)"
  if [[ ! -f "${latest}" ]]; then
    emit_no_latest
    return 0
  fi
  if [[ "${JSON_MODE}" -eq 1 ]]; then
    cat "${latest}"
  else
    cat "$(latest_md_path)"
  fi
}

artifacts_package() {
  local latest latest_md
  latest="$(latest_json_path)"
  latest_md="$(latest_md_path)"
  if [[ "${JSON_MODE}" -eq 1 ]]; then
    cat <<EOF
{
  "status": "ok",
  "schema": $(json_escape "${SCHEMA_PATH}"),
  "latest_json": $(json_escape "${latest}"),
  "latest_markdown": $(json_escape "${latest_md}")
}
EOF
  else
    printf 'Fab package artifacts\n'
    printf -- '- schema: %s\n' "${SCHEMA_PATH}"
    printf -- '- latest_json: %s\n' "${latest}"
    printf -- '- latest_markdown: %s\n' "${latest_md}"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --action)
      ACTION="${2:-}"
      shift 2
      ;;
    --json)
      JSON_MODE=1
      shift
      ;;
    --board-id)
      BOARD_ID="${2:-}"
      shift 2
      ;;
    --schematic)
      SOURCE_SCHEMATIC="${2:-}"
      shift 2
      ;;
    --board)
      SOURCE_BOARD="${2:-}"
      shift 2
      ;;
    --route-origin)
      ROUTE_ORIGIN="${2:-}"
      shift 2
      ;;
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

case "${ACTION}" in
  summary)
    summary_package
    ;;
  build)
    build_package
    ;;
  validate)
    validate_package
    ;;
  artifacts)
    artifacts_package
    ;;
  *)
    echo "Unknown action: ${ACTION}" >&2
    usage >&2
    exit 1
    ;;
esac
