#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNTIME_DIR="$ROOT_DIR/artifacts/ops/mascarade_runtime_health"
OPERATOR_DIR="$ROOT_DIR/artifacts/operator_lane"
ACTION="summary"
RETENTION_DAYS=14
LINES=20
JSON_OUTPUT=0
APPLY=0

usage() {
  cat <<'EOF'
Usage:
  bash tools/cockpit/mascarade_logs_tui.sh --action <summary|list|latest|purge> [options]

Options:
  --action <name>     summary|list|latest|purge
  --days <int>        Retention window for purge/list analysis (default: 14)
  --lines <int>       Max entries or log lines to display (default: 20)
  --apply             Apply purge instead of dry-run
  --json              Emit cockpit-v1 JSON
  -h, --help          Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --action)
      [[ $# -ge 2 ]] || { echo "--action requires a value" >&2; exit 2; }
      ACTION="$2"
      shift 2
      ;;
    --days)
      [[ $# -ge 2 ]] || { echo "--days requires a value" >&2; exit 2; }
      RETENTION_DAYS="$2"
      shift 2
      ;;
    --lines)
      [[ $# -ge 2 ]] || { echo "--lines requires a value" >&2; exit 2; }
      LINES="$2"
      shift 2
      ;;
    --apply)
      APPLY=1
      shift
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

if [[ ! "$ACTION" =~ ^(summary|list|latest|purge)$ ]]; then
  echo "Invalid action: $ACTION" >&2
  exit 2
fi

if ! [[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]] || ! [[ "$LINES" =~ ^[0-9]+$ ]]; then
  echo "--days and --lines must be integers" >&2
  exit 2
fi

mkdir -p "$RUNTIME_DIR" "$OPERATOR_DIR"

python3 - "$ACTION" "$ROOT_DIR" "$RUNTIME_DIR" "$OPERATOR_DIR" "$RETENTION_DAYS" "$LINES" "$JSON_OUTPUT" "$APPLY" <<'PY'
import json
import os
import sys
import time
from pathlib import Path

action, root_dir, runtime_dir_raw, operator_dir_raw, retention_days_raw, lines_raw, json_output_raw, apply_raw = sys.argv[1:]
root = Path(root_dir)
runtime_dir = Path(runtime_dir_raw)
operator_dir = Path(operator_dir_raw)
retention_days = int(retention_days_raw)
lines = int(lines_raw)
json_output = json_output_raw == "1"
apply = apply_raw == "1"
now = time.time()
cutoff = now - retention_days * 86400
memory_json = root / "artifacts" / "cockpit" / "kill_life_memory" / "latest.json"
memory_md = root / "artifacts" / "cockpit" / "kill_life_memory" / "latest.md"


def read_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None


def memory_context():
    payload = read_json(memory_json) if memory_json.exists() else {}
    if not isinstance(payload, dict):
        payload = {}
    entry = payload.get("entry", {}) if isinstance(payload.get("entry"), dict) else {}
    routing = entry.get("routing", {}) if isinstance(entry.get("routing"), dict) else {}
    return {
        "owner": entry.get("owner", "SyncOps"),
        "resume_ref": payload.get("resume_ref") or entry.get("resume_ref", ""),
        "trust_level": payload.get("trust_level") or entry.get("trust_level", "inferred"),
        "routing": routing,
        "memory_entry": entry,
        "memory_artifact": str(memory_json) if memory_json.exists() else "",
        "memory_markdown": str(memory_md) if memory_md.exists() else "",
    }


def runtime_files():
    if not runtime_dir.exists():
        return []
    return sorted([p for p in runtime_dir.iterdir() if p.is_file()], key=lambda p: p.stat().st_mtime, reverse=True)


def operator_health_files():
    if not operator_dir.exists():
        return []
    files = [p for p in operator_dir.iterdir() if p.is_file() and p.name.startswith("full_operator_lane_mascarade_health_") and p.suffix == ".json"]
    return sorted(files, key=lambda p: p.stat().st_mtime, reverse=True)


def candidate_purge_files():
    candidates = []
    for path in runtime_files():
        if path.name.startswith("latest."):
            continue
        if path.stat().st_mtime < cutoff:
            candidates.append(path)
    for path in operator_health_files():
        if path.stat().st_mtime < cutoff:
            candidates.append(path)
    return sorted(candidates, key=lambda p: p.stat().st_mtime)


def latest_runtime_summary():
    latest_json = runtime_dir / "latest.json"
    data = read_json(latest_json) if latest_json.exists() else None
    if not isinstance(data, dict):
        return {
            "status": "missing",
            "provider": "unknown",
            "model": "unknown",
            "checked_at": "",
            "path": str(latest_json),
        }
    return {
        "status": data.get("status", "unknown"),
        "provider": data.get("provider", "unknown"),
        "model": data.get("model", "unknown"),
        "checked_at": data.get("checked_at", ""),
        "path": str(latest_json),
    }


def latest_operator_summary():
    files = operator_health_files()
    if not files:
        return {"status": "missing", "path": "", "checked_at": ""}
    latest = files[0]
    data = read_json(latest)
    if not isinstance(data, dict):
        return {"status": "invalid", "path": str(latest), "checked_at": ""}
    return {
        "status": data.get("status", "unknown"),
        "path": str(latest),
        "checked_at": data.get("checked_at", data.get("generated_at", "")),
        "provider": data.get("provider", "unknown"),
        "model": data.get("model", "unknown"),
    }


def tail_lines(path: Path, count: int):
    if not path.exists():
        return []
    try:
        return path.read_text(encoding="utf-8", errors="replace").splitlines()[-count:]
    except Exception:
        return []


def format_ts(path: Path):
    return time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(path.stat().st_mtime))


def summary_payload():
    memory = memory_context()
    latest = latest_runtime_summary()
    operator = latest_operator_summary()
    files_runtime = runtime_files()
    files_operator = operator_health_files()
    stale = candidate_purge_files()
    status = latest["status"]
    if status in {"ok", "ready", "done", "success"}:
        overall = "ok"
    elif status in {"missing", "unknown"}:
        overall = "degraded"
    else:
        overall = "degraded"
    latest_log = runtime_dir / "latest.log"
    payload = {
        "contract_version": "cockpit-v1",
        "component": "mascarade-logs-tui",
        "action": "summary",
        "status": overall,
        "contract_status": overall,
        "owner": memory["owner"],
        "resume_ref": memory["resume_ref"],
        "trust_level": memory["trust_level"],
        "routing": memory["routing"],
        "memory_entry": memory["memory_entry"],
        "memory_markdown": memory["memory_markdown"],
        "retention_days": retention_days,
        "runtime_dir": str(runtime_dir),
        "operator_dir": str(operator_dir),
        "runtime_file_count": len(files_runtime),
        "operator_health_file_count": len(files_operator),
        "stale_candidate_count": len(stale),
        "latest_runtime": latest,
        "latest_operator_health": operator,
        "latest_log_tail": tail_lines(latest_log, min(lines, 12)),
        "artifacts": [str(p) for p in [latest_log, runtime_dir / "latest.json"] if p.exists()] + ([memory["memory_artifact"]] if memory["memory_artifact"] else []),
        "degraded_reasons": [] if overall == "ok" else [f"mascarade-runtime-{status}"],
        "next_steps": [] if overall == "ok" else ["bash tools/cockpit/mascarade_runtime_health.sh --json"],
    }
    return payload


def list_payload():
    memory = memory_context()
    combined = runtime_files() + operator_health_files()
    combined = sorted(combined, key=lambda p: p.stat().st_mtime, reverse=True)[:lines]
    entries = [
        {
            "file": str(path),
            "kind": "operator-health" if path.parent == operator_dir else "runtime-artifact",
            "modified_at": format_ts(path),
            "size_bytes": path.stat().st_size,
        }
        for path in combined
    ]
    status = "ok" if entries else "degraded"
    return {
        "contract_version": "cockpit-v1",
        "component": "mascarade-logs-tui",
        "action": "list",
        "status": status,
        "contract_status": status,
        "owner": memory["owner"],
        "resume_ref": memory["resume_ref"],
        "trust_level": memory["trust_level"],
        "routing": memory["routing"],
        "memory_entry": memory["memory_entry"],
        "memory_markdown": memory["memory_markdown"],
        "entries": entries,
        "artifacts": [entry["file"] for entry in entries] + ([memory["memory_artifact"]] if memory["memory_artifact"] else []),
        "degraded_reasons": [] if entries else ["mascarade-logs-empty"],
        "next_steps": [] if entries else ["Run bash tools/cockpit/mascarade_runtime_health.sh --json to create fresh artifacts."],
    }


def latest_payload():
    memory = memory_context()
    summary = summary_payload()
    latest_runtime_log = runtime_dir / "latest.log"
    payload = {
        "contract_version": "cockpit-v1",
        "component": "mascarade-logs-tui",
        "action": "latest",
        "status": summary["status"],
        "contract_status": summary["contract_status"],
        "owner": memory["owner"],
        "resume_ref": memory["resume_ref"],
        "trust_level": memory["trust_level"],
        "routing": memory["routing"],
        "memory_entry": memory["memory_entry"],
        "memory_markdown": memory["memory_markdown"],
        "latest_runtime": summary["latest_runtime"],
        "latest_operator_health": summary["latest_operator_health"],
        "latest_log_tail": tail_lines(latest_runtime_log, lines),
        "artifacts": summary["artifacts"],
        "degraded_reasons": summary["degraded_reasons"],
        "next_steps": summary["next_steps"],
    }
    return payload


def purge_payload():
    candidates = candidate_purge_files()
    purged = []
    if apply:
      for path in candidates:
          try:
              path.unlink()
              purged.append(str(path))
          except FileNotFoundError:
              pass
    status = "done" if apply else "ready"
    contract_status = "ok" if apply else "ready"
    return {
        "contract_version": "cockpit-v1",
        "component": "mascarade-logs-tui",
        "action": "purge",
        "status": status,
        "contract_status": contract_status,
        "retention_days": retention_days,
        "apply": apply,
        "candidate_count": len(candidates),
        "purged_count": len(purged),
        "candidates": [str(path) for path in candidates[:lines]],
        "artifacts": purged if apply else [str(path) for path in candidates[:lines]],
        "degraded_reasons": [],
        "next_steps": [] if apply else ["Re-run with --apply to remove stale Mascarade/Ollama artifacts."],
    }


if action == "summary":
    payload = summary_payload()
elif action == "list":
    payload = list_payload()
elif action == "latest":
    payload = latest_payload()
else:
    payload = purge_payload()

if json_output:
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    raise SystemExit(0)

if action == "summary":
    print("Mascarade/Ollama logs summary")
    print(f"runtime dir: {payload['runtime_dir']}")
    print(f"operator dir: {payload['operator_dir']}")
    print(f"latest runtime: {payload['latest_runtime']['status']} ({payload['latest_runtime']['provider']}/{payload['latest_runtime']['model']})")
    if payload["latest_runtime"]["checked_at"]:
        print(f"checked at: {payload['latest_runtime']['checked_at']}")
    print(f"runtime files: {payload['runtime_file_count']}")
    print(f"operator health files: {payload['operator_health_file_count']}")
    print(f"stale candidates (> {retention_days}j): {payload['stale_candidate_count']}")
    if payload["latest_operator_health"]["path"]:
        print(f"latest operator health: {payload['latest_operator_health']['status']} ({payload['latest_operator_health']['path']})")
    if payload["latest_log_tail"]:
        print("latest.log tail:")
        for line in payload["latest_log_tail"]:
            print(f"  {line}")
elif action == "list":
    print("Mascarade/Ollama log artifacts")
    for entry in payload["entries"]:
        print(f"{entry['modified_at']} | {entry['kind']} | {entry['size_bytes']} B | {entry['file']}")
elif action == "latest":
    print("Mascarade/Ollama latest state")
    print(f"runtime: {payload['latest_runtime']['status']} ({payload['latest_runtime']['provider']}/{payload['latest_runtime']['model']})")
    print(f"runtime json: {payload['latest_runtime']['path']}")
    if payload["latest_operator_health"]["path"]:
        print(f"operator health: {payload['latest_operator_health']['status']} ({payload['latest_operator_health']['path']})")
    print("latest.log tail:")
    for line in payload["latest_log_tail"]:
        print(f"  {line}")
else:
    mode = "apply" if apply else "dry-run"
    print(f"Mascarade/Ollama purge ({mode})")
    print(f"retention days: {retention_days}")
    print(f"candidate count: {payload['candidate_count']}")
    print(f"purged count: {payload['purged_count']}")
    for item in payload["candidates"]:
        print(f"  {item}")
PY
