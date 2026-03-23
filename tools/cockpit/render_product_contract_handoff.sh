#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

AUDIT_JSON="${ROOT_DIR}/artifacts/cockpit/product_contract_audit/latest.json"
KILL_LIFE_JSON="${ROOT_DIR}/artifacts/cockpit/kill_life_memory/latest.json"
KILL_LIFE_MD="${ROOT_DIR}/artifacts/cockpit/kill_life_memory/latest.md"
DAILY_MD="${ROOT_DIR}/artifacts/cockpit/daily_operator_summary_latest.md"
OUTPUT_DIR="${ROOT_DIR}/artifacts/cockpit/product_contract_handoff"

JSON_ONLY=0
MARKDOWN_ONLY=0
NO_REFRESH=0

usage() {
  cat <<'EOF'
Usage:
  bash tools/cockpit/render_product_contract_handoff.sh [--json|--markdown|--no-refresh]

Description:
  Génère un handoff produit minimal entre ops, Mascarade et kill_life.
  Le handoff agrège l'audit du contrat, la mémoire latest kill_life et
  la synthèse quotidienne pour fournir un seul point de reprise.

Options:
  --json       Affiche seulement le JSON latest.
  --markdown   Affiche seulement le Markdown latest.
  --no-refresh Garde un mode strict lecture seule sans régénérer les prérequis légers.
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
    --no-refresh)
      NO_REFRESH=1
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
JSON_FILE="${OUTPUT_DIR}/product_contract_handoff_${TIMESTAMP}.json"
MARKDOWN_FILE="${OUTPUT_DIR}/product_contract_handoff_${TIMESTAMP}.md"
LATEST_JSON="${OUTPUT_DIR}/latest.json"
LATEST_MARKDOWN="${OUTPUT_DIR}/latest.md"

python3 - "${ROOT_DIR}" "${AUDIT_JSON}" "${KILL_LIFE_JSON}" "${DAILY_MD}" "${JSON_FILE}" "${MARKDOWN_FILE}" "${NO_REFRESH}" "${TIMESTAMP}" <<'PY'
import datetime as dt
import json
import pathlib
import subprocess
import sys

root_dir = pathlib.Path(sys.argv[1])
audit_path = pathlib.Path(sys.argv[2])
kill_life_path = pathlib.Path(sys.argv[3])
daily_path = pathlib.Path(sys.argv[4])
json_out = pathlib.Path(sys.argv[5])
md_out = pathlib.Path(sys.argv[6])
no_refresh = sys.argv[7] == "1"
timestamp = sys.argv[8]


def load_json(path: pathlib.Path):
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}


def read_markdown_snippet(path: pathlib.Path, max_lines: int = 12):
    if not path.exists():
        return []
    lines = path.read_text(encoding="utf-8").splitlines()
    return [line for line in lines[:max_lines] if line.strip()]


def run_json_command(command):
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        return {"status": "failed", "stderr": result.stderr.strip(), "stdout": result.stdout.strip()}
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return {"status": "failed", "stderr": result.stderr.strip(), "stdout": result.stdout.strip(), "error": "invalid-json"}


audit = load_json(audit_path)
audit_status = audit.get("status", "missing")
degraded_reasons = []
prereqs_refreshed = []
kill_life_refresh_status = "skipped"
daily_refresh_status = "skipped"

if not no_refresh and not kill_life_path.exists():
    kill_life_refresh = run_json_command([
        "bash",
        str(root_dir / "tools/cockpit/write_kill_life_memory_entry.sh"),
        "--component", "product_contract_handoff",
        "--status", "ok" if audit_status == "ok" else "degraded",
        "--owner", "KillLife-Bridge",
        "--decision-action", "refresh-product-contract-handoff-prereqs",
        "--decision-reason", "Refresh lightweight kill_life continuity so the product handoff can render without replaying a heavy lane.",
        "--next-step", "Review artifacts/cockpit/product_contract_handoff/latest.md",
        "--resume-ref", f"kill-life:product-contract-handoff:{timestamp}",
        "--trust-level", "bounded" if audit_status == "ok" else "inferred",
        "--artifact", "artifacts/cockpit/product_contract_audit/latest.json",
        "--json",
    ])
    kill_life_refresh_status = str(kill_life_refresh.get("status", "failed"))
    prereqs_refreshed.append("kill_life_memory")

kill_life = load_json(kill_life_path)
entry = kill_life.get("entry", {}) if isinstance(kill_life.get("entry"), dict) else {}
routing = entry.get("routing", {}) if isinstance(entry.get("routing"), dict) else {}
decision = entry.get("decision", {}) if isinstance(entry.get("decision"), dict) else {}
memory_entry = entry.get("memory_entry", {}) if isinstance(entry.get("memory_entry"), dict) else {}

if not no_refresh and not daily_path.exists():
    daily_refresh = run_json_command([
        "bash",
        str(root_dir / "tools/cockpit/render_daily_operator_summary.sh"),
        "--json",
    ])
    daily_refresh_status = str(daily_refresh.get("status", "failed"))
    prereqs_refreshed.append("daily_operator_summary")

daily_snippet = read_markdown_snippet(daily_path)
kill_life_available = kill_life_path.exists() and bool(kill_life)
daily_available = daily_path.exists() and bool(daily_snippet)

trust_level = kill_life.get("trust_level") or entry.get("trust_level", "inferred")
resume_ref = kill_life.get("resume_ref") or entry.get("resume_ref", "missing")
owner = entry.get("owner", "unknown")
selected_target = routing.get("selected_target", "unknown")
next_step = kill_life.get("next_step") or entry.get("next_step", "Review latest daily summary")

if audit_status != "ok":
    degraded_reasons.append(f"audit-{audit_status}")
if kill_life_refresh_status in {"failed", "error", "blocked"}:
    degraded_reasons.append(f"kill-life-refresh-{kill_life_refresh_status}")
if daily_refresh_status in {"failed", "error", "blocked"}:
    degraded_reasons.append(f"daily-refresh-{daily_refresh_status}")
if not kill_life_available:
    degraded_reasons.append("missing-kill-life-latest")
if not daily_available:
    degraded_reasons.append("missing-daily-summary-latest")

status = "degraded" if degraded_reasons else "ok"
contract_status = status

next_steps = []
if audit_status != "ok":
    next_steps.append("Refresh product contract audit before relying on the handoff.")
if not kill_life_available:
    next_steps.append("Refresh kill_life continuity memory before using the product handoff as a restart point.")
if not daily_available:
    next_steps.append("Regenerate the daily operator summary so the handoff includes an operator-readable snippet.")
if not next_steps:
    next_steps.append(next_step)

payload = {
    "contract_version": "2026-03-21",
    "component": "product-contract-handoff",
    "status": status,
    "contract_status": contract_status,
    "generated_at": dt.datetime.now().astimezone().isoformat(timespec="seconds"),
    "audit_status": audit_status,
    "trust_level": trust_level,
    "resume_ref": resume_ref,
    "owner": owner,
    "selected_target": selected_target,
    "decision": decision,
    "memory_entry": memory_entry,
    "next_step": next_step,
    "next_steps": next_steps,
    "degraded_reasons": degraded_reasons,
    "prereqs_refreshed": prereqs_refreshed,
    "kill_life_refresh_status": kill_life_refresh_status,
    "daily_refresh_status": daily_refresh_status,
    "kill_life_available": kill_life_available,
    "daily_summary_available": daily_available,
    "daily_summary_snippet": daily_snippet,
    "json_file": str(json_out),
    "markdown_file": str(md_out),
    "latest_json_file": str(json_out.with_name("latest.json")),
    "latest_markdown_file": str(md_out.with_name("latest.md")),
    "artifacts": [
        "artifacts/cockpit/product_contract_audit/latest.json",
        "artifacts/cockpit/kill_life_memory/latest.json",
        "artifacts/cockpit/daily_operator_summary_latest.md",
        "artifacts/cockpit/product_contract_handoff/latest.json",
        "artifacts/cockpit/product_contract_handoff/latest.md",
    ],
}

json_out.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

lines = [
    "# Product contract handoff",
    "",
    f"- generated_at: {payload['generated_at']}",
    f"- audit_status: {audit_status}",
    f"- trust_level: {trust_level}",
    f"- resume_ref: {resume_ref}",
    f"- owner: {owner}",
    f"- selected_target: {selected_target}",
    f"- next_step: {next_step}",
    f"- degraded_reasons: {', '.join(degraded_reasons) if degraded_reasons else 'none'}",
    f"- prereqs_refreshed: {', '.join(prereqs_refreshed) if prereqs_refreshed else 'none'}",
    f"- kill_life_refresh_status: {kill_life_refresh_status}",
    f"- daily_refresh_status: {daily_refresh_status}",
    f"- kill_life_available: {kill_life_available}",
    f"- daily_summary_available: {daily_available}",
]

if decision:
    lines.extend([
        "",
        "## Decision",
        "",
        f"- action: {decision.get('action', 'unknown')}",
        f"- reason: {decision.get('reason', 'unknown')}",
    ])

if memory_entry:
    lines.extend([
        "",
        "## Continuity",
        "",
        f"- intent: {memory_entry.get('intent', 'unknown')}",
        f"- decision_state: {memory_entry.get('decision_state', 'unknown')}",
        f"- handoff: {memory_entry.get('handoff', 'unknown')}",
    ])

lines.extend([
    "",
    "## Next steps",
    "",
])
for step in next_steps:
    lines.append(f"- {step}")

lines.extend([
    "",
    "## Daily snippet",
    "",
])
if daily_snippet:
    for line in daily_snippet:
        lines.append(f"- {line}")
else:
    lines.append("- daily summary unavailable")

md_out.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

cp "${JSON_FILE}" "${LATEST_JSON}"
cp "${MARKDOWN_FILE}" "${LATEST_MARKDOWN}"

if [[ "${JSON_ONLY}" == "1" ]]; then
  cat "${LATEST_JSON}"
elif [[ "${MARKDOWN_ONLY}" == "1" ]]; then
  cat "${LATEST_MARKDOWN}"
else
  printf 'product_contract_handoff status=%s json=%s markdown=%s\n' \
    "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["status"])' "${LATEST_JSON}")" \
    "${LATEST_JSON#${ROOT_DIR}/}" \
    "${LATEST_MARKDOWN#${ROOT_DIR}/}"
fi
