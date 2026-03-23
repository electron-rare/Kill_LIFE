#!/usr/bin/env bash
set -euo pipefail

# mascarade_mesh_env_sync.sh
# Canonical Mascarade roots and .env propagation for mesh machines.
# Contract: cockpit-v1
# Date: 2026-03-22

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts/cockpit/mascarade_mesh_env_sync"
mkdir -p "${ARTIFACTS_DIR}"

ACTION="status"
JSON_MODE=0
SOURCE_ENV="${SOURCE_ENV:-/Users/electron/Documents/Projets/mascarade/.env}"

KEYS=(
  "ANTHROPIC_API_KEY"
  "MISTRAL_API_KEY"
  "OPENAI_API_KEY"
)

HOST_LABELS=(
  "clems"
  "root"
  "kxkm"
  "cils"
)

HOST_TARGETS=(
  "clems@192.168.0.120"
  "root@192.168.0.119"
  "kxkm@kxkm-ai"
  "cils@100.126.225.111"
)

HOST_ROOTS=(
  "/home/clems/mascarade"
  "/root/mascarade-main"
  "/home/kxkm/mascarade"
  "/Users/cils/mascarade-main"
)

usage() {
  cat <<'EOF'
Usage: mascarade_mesh_env_sync.sh [--action status|sync|paths] [--json]

Actions:
  status   Inspect canonical Mascarade roots and .env presence on the mesh
  sync     Propagate selected keys from the local source .env to the remote roots
  paths    Print the canonical roots only

Options:
  --json   Emit cockpit-v1 JSON
  --help   Show this help

Env vars:
  SOURCE_ENV   Local source .env (default: /Users/electron/Documents/Projets/mascarade/.env)
EOF
}

json_escape() {
  python3 - "$1" <<'PY'
import json
import sys
print(json.dumps(sys.argv[1]))
PY
}

load_updates_json() {
  python3 - "$SOURCE_ENV" "${KEYS[@]}" <<'PY'
import json
import sys
from pathlib import Path

env_path = Path(sys.argv[1])
keys = sys.argv[2:]
values = {}

for line in env_path.read_text(encoding="utf-8").splitlines():
    if "=" not in line or line.lstrip().startswith("#"):
        continue
    key, value = line.split("=", 1)
    if key in keys:
        values[key] = value

missing = [key for key in keys if key not in values or not values[key]]
if missing:
    raise SystemExit("missing keys in source env: " + ", ".join(missing))

print(json.dumps(values))
PY
}

remote_status() {
  local host="$1"
  local root="$2"
  ssh -o BatchMode=yes -o ConnectTimeout=8 "$host" python3 - "$root" <<'PY'
import json
import socket
import sys
from pathlib import Path

root = Path(sys.argv[1])
ports = {}
for port in (3000, 3100, 8000, 8080, 11434):
    s = socket.socket()
    s.settimeout(0.4)
    try:
        s.connect(("127.0.0.1", port))
        ports[str(port)] = True
    except Exception:
        ports[str(port)] = False
    finally:
        s.close()

print(json.dumps({
    "status": "ok",
    "hostname": socket.gethostname(),
    "root": str(root),
    "root_exists": root.exists(),
    "env_path": str(root / ".env"),
    "env_exists": (root / ".env").exists(),
    "git_exists": (root / ".git").exists(),
    "compose_exists": any((root / name).exists() for name in ("docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml")),
    "ports": ports,
}))
PY
}

remote_sync() {
  local host="$1"
  local root="$2"
  local payload_b64="$3"
  ssh -o BatchMode=yes -o ConnectTimeout=8 "$host" python3 - "$root" "$payload_b64" <<'PY'
import base64
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
updates = json.loads(base64.b64decode(sys.argv[2]).decode("utf-8"))

if not root.exists():
    print(json.dumps({
        "status": "missing-root",
        "root": str(root),
    }))
    raise SystemExit(0)

env_path = root / ".env"
lines = env_path.read_text(encoding="utf-8").splitlines() if env_path.exists() else []

seen = set()
out = []
for line in lines:
    replaced = False
    for key, value in updates.items():
        if line.startswith(f"{key}="):
            out.append(f"{key}={value}")
            seen.add(key)
            replaced = True
            break
    if not replaced:
        out.append(line)

for key, value in updates.items():
    if key not in seen:
        out.append(f"{key}={value}")

env_path.write_text("\n".join(out) + "\n", encoding="utf-8")

print(json.dumps({
    "status": "updated",
    "root": str(root),
    "env_path": str(env_path),
    "updated_keys": sorted(updates.keys()),
}))
PY
}

emit_paths_text() {
  local idx
  for idx in "${!HOST_LABELS[@]}"; do
    printf '%s %s %s\n' "${HOST_LABELS[$idx]}" "${HOST_TARGETS[$idx]}" "${HOST_ROOTS[$idx]}"
  done
}

run_action() {
  local stamp artifact_file latest_file now
  local mode="$1"
  local updates_json=""

  if [[ "$mode" == "sync" ]]; then
    updates_json="$(load_updates_json)"
  fi

  stamp="$(date +%Y%m%d_%H%M%S)"
  artifact_file="${ARTIFACTS_DIR}/mascarade_mesh_env_sync_${stamp}.json"
  latest_file="${ARTIFACTS_DIR}/latest.json"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  python3 - "$mode" "$now" "$SOURCE_ENV" "$artifact_file" "$latest_file" "$updates_json" "${HOST_LABELS[@]}" -- "${HOST_TARGETS[@]}" -- "${HOST_ROOTS[@]}" <<'PY'
import json
import subprocess
import sys

mode = sys.argv[1]
timestamp = sys.argv[2]
source_env = sys.argv[3]
artifact_file = sys.argv[4]
latest_file = sys.argv[5]
updates_json = sys.argv[6]

args = sys.argv[7:]
sep1 = args.index("--")
labels = args[:sep1]
args = args[sep1 + 1 :]
sep2 = args.index("--")
targets = args[:sep2]
roots = args[sep2 + 1 :]

results = []
updates = json.loads(updates_json) if updates_json else {}

for label, target, root in zip(labels, targets, roots):
    if mode == "status":
        proc = subprocess.run(
            [
                "/Users/electron/Documents/Lelectron_rare/Kill_LIFE/tools/cockpit/mascarade_mesh_env_sync.sh",
                "__remote_status__",
                target,
                root,
            ],
            capture_output=True,
            text=True,
        )
    else:
        import base64
        proc = subprocess.run(
            [
                "/Users/electron/Documents/Lelectron_rare/Kill_LIFE/tools/cockpit/mascarade_mesh_env_sync.sh",
                "__remote_sync__",
                target,
                root,
                base64.b64encode(json.dumps(updates).encode("utf-8")).decode("ascii"),
            ],
            capture_output=True,
            text=True,
        )

    record = {"label": label, "host": target, "returncode": proc.returncode}
    stdout = (proc.stdout or "").strip()
    stderr = (proc.stderr or "").strip()
    if stdout:
        try:
            record.update(json.loads(stdout.splitlines()[-1]))
        except Exception:
            record["status"] = "parse-error"
            record["stdout"] = stdout
    if stderr:
        record["stderr"] = stderr
    if "status" not in record:
        record["status"] = "ssh-error" if proc.returncode else "empty"
    results.append(record)

summary = {
    "contract_version": "cockpit-v1",
    "component": "mascarade-mesh-env-sync",
    "action": mode,
    "timestamp": timestamp,
    "source_env": source_env,
    "updated_keys": sorted(updates.keys()),
    "results": results,
}

summary["ok"] = sum(1 for item in results if item.get("status") in {"ok", "updated"})
summary["missing_root"] = sum(1 for item in results if item.get("status") == "missing-root")
summary["ssh_errors"] = sum(1 for item in results if item.get("status") == "ssh-error")

payload = json.dumps(summary, indent=2) + "\n"
with open(artifact_file, "w", encoding="utf-8") as handle:
    handle.write(payload)
with open(latest_file, "w", encoding="utf-8") as handle:
    handle.write(payload)
print(payload, end="")
PY
}

if [[ "${1:-}" == "__remote_status__" ]]; then
  shift
  remote_status "$@"
  exit 0
fi

if [[ "${1:-}" == "__remote_sync__" ]]; then
  shift
  remote_sync "$@"
  exit 0
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --action)
      ACTION="${2:-}"
      shift 2
      ;;
    --json)
      JSON_MODE=1
      shift
      ;;
    --help|-h)
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

case "$ACTION" in
  paths)
    if [[ "$JSON_MODE" -eq 1 ]]; then
      cat <<EOF
{
  "contract_version": "cockpit-v1",
  "component": "mascarade-mesh-env-sync",
  "action": "paths",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "source_env": $(json_escape "$SOURCE_ENV"),
  "machines": [
    {"label":"${HOST_LABELS[0]}","host":"${HOST_TARGETS[0]}","root":"${HOST_ROOTS[0]}"},
    {"label":"${HOST_LABELS[1]}","host":"${HOST_TARGETS[1]}","root":"${HOST_ROOTS[1]}"},
    {"label":"${HOST_LABELS[2]}","host":"${HOST_TARGETS[2]}","root":"${HOST_ROOTS[2]}"},
    {"label":"${HOST_LABELS[3]}","host":"${HOST_TARGETS[3]}","root":"${HOST_ROOTS[3]}"}
  ]
}
EOF
    else
      emit_paths_text
    fi
    ;;
  status|sync)
    run_action "$ACTION"
    ;;
  *)
    printf 'Unknown action: %s\n' "$ACTION" >&2
    usage >&2
    exit 2
    ;;
esac
