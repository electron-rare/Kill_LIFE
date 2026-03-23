#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COCKPIT_DIR="$ROOT_DIR/artifacts/cockpit"
OPERATOR_DIR="$ROOT_DIR/artifacts/operator_lane"
OUTPUT_MODE="text"

usage() {
  cat <<'EOF'
Usage:
  bash tools/cockpit/mascarade_incident_registry.sh [--json]

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

mkdir -p "$COCKPIT_DIR" "$OPERATOR_DIR"

RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_MD="$COCKPIT_DIR/mascarade_incident_registry_${RUN_ID}.md"
OUT_JSON="$COCKPIT_DIR/mascarade_incident_registry_${RUN_ID}.json"

python3 - "$COCKPIT_DIR" "$OPERATOR_DIR" "$OUT_MD" "$OUT_JSON" <<'PY'
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

cockpit_dir = Path(sys.argv[1])
operator_dir = Path(sys.argv[2])
out_md = Path(sys.argv[3])
out_json = Path(sys.argv[4])
memory_json = cockpit_dir / "kill_life_memory" / "latest.json"
memory_md = cockpit_dir / "kill_life_memory" / "latest.md"


def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}


def iter_files(directory: Path, prefix: str, suffix=".json", exclude=()):
    if not directory.exists():
        return []
    items = []
    for path in directory.iterdir():
        if not path.is_file():
            continue
        if not path.name.startswith(prefix) or not path.name.endswith(suffix):
            continue
        if any(token in path.name for token in exclude):
            continue
        items.append(path)
    return sorted(items, key=lambda p: p.stat().st_mtime, reverse=True)


brief_files = iter_files(cockpit_dir, "mascarade_incident_brief_", exclude=("latest",))
operator_files = iter_files(operator_dir, "full_operator_lane_", exclude=("mascarade_health", "mascarade_logs"))
memory_payload = load_json(memory_json) if memory_json.exists() else {}
memory_entry = memory_payload.get("entry", {}) if isinstance(memory_payload.get("entry"), dict) else {}
routing = memory_entry.get("routing", {}) if isinstance(memory_entry.get("routing"), dict) else {}
resume_ref = memory_payload.get("resume_ref") or memory_entry.get("resume_ref", "")
trust_level = memory_payload.get("trust_level") or memory_entry.get("trust_level", "inferred")

entries = []

for path in brief_files[:20]:
    data = load_json(path)
    entries.append({
        "ts": data.get("generated_at", ""),
        "source": "brief",
        "status": data.get("status", "unknown"),
        "path": str(path),
        "reasons": data.get("degraded_reasons", []),
        "next_steps": data.get("next_steps", []),
    })

for path in operator_files[:20]:
    data = load_json(path)
    status = data.get("status", "unknown")
    error = data.get("error", "")
    if status in {"ok", "ready", "done", "success"} and not error:
        continue
    entries.append({
        "ts": data.get("generated_at", ""),
        "source": "operator-lane",
        "status": status,
        "path": str(path),
        "reasons": [error] if error else [],
        "next_steps": [data.get("suggested_command", "")] if data.get("suggested_command") else [],
    })

def classify(entry):
    status = (entry.get("status") or "").lower()
    reasons = " ".join(entry.get("reasons", []))
    if status in {"failed", "error", "blocked", "ko"}:
        if "run-api-unreachable" in reasons or "poll-api-unreachable" in reasons:
            return ("high", "P1")
        if "status-api-unreachable" in reasons or "validate-api-unreachable" in reasons:
            return ("medium", "P2")
        return ("high", "P1")
    if status in {"degraded"}:
        return ("medium", "P2")
    return ("low", "P3")

entries.sort(key=lambda item: item.get("ts", ""), reverse=True)
entries = entries[:25]
for entry in entries:
    severity, priority = classify(entry)
    entry["severity"] = severity
    entry["priority"] = priority

overall = "ok" if not entries else "degraded"
generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

severity_counts = {"high": 0, "medium": 0, "low": 0}
priority_counts = {"P1": 0, "P2": 0, "P3": 0}
for entry in entries:
    severity_counts[entry["severity"]] = severity_counts.get(entry["severity"], 0) + 1
    priority_counts[entry["priority"]] = priority_counts.get(entry["priority"], 0) + 1

lines = [
    "# Mascarade incident registry",
    "",
    f"- generated_at: {generated_at}",
    f"- entry_count: {len(entries)}",
    f"- trust_level: {trust_level}",
    f"- resume_ref: {resume_ref or 'missing'}",
    f"- owner: {memory_entry.get('owner', 'unknown')}",
    f"- selected_target: {routing.get('selected_target', 'unknown')}",
    f"- kill_life_memory: {memory_md if memory_md.exists() else 'missing'}",
    "",
    "## Severity summary",
    "",
    "| Severity | Count | Priority |",
    "| --- | --- | --- |",
    f"| high | {severity_counts['high']} | P1 |",
    f"| medium | {severity_counts['medium']} | P2 |",
    f"| low | {severity_counts['low']} | P3 |",
    "",
    "## Incident table",
    "",
    "| Timestamp | Source | Status | Severity | Priority | Path | Reasons |",
    "| --- | --- | --- | --- | --- | --- | --- |",
]

if entries:
    for entry in entries:
        reasons = ", ".join([r for r in entry.get("reasons", []) if r]) or "none"
        lines.append(f"| {entry.get('ts') or 'n/a'} | {entry['source']} | {entry['status']} | {entry['severity']} | {entry['priority']} | `{entry['path']}` | {reasons} |")
else:
    lines.append("| n/a | registry | ok | low | P3 | `n/a` | none |")

lines.extend(["", "## Next steps", ""])
if entries:
    seen = []
    for entry in entries:
        for step in entry.get("next_steps", []):
            if step and step not in seen:
                seen.append(step)
                lines.append(f"- {step}")
    if not seen:
        lines.append("- no explicit next step captured")
else:
    lines.append("- no active incident captured")

out_md.write_text("\n".join(lines) + "\n", encoding="utf-8")
shutil.copyfile(out_md, out_md.with_name("mascarade_incident_registry_latest.md"))

payload = {
    "contract_version": "cockpit-v1",
    "component": "mascarade-incident-registry",
    "action": "render",
    "status": overall,
    "contract_status": overall,
    "generated_at": generated_at,
    "owner": memory_entry.get("owner", "SyncOps"),
    "resume_ref": resume_ref,
    "trust_level": trust_level,
    "routing": routing,
    "memory_entry": memory_entry,
    "memory_markdown": str(memory_md) if memory_md.exists() else "",
    "entry_count": len(entries),
    "severity_counts": severity_counts,
    "priority_counts": priority_counts,
    "entries": entries,
    "markdown_file": str(out_md),
    "latest_markdown_file": str(out_md.with_name("mascarade_incident_registry_latest.md")),
    "artifacts": [
        str(out_md),
        str(out_md.with_name("mascarade_incident_registry_latest.md")),
    ] + ([str(memory_json)] if memory_json.exists() else []),
    "degraded_reasons": [f"{entry['source']}-{entry['status']}" for entry in entries[:5]],
    "next_steps": [step for entry in entries for step in entry.get("next_steps", []) if step][:5],
}

out_json.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
shutil.copyfile(out_json, out_json.with_name("mascarade_incident_registry_latest.json"))
print(json.dumps(payload, ensure_ascii=False, indent=2))
PY

if [[ "$OUTPUT_MODE" == "json" ]]; then
  cat "$OUT_JSON"
else
  cat <<EOF
Mascarade incident registry
markdown: $OUT_MD
json: $OUT_JSON
EOF
fi
