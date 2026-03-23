#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
CATALOG_FILE="${ROOT_DIR}/specs/contracts/mascarade_model_profiles.kxkm_ai.json"
REMOTE_HOST="kxkm@kxkm-ai"
REMOTE_DIR="/home/kxkm/mascarade-main"
LOG_DIR="${ROOT_DIR}/artifacts/cockpit"
mkdir -p "${LOG_DIR}"

ACTION="plan"
APPLY=0
JSON=0
DAYS=14
LOG_FILE="${LOG_DIR}/sync_mascarade_agents_kxkm_$(date '+%Y%m%d_%H%M%S').log"

usage() {
  cat <<'EOF'
Usage: bash tools/ops/sync_mascarade_agents_kxkm.sh [options]

Options:
  --action <plan|sync|clean-logs>   Action to run
  --apply                           Apply remote write for sync
  --json                            Emit JSON when available
  --remote <user@host>              Remote host (default: kxkm@kxkm-ai)
  --remote-dir <path>               Remote mascarade directory
  --catalog <path>                  Local catalog path
  --days <N>                        Retention for clean-logs (default: 14)
  -h, --help                        Show this help
EOF
}

have_tty() {
  [[ -t 0 && -t 1 ]]
}

choose_action_interactive() {
  if command -v gum >/dev/null 2>&1 && have_tty; then
    gum choose plan sync clean-logs
    return 0
  fi
  return 1
}

log_line() {
  local level="$1"
  shift
  local msg="${level} $(date '+%Y-%m-%d %H:%M:%S %z') ${*}"
  printf '%s\n' "${msg}" | tee -a "${LOG_FILE}" >/dev/null
}

require_catalog() {
  if [[ ! -f "${CATALOG_FILE}" ]]; then
    printf 'Missing catalog file: %s\n' "${CATALOG_FILE}" >&2
    exit 1
  fi
}

agent_payload_json() {
  python3 - "${CATALOG_FILE}" <<'PY'
import json
import sys
from pathlib import Path

catalog_path = Path(sys.argv[1])
data = json.loads(catalog_path.read_text(encoding="utf-8"))
strategy_map = {
    "local-fast": "fastest",
    "fallback-safe": "cheapest",
}
agents = []
for item in data.get("profiles", []):
    if not isinstance(item, dict):
        continue
    profile_id = str(item.get("id", "")).strip()
    if not profile_id:
        continue
    label = str(item.get("label", "")).strip() or profile_id
    category = str(item.get("category", "")).strip() or profile_id
    intended = item.get("intended_tasks")
    tasks = [entry.strip() for entry in intended if isinstance(entry, str) and entry.strip()] if isinstance(intended, list) else []
    summary = ", ".join(tasks[:3]) if tasks else category
    agents.append(
        {
            "name": f"kxkm-{profile_id}",
            "description": f"{label} copilot for {summary}.",
            "system_prompt": str(item.get("prompt", "")).strip(),
            "preferred_provider": str(item.get("default_provider", "")).strip() or None,
            "preferred_model": str(item.get("default_model", "")).strip() or None,
            "strategy": strategy_map.get(profile_id, "best"),
            "temperature": float(item.get("temperature", 0.2)),
            "max_tokens": int(item.get("max_tokens", 700)),
        }
    )
payload = {
    "status": "ok",
    "target_host": data.get("target_host", ""),
    "catalog_file": str(catalog_path),
    "agents": agents,
}
print(json.dumps(payload, ensure_ascii=False))
PY
}

emit_plan() {
  local payload
  payload="$(agent_payload_json)"
  if [[ "${JSON}" -eq 1 ]]; then
    printf '%s\n' "${payload}"
    return 0
  fi
  python3 - <<'PY' "${payload}" "${REMOTE_HOST}" "${REMOTE_DIR}" "${APPLY}"
import json
import sys

payload = json.loads(sys.argv[1])
remote_host = sys.argv[2]
remote_dir = sys.argv[3]
apply_mode = sys.argv[4] == "1"

print("# Sync Mascarade agents -> kxkm-ai\n")
print(f"- remote_host: {remote_host}")
print(f"- remote_dir: {remote_dir}")
print(f"- apply: {apply_mode}")
print(f"- catalog_file: {payload.get('catalog_file', '')}")
print(f"- agent_count: {len(payload.get('agents', []))}")
for agent in payload.get("agents", []):
    print(
        f"- {agent['name']}: {agent.get('preferred_provider') or '-'} / "
        f"{agent.get('preferred_model') or '-'} / strategy={agent.get('strategy')}"
    )
PY
}

apply_sync() {
  local payload
  local payload_b64
  local response
  payload="$(agent_payload_json)"
  if [[ "${APPLY}" -ne 1 ]]; then
    emit_plan
    return 0
  fi
  payload_b64="$(printf '%s' "${payload}" | base64 | tr -d '\n')"

  response="$(
    ssh -o BatchMode=yes -o ConnectTimeout=5 "${REMOTE_HOST}" \
      "REMOTE_DIR='${REMOTE_DIR}' PAYLOAD_B64='${payload_b64}' python3 - <<'PY'
import base64
import json
import os
import subprocess
from pathlib import Path

payload = json.loads(base64.b64decode(os.environ['PAYLOAD_B64']).decode('utf-8'))
remote_dir = Path(os.environ['REMOTE_DIR'])
repo_target = remote_dir / 'data' / 'agents.json'
runtime_target = None
runtime_via_docker = False

try:
    inspect = subprocess.run(
        ['docker', 'inspect', 'mascarade-core', '--format', '{{json .Mounts}}'],
        check=True,
        capture_output=True,
        text=True,
    )
    mounts = json.loads(inspect.stdout or '[]')
    for mount in mounts:
        if isinstance(mount, dict) and mount.get('Destination') == '/app/data':
            runtime_target = 'docker://mascarade-core/app/data/agents.json'
            runtime_via_docker = True
            break
except Exception:
    runtime_target = None
    runtime_via_docker = False

targets = [repo_target]
if runtime_target is not None and runtime_target not in targets:
    targets.append(runtime_target)

primary_target = runtime_target or repo_target
repo_target.parent.mkdir(parents=True, exist_ok=True)

existing = []
try:
    if repo_target.exists():
        loaded = json.loads(repo_target.read_text(encoding='utf-8'))
        if isinstance(loaded, list):
            existing = [item for item in loaded if isinstance(item, dict)]
except json.JSONDecodeError:
    existing = []

incoming = [item for item in payload.get('agents', []) if isinstance(item, dict)]
incoming_by_name = {}
for item in incoming:
    name = str(item.get('name', '')).strip()
    if name:
        incoming_by_name[name] = item

merged = []
seen = set()
updated = []
for item in existing:
    name = str(item.get('name', '')).strip()
    if name in incoming_by_name:
      merged.append(incoming_by_name[name])
      updated.append(name)
      seen.add(name)
    else:
      merged.append(item)
      seen.add(name)

created = []
for name, item in incoming_by_name.items():
    if name not in seen:
        merged.append(item)
        created.append(name)

serialized = json.dumps(merged, indent=2, ensure_ascii=False) + '\n'
repo_target.write_text(serialized, encoding='utf-8')

if runtime_via_docker:
    subprocess.run(
        ['docker', 'exec', '-u', '0', '-i', 'mascarade-core', 'sh', '-lc', 'cat > /app/data/agents.json'],
        input=serialized,
        text=True,
        check=True,
    )

print(json.dumps({
    'status': 'ok',
    'path': str(primary_target),
    'paths': [str(path) for path in targets],
    'created': created,
    'updated': updated,
    'count': len(merged),
}))
PY"
  )"

  if [[ "${JSON}" -eq 1 ]]; then
    printf '%s\n' "${response}"
  else
    python3 - "${response}" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
print("# Sync applied\n")
print(f"- path: {payload.get('path', '')}")
print(f"- count: {payload.get('count', 0)}")
print(f"- created: {', '.join(payload.get('created', [])) or 'none'}")
print(f"- updated: {', '.join(payload.get('updated', [])) or 'none'}")
PY
  fi
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
      JSON=1
      shift
      ;;
    --remote)
      REMOTE_HOST="${2:-}"
      shift 2
      ;;
    --remote-dir)
      REMOTE_DIR="${2:-}"
      shift 2
      ;;
    --catalog)
      CATALOG_FILE="${2:-}"
      shift 2
      ;;
    --days)
      DAYS="${2:-14}"
      shift 2
      ;;
    -h|--help)
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

if [[ -z "${ACTION}" ]]; then
  if ACTION="$(choose_action_interactive)"; then
    :
  fi
fi

if ! [[ "${DAYS}" =~ ^[0-9]+$ ]]; then
  printf -- '--days requires an integer\n' >&2
  exit 2
fi

require_catalog
log_line "INFO" "action=${ACTION} remote=${REMOTE_HOST} apply=${APPLY}"

case "${ACTION}" in
  plan)
    emit_plan
    ;;
  sync)
    apply_sync
    ;;
  clean-logs)
    find "${LOG_DIR}" -type f -name 'sync_mascarade_agents_kxkm_*.log' -mtime +"${DAYS}" -delete
    printf 'cleaned sync_mascarade_agents_kxkm logs older than %s days in %s\n' "${DAYS}" "${LOG_DIR}"
    ;;
  *)
    printf 'Unknown action: %s\n' "${ACTION}" >&2
    usage >&2
    exit 2
    ;;
esac
