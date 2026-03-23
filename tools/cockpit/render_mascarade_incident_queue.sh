#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COCKPIT_DIR="$ROOT_DIR/artifacts/cockpit"
OUTPUT_MODE="text"

usage() {
  cat <<'EOF'
Usage:
  bash tools/cockpit/render_mascarade_incident_queue.sh [--json]

Options:
  --json    Emit cockpit-v1 JSON to stdout
  -h,--help Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      OUTPUT_MODE="json"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

mkdir -p "$COCKPIT_DIR"

RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_MD="$COCKPIT_DIR/mascarade_incident_queue_${RUN_ID}.md"
OUT_JSON="$COCKPIT_DIR/mascarade_incident_queue_${RUN_ID}.json"

python3 - "$COCKPIT_DIR" "$OUT_MD" "$OUT_JSON" <<'PY'
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

cockpit_dir = Path(sys.argv[1])
out_md = Path(sys.argv[2])
out_json = Path(sys.argv[3])

registry_file = cockpit_dir / "mascarade_incident_registry_latest.json"
memory_json = cockpit_dir / "kill_life_memory" / "latest.json"
memory_md = cockpit_dir / "kill_life_memory" / "latest.md"


def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}


def parse_timestamp(value: str) -> float:
    if not value:
        return 0.0
    candidates = (
        value,
        value.replace(" UTC", "+00:00"),
        value.replace("Z", "+00:00"),
    )
    for candidate in candidates:
        try:
            return datetime.fromisoformat(candidate).timestamp()
        except ValueError:
            continue
    for pattern in ("%Y-%m-%d %H:%M:%S UTC", "%Y-%m-%dT%H:%M:%S%z", "%Y-%m-%d %H:%M:%S%z"):
        try:
            return datetime.strptime(value, pattern).timestamp()
        except ValueError:
            continue
    return 0.0


registry = load_json(registry_file)
memory_payload = load_json(memory_json) if memory_json.exists() else {}
memory_entry = memory_payload.get("entry", {}) if isinstance(memory_payload.get("entry"), dict) else {}
routing = memory_entry.get("routing", {}) if isinstance(memory_entry.get("routing"), dict) else {}
resume_ref = memory_payload.get("resume_ref") or memory_entry.get("resume_ref", "")
trust_level = memory_payload.get("trust_level") or memory_entry.get("trust_level", "inferred")
entries = registry.get("entries", [])
if not isinstance(entries, list):
    entries = []

priority_rank = {"P1": 0, "P2": 1, "P3": 2}
severity_rank = {"high": 0, "medium": 1, "low": 2}

queue_entries = sorted(
    entries,
    key=lambda item: (
        priority_rank.get(item.get("priority"), 9),
        severity_rank.get(item.get("severity"), 9),
        -parse_timestamp(item.get("ts", "")),
    ),
)

priority_counts = {"P1": 0, "P2": 0, "P3": 0}
severity_counts = {"high": 0, "medium": 0, "low": 0}
for entry in queue_entries:
    priority = entry.get("priority", "P3")
    severity = entry.get("severity", "low")
    priority_counts[priority] = priority_counts.get(priority, 0) + 1
    severity_counts[severity] = severity_counts.get(severity, 0) + 1

generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
status = "ok"
degraded_reasons = []
if not registry_file.exists():
    status = "degraded"
    degraded_reasons.append("registry-missing")
elif queue_entries:
    status = "degraded"
    degraded_reasons.extend(
        [
            f"{entry.get('priority', 'P3')}:{entry.get('source', 'unknown')}:{entry.get('status', 'unknown')}"
            for entry in queue_entries[:5]
        ]
    )

next_steps = []
for entry in queue_entries:
    for step in entry.get("next_steps", []):
        if step and step not in next_steps:
            next_steps.append(step)
if not next_steps:
    next_steps.append("Review the latest Mascarade incident registry before operator handoff.")

lines = [
    "# Mascarade incident queue",
    "",
    f"- generated_at: {generated_at}",
    f"- registry_file: {registry_file if registry_file.exists() else 'missing'}",
    f"- trust_level: {trust_level}",
    f"- resume_ref: {resume_ref or 'missing'}",
    f"- selected_target: {routing.get('selected_target', 'unknown')}",
    f"- kill_life_memory: {memory_md if memory_md.exists() else 'missing'}",
    f"- entry_count: {len(queue_entries)}",
    "- queue_order: priority -> severity -> recency",
    "",
    "## Queue summary",
    "",
    "| Priority | Count | Severity | Count |",
    "| --- | --- | --- | --- |",
    f"| P1 | {priority_counts['P1']} | high | {severity_counts['high']} |",
    f"| P2 | {priority_counts['P2']} | medium | {severity_counts['medium']} |",
    f"| P3 | {priority_counts['P3']} | low | {severity_counts['low']} |",
    "",
    "## Incident queue",
    "",
    "| Rank | Priority | Severity | Status | Source | Timestamp | Path | Reasons |",
    "| --- | --- | --- | --- | --- | --- | --- | --- |",
]

if queue_entries:
    for index, entry in enumerate(queue_entries, start=1):
        reasons = ", ".join([reason for reason in entry.get("reasons", []) if reason]) or "none"
        lines.append(
            f"| {index} | {entry.get('priority', 'P3')} | {entry.get('severity', 'low')} | "
            f"{entry.get('status', 'unknown')} | {entry.get('source', 'unknown')} | "
            f"{entry.get('ts') or 'n/a'} | `{entry.get('path') or 'n/a'}` | {reasons} |"
        )
else:
    lines.append("| 0 | P3 | low | ok | queue | n/a | `n/a` | none |")

lines.extend(["", "## Next steps", ""])
for step in next_steps[:10]:
    lines.append(f"- {step}")

out_md.write_text("\n".join(lines) + "\n", encoding="utf-8")
shutil.copyfile(out_md, out_md.with_name("mascarade_incident_queue_latest.md"))

payload = {
    "contract_version": "cockpit-v1",
    "component": "mascarade-incident-queue",
    "action": "render",
    "status": status,
    "contract_status": status,
    "generated_at": generated_at,
    "owner": memory_entry.get("owner", "SyncOps"),
    "resume_ref": resume_ref,
    "trust_level": trust_level,
    "routing": routing,
    "memory_entry": memory_entry,
    "memory_markdown": str(memory_md) if memory_md.exists() else "",
    "registry_file": str(registry_file) if registry_file.exists() else "",
    "entry_count": len(queue_entries),
    "queue_order": "priority,severity,recency",
    "priority_counts": priority_counts,
    "severity_counts": severity_counts,
    "entries": queue_entries,
    "markdown_file": str(out_md),
    "latest_markdown_file": str(out_md.with_name("mascarade_incident_queue_latest.md")),
    "artifacts": [
        str(out_md),
        str(out_md.with_name("mascarade_incident_queue_latest.md")),
        str(out_json),
        str(out_json.with_name("mascarade_incident_queue_latest.json")),
    ] + ([str(registry_file)] if registry_file.exists() else []) + ([str(memory_json)] if memory_json.exists() else []),
    "degraded_reasons": degraded_reasons,
    "next_steps": next_steps[:10],
}

out_json.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
shutil.copyfile(out_json, out_json.with_name("mascarade_incident_queue_latest.json"))
print(json.dumps(payload, ensure_ascii=False, indent=2))
PY

if [[ "$OUTPUT_MODE" == "json" ]]; then
  cat "$OUT_JSON"
else
  cat <<EOF
Mascarade incident queue
markdown: $OUT_MD
json: $OUT_JSON
EOF
fi
