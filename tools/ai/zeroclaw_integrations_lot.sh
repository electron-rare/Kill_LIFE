#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

COMMAND="status"
OUTPUT_JSON=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: bash tools/ai/zeroclaw_integrations_lot.sh <status|paths|verify|run> [options]

Inspect or validate the tracked ZeroClaw/n8n integration lot.

Commands:
  status      Print the scoped git status and canonical commands
  paths       Print the exact tracked paths that define the lot
  verify      Validate the scripts and the local n8n smoke runtime
  run         Alias of `verify`

Options:
  --json      Emit machine-readable JSON for `status` or `verify`
  --dry-run   Print the commands that `verify` would execute
  -h, --help  Show this help
EOF
}

lot_paths() {
  cat <<'EOF'
docs/plans/18_plan_enchainement_autonome_des_lots_utiles.md
docs/plans/18_todo_enchainement_autonome_des_lots_utiles.md
specs/03_plan.md
specs/04_tasks.md
specs/README.md
specs/mcp_tasks.md
specs/zeroclaw_dual_hw_todo.md
tools/ai/integrations/n8n/README.md
tools/ai/integrations/n8n/kill_life_smoke_workflow.json
tools/ai/zeroclaw_integrations_down.sh
tools/ai/zeroclaw_integrations_import_n8n.sh
tools/ai/zeroclaw_integrations_lot.sh
tools/ai/zeroclaw_integrations_status.sh
tools/ai/zeroclaw_integrations_up.sh
tools/cockpit/README.md
tools/cockpit/lot_chain.sh
tools/cockpit/run_next_lots_autonomously.sh
ai-agentic-embedded-base/specs/03_plan.md
ai-agentic-embedded-base/specs/04_tasks.md
ai-agentic-embedded-base/specs/README.md
ai-agentic-embedded-base/specs/mcp_tasks.md
ai-agentic-embedded-base/specs/zeroclaw_dual_hw_todo.md
EOF
}

status_text() {
  local -a paths
  mapfile -t paths < <(lot_paths)

  printf 'lot_id=zeroclaw-integrations-n8n\n'
  printf 'root=%s\n' "$ROOT_DIR"
  printf 'dirty_status:\n'
  git -C "$ROOT_DIR" status --short -- "${paths[@]}" || true
  printf '\ncanonical_commands:\n'
  printf -- '- bash tools/ai/zeroclaw_integrations_status.sh --json\n'
  printf -- '- bash tools/ai/zeroclaw_integrations_lot.sh verify\n'
  printf -- '- bash tools/run_autonomous_next_lots.sh run\n'
  printf -- '- bash tools/cockpit/lot_chain.sh all --yes\n'
}

status_json() {
  local -a paths
  local dirty_json
  mapfile -t paths < <(lot_paths)
  dirty_json="$(
    git -C "$ROOT_DIR" status --short -- "${paths[@]}" \
      | python3 -c 'import json,sys; print(json.dumps([line.rstrip() for line in sys.stdin if line.strip()]))'
  )"

  PATHS_JSON="$(printf '%s\n' "${paths[@]}" | python3 -c 'import json,sys; print(json.dumps([line.rstrip() for line in sys.stdin if line.strip()]))')" \
  DIRTY_JSON="${dirty_json}" \
  python3 - <<'PY'
import json
import os

print(json.dumps({
    "lot_id": "zeroclaw-integrations-n8n",
    "paths": json.loads(os.environ["PATHS_JSON"]),
    "dirty_status": json.loads(os.environ["DIRTY_JSON"]),
    "canonical_commands": [
        "bash tools/ai/zeroclaw_integrations_status.sh --json",
        "bash tools/ai/zeroclaw_integrations_lot.sh verify",
        "bash tools/run_autonomous_next_lots.sh run",
        "bash tools/cockpit/lot_chain.sh all --yes",
    ],
}, ensure_ascii=True))
PY
}

run_verify() {
  local -a syntax_cmd status_cmd import_cmd
  local syntax_ok=0
  local status_json_output=""
  local import_json_output=""
  local verify_output=""
  local verify_rc=0
  local status_rc=0
  local import_rc=0

  syntax_cmd=(
    bash -n
    "$ROOT_DIR/tools/ai/zeroclaw_integrations_up.sh"
    "$ROOT_DIR/tools/ai/zeroclaw_integrations_status.sh"
    "$ROOT_DIR/tools/ai/zeroclaw_integrations_import_n8n.sh"
    "$ROOT_DIR/tools/ai/zeroclaw_integrations_down.sh"
    "$ROOT_DIR/tools/ai/zeroclaw_integrations_lot.sh"
    "$ROOT_DIR/tools/cockpit/lot_chain.sh"
  )
  status_cmd=(bash "$ROOT_DIR/tools/ai/zeroclaw_integrations_up.sh" --json)
  import_cmd=(bash "$ROOT_DIR/tools/ai/zeroclaw_integrations_import_n8n.sh" --json)

  if [[ "$DRY_RUN" == "1" ]]; then
    printf '%s\n' "${syntax_cmd[*]}"
    printf '%s\n' "${status_cmd[*]}"
    printf '%s\n' "${import_cmd[*]}"
    return 0
  fi

  "${syntax_cmd[@]}"
  syntax_ok=1
  if ! status_json_output="$("${status_cmd[@]}" 2>&1)"; then
    status_rc=$?
  fi
  status_json_output="$(
    RAW_OUTPUT="${status_json_output}" STAGE_NAME="status" python3 - <<'PY'
import json
import os

raw = os.environ["RAW_OUTPUT"]
stage = os.environ["STAGE_NAME"]
try:
    payload = json.loads(raw)
except json.JSONDecodeError:
    payload = {
        "status": "blocked",
        "reason": raw.strip() or f"{stage} command failed",
        "stage": stage,
    }
print(json.dumps(payload, ensure_ascii=True))
PY
  )"

  if [[ "${status_rc}" -eq 0 ]]; then
    if ! import_json_output="$("${import_cmd[@]}" 2>&1)"; then
      import_rc=$?
    fi
  else
    import_rc=1
    import_json_output='{"workflow_id":"kill-life-n8n-smoke","import_action":"skipped","publish_action":"skipped","active":false,"reason":"status_failed"}'
  fi
  import_json_output="$(
    RAW_OUTPUT="${import_json_output}" STAGE_NAME="import" python3 - <<'PY'
import json
import os

raw = os.environ["RAW_OUTPUT"]
stage = os.environ["STAGE_NAME"]
try:
    payload = json.loads(raw)
except json.JSONDecodeError:
    payload = {
        "workflow_id": "kill-life-n8n-smoke",
        "import_action": "failed",
        "publish_action": "failed",
        "active": False,
        "reason": raw.strip() or f"{stage} command failed",
        "stage": stage,
    }
print(json.dumps(payload, ensure_ascii=True))
PY
  )"
  verify_output="$(
    STATUS_JSON="${status_json_output}" \
    IMPORT_JSON="${import_json_output}" \
    python3 - <<'PY'
import json
import os

status = json.loads(os.environ["STATUS_JSON"])
workflow = json.loads(os.environ["IMPORT_JSON"])
blockers = []
overall = "ready"

status_state = str(status.get("status", "")).strip().lower()
if status_state in {"blocked", "degraded"}:
    overall = "blocked"
    blockers.append(str(status.get("reason", status_state)))
else:
    if not status.get("container_running", False):
        overall = "blocked"
        blockers.append("n8n container not running")
    if not status.get("internal_http_ok", False):
        overall = "blocked"
        blockers.append("n8n internal health probe failed")
    if not status.get("host_http_ok", False):
        overall = "blocked"
        blockers.append("n8n host HTTP probe failed")

if not workflow.get("active", False):
    overall = "blocked"
    blockers.append("tracked smoke workflow is not active")

if workflow.get("reason"):
    overall = "blocked"
    blockers.append(str(workflow["reason"]))

payload = {
    "lot_id": "zeroclaw-integrations-n8n",
    "syntax_ok": True,
    "overall_status": overall,
    "blockers": list(dict.fromkeys(blockers)),
    "status": status,
    "import": workflow,
}
print(json.dumps(payload, ensure_ascii=True))
PY
  )"

  if [[ "${status_rc}" -ne 0 || "${import_rc}" -ne 0 ]]; then
    verify_rc=1
  elif ! python3 - <<'PY' "${verify_output}"
import json
import sys
payload = json.loads(sys.argv[1])
raise SystemExit(0 if payload.get("overall_status") == "ready" else 1)
PY
  then
    verify_rc=1
  fi

  if [[ "$OUTPUT_JSON" == "1" ]]; then
    printf '%s\n' "${verify_output}"
    return "${verify_rc}"
  fi

  printf 'syntax_ok=true\n'
  printf 'verify=%s\n' "${verify_output}"
  return "${verify_rc}"
}

if [[ $# -gt 0 ]]; then
  COMMAND="$1"
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      OUTPUT_JSON=1
      ;;
    --dry-run)
      DRY_RUN=1
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
  shift
done

case "$COMMAND" in
  status)
    if [[ "$OUTPUT_JSON" == "1" ]]; then
      status_json
    else
      status_text
    fi
    ;;
  paths)
    lot_paths
    ;;
  verify|run)
    run_verify
    ;;
  *)
    echo "Unknown command: $COMMAND" >&2
    usage >&2
    exit 2
    ;;
esac
