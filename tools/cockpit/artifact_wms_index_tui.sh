#!/usr/bin/env bash
set -euo pipefail

# artifact_wms_index_tui.sh
# Index latest artifacts by lot, layer, and consumer.
# Contract: cockpit-v1
# Date: 2026-03-22

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARTIFACT_ROOT="${ARTIFACT_ROOT:-${ROOT_DIR}/artifacts}"
RULES_FILE="${RULES_FILE:-${ROOT_DIR}/specs/contracts/artifact_wms_index_rules.json}"
ACTION="summary"
JSON_MODE=0

usage() {
  cat <<'EOF'
Usage: artifact_wms_index_tui.sh [--action summary|entries|unknown] [--json]

Actions:
  summary   Show aggregate WMS artifact index summary
  entries   Show all indexed latest artifacts
  unknown   Show only artifacts that did not match a rule

Options:
  --json    Emit cockpit-v1 JSON
  --help    Show this help
EOF
}

run_view() {
  python3 - "$ARTIFACT_ROOT" "$RULES_FILE" "$ACTION" "$JSON_MODE" <<'PY'
import fnmatch
import json
import sys
from pathlib import Path

artifact_root = Path(sys.argv[1])
rules_file = Path(sys.argv[2])
action = sys.argv[3]
json_mode = sys.argv[4] == "1"

rules = json.loads(rules_file.read_text(encoding="utf-8"))
patterns = rules["scan"]["latest_patterns"]
rule_entries = rules["rules"]
defaults = rules["defaults"]

latest_files = []
for pattern in patterns:
    latest_files.extend(artifact_root.rglob(pattern))

seen = set()
entries = []

def match_rule(relpath: str):
    for rule in rule_entries:
        if rule["match"] in relpath:
            return rule
    return defaults

for path in sorted(latest_files):
    rel = path.relative_to(artifact_root).as_posix()
    if rel in seen:
        continue
    seen.add(rel)
    rule = match_rule(rel)
    entry = {
        "artifact": rel,
        "absolute_path": str(path),
        "consumer_layer": rule["consumer_layer"],
        "owner_agent": rule["owner_agent"],
        "lot_refs": rule["lot_refs"],
        "purpose": rule["purpose"],
        "size_bytes": path.stat().st_size if path.exists() else 0,
        "status": "known" if rule is not defaults else "unknown",
    }
    entries.append(entry)

unknown = [entry for entry in entries if entry["status"] == "unknown"]

payload = {
    "contract_version": "cockpit-v1",
    "component": "artifact-wms-index",
    "action": action,
    "status": "ok",
    "artifact_root": str(artifact_root),
    "rules_file": str(rules_file),
    "entries_total": len(entries),
    "unknown_total": len(unknown),
}

if action == "summary":
    counts = {}
    for entry in entries:
        counts[entry["consumer_layer"]] = counts.get(entry["consumer_layer"], 0) + 1
    payload["counts_by_consumer_layer"] = counts
    payload["sample_latest"] = entries[:10]
elif action == "entries":
    payload["entries"] = entries
elif action == "unknown":
    payload["entries"] = unknown
else:
    raise SystemExit(f"unknown action: {action}")

if json_mode:
    print(json.dumps(payload, indent=2))
    raise SystemExit(0)

if action == "summary":
    print("Artifact WMS Index")
    print(f"artifact root: {artifact_root}")
    print(f"rules file: {rules_file}")
    print(f"entries total: {len(entries)}")
    print(f"unknown total: {len(unknown)}")
    for layer, count in sorted(payload["counts_by_consumer_layer"].items()):
        print(f"- {layer}: {count}")
elif action in {"entries", "unknown"}:
    print("Artifacts")
    for entry in payload["entries"]:
        print(
            f"- {entry['artifact']} | consumer={entry['consumer_layer']} | "
            f"owner={entry['owner_agent']} | lots={','.join(entry['lot_refs']) or '-'} | "
            f"status={entry['status']}"
        )
PY
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
    --help|-h)
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

case "$ACTION" in
  summary|entries|unknown)
    run_view
    ;;
  *)
    printf 'Unknown action: %s\n' "$ACTION" >&2
    usage >&2
    exit 2
    ;;
esac
