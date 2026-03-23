#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COCKPIT_DIR="$ROOT_DIR/artifacts/cockpit"
OUTPUT_MODE="text"

usage() {
  cat <<'EOF'
Usage:
  bash tools/cockpit/render_mascarade_incident_watch.sh [--json]

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
OUT_MD="$COCKPIT_DIR/mascarade_incident_watch_${RUN_ID}.md"
OUT_JSON="$COCKPIT_DIR/mascarade_incident_watch_${RUN_ID}.json"

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
queue_file = cockpit_dir / "mascarade_incident_queue_latest.json"
daily_file = cockpit_dir / "daily_operator_summary_latest.json"
memory_json = cockpit_dir / "kill_life_memory" / "latest.json"
memory_md = cockpit_dir / "kill_life_memory" / "latest.md"


def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}


registry = load_json(registry_file)
queue = load_json(queue_file)
daily = load_json(daily_file)
memory_payload = load_json(memory_json) if memory_json.exists() else {}
memory_entry = memory_payload.get("entry", {}) if isinstance(memory_payload.get("entry"), dict) else {}
routing = memory_entry.get("routing", {}) if isinstance(memory_entry.get("routing"), dict) else {}
resume_ref = memory_payload.get("resume_ref") or memory_entry.get("resume_ref", "")
trust_level = memory_payload.get("trust_level") or memory_entry.get("trust_level", "inferred")

priority_counts = registry.get("priority_counts", {}) if isinstance(registry.get("priority_counts"), dict) else {}
severity_counts = registry.get("severity_counts", {}) if isinstance(registry.get("severity_counts"), dict) else {}
entries = queue.get("entries", []) if isinstance(queue.get("entries"), list) else []
top_entries = entries[:5]

next_steps = []
for candidate in (queue.get("next_steps", []), registry.get("next_steps", []), daily.get("next_steps", [])):
    if isinstance(candidate, list):
        for step in candidate:
            if step and step not in next_steps:
                next_steps.append(step)
if not next_steps:
    next_steps.append("Refresh the latest queue and registry artifacts before the next operator handoff.")

status = "ok" if registry_file.exists() or queue_file.exists() else "degraded"
generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

lines = [
    "# Mascarade incident watch",
    "",
    f"- generated_at: {generated_at}",
    f"- registry_file: {registry_file if registry_file.exists() else 'missing'}",
    f"- queue_file: {queue_file if queue_file.exists() else 'missing'}",
    f"- daily_file: {daily_file if daily_file.exists() else 'missing'}",
    f"- trust_level: {trust_level}",
    f"- resume_ref: {resume_ref or 'missing'}",
    f"- selected_target: {routing.get('selected_target', 'unknown')}",
    f"- kill_life_memory: {memory_md if memory_md.exists() else 'missing'}",
    "",
    "## Rollup",
    "",
    f"- priority P1/P2/P3: {priority_counts.get('P1', 0)}/{priority_counts.get('P2', 0)}/{priority_counts.get('P3', 0)}",
    f"- severity high/medium/low: {severity_counts.get('high', 0)}/{severity_counts.get('medium', 0)}/{severity_counts.get('low', 0)}",
    "",
    "## Top queue",
    "",
]

if top_entries:
    lines.extend([
        "| Priority | Severity | Status | Source | Timestamp | Reasons |",
        "| --- | --- | --- | --- | --- | --- |",
    ])
    for entry in top_entries:
        reasons = ", ".join([reason for reason in entry.get("reasons", []) if reason]) or "none"
        lines.append(
            f"| {entry.get('priority', 'P3')} | {entry.get('severity', 'low')} | "
            f"{entry.get('status', 'unknown')} | {entry.get('source', 'unknown')} | "
            f"{entry.get('ts') or 'n/a'} | {reasons} |"
        )
else:
    lines.append("- no queued incident")

lines.extend(["", "## Next steps", ""])
for step in next_steps[:5]:
    lines.append(f"- {step}")

out_md.write_text("\n".join(lines) + "\n", encoding="utf-8")
shutil.copyfile(out_md, out_md.with_name("mascarade_incident_watch_latest.md"))

payload = {
    "contract_version": "cockpit-v1",
    "component": "mascarade-incident-watch",
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
    "priority_counts": priority_counts,
    "severity_counts": severity_counts,
    "top_entries": top_entries,
    "registry_file": str(registry_file) if registry_file.exists() else "",
    "queue_file": str(queue_file) if queue_file.exists() else "",
    "daily_file": str(daily_file) if daily_file.exists() else "",
    "markdown_file": str(out_md),
    "latest_markdown_file": str(out_md.with_name("mascarade_incident_watch_latest.md")),
    "artifacts": [
        str(out_md),
        str(out_md.with_name("mascarade_incident_watch_latest.md")),
        str(out_json),
        str(out_json.with_name("mascarade_incident_watch_latest.json")),
    ] + [str(path) for path in (registry_file, queue_file, daily_file) if path.exists()] + ([str(memory_json)] if memory_json.exists() else []),
    "degraded_reasons": [] if status == "ok" else ["incident-watch-missing-artifacts"],
    "next_steps": next_steps[:5],
}

out_json.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
shutil.copyfile(out_json, out_json.with_name("mascarade_incident_watch_latest.json"))
print(json.dumps(payload, ensure_ascii=False, indent=2))
PY

if [[ "$OUTPUT_MODE" == "json" ]]; then
  cat "$OUT_JSON"
else
  cat <<EOF
Mascarade incident watch
markdown: $OUT_MD
json: $OUT_JSON
EOF
fi
