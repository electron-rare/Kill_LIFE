#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CATALOG_FILE="${ROOT_DIR}/specs/contracts/mascarade_model_profiles.tower.json"
REMOTE_HOST="clems@192.168.0.120"
REMOTE_DIR="/home/clems/mascarade-main"
ACTION="plan"
APPLY=0
JSON_OUTPUT=0

usage() {
  cat <<'EOF'
Usage: bash tools/ops/sync_mascarade_agents_tower.sh [options]

Options:
  --action plan|sync   Action to execute. Default: plan
  --apply              Apply remote merge into data/agents.json
  --json               Emit JSON
  --catalog FILE       Override catalog file
  --remote-host HOST   Override remote host
  --remote-dir DIR     Override remote Mascarade dir
  --help               Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --action)
      ACTION="${2:-}"
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
    --catalog)
      CATALOG_FILE="${2:-}"
      shift 2
      ;;
    --remote-host)
      REMOTE_HOST="${2:-}"
      shift 2
      ;;
    --remote-dir)
      REMOTE_DIR="${2:-}"
      shift 2
      ;;
    --help|-h)
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

if [[ "${ACTION}" != "plan" && "${ACTION}" != "sync" ]]; then
  echo "Invalid --action: ${ACTION}" >&2
  exit 2
fi

if [[ ! -f "${CATALOG_FILE}" ]]; then
  echo "Missing catalog file: ${CATALOG_FILE}" >&2
  exit 1
fi

catalog_payload="$(
  python3 - "${CATALOG_FILE}" <<'PY'
import json
import sys
from pathlib import Path

catalog = json.loads(Path(sys.argv[1]).read_text())
profiles = catalog.get("profiles", [])
payload = []
for profile in profiles:
    payload.append(
        {
            "name": profile["name"],
            "description": profile["description"],
            "system_prompt": profile["system_prompt"],
            "preferred_provider": profile["preferred_provider"],
            "preferred_model": profile["preferred_model"],
            "strategy": profile.get("strategy", "balanced"),
            "temperature": profile.get("temperature", 0.2),
            "max_tokens": profile.get("max_tokens", 4096),
        }
    )
print(json.dumps({"catalog": catalog, "agents": payload}, ensure_ascii=True))
PY
)"

if [[ "${ACTION}" == "plan" || "${APPLY}" -eq 0 ]]; then
  python3 - "${catalog_payload}" "${REMOTE_HOST}" "${REMOTE_DIR}" "${ACTION}" "${JSON_OUTPUT}" "${APPLY}" <<'PY'
import json
import sys

blob = json.loads(sys.argv[1])
catalog = blob["catalog"]
agents = blob["agents"]
summary = {
    "status": "planned",
    "action": sys.argv[4],
    "apply": sys.argv[6] == "1",
    "target_id": catalog.get("target_id", "tower"),
    "target_host": sys.argv[2],
    "remote_dir": sys.argv[3],
    "catalog_file": sys.argv[1] if len(sys.argv) > 1 else "",
    "agents": [agent["name"] for agent in agents],
    "count": len(agents),
}
if sys.argv[5] == "1":
    print(json.dumps(summary, indent=2, ensure_ascii=True))
else:
    print("Tower Mascarade agent sync plan")
    print(f"- target: {summary['target_host']}")
    print(f"- remote_dir: {summary['remote_dir']}")
    print(f"- agents: {', '.join(summary['agents'])}")
PY
  exit 0
fi

payload_b64="$(printf '%s' "${catalog_payload}" | base64 | tr -d '\n')"

remote_result="$(
  ssh -o BatchMode=yes -o ConnectTimeout=5 "${REMOTE_HOST}" \
    "mkdir -p '${REMOTE_DIR}/data' && PAYLOAD_B64='${payload_b64}' python3 - '${REMOTE_DIR}/data/agents.json'" <<'PY'
import base64
import json
import os
import sys
from pathlib import Path

path = Path(sys.argv[1])
blob = json.loads(base64.b64decode(os.environ["PAYLOAD_B64"]).decode())
agents = blob["agents"]
if path.exists():
    try:
        existing = json.loads(path.read_text())
    except Exception:
        existing = []
else:
    existing = []
if not isinstance(existing, list):
    existing = []
by_name = {}
for item in existing:
    if isinstance(item, dict) and item.get("name"):
        by_name[item["name"]] = item
created = 0
updated = 0
for agent in agents:
    name = agent["name"]
    if name in by_name:
        updated += 1
    else:
        created += 1
    by_name[name] = agent
merged = [by_name[name] for name in sorted(by_name.keys())]
path.write_text(json.dumps(merged, indent=2, ensure_ascii=True) + "\n")
print(json.dumps({
    "status": "applied",
    "target_file": str(path),
    "created": created,
    "updated": updated,
    "count": len(merged),
    "agents": [agent["name"] for agent in agents]
}, ensure_ascii=True))
PY
)"

python3 - "${remote_result}" "${REMOTE_HOST}" "${REMOTE_DIR}" "${JSON_OUTPUT}" <<'PY'
import json
import sys

remote = json.loads(sys.argv[1])
summary = {
    "status": remote.get("status", "applied"),
    "target_host": sys.argv[2],
    "remote_dir": sys.argv[3],
    "target_file": remote.get("target_file"),
    "created": remote.get("created", 0),
    "updated": remote.get("updated", 0),
    "count": remote.get("count", 0),
    "agents": remote.get("agents", []),
}
if sys.argv[4] == "1":
    print(json.dumps(summary, indent=2, ensure_ascii=True))
else:
    print("Tower Mascarade agent sync applied")
    print(f"- target: {summary['target_host']}")
    print(f"- created: {summary['created']}")
    print(f"- updated: {summary['updated']}")
    print(f"- file: {summary['target_file']}")
PY
