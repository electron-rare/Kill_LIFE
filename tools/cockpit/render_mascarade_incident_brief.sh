#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COCKPIT_DIR="$ROOT_DIR/artifacts/cockpit"
RUNTIME_DIR="$ROOT_DIR/artifacts/ops/mascarade_runtime_health"
OPERATOR_DIR="$ROOT_DIR/artifacts/operator_lane"
OUTPUT_MODE="text"

usage() {
  cat <<'EOF'
Usage:
  bash tools/cockpit/render_mascarade_incident_brief.sh [--json]

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

mkdir -p "$COCKPIT_DIR" "$RUNTIME_DIR" "$OPERATOR_DIR"

RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_MD="$COCKPIT_DIR/mascarade_incident_brief_${RUN_ID}.md"
OUT_JSON="$COCKPIT_DIR/mascarade_incident_brief_${RUN_ID}.json"

python3 - "$RUNTIME_DIR" "$OPERATOR_DIR" "$OUT_MD" "$OUT_JSON" "$COCKPIT_DIR" <<'PY'
import json
import os
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

runtime_dir = Path(sys.argv[1])
operator_dir = Path(sys.argv[2])
out_md = Path(sys.argv[3])
out_json = Path(sys.argv[4])
cockpit_dir = Path(sys.argv[5])


def read_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}


def latest_matching(directory: Path, prefix: str, suffix: str = ".json", exclude_contains=None):
    exclude_contains = exclude_contains or []
    candidates = []
    if directory.exists():
        for path in directory.iterdir():
            if not path.is_file():
                continue
            if not path.name.startswith(prefix) or not path.name.endswith(suffix):
                continue
            if any(token in path.name for token in exclude_contains):
                continue
            candidates.append(path)
    candidates.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    return candidates[0] if candidates else None


runtime_latest = runtime_dir / "latest.json"
runtime_data = read_json(runtime_latest)

operator_summary_path = latest_matching(operator_dir, "full_operator_lane_", ".json", exclude_contains=["mascarade_health", "mascarade_logs"])
operator_summary = read_json(operator_summary_path) if operator_summary_path else {}

operator_logs_path = latest_matching(operator_dir, "full_operator_lane_mascarade_logs_", ".json")
operator_logs = read_json(operator_logs_path) if operator_logs_path else {}
memory_json = cockpit_dir / "kill_life_memory" / "latest.json"
memory_md = cockpit_dir / "kill_life_memory" / "latest.md"
memory_payload = read_json(memory_json) if memory_json.exists() else {}
memory_entry = memory_payload.get("entry", {}) if isinstance(memory_payload.get("entry"), dict) else {}
routing = memory_entry.get("routing", {}) if isinstance(memory_entry.get("routing"), dict) else {}
resume_ref = memory_payload.get("resume_ref") or memory_entry.get("resume_ref", "")
trust_level = memory_payload.get("trust_level") or memory_entry.get("trust_level", "inferred")

runtime_status = runtime_data.get("status", "missing")
runtime_provider = runtime_data.get("provider", "unknown")
runtime_model = runtime_data.get("model", "unknown")
runtime_checked_at = runtime_data.get("checked_at", "")
runtime_next_steps = runtime_data.get("next_steps", []) if isinstance(runtime_data.get("next_steps"), list) else []
runtime_reasons = runtime_data.get("degraded_reasons", []) if isinstance(runtime_data.get("degraded_reasons"), list) else []

lane_status = operator_summary.get("status", "missing")
lane_error = operator_summary.get("error", "")
lane_hint = operator_summary.get("hint", "")
lane_command = operator_summary.get("suggested_command", "")
lane_url = operator_summary.get("url", "")

logs_status = operator_logs.get("status", "missing")
logs_action = operator_logs.get("logs_action", operator_logs.get("action", "summary"))
logs_details = operator_logs.get("details", {}) if isinstance(operator_logs.get("details"), dict) else operator_logs
latest_runtime = logs_details.get("latest_runtime", {}) if isinstance(logs_details.get("latest_runtime"), dict) else {}
latest_tail = logs_details.get("latest_log_tail", []) if isinstance(logs_details.get("latest_log_tail"), list) else []
stale_count = logs_details.get("stale_candidate_count", logs_details.get("candidate_count", 0))

overall = "ok"
reasons = []
if runtime_status not in {"ok", "ready", "success", "done"}:
    overall = "degraded"
    reasons.append(f"runtime-{runtime_status}")
if lane_status not in {"ok", "ready", "success", "done", ""}:
    overall = "degraded"
    reasons.append(f"lane-{lane_status}")
if logs_status not in {"ok", "ready", "success", "done"}:
    overall = "degraded"
    reasons.append(f"logs-{logs_status}")

next_steps = []
for item in runtime_next_steps:
    if item and item not in next_steps:
        next_steps.append(item)
for item in [lane_hint, lane_command]:
    if item and item not in next_steps:
        next_steps.append(item)

generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

lines = [
    "# Mascarade incident brief",
    "",
    f"- generated_at: {generated_at}",
    f"- overall_status: {overall}",
    "",
    "## Runtime",
    "",
    f"- status: {runtime_status}",
    f"- provider/model: {runtime_provider} / {runtime_model}",
    f"- checked_at: {runtime_checked_at or 'unknown'}",
]

if runtime_reasons:
    lines.extend(["", "### Runtime degraded reasons", ""])
    lines.extend([f"- {item}" for item in runtime_reasons])

lines.extend([
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
    "## Operator lane",
    "",
    f"- status: {lane_status or 'unknown'}",
    f"- error: {lane_error or 'none'}",
    f"- url: {lane_url or 'n/a'}",
])

if lane_hint or lane_command:
    lines.extend(["", "### Operator hints", ""])
    if lane_hint:
        lines.append(f"- {lane_hint}")
    if lane_command:
        lines.append(f"- suggested_command: `{lane_command}`")

lines.extend([
    "",
    "## Logs",
    "",
    f"- status: {logs_status}",
    f"- action: {logs_action}",
    f"- stale_candidates: {stale_count}",
])

runtime_path = latest_runtime.get("path", "")
if runtime_path:
    lines.append(f"- latest_runtime_path: `{runtime_path}`")

if latest_tail:
    lines.extend(["", "### Latest log tail", ""])
    lines.extend([f"- `{item}`" for item in latest_tail[:8]])

if next_steps:
    lines.extend(["", "## Next steps", ""])
    lines.extend([f"- {item}" for item in next_steps])

out_md.write_text("\n".join(lines) + "\n", encoding="utf-8")
shutil.copyfile(out_md, out_md.with_name("mascarade_incident_brief_latest.md"))

payload = {
    "contract_version": "cockpit-v1",
    "component": "mascarade-incident-brief",
    "action": "render",
    "status": overall,
    "contract_status": overall,
    "generated_at": generated_at,
    "owner": memory_entry.get("owner", "Runtime-Companion"),
    "resume_ref": resume_ref,
    "trust_level": trust_level,
    "routing": routing,
    "memory_entry": memory_entry,
    "memory_markdown": str(memory_md) if memory_md.exists() else "",
    "markdown_file": str(out_md),
    "latest_markdown_file": str(out_md.with_name("mascarade_incident_brief_latest.md")),
    "runtime_file": str(runtime_latest),
    "operator_summary_file": str(operator_summary_path) if operator_summary_path else "",
    "operator_logs_file": str(operator_logs_path) if operator_logs_path else "",
    "artifacts": [
        str(out_md),
        str(out_md.with_name("mascarade_incident_brief_latest.md")),
        str(runtime_latest),
    ] + ([str(operator_summary_path)] if operator_summary_path else []) + ([str(operator_logs_path)] if operator_logs_path else []) + ([str(memory_json)] if memory_json.exists() else []),
    "degraded_reasons": reasons,
    "next_steps": next_steps,
}

out_json.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
shutil.copyfile(out_json, out_json.with_name("mascarade_incident_brief_latest.json"))
print(json.dumps(payload, ensure_ascii=False, indent=2))
PY

if [[ "$OUTPUT_MODE" == "json" ]]; then
  cat "$OUT_JSON"
else
  cat <<EOF
Mascarade incident brief
markdown: $OUT_MD
json: $OUT_JSON
EOF
fi
