#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COCKPIT_DIR="$ROOT_DIR/artifacts/cockpit"
OUTPUT_MODE="text"
DAILY_LOG=""
BRIEF_MARKDOWN=""
REGISTRY_MARKDOWN=""
QUEUE_MARKDOWN=""

usage() {
  cat <<'EOF'
Usage:
  bash tools/cockpit/render_daily_operator_summary.sh [--daily-log FILE] [--brief-markdown FILE] [--registry-markdown FILE] [--queue-markdown FILE] [--json]

Options:
  --daily-log FILE       Daily alignment log to summarize
  --brief-markdown FILE  Mascarade brief markdown source
  --registry-markdown FILE Mascarade registry markdown source
  --queue-markdown FILE  Mascarade queue markdown source
  --json                 Emit cockpit-v1 JSON to stdout
  -h,--help              Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --daily-log)
      DAILY_LOG="${2:-}"
      shift 2
      ;;
    --brief-markdown)
      BRIEF_MARKDOWN="${2:-}"
      shift 2
      ;;
    --registry-markdown)
      REGISTRY_MARKDOWN="${2:-}"
      shift 2
      ;;
    --queue-markdown)
      QUEUE_MARKDOWN="${2:-}"
      shift 2
      ;;
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
OUT_MD="$COCKPIT_DIR/daily_operator_summary_${RUN_ID}.md"
OUT_JSON="$COCKPIT_DIR/daily_operator_summary_${RUN_ID}.json"

python3 - "$COCKPIT_DIR" "$DAILY_LOG" "$BRIEF_MARKDOWN" "$REGISTRY_MARKDOWN" "$QUEUE_MARKDOWN" "$OUT_MD" "$OUT_JSON" <<'PY'
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

cockpit_dir = Path(sys.argv[1])
daily_log_arg = sys.argv[2]
brief_arg = sys.argv[3]
registry_arg = sys.argv[4]
queue_arg = sys.argv[5]
out_md = Path(sys.argv[6])
out_json = Path(sys.argv[7])


def latest_matching(pattern: str):
    files = sorted(cockpit_dir.glob(pattern), key=lambda p: p.stat().st_mtime, reverse=True)
    return files[0] if files else None


daily_log = Path(daily_log_arg) if daily_log_arg else latest_matching("machine_alignment_daily_*.log")
brief_md = Path(brief_arg) if brief_arg else cockpit_dir / "mascarade_incident_brief_latest.md"
registry_md = Path(registry_arg) if registry_arg else cockpit_dir / "mascarade_incident_registry_latest.md"
queue_md = Path(queue_arg) if queue_arg else cockpit_dir / "mascarade_incident_queue_latest.md"
registry_json = cockpit_dir / "mascarade_incident_registry_latest.json"
memory_json = cockpit_dir / "kill_life_memory" / "latest.json"
memory_md = cockpit_dir / "kill_life_memory" / "latest.md"


def read_lines(path: Path):
    try:
        return path.read_text(encoding="utf-8", errors="replace").splitlines()
    except Exception:
        return []


def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}


summary_lines = [line for line in read_lines(daily_log) if line.startswith("[summary]")] if daily_log and daily_log.exists() else []
brief_tail = read_lines(brief_md)[-16:] if brief_md.exists() else ["Brief indisponible."]
registry_tail = read_lines(registry_md)[-16:] if registry_md.exists() else ["Registre indisponible."]
queue_tail = read_lines(queue_md)[-16:] if queue_md.exists() else ["Queue indisponible."]
registry_payload = load_json(registry_json) if registry_json.exists() else {}
memory_payload = load_json(memory_json) if memory_json.exists() else {}
priority_counts = registry_payload.get("priority_counts", {}) if isinstance(registry_payload.get("priority_counts"), dict) else {}
severity_counts = registry_payload.get("severity_counts", {}) if isinstance(registry_payload.get("severity_counts"), dict) else {}
memory_entry = memory_payload.get("entry", {}) if isinstance(memory_payload.get("entry"), dict) else {}
routing = memory_entry.get("routing", {}) if isinstance(memory_entry.get("routing"), dict) else {}
resume_ref = memory_payload.get("resume_ref") or memory_entry.get("resume_ref", "")
trust_level = memory_payload.get("trust_level") or memory_entry.get("trust_level", "inferred")
memory_tail = read_lines(memory_md)[-12:] if memory_md.exists() else ["Kill life memory indisponible."]

overall = "ok"
reasons = []
for line in summary_lines:
    if "result=degraded" in line or "status=degraded" in line:
        overall = "degraded"
    if "result=ko" in line or "status=failed" in line or "status=ko" in line:
        overall = "degraded"
        reasons.append(line)

for label, path in (("brief", brief_md), ("registry", registry_md), ("queue", queue_md)):
    if not path.exists():
        overall = "degraded"
        reasons.append(f"missing-{label}-markdown")
if not memory_json.exists():
    overall = "degraded"
    reasons.append("missing-kill-life-memory")

generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

lines = [
    "# Daily operator summary",
    "",
    f"- generated_at: {generated_at}",
    f"- daily_log: {daily_log if daily_log else 'none'}",
    f"- mascarade_brief: {brief_md if brief_md.exists() else 'missing'}",
    f"- mascarade_registry: {registry_md if registry_md.exists() else 'missing'}",
    f"- mascarade_queue: {queue_md if queue_md.exists() else 'missing'}",
    "",
    "## Incident priority rollup",
    "",
    f"- priority P1/P2/P3: {priority_counts.get('P1', 0)}/{priority_counts.get('P2', 0)}/{priority_counts.get('P3', 0)}",
    f"- severity high/medium/low: {severity_counts.get('high', 0)}/{severity_counts.get('medium', 0)}/{severity_counts.get('low', 0)}",
    "",
    "## Execution continuity",
    "",
    f"- trust_level: {trust_level}",
    f"- resume_ref: {resume_ref or 'missing'}",
    f"- owner: {memory_entry.get('owner', 'unknown')}",
    f"- selected_target: {routing.get('selected_target', 'unknown')}",
    f"- selected_host: {routing.get('selected_host', 'unknown')}",
    f"- kill_life_memory: {memory_md if memory_md.exists() else 'missing'}",
    "",
    "## Daily alignment highlights",
    "",
]

if summary_lines:
    lines.extend([f"- {line}" for line in summary_lines])
else:
    lines.append("- no summary line found")

lines.extend(["", "## Mascarade incident brief", "", "```text"])
lines.extend(brief_tail)
lines.extend(["```", "", "## Mascarade incident registry", "", "```text"])
lines.extend(registry_tail)
lines.extend(["```", "", "## Mascarade incident queue", "", "```text"])
lines.extend(queue_tail)
lines.extend(["```", "", "## Kill life execution memory", "", "```text"])
lines.extend(memory_tail)
lines.extend(["```"])

out_md.write_text("\n".join(lines) + "\n", encoding="utf-8")
shutil.copyfile(out_md, out_md.with_name("daily_operator_summary_latest.md"))

payload = {
    "contract_version": "cockpit-v1",
    "component": "daily-operator-summary",
    "action": "render",
    "status": overall,
    "contract_status": overall,
    "generated_at": generated_at,
    "daily_log": str(daily_log) if daily_log else "",
    "brief_markdown": str(brief_md) if brief_md.exists() else "",
    "registry_markdown": str(registry_md) if registry_md.exists() else "",
    "queue_markdown": str(queue_md) if queue_md.exists() else "",
    "owner": memory_entry.get("owner", "SyncOps"),
    "resume_ref": resume_ref,
    "trust_level": trust_level,
    "routing": routing,
    "memory_entry": memory_entry,
    "memory_markdown": str(memory_md) if memory_md.exists() else "",
    "priority_counts": priority_counts,
    "severity_counts": severity_counts,
    "markdown_file": str(out_md),
    "latest_markdown_file": str(out_md.with_name("daily_operator_summary_latest.md")),
    "artifacts": [
        str(out_md),
        str(out_md.with_name("daily_operator_summary_latest.md")),
    ] + ([str(daily_log)] if daily_log else []) + ([str(memory_json)] if memory_json.exists() else []),
    "degraded_reasons": reasons[:5],
    "next_steps": ["Review the latest Mascarade brief, registry and queue before operator handoff."],
}

out_json.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
shutil.copyfile(out_json, out_json.with_name("daily_operator_summary_latest.json"))
PY

if [[ "$OUTPUT_MODE" == "json" ]]; then
  cat "$OUT_JSON"
else
  cat <<EOF
Daily operator summary
markdown: $OUT_MD
json: $OUT_JSON
EOF
fi
