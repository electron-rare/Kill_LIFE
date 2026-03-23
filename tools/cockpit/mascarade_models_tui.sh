#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
CATALOG_FILE="${ROOT_DIR}/specs/contracts/mascarade_model_profiles.kxkm_ai.json"
LOG_DIR="${ROOT_DIR}/artifacts/cockpit"
mkdir -p "${LOG_DIR}"

ACTION=""
PROFILE=""
JSON=0
DAYS=14
LOG_FILE="${LOG_DIR}/mascarade_models_tui_$(date '+%Y%m%d_%H%M%S').log"

usage() {
  cat <<'EOF'
Usage: bash tools/cockpit/mascarade_models_tui.sh [options]

Options:
  --action <summary|list|show|env|prompt|agents-json|clean-logs>  Action to run
  --profile <id>                                      Profile id for show/env/prompt
  --json                                              Emit JSON when available
  --days <N>                                          Retention for clean-logs (default: 14)
  -h, --help                                          Show this help
EOF
}

have_tty() {
  [[ -t 0 && -t 1 ]]
}

choose_action_interactive() {
  if command -v gum >/dev/null 2>&1 && have_tty; then
    gum choose summary list show env prompt agents-json clean-logs
    return 0
  fi
  return 1
}

choose_profile_interactive() {
  if command -v gum >/dev/null 2>&1 && have_tty; then
    python3 - "${CATALOG_FILE}" <<'PY' | gum choose
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
for item in data.get("profiles", []):
    if isinstance(item, dict):
        profile_id = str(item.get("id", "")).strip()
        if profile_id:
            print(profile_id)
PY
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

emit_catalog() {
  python3 - "${CATALOG_FILE}" "${ACTION}" "${PROFILE}" "${JSON}" <<'PY'
import json
import shlex
import sys
from pathlib import Path

catalog_path = Path(sys.argv[1])
action = sys.argv[2]
profile_id = sys.argv[3]
json_mode = sys.argv[4] == "1"

data = json.loads(catalog_path.read_text(encoding="utf-8"))
profiles = [item for item in data.get("profiles", []) if isinstance(item, dict)]
index = {str(item.get("id", "")).strip(): item for item in profiles}
target = index.get(profile_id, {})

def emit_json(payload: dict) -> None:
    print(json.dumps(payload, ensure_ascii=False))

if action == "summary":
    payload = {
        "status": "ok",
        "component": "mascarade_models_tui",
        "action": action,
        "catalog_file": str(catalog_path),
        "target_host": data.get("target_host", ""),
        "default_profile": data.get("default_profile", ""),
        "profile_count": len(profiles),
        "profiles": [str(item.get("id", "")).strip() for item in profiles],
    }
    if json_mode:
        emit_json(payload)
    else:
        print("# Mascarade model profiles\n")
        print(f"- catalog: {payload['catalog_file']}")
        print(f"- target_host: {payload['target_host']}")
        print(f"- default_profile: {payload['default_profile']}")
        print(f"- profile_count: {payload['profile_count']}")
        print(f"- profiles: {', '.join(payload['profiles'])}")
elif action == "list":
    payload = {
        "status": "ok",
        "component": "mascarade_models_tui",
        "action": action,
        "profiles": profiles,
    }
    if json_mode:
        emit_json(payload)
    else:
        print("# Profiles\n")
        for item in profiles:
            print(f"- {item.get('id', '')}: {item.get('label', '')} [{item.get('category', '')}]")
elif action == "show":
    if not target:
        raise SystemExit("profile not found")
    payload = {
        "status": "ok",
        "component": "mascarade_models_tui",
        "action": action,
        "profile": target,
    }
    if json_mode:
        emit_json(payload)
    else:
        print(json.dumps(target, indent=2, ensure_ascii=False))
elif action == "env":
    if not target:
        raise SystemExit("profile not found")
    provider_preference = ",".join(target.get("provider_preference", []))
    lines = [
        f'export MASCARADE_MODEL_CATALOG={shlex.quote(str(catalog_path))}',
        f'export MASCARADE_OPERATOR_PROFILE={shlex.quote(str(target.get("id", "")))}',
        f'export MASCARADE_OPERATOR_PROVIDER={shlex.quote(str(target.get("default_provider", "")))}',
        f'export MASCARADE_OPERATOR_MODEL={shlex.quote(str(target.get("default_model", "")))}',
        f'export MASCARADE_DEFAULT_MODEL={shlex.quote(str(target.get("default_model", "")))}',
        f'export MASCARADE_OPERATOR_PROVIDER_PREFERENCE={shlex.quote(provider_preference)}',
        f'export MASCARADE_OPERATOR_TIMEOUT={shlex.quote("45")}',
    ]
    payload = {
        "status": "ok",
        "component": "mascarade_models_tui",
        "action": action,
        "profile": str(target.get("id", "")),
        "exports": lines,
    }
    if json_mode:
        emit_json(payload)
    else:
        print("\n".join(lines))
elif action == "prompt":
  if not target:
    raise SystemExit("profile not found")
  payload = {
        "status": "ok",
        "component": "mascarade_models_tui",
        "action": action,
        "profile": str(target.get("id", "")),
        "prompt": str(target.get("prompt", "")),
    }
    if json_mode:
      emit_json(payload)
    else:
      print(payload["prompt"])
elif action == "agents-json":
    strategy_map = {
        "local-fast": "fastest",
        "fallback-safe": "cheapest",
    }
    agents = []
    for item in profiles:
        profile_id = str(item.get("id", "")).strip()
        label = str(item.get("label", "")).strip() or profile_id
        category = str(item.get("category", "")).strip()
        intended = item.get("intended_tasks")
        tasks = [entry for entry in intended if isinstance(entry, str) and entry.strip()] if isinstance(intended, list) else []
        summary = ", ".join(tasks[:3]) if tasks else category or "general assistance"
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
        "component": "mascarade_models_tui",
        "action": action,
        "target_host": data.get("target_host", ""),
        "agents": agents,
    }
    if json_mode:
        emit_json(payload)
    else:
        print(json.dumps(payload, indent=2, ensure_ascii=False))
else:
    raise SystemExit(f"unsupported action: {action}")
PY
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --action)
      ACTION="${2:-}"
      shift 2
      ;;
    --profile)
      PROFILE="${2:-}"
      shift 2
      ;;
    --json)
      JSON=1
      shift
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
  else
    ACTION="summary"
  fi
fi

if [[ "${ACTION}" == "show" || "${ACTION}" == "env" || "${ACTION}" == "prompt" ]] && [[ -z "${PROFILE}" ]]; then
  if PROFILE="$(choose_profile_interactive)"; then
    :
  else
    printf -- '--profile is required with action %s\n' "${ACTION}" >&2
    exit 2
  fi
fi

if ! [[ "${DAYS}" =~ ^[0-9]+$ ]]; then
  printf -- '--days requires an integer\n' >&2
  exit 2
fi

require_catalog
log_line "INFO" "action=${ACTION} profile=${PROFILE:-all}"

case "${ACTION}" in
  summary|list|show|env|prompt|agents-json)
    emit_catalog
    ;;
  clean-logs)
    find "${LOG_DIR}" -type f -name 'mascarade_models_tui_*.log' -mtime +"${DAYS}" -delete
    printf 'cleaned mascarade_models_tui logs older than %s days in %s\n' "${DAYS}" "${LOG_DIR}"
    ;;
  *)
    printf 'Unknown action: %s\n' "${ACTION}" >&2
    usage >&2
    exit 2
    ;;
esac
