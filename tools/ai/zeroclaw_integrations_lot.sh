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
  status_json_output="$("${status_cmd[@]}")"
  import_json_output="$("${import_cmd[@]}")"

  if [[ "$OUTPUT_JSON" == "1" ]]; then
    SYNTAX_OK="$syntax_ok" \
    STATUS_JSON="${status_json_output}" \
    IMPORT_JSON="${import_json_output}" \
    python3 - <<'PY'
import json
import os

print(json.dumps({
    "lot_id": "zeroclaw-integrations-n8n",
    "syntax_ok": os.environ["SYNTAX_OK"] == "1",
    "status": json.loads(os.environ["STATUS_JSON"]),
    "import": json.loads(os.environ["IMPORT_JSON"]),
}, ensure_ascii=True))
PY
    return 0
  fi

  printf 'syntax_ok=true\n'
  printf 'status=%s\n' "${status_json_output}"
  printf 'import=%s\n' "${import_json_output}"
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
