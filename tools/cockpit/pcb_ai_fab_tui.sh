#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REGISTRY_PATH="${ROOT_DIR}/specs/contracts/pcb_ai_fab_registry.json"
ACTION="summary"
OUTPUT_JSON=0

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--action summary|tools|gaps|lots|pipeline|readiness] [--json]
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --action)
      ACTION="${2:-}"
      shift 2
      ;;
    --json)
      OUTPUT_JSON=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

python3 - "$REGISTRY_PATH" "$ACTION" "$OUTPUT_JSON" <<'PY'
import json
import pathlib
import sys

registry_path = pathlib.Path(sys.argv[1])
action = sys.argv[2]
as_json = sys.argv[3] == "1"

data = json.loads(registry_path.read_text(encoding="utf-8"))
tools = data.get("tools", [])

if action == "summary":
    payload = {
        "status": "ok",
        "scope": data.get("scope"),
        "tool_count": len(tools),
        "tool_ids": [tool["id"] for tool in tools],
        "gaps": data.get("gaps", []),
        "recommended_lots": data.get("recommended_lots", []),
    }
elif action == "tools":
    payload = {
        "status": "ok",
        "tools": [
            {
                "id": tool["id"],
                "name": tool["name"],
                "status": tool["status"],
                "owner_agent": tool["owner_agent"],
                "sub_agent": tool["sub_agent"],
                "fit_with_kill_life": tool.get("fit_with_kill_life", []),
            }
            for tool in tools
        ],
    }
elif action == "gaps":
    payload = {
        "status": "ok",
        "gaps": data.get("gaps", []),
    }
elif action == "lots":
    payload = {
        "status": "ok",
        "recommended_lots": data.get("recommended_lots", []),
    }
elif action in {"pipeline", "readiness"}:
    payload = {
        "status": "ok",
        "pipeline": [
            "T-HP-013: hypnoled bom analysis",
            "T-RE-297: fab package contract",
            "T-HP-035 / T-RE-298: kicad-happy parity",
            "T-RE-296 / T-HP-033: quilter canary",
            "T-HP-034: pcbdesigner evaluation",
            "T-MS-002/003 + T-MA-016/017/021: mistral vm lots"
        ],
        "current_priority": "fab-package-first",
        "blocking_facts": [
            "eda providers and agent from plan 26 are not implemented in active Mascarade repo",
            "Hypnoled assets referenced by TODO 25 are not present in the current checkout"
        ]
    }
else:
    print(f"Unknown action: {action}", file=sys.stderr)
    sys.exit(1)

if as_json:
    print(json.dumps(payload, ensure_ascii=True, indent=2))
    sys.exit(0)

if action == "summary":
    print("PCB AI / FAB stack")
    print(f"- scope: {payload['scope']}")
    print(f"- tools: {payload['tool_count']}")
    print("- ids: " + ", ".join(payload["tool_ids"]))
    print("- gaps:")
    for gap in payload["gaps"]:
        print(f"  - {gap}")
    print("- lots:")
    for lot in payload["recommended_lots"]:
        print(f"  - {lot['id']} [{lot['status']}] {lot['title']}")
elif action == "tools":
    print("PCB AI tools")
    for tool in payload["tools"]:
        print(f"- {tool['id']}: {tool['name']} [{tool['status']}] owner={tool['owner_agent']}/{tool['sub_agent']}")
        for fit in tool["fit_with_kill_life"]:
            print(f"    - {fit}")
elif action == "gaps":
    print("PCB AI gaps")
    for gap in payload["gaps"]:
        print(f"- {gap}")
elif action == "lots":
    print("PCB AI lots")
    for lot in payload["recommended_lots"]:
        print(f"- {lot['id']} [{lot['status']}] {lot['title']}")
elif action in {"pipeline", "readiness"}:
    print("PCB AI pipeline")
    print(f"- priority: {payload['current_priority']}")
    print("- order:")
    for item in payload["pipeline"]:
        print(f"  - {item}")
    print("- blockers:")
    for item in payload["blocking_facts"]:
        print(f"  - {item}")
PY
