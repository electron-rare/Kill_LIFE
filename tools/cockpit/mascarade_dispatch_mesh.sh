#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DISPATCH_FILE="${ROOT_DIR}/specs/contracts/mascarade_dispatch.mesh.json"
REGISTRY_FILE="${ROOT_DIR}/specs/contracts/machine_registry.mesh.json"
ACTION="summary"
PROFILE_ID=""
FAMILY_ID=""
JSON_OUTPUT=0

usage() {
  cat <<'EOF'
Usage: bash tools/cockpit/mascarade_dispatch_mesh.sh [options]

Options:
  --action summary|route   Default: summary
  --profile ID            Profile id to route
  --family ID             Explicit family override
  --dispatch-file FILE    Override dispatch contract
  --registry-file FILE    Override registry contract
  --json                  Emit JSON
  --help                  Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --action)
      ACTION="${2:-}"
      shift 2
      ;;
    --profile)
      PROFILE_ID="${2:-}"
      shift 2
      ;;
    --family)
      FAMILY_ID="${2:-}"
      shift 2
      ;;
    --dispatch-file)
      DISPATCH_FILE="${2:-}"
      shift 2
      ;;
    --registry-file)
      REGISTRY_FILE="${2:-}"
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
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "${ACTION}" != "summary" && "${ACTION}" != "route" ]]; then
  echo "Invalid --action: ${ACTION}" >&2
  exit 2
fi

python3 - "${DISPATCH_FILE}" "${REGISTRY_FILE}" "${ACTION}" "${PROFILE_ID}" "${FAMILY_ID}" "${JSON_OUTPUT}" <<'PY'
import json
import sys
from pathlib import Path

dispatch = json.loads(Path(sys.argv[1]).read_text())
registry = json.loads(Path(sys.argv[2]).read_text())
action = sys.argv[3]
profile = sys.argv[4]
family_override = sys.argv[5]
json_output = sys.argv[6] == "1"

def registry_targets(data):
    if isinstance(data.get("targets"), list):
        return data["targets"]
    if isinstance(data.get("targets"), dict):
        return [{"id": key, **value} for key, value in data["targets"].items()]
    if isinstance(data.get("machines"), list):
        return data["machines"]
    if isinstance(data.get("hosts"), list):
        return data["hosts"]
    return []

targets = registry_targets(registry)
target_map = {}
for item in targets:
    if not isinstance(item, dict):
        continue
    ident = item.get("id") or item.get("name")
    if ident:
        target_map[ident] = item

default_order = dispatch.get("default_host_order", [])
profile_overrides = dispatch.get("profile_overrides", {})
family_defaults = dispatch.get("family_defaults", {})
keyword_families = dispatch.get("keyword_families", {})

def infer_family(profile_name):
    profile_name = (profile_name or "").lower()
    for family_name, keywords in keyword_families.items():
        for keyword in keywords:
            if keyword in profile_name:
                return family_name
    return "interactive-safe"

def resolve_family(profile_name, family_name):
    if family_name:
        return family_name
    if profile_name in profile_overrides and profile_overrides[profile_name].get("family"):
        return profile_overrides[profile_name]["family"]
    return infer_family(profile_name)

family = resolve_family(profile, family_override)
override = profile_overrides.get(profile, {})
host_order = override.get("host_order") or family_defaults.get(family, {}).get("host_order") or default_order
host_order = [host for host in host_order if host in target_map] + [host for host in default_order if host not in host_order and host in target_map]

selected_target = host_order[0] if host_order else None
selected_meta = target_map.get(selected_target, {})

summary = {
    "status": "ok",
    "action": action,
    "profile": profile or None,
    "family": family,
    "dispatch_file": sys.argv[1],
    "registry_file": sys.argv[2],
    "default_host_order": default_order,
    "resolved_host_order": host_order,
    "selected_target": selected_target,
    "selected_host": selected_meta.get("host") or selected_meta.get("ssh_host"),
    "selected_priority": selected_meta.get("priority"),
    "selected_placement": selected_meta.get("placement"),
    "notes": family_defaults.get(family, {}).get("notes"),
}

if json_output:
    print(json.dumps(summary, indent=2, ensure_ascii=True))
else:
    print("Mascarade dispatch mesh")
    print(f"- action: {summary['action']}")
    print(f"- family: {summary['family']}")
    if summary["profile"]:
        print(f"- profile: {summary['profile']}")
    print(f"- route: {' -> '.join(summary['resolved_host_order'])}")
    print(f"- selected: {summary['selected_target']} ({summary['selected_host']})")
PY
