#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
MEMORY_DIR="${ROOT_DIR}/artifacts/cockpit/kill_life_memory"
COMPONENT="unknown"
STATUS="degraded"
OWNER="SyncOps"
DECISION_ACTION="record-memory-entry"
DECISION_REASON="Persist execution continuity in kill_life."
NEXT_STEP="Review the latest cockpit artifact."
RESUME_REF=""
TRUST_LEVEL="inferred"
ROUTING_FILE=""
JSON_OUTPUT=0
ARTIFACTS=()

usage() {
  cat <<'USAGE'
Usage: bash tools/cockpit/write_kill_life_memory_entry.sh [options]

Options:
  --component NAME
  --status ok|degraded|error|blocked
  --owner NAME
  --decision-action TEXT
  --decision-reason TEXT
  --next-step TEXT
  --resume-ref TEXT
  --trust-level verified|bounded|inferred
  --routing-file FILE
  --artifact PATH          Repeatable
  --json
  -h, --help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --component)
      COMPONENT="${2:-}"
      shift 2
      ;;
    --status)
      STATUS="${2:-}"
      shift 2
      ;;
    --owner)
      OWNER="${2:-}"
      shift 2
      ;;
    --decision-action)
      DECISION_ACTION="${2:-}"
      shift 2
      ;;
    --decision-reason)
      DECISION_REASON="${2:-}"
      shift 2
      ;;
    --next-step)
      NEXT_STEP="${2:-}"
      shift 2
      ;;
    --resume-ref)
      RESUME_REF="${2:-}"
      shift 2
      ;;
    --trust-level)
      TRUST_LEVEL="${2:-}"
      shift 2
      ;;
    --routing-file)
      ROUTING_FILE="${2:-}"
      shift 2
      ;;
    --artifact)
      ARTIFACTS+=("${2:-}")
      shift 2
      ;;
    --json)
      JSON_OUTPUT=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

mkdir -p "${MEMORY_DIR}"
timestamp="$(date '+%Y%m%d_%H%M%S')"
entry_json="${MEMORY_DIR}/${COMPONENT}_${timestamp}.json"
entry_md="${MEMORY_DIR}/${COMPONENT}_${timestamp}.md"
latest_json="${MEMORY_DIR}/latest.json"
latest_md="${MEMORY_DIR}/latest.md"
component_latest_json="${MEMORY_DIR}/${COMPONENT}_latest.json"
component_latest_md="${MEMORY_DIR}/${COMPONENT}_latest.md"
intelligence_json="${ROOT_DIR}/artifacts/cockpit/intelligence_program/latest.json"
intelligence_md="${ROOT_DIR}/artifacts/cockpit/intelligence_program/latest.md"

if [[ ! -f "${intelligence_json}" || ! -f "${intelligence_md}" ]]; then
  bash "${ROOT_DIR}/tools/cockpit/intelligence_tui.sh" --action memory --json >/dev/null 2>/dev/null || true
fi

ARTIFACTS_JSON="$(
  python3 - "${ARTIFACTS[@]}" <<'PY'
import json
import sys

print(json.dumps([item for item in sys.argv[1:] if item], ensure_ascii=True))
PY
)"

ARTIFACTS_JSON="${ARTIFACTS_JSON}" python3 - "${entry_json}" "${entry_md}" "${latest_json}" "${latest_md}" "${component_latest_json}" "${component_latest_md}" "${COMPONENT}" "${STATUS}" "${OWNER}" "${DECISION_ACTION}" "${DECISION_REASON}" "${NEXT_STEP}" "${RESUME_REF}" "${TRUST_LEVEL}" "${ROUTING_FILE}" "${intelligence_json}" "${intelligence_md}" <<'PY'
import json
import os
import sys
from pathlib import Path

entry_json = Path(sys.argv[1])
entry_md = Path(sys.argv[2])
latest_json = Path(sys.argv[3])
latest_md = Path(sys.argv[4])
component_latest_json = Path(sys.argv[5])
component_latest_md = Path(sys.argv[6])
component = sys.argv[7]
status = sys.argv[8]
owner = sys.argv[9]
decision_action = sys.argv[10]
decision_reason = sys.argv[11]
next_step = sys.argv[12]
resume_ref = sys.argv[13]
trust_level = sys.argv[14]
routing_file = Path(sys.argv[15]) if sys.argv[15] else None
intelligence_json = Path(sys.argv[16])
intelligence_md = Path(sys.argv[17])
artifacts = json.loads(os.environ.get("ARTIFACTS_JSON", "[]"))

routing = {}
if routing_file and routing_file.exists():
    try:
        routing = json.loads(routing_file.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        routing = {"status": "invalid-json", "file": str(routing_file)}

intelligence_memory = {
    "json": str(intelligence_json) if intelligence_json.exists() else "",
    "markdown": str(intelligence_md) if intelligence_md.exists() else "",
}

entry = {
    "status": status,
    "component": component,
    "owner": owner,
    "decision": {
        "action": decision_action,
        "reason": decision_reason,
    },
    "next_step": next_step,
    "resume_ref": resume_ref,
    "trust_level": trust_level,
    "routing": routing,
    "artifacts": artifacts,
    "intelligence_memory": intelligence_memory,
}

summary = {
    "status": "ok",
    "component": component,
    "entry": entry,
    "artifacts": artifacts,
    "entry_file": str(entry_json),
    "markdown_file": str(entry_md),
    "latest_json": str(latest_json),
    "latest_markdown": str(latest_md),
    "component_latest_json": str(component_latest_json),
    "component_latest_markdown": str(component_latest_md),
    "resume_ref": resume_ref,
    "trust_level": trust_level,
    "intelligence_memory": intelligence_memory,
}

entry_md.write_text(
    "\n".join(
        (
            [
                f"# kill_life memory entry - {component}",
                "",
                f"- status: {status}",
                f"- owner: {owner}",
                f"- trust_level: {trust_level}",
                f"- resume_ref: {resume_ref}",
                f"- next_step: {next_step}",
                "",
                "## Decision",
                f"- action: {decision_action}",
                f"- reason: {decision_reason}",
                "",
                "## Routing",
                f"- selected_target: {routing.get('selected_target', 'unknown')}",
                f"- selected_host: {routing.get('selected_host', 'unknown')}",
                f"- family: {routing.get('family', 'unknown')}",
                "",
                "## Intelligence memory",
                f"- json: {intelligence_memory['json'] or 'missing'}",
                f"- markdown: {intelligence_memory['markdown'] or 'missing'}",
                "",
                "## Artifacts",
            ]
            + ([f"- {item}" for item in artifacts] if artifacts else ["- none"])
        )
    )
    + "\n",
    encoding="utf-8",
)

entry_json.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
latest_json.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
latest_md.write_text(entry_md.read_text(encoding="utf-8"), encoding="utf-8")
component_latest_json.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
component_latest_md.write_text(entry_md.read_text(encoding="utf-8"), encoding="utf-8")

print(json.dumps(summary, ensure_ascii=False))
PY
