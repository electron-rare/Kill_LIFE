#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COCKPIT_DIR="$ROOT_DIR/artifacts/cockpit"
OUTPUT_MODE="text"

usage() {
  cat <<'EOF'
Usage:
  bash tools/cockpit/render_mascarade_watch_history.sh [--json]

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
OUT_MD="$COCKPIT_DIR/mascarade_watch_history_${RUN_ID}.md"
OUT_JSON="$COCKPIT_DIR/mascarade_watch_history_${RUN_ID}.json"

python3 - "$COCKPIT_DIR" "$OUT_MD" "$OUT_JSON" <<'PY'
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

cockpit_dir = Path(sys.argv[1])
out_md = Path(sys.argv[2])
out_json = Path(sys.argv[3])


def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}


watch_files = sorted(
    [
        path
        for path in cockpit_dir.glob("mascarade_incident_watch_*.json")
        if "latest" not in path.name
    ],
    key=lambda path: path.stat().st_mtime,
    reverse=True,
)
memory_json = cockpit_dir / "kill_life_memory" / "latest.json"
memory_md = cockpit_dir / "kill_life_memory" / "latest.md"
memory_payload = load_json(memory_json) if memory_json.exists() else {}
memory_entry = memory_payload.get("entry", {}) if isinstance(memory_payload.get("entry"), dict) else {}
routing = memory_entry.get("routing", {}) if isinstance(memory_entry.get("routing"), dict) else {}
resume_ref = memory_payload.get("resume_ref") or memory_entry.get("resume_ref", "")
trust_level = memory_payload.get("trust_level") or memory_entry.get("trust_level", "inferred")

rows = []
for path in watch_files[:30]:
    payload = load_json(path)
    priority = payload.get("priority_counts", {}) if isinstance(payload.get("priority_counts"), dict) else {}
    severity = payload.get("severity_counts", {}) if isinstance(payload.get("severity_counts"), dict) else {}
    rows.append(
        {
            "generated_at": payload.get("generated_at", ""),
            "status": payload.get("status", "unknown"),
            "file": str(path),
            "priority_counts": {
                "P1": priority.get("P1", 0),
                "P2": priority.get("P2", 0),
                "P3": priority.get("P3", 0),
            },
            "severity_counts": {
                "high": severity.get("high", 0),
                "medium": severity.get("medium", 0),
                "low": severity.get("low", 0),
            },
        }
    )

generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
status = "ok" if rows else "degraded"

lines = [
    "# Mascarade watch history",
    "",
    f"- generated_at: {generated_at}",
    f"- entry_count: {len(rows)}",
    f"- trust_level: {trust_level}",
    f"- resume_ref: {resume_ref or 'missing'}",
    f"- selected_target: {routing.get('selected_target', 'unknown')}",
    f"- kill_life_memory: {memory_md if memory_md.exists() else 'missing'}",
    "",
    "## History",
    "",
    "| Generated at | Status | P1 | P2 | P3 | High | Medium | Low | Source |",
    "| --- | --- | --- | --- | --- | --- | --- | --- | --- |",
]

if rows:
    for row in rows:
        lines.append(
            f"| {row['generated_at'] or 'n/a'} | {row['status']} | "
            f"{row['priority_counts']['P1']} | {row['priority_counts']['P2']} | {row['priority_counts']['P3']} | "
            f"{row['severity_counts']['high']} | {row['severity_counts']['medium']} | {row['severity_counts']['low']} | "
            f"`{row['file']}` |"
        )
else:
    lines.append("| n/a | degraded | 0 | 0 | 0 | 0 | 0 | 0 | `n/a` |")

out_md.write_text("\n".join(lines) + "\n", encoding="utf-8")
shutil.copyfile(out_md, out_md.with_name("mascarade_watch_history_latest.md"))

payload = {
    "contract_version": "cockpit-v1",
    "component": "mascarade-watch-history",
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
    "entry_count": len(rows),
    "entries": rows,
    "markdown_file": str(out_md),
    "latest_markdown_file": str(out_md.with_name("mascarade_watch_history_latest.md")),
    "artifacts": [
        str(out_md),
        str(out_md.with_name("mascarade_watch_history_latest.md")),
        str(out_json),
        str(out_json.with_name("mascarade_watch_history_latest.json")),
    ] + [str(row["file"]) for row in rows] + ([str(memory_json)] if memory_json.exists() else []),
    "degraded_reasons": [] if rows else ["watch-history-empty"],
    "next_steps": [] if rows else ["Generate at least one incident-watch artifact before reviewing history."],
}

out_json.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
shutil.copyfile(out_json, out_json.with_name("mascarade_watch_history_latest.json"))
print(json.dumps(payload, ensure_ascii=False, indent=2))
PY

if [[ "$OUTPUT_MODE" == "json" ]]; then
  cat "$OUT_JSON"
else
  cat <<EOF
Mascarade watch history
markdown: $OUT_MD
json: $OUT_JSON
EOF
fi
