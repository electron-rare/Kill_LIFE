#!/usr/bin/env bash
set -euo pipefail

HOST="kxkm@kxkm-ai"
AGENTS_CSV="kxkm-code,kxkm-cad,kxkm-ops,kxkm-fallback-safe"
MESSAGE="Respond in one short sentence with your role name and current focus."
LOG_DIR="artifacts/ops/mascarade_agent_smoke"
JSON_OUTPUT=0

usage() {
  cat <<'EOF'
Usage: bash tools/ops/smoke_mascarade_agents_kxkm.sh [options]

Options:
  --host <ssh-target>         SSH target (default: kxkm@kxkm-ai)
  --agents <csv>              Comma-separated agent names
  --message <text>            Prompt sent to each agent
  --log-dir <path>            Local artifact directory
  --json                      Emit JSON only
  --help                      Show this help
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --host)
      HOST="${2:-}"
      shift 2
      ;;
    --agents)
      AGENTS_CSV="${2:-}"
      shift 2
      ;;
    --message)
      MESSAGE="${2:-}"
      shift 2
      ;;
    --log-dir)
      LOG_DIR="${2:-}"
      shift 2
      ;;
    --json)
      JSON_OUTPUT=1
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

if [ -z "$HOST" ] || [ -z "$AGENTS_CSV" ] || [ -z "$MESSAGE" ] || [ -z "$LOG_DIR" ]; then
  printf 'host, agents, message and log-dir must be non-empty\n' >&2
  exit 2
fi

mkdir -p "$LOG_DIR"

timestamp="$(date '+%Y%m%dT%H%M%S%z')"
artifact_path="${LOG_DIR}/mascarade_agent_smoke_${timestamp}.json"
latest_path="${LOG_DIR}/latest.json"
tmp_output="$(mktemp)"
trap 'rm -f "$tmp_output"' EXIT

cat <<'REMOTE' | ssh -o BatchMode=yes -o ConnectTimeout=5 "$HOST" bash -s -- "$AGENTS_CSV" "$MESSAGE" > "$tmp_output"
set -euo pipefail
agents_csv="$1"
message_text="$2"
API_KEY="$(docker inspect mascarade-api --format '{{range .Config.Env}}{{println .}}{{end}}' | sed -n 's/^MASCARADE_API_KEY=//p' | head -n1)"
API_KEY="$API_KEY" python3 - "$agents_csv" "$message_text" <<'PY'
import json
import os
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone

agents = [item for item in sys.argv[1].split(",") if item]
message = sys.argv[2]
api_key = os.environ["API_KEY"]
api_url = "http://127.0.0.1:3100/api/agents"
headers = {"Authorization": f"Bearer {api_key}"}

with urllib.request.urlopen(urllib.request.Request(api_url, headers=headers), timeout=10) as response:
    registry_payload = json.loads(response.read().decode("utf-8"))

registry_agents = registry_payload.get("agents", [])
registry_names = {agent.get("name") for agent in registry_agents if isinstance(agent, dict)}
results = []

for name in agents:
    payload = json.dumps(
        {"messages": [{"role": "user", "content": message}]}
    ).encode("utf-8")
    request = urllib.request.Request(
        f"{api_url}/{name}/run",
        data=payload,
        headers={**headers, "Content-Type": "application/json"},
        method="POST",
    )
    result = {
        "name": name,
        "registered": name in registry_names,
    }
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            body = json.loads(response.read().decode("utf-8"))
            result.update(
                {
                    "http_status": response.status,
                    "status": "ok" if response.status == 200 else "degraded",
                    "provider": body.get("provider"),
                    "model": body.get("model"),
                    "content": body.get("content"),
                    "error": body.get("error"),
                }
            )
    except urllib.error.HTTPError as exc:
        try:
            body = json.loads(exc.read().decode("utf-8"))
        except Exception:
            body = {"error": str(exc)}
        result.update(
            {
                "http_status": exc.code,
                "status": "error",
                "provider": body.get("provider"),
                "model": body.get("model"),
                "content": body.get("content"),
                "error": body.get("error", str(exc)),
            }
        )
    except Exception as exc:
        result.update(
            {
                "http_status": None,
                "status": "error",
                "provider": None,
                "model": None,
                "content": None,
                "error": str(exc),
            }
        )
    results.append(result)

overall = "ok" if results and all(item["status"] == "ok" for item in results) else "degraded"
print(
    json.dumps(
        {
            "status": overall,
            "component": "mascarade-agent-smoke",
            "action": "run",
            "host": os.uname().nodename,
            "ssh_target": os.environ.get("SSH_CONNECTION", "").split()[2] if os.environ.get("SSH_CONNECTION") else None,
            "api_url": api_url,
            "checked_at": datetime.now(timezone.utc).isoformat(),
            "agents": results,
        },
        ensure_ascii=True,
    )
)
PY
REMOTE

cp "$tmp_output" "$artifact_path"
cp "$artifact_path" "$latest_path"

if [ "$JSON_OUTPUT" -eq 1 ]; then
  cat "$artifact_path"
else
  python3 - "$artifact_path" <<'PY'
import json
import sys

payload = json.loads(open(sys.argv[1], encoding="utf-8").read())
print(f"status={payload.get('status')} artifact={sys.argv[1]}")
for item in payload.get("agents", []):
    print(
        "{name}: status={status} http={http_status} provider={provider} model={model}".format(
            name=item.get("name"),
            status=item.get("status"),
            http_status=item.get("http_status"),
            provider=item.get("provider"),
            model=item.get("model"),
        )
    )
PY
fi

python3 - "$artifact_path" <<'PY'
import json
import sys
payload = json.loads(open(sys.argv[1], encoding="utf-8").read())
raise SystemExit(0 if payload.get("status") == "ok" else 1)
PY
