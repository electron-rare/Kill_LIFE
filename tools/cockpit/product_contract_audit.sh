#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

CONTRACT_FILE="${ROOT_DIR}/specs/contracts/ops_mascarade_kill_life.contract.json"
OUTPUT_DIR="${ROOT_DIR}/artifacts/cockpit/product_contract_audit"

JSON_ONLY=0
MARKDOWN_ONLY=0

usage() {
  cat <<'EOF'
Usage:
  bash tools/cockpit/product_contract_audit.sh [--json|--markdown]

Description:
  Audit statique du contrat produit ops / Mascarade / kill_life.
  Le script ne relance pas les lanes runtime ; il vérifie les surfaces
  cockpit et les points d'entrée source pour s'assurer que les ancrages
  de continuité et les champs du contrat restent visibles.

Options:
  --json       Affiche seulement le JSON latest.
  --markdown   Affiche seulement le Markdown latest.
  -h, --help   Affiche cette aide.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      JSON_ONLY=1
      shift
      ;;
    --markdown)
      MARKDOWN_ONLY=1
      shift
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

if [[ "${JSON_ONLY}" == "1" && "${MARKDOWN_ONLY}" == "1" ]]; then
  printf 'Use only one of --json or --markdown.\n' >&2
  exit 2
fi

mkdir -p "${OUTPUT_DIR}"

TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
JSON_FILE="${OUTPUT_DIR}/product_contract_audit_${TIMESTAMP}.json"
MARKDOWN_FILE="${OUTPUT_DIR}/product_contract_audit_${TIMESTAMP}.md"
LATEST_JSON="${OUTPUT_DIR}/latest.json"
LATEST_MARKDOWN="${OUTPUT_DIR}/latest.md"

read -r -d '' TARGETS_JSON <<'EOF_TARGETS' || true
[
  {
    "name": "render_product_contract_handoff",
    "file": "tools/cockpit/render_product_contract_handoff.sh",
    "kind": "handoff-runtime",
    "required": ["--no-refresh", "degraded_reasons", "prereqs_refreshed", "kill_life_refresh_status", "daily_refresh_status"]
  },
  {
    "name": "full_operator_lane",
    "file": "tools/cockpit/full_operator_lane.sh",
    "kind": "json-surface",
    "required": ["owner", "decision", "resume_ref", "trust_level", "routing", "memory_entry", "product_contract_handoff_status", "product_contract_handoff_artifact", "product_contract_handoff_markdown"]
  },
  {
    "name": "run_alignment_daily",
    "file": "tools/cockpit/run_alignment_daily.sh",
    "kind": "json-surface",
    "required": ["owner", "decision", "resume_ref", "trust_level", "routing", "memory_entry", "product_contract_handoff_status", "product_contract_handoff_artifact", "product_contract_handoff_markdown"]
  },
  {
    "name": "mascarade_runtime_health",
    "file": "tools/cockpit/mascarade_runtime_health.sh",
    "kind": "json-surface",
    "required": ["owner", "decision", "resume_ref", "trust_level", "routing", "memory_entry"]
  },
  {
    "name": "mascarade_incidents_tui",
    "file": "tools/cockpit/mascarade_incidents_tui.sh",
    "kind": "json-surface",
    "required": ["resume_ref", "trust_level", "routing", "memory_entry"]
  },
  {
    "name": "mascarade_incident_registry",
    "file": "tools/cockpit/mascarade_incident_registry.sh",
    "kind": "registry",
    "required": ["resume_ref", "trust_level", "routing", "memory_entry"]
  },
  {
    "name": "mascarade_logs_tui",
    "file": "tools/cockpit/mascarade_logs_tui.sh",
    "kind": "logs",
    "required": ["resume_ref", "trust_level", "routing", "memory_entry"]
  },
  {
    "name": "render_daily_operator_summary",
    "file": "tools/cockpit/render_daily_operator_summary.sh",
    "kind": "handoff",
    "required": ["trust_level", "resume_ref", "routing", "memory_entry"]
  },
  {
    "name": "render_weekly_refonte_summary",
    "file": "tools/cockpit/render_weekly_refonte_summary.sh",
    "kind": "handoff",
    "required": ["trust_level", "resume_ref", "routing", "memory_entry"]
  },
  {
    "name": "yiacad_operator_index",
    "file": "tools/cockpit/yiacad_operator_index.sh",
    "kind": "entrypoint",
    "required": [
      "artifacts/cockpit/kill_life_memory/latest.json",
      "artifacts/cockpit/kill_life_memory/latest.md",
      "artifacts/cockpit/daily_operator_summary_latest.md",
      "artifacts/cockpit/product_contract_handoff/latest.json",
      "artifacts/cockpit/product_contract_handoff/latest.md"
    ]
  },
  {
    "name": "intelligence_tui",
    "file": "tools/cockpit/intelligence_tui.sh",
    "kind": "governance",
    "required": ["kill_life_memory", "kill_life_json", "kill_life_markdown"]
  },
  {
    "name": "refonte_tui",
    "file": "tools/cockpit/refonte_tui.sh",
    "kind": "entrypoint",
    "required": [
      "artifacts/cockpit/kill_life_memory/latest.json",
      "artifacts/cockpit/kill_life_memory/latest.md",
      "artifacts/cockpit/daily_operator_summary_latest.md",
      "artifacts/cockpit/product_contract_handoff/latest.json",
      "artifacts/cockpit/product_contract_handoff/latest.md"
    ]
  },
  {
    "name": "lot_chain",
    "file": "tools/cockpit/lot_chain.sh",
    "kind": "pilot-chain",
    "required": [
      "artifacts/cockpit/kill_life_memory/latest.json",
      "artifacts/cockpit/kill_life_memory/latest.md",
      "T-LC-008"
    ]
  }
]
EOF_TARGETS

PRODUCT_CONTRACT_TARGETS="${TARGETS_JSON}" python3 - "${CONTRACT_FILE}" "${JSON_FILE}" "${MARKDOWN_FILE}" <<'PY'
import datetime as dt
import json
import os
import pathlib
import sys

contract_path = pathlib.Path(sys.argv[1])
json_path = pathlib.Path(sys.argv[2])
markdown_path = pathlib.Path(sys.argv[3])
root_dir = contract_path.parents[2]

contract = json.loads(contract_path.read_text(encoding="utf-8"))
targets = json.loads(os.environ["PRODUCT_CONTRACT_TARGETS"])

required_fields = [
    entry["name"]
    for entry in contract.get("contract_fields", [])
    if entry.get("required")
]
expected_required = [
    "status",
    "decision",
    "owner",
    "artifacts",
    "next_step",
    "resume_ref",
    "trust_level",
    "routing",
    "memory_entry",
]
contract_gaps = [field for field in expected_required if field not in required_fields]

results = []
ok_count = 0
gap_count = 0
missing_count = 0

for target in targets:
    file_path = root_dir / target["file"]
    record = {
        "name": target["name"],
        "kind": target["kind"],
        "file": target["file"],
        "required": target["required"],
        "missing": [],
    }
    if not file_path.exists():
        record["status"] = "missing-file"
        record["missing"] = target["required"]
        missing_count += 1
        results.append(record)
        continue
    content = file_path.read_text(encoding="utf-8")
    missing = [needle for needle in target["required"] if needle not in content]
    record["missing"] = missing
    if missing:
        record["status"] = "gap"
        gap_count += 1
    else:
        record["status"] = "ok"
        ok_count += 1
    results.append(record)

status = "ok" if not contract_gaps and gap_count == 0 and missing_count == 0 else "degraded"

next_steps = []
if contract_gaps:
    next_steps.append(
        "Aligner specs/contracts/ops_mascarade_kill_life.contract.json sur les champs requis attendus."
    )
if gap_count or missing_count:
    next_steps.append(
        "Corriger les surfaces en ecart pour garder la meme reprise entre ops, Mascarade et kill_life."
    )
if not next_steps:
    next_steps.append(
        "Maintenir l audit statique a chaque lot de consolidation des surfaces cockpit."
    )

payload = {
    "contract_version": contract.get("version", "unknown"),
    "component": "product-contract-audit",
    "status": status,
    "contract_status": status,
    "generated_at": dt.datetime.now().astimezone().isoformat(timespec="seconds"),
    "required_contract_fields": required_fields,
    "expected_required_fields": expected_required,
    "contract_field_gaps": contract_gaps,
    "target_count": len(results),
    "targets_ok": ok_count,
    "targets_gap": gap_count,
    "targets_missing_file": missing_count,
    "targets": results,
    "next_steps": next_steps,
    "artifacts": [
        "artifacts/cockpit/product_contract_audit/latest.json",
        "artifacts/cockpit/product_contract_audit/latest.md",
        "specs/contracts/ops_mascarade_kill_life.contract.json"
    ]
}

json_path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

lines = [
    "# Audit statique du contrat produit ops / Mascarade / kill_life",
    "",
    f"- Généré: `{payload['generated_at']}`",
    f"- Version contrat: `{payload['contract_version']}`",
    f"- Statut: `{payload['status']}`",
    f"- Surfaces OK: `{ok_count}` / `{len(results)}`",
    f"- Surfaces en écart: `{gap_count}`",
    f"- Fichiers manquants: `{missing_count}`",
    "",
    "## Champs requis",
    "",
    f"- Attendus: `{', '.join(expected_required)}`",
    f"- Contrat courant: `{', '.join(required_fields)}`",
]

if contract_gaps:
    lines.extend([
        "",
        "## Écarts contrat",
        "",
        f"- Champs absents: `{', '.join(contract_gaps)}`",
    ])

lines.extend([
    "",
    "## Couverture par surface",
    "",
])

for result in results:
    lines.append(
        f"- `{result['name']}` (`{result['kind']}`) via `{result['file']}`: `{result['status']}`"
    )
    if result["missing"]:
        lines.append(f"  - Manquants: `{', '.join(result['missing'])}`")

lines.extend([
    "",
    "## Prochaines actions",
    "",
])
for step in next_steps:
    lines.append(f"- {step}")

markdown_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

cp "${JSON_FILE}" "${LATEST_JSON}"
cp "${MARKDOWN_FILE}" "${LATEST_MARKDOWN}"

if [[ "${JSON_ONLY}" == "1" ]]; then
  cat "${LATEST_JSON}"
elif [[ "${MARKDOWN_ONLY}" == "1" ]]; then
  cat "${LATEST_MARKDOWN}"
else
  printf 'product_contract_audit status=%s json=%s markdown=%s\n' \
    "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["status"])' "${LATEST_JSON}")" \
    "${LATEST_JSON#${ROOT_DIR}/}" \
    "${LATEST_MARKDOWN#${ROOT_DIR}/}"
fi
