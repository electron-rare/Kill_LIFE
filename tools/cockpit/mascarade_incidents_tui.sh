#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COCKPIT_DIR="$ROOT_DIR/artifacts/cockpit"
ACTION="summary"
LINES=18
JSON_OUTPUT=0

usage() {
  cat <<'EOF'
Usage:
  bash tools/cockpit/mascarade_incidents_tui.sh --action <summary|brief|registry|queue|daily|watch> [--lines N] [--json]

Options:
  --action <name>  summary|brief|registry|queue|daily|watch
  --lines <int>    Number of tail lines to display (default: 18)
  --json           Emit cockpit-v1 JSON to stdout
  -h,--help        Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --action)
      ACTION="${2:-}"
      shift 2
      ;;
    --lines)
      LINES="${2:-}"
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
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! "$ACTION" =~ ^(summary|brief|registry|queue|daily|watch)$ ]]; then
  echo "Invalid action: $ACTION" >&2
  exit 2
fi
if ! [[ "$LINES" =~ ^[0-9]+$ ]]; then
  echo "--lines must be an integer" >&2
  exit 2
fi

mkdir -p "$COCKPIT_DIR"

python3 - "$COCKPIT_DIR" "$ACTION" "$LINES" "$JSON_OUTPUT" <<'PY'
import json
import sys
from pathlib import Path

cockpit_dir = Path(sys.argv[1])
action = sys.argv[2]
lines = int(sys.argv[3])
json_output = sys.argv[4] == "1"

paths = {
    "brief": cockpit_dir / "mascarade_incident_brief_latest.md",
    "registry": cockpit_dir / "mascarade_incident_registry_latest.md",
    "queue": cockpit_dir / "mascarade_incident_queue_latest.md",
    "daily": cockpit_dir / "daily_operator_summary_latest.md",
}

json_paths = {
    "registry": cockpit_dir / "mascarade_incident_registry_latest.json",
    "queue": cockpit_dir / "mascarade_incident_queue_latest.json",
    "daily": cockpit_dir / "daily_operator_summary_latest.json",
}
memory_json = cockpit_dir / "kill_life_memory" / "latest.json"
memory_markdown = cockpit_dir / "kill_life_memory" / "latest.md"


def tail(path: Path, count: int):
    try:
        return path.read_text(encoding="utf-8", errors="replace").splitlines()[-count:]
    except Exception:
        return []


def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}


def memory_context():
    payload = load_json(memory_json) if memory_json.exists() else {}
    entry = payload.get("entry", {}) if isinstance(payload.get("entry"), dict) else {}
    routing = entry.get("routing", {}) if isinstance(entry.get("routing"), dict) else {}
    return {
        "owner": entry.get("owner", ""),
        "resume_ref": payload.get("resume_ref") or entry.get("resume_ref", ""),
        "trust_level": payload.get("trust_level") or entry.get("trust_level", "inferred"),
        "routing": routing,
        "memory_entry": entry,
        "memory_artifact": str(memory_json) if memory_json.exists() else "",
        "memory_markdown": str(memory_markdown) if memory_markdown.exists() else "",
    }


def summary_payload():
    entry = {}
    for key, path in paths.items():
        entry[key] = {
            "path": str(path),
            "exists": path.exists(),
            "tail": tail(path, min(lines, 10)),
        }
    memory = memory_context()
    artifacts = [item["path"] for item in entry.values() if item["exists"]]
    if memory["memory_artifact"]:
        artifacts.append(memory["memory_artifact"])
    status = "ok" if any(item["exists"] for item in entry.values()) else "degraded"
    return {
        "contract_version": "cockpit-v1",
        "component": "mascarade-incidents-tui",
        "action": "summary",
        "status": status,
        "contract_status": status,
        "owner": memory["owner"] or "SyncOps",
        "resume_ref": memory["resume_ref"],
        "trust_level": memory["trust_level"],
        "routing": memory["routing"],
        "memory_entry": memory["memory_entry"],
        "entries": entry,
        "artifacts": artifacts,
        "degraded_reasons": [] if status == "ok" else ["mascarade-incidents-missing"],
        "next_steps": [] if status == "ok" else ["Run the daily and incident rendering scripts to regenerate latest incident artifacts."],
    }


def document_payload(name: str):
    path = paths[name]
    exists = path.exists()
    status = "ok" if exists else "degraded"
    memory = memory_context()
    artifacts = [str(path)] if exists else []
    if memory["memory_artifact"]:
        artifacts.append(memory["memory_artifact"])
    return {
        "contract_version": "cockpit-v1",
        "component": "mascarade-incidents-tui",
        "action": name,
        "status": status,
        "contract_status": status,
        "owner": memory["owner"] or "SyncOps",
        "resume_ref": memory["resume_ref"],
        "trust_level": memory["trust_level"],
        "routing": memory["routing"],
        "memory_entry": memory["memory_entry"],
        "path": str(path),
        "exists": exists,
        "tail": tail(path, lines) if exists else [],
        "artifacts": artifacts,
        "degraded_reasons": [] if exists else [f"missing-{name}-artifact"],
        "next_steps": [] if exists else [f"Regenerate the latest {name} artifact before review."],
    }


def watch_payload():
    registry = load_json(json_paths["registry"])
    queue = load_json(json_paths["queue"])
    daily = load_json(json_paths["daily"])
    memory = memory_context()

    priority_counts = registry.get("priority_counts", {}) if isinstance(registry.get("priority_counts"), dict) else {}
    severity_counts = registry.get("severity_counts", {}) if isinstance(registry.get("severity_counts"), dict) else {}
    entries = queue.get("entries", []) if isinstance(queue.get("entries"), list) else []

    top_entries = []
    for entry in entries[:5]:
        top_entries.append({
            "priority": entry.get("priority", "P3"),
            "severity": entry.get("severity", "low"),
            "status": entry.get("status", "unknown"),
            "source": entry.get("source", "unknown"),
            "timestamp": entry.get("ts", ""),
            "reasons": entry.get("reasons", []),
        })

    next_steps = []
    for candidate in (
        queue.get("next_steps", []),
        registry.get("next_steps", []),
        daily.get("next_steps", []),
    ):
        if isinstance(candidate, list):
            for step in candidate:
                if step and step not in next_steps:
                    next_steps.append(step)

    status = "ok" if json_paths["queue"].exists() or json_paths["registry"].exists() else "degraded"
    artifacts = [str(path) for path in json_paths.values() if path.exists()]
    if memory["memory_artifact"]:
        artifacts.append(memory["memory_artifact"])
    return {
        "contract_version": "cockpit-v1",
        "component": "mascarade-incidents-tui",
        "action": "watch",
        "status": status,
        "contract_status": status,
        "owner": memory["owner"] or "SyncOps",
        "resume_ref": memory["resume_ref"],
        "trust_level": memory["trust_level"],
        "routing": memory["routing"],
        "memory_entry": memory["memory_entry"],
        "priority_counts": priority_counts,
        "severity_counts": severity_counts,
        "top_entries": top_entries,
        "artifacts": artifacts,
        "degraded_reasons": [] if status == "ok" else ["incident-watch-missing-artifacts"],
        "next_steps": next_steps[:5] if next_steps else ["Regenerate queue and registry artifacts before operator watch review."],
    }


if action == "summary":
    payload = summary_payload()
elif action == "watch":
    payload = watch_payload()
else:
    payload = document_payload(action)

if json_output:
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    raise SystemExit(0)

if action == "summary":
    print("Mascarade incidents summary")
    print(f"trust_level: {payload.get('trust_level', 'inferred')}")
    print(f"resume_ref: {payload.get('resume_ref') or 'n/a'}")
    for key, item in payload["entries"].items():
        print(f"{key}: {'ok' if item['exists'] else 'missing'} -> {item['path']}")
        for line in item["tail"]:
            print(f"  {line}")
elif action == "watch":
    print("Mascarade incident watch")
    print(f"trust_level: {payload.get('trust_level', 'inferred')}")
    print(f"resume_ref: {payload.get('resume_ref') or 'n/a'}")
    routing = payload.get("routing", {}) if isinstance(payload.get("routing"), dict) else {}
    print(f"routing: {routing.get('selected_target', 'unknown')} -> {routing.get('selected_host', 'unknown')}")
    priority = payload.get("priority_counts", {})
    severity = payload.get("severity_counts", {})
    print(f"priority P1/P2/P3: {priority.get('P1', 0)}/{priority.get('P2', 0)}/{priority.get('P3', 0)}")
    print(f"severity high/medium/low: {severity.get('high', 0)}/{severity.get('medium', 0)}/{severity.get('low', 0)}")
    print("top queue:")
    for entry in payload.get("top_entries", []):
        reasons = ", ".join(entry.get("reasons", [])) if entry.get("reasons") else "none"
        print(f"  - {entry.get('priority')} {entry.get('severity')} {entry.get('status')} {entry.get('source')} {entry.get('timestamp') or 'n/a'} :: {reasons}")
    if not payload.get("top_entries"):
        print("  - no queued incident")
    print("next steps:")
    for step in payload.get("next_steps", []):
        print(f"  - {step}")
else:
    print(f"Mascarade incidents view: {action}")
    print(f"trust_level: {payload.get('trust_level', 'inferred')}")
    print(f"resume_ref: {payload.get('resume_ref') or 'n/a'}")
    print(f"path: {payload['path']}")
    if payload["tail"]:
        for line in payload["tail"]:
            print(line)
    else:
        print("No content available.")
PY
