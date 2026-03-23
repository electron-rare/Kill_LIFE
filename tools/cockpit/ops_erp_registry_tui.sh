#!/usr/bin/env bash
set -euo pipefail

# ops_erp_registry_tui.sh
# Read the ERP / L'electronrare Ops registry for Kill_LIFE.
# Contract: cockpit-v1
# Date: 2026-03-22

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REGISTRY_FILE="${REGISTRY_FILE:-${ROOT_DIR}/specs/contracts/ops_kill_life_erp_registry.json}"
ACTION="summary"
JSON_MODE=0

usage() {
  cat <<'EOF'
Usage: ops_erp_registry_tui.sh [--action summary|machines|modules|secrets] [--json]

Actions:
  summary   Show top-level ERP bridge summary
  machines  Show canonical machine table
  modules   Show module-to-layer ownership table
  secrets   Show secret scopes and consumers

Options:
  --json    Emit cockpit-v1 JSON
  --help    Show this help
EOF
}

emit_view() {
  local view="$1"
  python3 - "$REGISTRY_FILE" "$view" "$JSON_MODE" <<'PY'
import json
import sys
from pathlib import Path

registry_path = Path(sys.argv[1])
view = sys.argv[2]
json_mode = sys.argv[3] == "1"

data = json.loads(registry_path.read_text(encoding="utf-8"))

payload = {
    "contract_version": "cockpit-v1",
    "component": "ops-erp-registry",
    "action": view,
    "status": "ok",
    "registry_file": str(registry_path),
    "source_contract": data.get("contract_version"),
}

if view == "summary":
    payload["ops_surface"] = data.get("ops_surface")
    payload["layers"] = data.get("layers")
    payload["machines_total"] = len(data.get("machines", []))
    payload["modules_total"] = len(data.get("modules", []))
    payload["secret_scopes_total"] = len(data.get("secret_scopes", []))
elif view == "machines":
    payload["machines"] = data.get("machines", [])
elif view == "modules":
    payload["modules"] = data.get("modules", [])
elif view == "secrets":
    payload["secret_scopes"] = data.get("secret_scopes", [])
else:
    raise SystemExit(f"unknown action: {view}")

if json_mode:
    print(json.dumps(payload, indent=2))
    raise SystemExit(0)

if view == "summary":
    print("ERP / L'electronrare Ops Registry")
    print(f"registry: {registry_path}")
    print(f"ops surface: {data['ops_surface']['url']}")
    print(f"layers: {len(data.get('layers', []))}")
    print(f"machines: {len(data.get('machines', []))}")
    print(f"modules: {len(data.get('modules', []))}")
    print(f"secret scopes: {len(data.get('secret_scopes', []))}")
elif view == "machines":
    print("Machines")
    for machine in data.get("machines", []):
        print(
            f"- {machine['label']}: {machine['host']} | root={machine['canonical_root']} | "
            f"role={machine['role']} | priority={machine['priority_order']} | "
            f"load={machine['load_policy']} | owner={machine['owner_agent']}"
        )
elif view == "modules":
    print("Modules")
    for module in data.get("modules", []):
        print(
            f"- {module['path']} | layer={module['layer']} | "
            f"owner={module['owner_agent']} | purpose={module['purpose']}"
        )
elif view == "secrets":
    print("Secret scopes")
    for secret in data.get("secret_scopes", []):
        print(
            f"- {secret['name']} | env={secret['env_var']} | "
            f"owner={secret['owner_agent']} | consumer={secret['consumer_scope']}"
        )
PY
}

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
  summary|machines|modules|secrets)
    emit_view "$ACTION"
    ;;
  *)
    printf 'Unknown action: %s\n' "$ACTION" >&2
    usage >&2
    exit 2
    ;;
esac
