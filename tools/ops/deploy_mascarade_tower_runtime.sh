#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REMOTE_HOST="clems@192.168.0.120"
REMOTE_DIR="/home/clems/mascarade-main"
ACTION="status"
JSON_OUTPUT=0
SEED_AGENTS=1

usage() {
  cat <<'EOF'
Usage: bash tools/ops/deploy_mascarade_tower_runtime.sh [options]

Options:
  --action status|apply  Default: status
  --remote-host HOST     Override tower SSH host
  --remote-dir DIR       Override Mascarade remote dir
  --json                 Emit JSON
  --skip-seed            Do not seed tower-* agents on apply
  --help                 Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --action)
      ACTION="${2:-}"
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
    --json)
      JSON_OUTPUT=1
      shift
      ;;
    --skip-seed)
      SEED_AGENTS=0
      shift
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

if [[ "${ACTION}" != "status" && "${ACTION}" != "apply" ]]; then
  echo "Invalid --action: ${ACTION}" >&2
  exit 2
fi

runtime_status="$(
  ssh -o BatchMode=yes -o ConnectTimeout=5 "${REMOTE_HOST}" "python3 - <<'PY'
import json
import subprocess
from pathlib import Path

def run(cmd):
    return subprocess.run(cmd, shell=True, text=True, capture_output=True)

docker_ok = run('command -v docker >/dev/null 2>&1')
containers = []
models = []
if docker_ok.returncode == 0:
    ps = run(\"docker ps --format '{{.Names}}|{{.Status}}|{{.Ports}}'\")
    for raw in ps.stdout.splitlines():
        if raw.startswith('mascarade-'):
            parts = raw.split('|', 2)
            containers.append({
                'name': parts[0],
                'status': parts[1] if len(parts) > 1 else '',
                'ports': parts[2] if len(parts) > 2 else '',
            })
    listing = run(\"docker exec mascarade-ollama ollama list 2>/dev/null | sed -n '2,12p'\")
    for raw in listing.stdout.splitlines():
        model = raw.strip().split()
        if model:
            models.append(model[0])

result = {
    'status': 'ok' if docker_ok.returncode == 0 else 'error',
    'remote_dir': '/home/clems/mascarade-main',
    'runtime_mode': 'normalize-existing-stack',
    'docker': docker_ok.returncode == 0,
    'remote_dir_exists': Path('/home/clems/mascarade-main').exists(),
    'containers': containers,
    'models': models,
}
print(json.dumps(result, ensure_ascii=True))
PY"
)"

seed_status='{"status":"skipped"}'
if [[ "${ACTION}" == "apply" && "${SEED_AGENTS}" -eq 1 ]]; then
  seed_status="$(bash "${ROOT_DIR}/tools/ops/sync_mascarade_agents_tower.sh" --action sync --apply --json --remote-host "${REMOTE_HOST}" --remote-dir "${REMOTE_DIR}")"
fi

python3 - "${runtime_status}" "${seed_status}" "${REMOTE_HOST}" "${REMOTE_DIR}" "${ACTION}" "${JSON_OUTPUT}" <<'PY'
import json
import sys

runtime = json.loads(sys.argv[1])
seed = json.loads(sys.argv[2])
summary = {
    "status": "ok" if runtime.get("status") == "ok" else "error",
    "action": sys.argv[5],
    "target_host": sys.argv[3],
    "remote_dir": sys.argv[4],
    "runtime_mode": runtime.get("runtime_mode", "normalize-existing-stack"),
    "runtime_containers": runtime.get("containers", []),
    "runtime_models": runtime.get("models", []),
    "seed_status": seed.get("status", "skipped"),
    "seed_created": seed.get("created", 0),
    "seed_updated": seed.get("updated", 0),
    "seed_agents": seed.get("agents", []),
}
if sys.argv[6] == "1":
    print(json.dumps(summary, indent=2, ensure_ascii=True))
else:
    print("Tower Mascarade runtime")
    print(f"- target: {summary['target_host']}")
    print(f"- mode: {summary['runtime_mode']}")
    print(f"- containers: {', '.join(item['name'] for item in summary['runtime_containers'])}")
    print(f"- models: {', '.join(summary['runtime_models'][:4])}")
    print(f"- seed_status: {summary['seed_status']}")
PY
