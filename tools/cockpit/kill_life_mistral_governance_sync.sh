#!/usr/bin/env bash
set -euo pipefail

# kill_life_mistral_governance_sync.sh
# Sync Kill_LIFE governance-only Mistral key to per-user secret files on mesh machines.
# Contract: cockpit-v1
# Date: 2026-03-22

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts/cockpit/kill_life_mistral_governance_sync"
mkdir -p "${ARTIFACTS_DIR}"

ACTION="sync"
SECRET_FILE="${SECRET_FILE:-${HOME}/.kill-life/mistral.env}"

HOST_LABELS=(
  "local"
  "clems"
  "root"
  "kxkm"
  "cils"
)

HOST_TARGETS=(
  "local"
  "clems@192.168.0.120"
  "root@192.168.0.119"
  "kxkm@kxkm-ai"
  "cils@100.126.225.111"
)

HOST_SECRET_FILES=(
  "${HOME}/.kill-life/mistral.env"
  "/home/clems/.kill-life/mistral.env"
  "/root/.kill-life/mistral.env"
  "/home/kxkm/.kill-life/mistral.env"
  "/Users/cils/.kill-life/mistral.env"
)

usage() {
  cat <<'EOF'
Usage: kill_life_mistral_governance_sync.sh [--action sync|status] [--help]

Actions:
  sync    Write/update MISTRAL_GOVERNANCE_API_KEY on all configured machines
  status  Report presence of the secret file on all configured machines

Env vars:
  SECRET_FILE   Local governance secret source (default: ~/.kill-life/mistral.env)
EOF
}

load_governance_key() {
  python3 - "$SECRET_FILE" <<'PY'
import json
import sys
from pathlib import Path

secret_path = Path(sys.argv[1]).expanduser()
if not secret_path.exists():
    raise SystemExit(f"missing secret file: {secret_path}")

value = None
for line in secret_path.read_text(encoding="utf-8").splitlines():
    if line.startswith("MISTRAL_GOVERNANCE_API_KEY="):
        value = line.split("=", 1)[1]
        break

if not value:
    raise SystemExit("MISTRAL_GOVERNANCE_API_KEY missing in secret file")

print(value)
PY
}

remote_status() {
  local host="$1"
  local secret_path="$2"
  ssh -o BatchMode=yes -o ConnectTimeout=8 "$host" python3 - "$secret_path" <<'PY'
import json
import sys
from pathlib import Path

secret_path = Path(sys.argv[1])
print(json.dumps({
    "status": "ok",
    "secret_path": str(secret_path),
    "exists": secret_path.exists(),
}))
PY
}

remote_sync() {
  local host="$1"
  local secret_path="$2"
  local key_b64="$3"
  ssh -o BatchMode=yes -o ConnectTimeout=8 "$host" python3 - "$secret_path" "$key_b64" <<'PY'
import base64
import json
import sys
from pathlib import Path

secret_path = Path(sys.argv[1])
key = base64.b64decode(sys.argv[2]).decode("utf-8")

secret_path.parent.mkdir(parents=True, exist_ok=True)
secret_path.write_text(f"MISTRAL_GOVERNANCE_API_KEY={key}\n", encoding="utf-8")
secret_path.chmod(0o600)

print(json.dumps({
    "status": "updated",
    "secret_path": str(secret_path),
}))
PY
}

run_action() {
  local mode="$1"
  local stamp artifact_file latest_file now
  local key="" key_b64=""

  if [[ "$mode" == "sync" ]]; then
    key="$(load_governance_key)"
    key_b64="$(printf '%s' "$key" | base64)"
  fi

  stamp="$(date +%Y%m%d_%H%M%S)"
  artifact_file="${ARTIFACTS_DIR}/kill_life_mistral_governance_sync_${stamp}.json"
  latest_file="${ARTIFACTS_DIR}/latest.json"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  python3 - "$mode" "$now" "$artifact_file" "$latest_file" "$key_b64" "${HOST_LABELS[@]}" -- "${HOST_TARGETS[@]}" -- "${HOST_SECRET_FILES[@]}" <<'PY'
import json
import subprocess
import sys

mode = sys.argv[1]
timestamp = sys.argv[2]
artifact_file = sys.argv[3]
latest_file = sys.argv[4]
key_b64 = sys.argv[5]
args = sys.argv[6:]
sep1 = args.index("--")
labels = args[:sep1]
args = args[sep1 + 1 :]
sep2 = args.index("--")
targets = args[:sep2]
secret_files = args[sep2 + 1 :]

results = []

for label, target, secret_path in zip(labels, targets, secret_files):
    if target == "local":
        if mode == "status":
            proc = subprocess.run(
                ["python3", "-", secret_path],
                input=(
                    "import json,sys\n"
                    "from pathlib import Path\n"
                    "p=Path(sys.argv[1]).expanduser()\n"
                    "print(json.dumps({'status':'ok','secret_path':str(p),'exists':p.exists()}))\n"
                ),
                text=True,
                capture_output=True,
            )
        else:
            proc = subprocess.run(
                ["python3", "-", secret_path, key_b64],
                input=(
                    "import base64,json,sys\n"
                    "from pathlib import Path\n"
                    "p=Path(sys.argv[1]).expanduser(); key=base64.b64decode(sys.argv[2]).decode('utf-8')\n"
                    "p.parent.mkdir(parents=True, exist_ok=True)\n"
                    "p.write_text(f'MISTRAL_GOVERNANCE_API_KEY={key}\\n', encoding='utf-8')\n"
                    "p.chmod(0o600)\n"
                    "print(json.dumps({'status':'updated','secret_path':str(p)}))\n"
                ),
                text=True,
                capture_output=True,
            )
    else:
        subcmd = "__remote_status__" if mode == "status" else "__remote_sync__"
        argv = [
            "/Users/electron/Documents/Lelectron_rare/Kill_LIFE/tools/cockpit/kill_life_mistral_governance_sync.sh",
            subcmd,
            target,
            secret_path,
        ]
        if mode == "sync":
            argv.append(key_b64)
        proc = subprocess.run(argv, capture_output=True, text=True)

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
    "component": "kill-life-mistral-governance-sync",
    "action": mode,
    "timestamp": timestamp,
    "results": results,
}
summary["ok"] = sum(1 for item in results if item.get("status") in {"ok", "updated"})
summary["errors"] = sum(1 for item in results if item.get("status") not in {"ok", "updated"})

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
  sync|status)
    run_action "$ACTION"
    ;;
  *)
    printf 'Unknown action: %s\n' "$ACTION" >&2
    usage >&2
    exit 2
    ;;
esac
