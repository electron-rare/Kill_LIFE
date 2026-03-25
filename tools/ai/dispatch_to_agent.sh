#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────
# dispatch_to_agent.sh — T-MA-034: Lot chain dispatch vers agents Mistral
#
# Takes a lot ID and dispatches to the appropriate Mascarade agent
# based on domain-to-agent mapping.
#
# Domain mapping:
#   kicad, pcb, cad, eda       -> Devstral (pcb-routing-kicad profile)
#   firmware, embedded, esp32   -> Devstral (coder profile)
#   spice, analog, simulation   -> Devstral (coder profile)
#   docs, readme, specs         -> Tower (writer profile)
#   ops, infra, deploy, docker  -> Sentinelle (ops profile)
#   finetune, dataset, training -> Forge (fine-tune profile)
#   review, audit, quality      -> Sentinelle (monitoring profile)
#
# Usage:
#   bash tools/ai/dispatch_to_agent.sh --lot T-MA-033 --domain docs
#   bash tools/ai/dispatch_to_agent.sh --lot T-RE-204 --domain firmware --prompt "Fix the SPI driver"
#   bash tools/ai/dispatch_to_agent.sh --lot T-MA-021 --domain finetune --dry-run
#   bash tools/ai/dispatch_to_agent.sh --list-agents
#
# Contract: cockpit-v1
# Owner: PM-Mesh
# Date: 2026-03-25
# ──────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts/ai/dispatch"
mkdir -p "${ARTIFACTS_DIR}"

# shellcheck source=/dev/null
[[ -f "${ROOT_DIR}/tools/cockpit/load_mistral_governance_env.sh" ]] && \
  source "${ROOT_DIR}/tools/cockpit/load_mistral_governance_env.sh"

STAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${ARTIFACTS_DIR}/dispatch_${STAMP}.json"

# Agent IDs (from Lot 23 Mistral AI Studio)
SENTINELLE_ID="${MISTRAL_AGENT_SENTINELLE_ID:-ag_019d124c302375a8bf06f9ff8a99fb5f}"
TOWER_ID="${MISTRAL_AGENT_TOWER_ID:-ag_019d124e760877359ad3ff5031179ebc}"
FORGE_ID="${MISTRAL_AGENT_FORGE_ID:-ag_019d1251023f73258b80ac73f90458f6}"
DEVSTRAL_ID="${MISTRAL_AGENT_DEVSTRAL_ID:-ag_019d125348eb77e880df33acbd395efa}"

MISTRAL_BASE="${MISTRAL_BASE:-https://api.mistral.ai/v1}"
API_KEY="${MISTRAL_GOVERNANCE_API_KEY:-${MISTRAL_API_KEY:-${MISTRAL_AGENTS_API_KEY:-}}}"

# Mascarade local endpoints (Tower Ollama)
MASCARADE_BASE="${MASCARADE_BASE:-http://192.168.0.120:8042}"
OLLAMA_HOST="${OLLAMA_HOST:-http://192.168.0.120:11434}"

LOT_ID=""
DOMAIN=""
PROMPT=""
DRY_RUN=0
USE_LOCAL=0
LOCAL_MODEL="devstral"
LIST_AGENTS=0
JSON_OUTPUT=0
VERBOSE=0
TIMEOUT=60

usage() {
  cat <<'EOF'
Usage: bash tools/ai/dispatch_to_agent.sh [options]

Options:
  --lot ID            Lot/task ID to dispatch (e.g. T-MA-033)
  --domain NAME       Domain hint: kicad, firmware, docs, ops, finetune, etc.
  --prompt TEXT        Custom prompt to send to the agent
  --local             Use local Ollama instead of Mistral API (zero cost)
  --local-model NAME  Local Ollama model (default: devstral)
  --dry-run           Show what would be dispatched without calling API
  --list-agents       List all agent mappings
  --json              Emit JSON output
  --timeout SEC       API timeout (default: 60)
  --verbose           Verbose output
  --help              Show this help

Examples:
  bash tools/ai/dispatch_to_agent.sh --lot T-MA-033 --domain docs
  bash tools/ai/dispatch_to_agent.sh --lot T-RE-204 --domain firmware --local
  bash tools/ai/dispatch_to_agent.sh --list-agents
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lot)          LOT_ID="${2:-}"; shift 2 ;;
    --domain)       DOMAIN="${2:-}"; shift 2 ;;
    --prompt)       PROMPT="${2:-}"; shift 2 ;;
    --local)        USE_LOCAL=1; shift ;;
    --local-model)  LOCAL_MODEL="${2:-devstral}"; shift 2 ;;
    --dry-run)      DRY_RUN=1; shift ;;
    --list-agents)  LIST_AGENTS=1; shift ;;
    --json)         JSON_OUTPUT=1; shift ;;
    --timeout)      TIMEOUT="${2:-60}"; shift 2 ;;
    --verbose)      VERBOSE=1; shift ;;
    --help|-h)      usage; exit 0 ;;
    *)              echo "Unknown: $1" >&2; usage >&2; exit 2 ;;
  esac
done

# ── Agent registry ─────────────────────────────────────────────────────

print_agent_map() {
  cat <<'EOF'
Agent Registry — Mascarade Mistral Agents (Lot 23)

Category: Sentinelle (Monitoring & Ops)
  Agent ID:  ag_019d124c302375a8bf06f9ff8a99fb5f
  Model:     mistral-medium-latest (temp 0.1)
  Domains:   ops, infra, deploy, docker, monitoring, review, audit, quality, health
  Profile:   Low temperature, structured diagnostics, JSON output preferred

Category: Tower (Knowledge & Content)
  Agent ID:  ag_019d124e760877359ad3ff5031179ebc
  Model:     magistral-medium-latest (temp 0.4)
  Domains:   docs, readme, specs, content, email, crm, training, research
  Profile:   Higher creativity, long-form text, templates, commercial content

Category: Forge (Fine-tune & Data)
  Agent ID:  ag_019d1251023f73258b80ac73f90458f6
  Model:     codestral-latest (temp 0.21)
  Domains:   finetune, dataset, training, evaluation, benchmark, data
  Profile:   Code-oriented, dataset validation, training pipeline support

Category: Devstral (Code & Engineering)
  Agent ID:  ag_019d125348eb77e880df33acbd395efa
  Model:     devstral-latest (temp 0.17)
  Domains:   kicad, pcb, cad, eda, firmware, embedded, esp32, stm32, spice, analog, code, dev
  Profile:   Low temperature, precise code generation, engineering focus
EOF
}

if [[ "${LIST_AGENTS}" -eq 1 ]]; then
  print_agent_map
  exit 0
fi

if [[ -z "${LOT_ID}" ]]; then
  echo "ERROR: --lot is required" >&2
  usage >&2
  exit 2
fi

# ── Domain-to-agent resolver ──────────────────────────────────────────

resolve_agent() {
  local domain="$1"
  domain="$(echo "${domain}" | tr '[:upper:]' '[:lower:]')"

  case "${domain}" in
    kicad|pcb|cad|eda|freecad)
      echo "devstral|${DEVSTRAL_ID}|pcb-routing-kicad"
      ;;
    firmware|embedded|esp32|stm32|platformio|iot)
      echo "devstral|${DEVSTRAL_ID}|coder-firmware"
      ;;
    spice|analog|simulation|power|dsp|emc)
      echo "devstral|${DEVSTRAL_ID}|coder-analog"
      ;;
    code|dev|refactor|debug|python|bash)
      echo "devstral|${DEVSTRAL_ID}|coder-general"
      ;;
    docs|readme|specs|content|wiki|markdown)
      echo "tower|${TOWER_ID}|writer"
      ;;
    email|crm|commercial|training|formation)
      echo "tower|${TOWER_ID}|commercial"
      ;;
    research|veille|analysis)
      echo "tower|${TOWER_ID}|researcher"
      ;;
    ops|infra|deploy|docker|monitoring|health|mesh)
      echo "sentinelle|${SENTINELLE_ID}|ops-monitoring"
      ;;
    review|audit|quality|security)
      echo "sentinelle|${SENTINELLE_ID}|quality-audit"
      ;;
    finetune|dataset|training-data|evaluation|benchmark|data)
      echo "forge|${FORGE_ID}|fine-tune-pipeline"
      ;;
    *)
      # Default: Devstral for unknown technical domains
      echo "devstral|${DEVSTRAL_ID}|general"
      ;;
  esac
}

# ── Build prompt ──────────────────────────────────────────────────────

build_dispatch_prompt() {
  local lot="$1"
  local domain="$2"
  local agent_name="$3"
  local profile="$4"
  local custom_prompt="$5"

  if [[ -n "${custom_prompt}" ]]; then
    echo "${custom_prompt}"
    return
  fi

  cat <<PROMPT
Tu es l'agent ${agent_name} de Mascarade, profil ${profile}.

Lot a traiter: ${lot}
Domaine: ${domain}

Contexte: Ce lot fait partie du plan 23 d'integration des agents Mistral dans l'ecosysteme Kill_LIFE / Mascarade.

Tache: Analyse le lot ${lot} dans le domaine ${domain} et produis:
1. Un diagnostic court (3 lignes max)
2. Les actions concretes a mener (liste numerotee)
3. Les risques ou blocages identifies
4. Le statut recommande (ready / blocked / needs-input)

Reponds de maniere structuree et operationnelle.
PROMPT
}

# ── Resolve and dispatch ──────────────────────────────────────────────

IFS='|' read -r AGENT_NAME AGENT_ID AGENT_PROFILE <<< "$(resolve_agent "${DOMAIN}")"

DISPATCH_PROMPT="$(build_dispatch_prompt "${LOT_ID}" "${DOMAIN}" "${AGENT_NAME}" "${AGENT_PROFILE}" "${PROMPT}")"

echo "[dispatch] Lot: ${LOT_ID}"
echo "[dispatch] Domain: ${DOMAIN}"
echo "[dispatch] Agent: ${AGENT_NAME} (${AGENT_PROFILE})"
echo "[dispatch] Agent ID: ${AGENT_ID}"

if [[ "${USE_LOCAL}" -eq 1 ]]; then
  echo "[dispatch] Mode: local Ollama (${LOCAL_MODEL} @ ${OLLAMA_HOST})"
else
  echo "[dispatch] Mode: Mistral API"
fi

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "[dispatch] DRY RUN — would send to ${AGENT_NAME}:"
  echo "---"
  echo "${DISPATCH_PROMPT}"
  echo "---"

  python3 -c "
import json
print(json.dumps({
    'contract': 'cockpit-v1',
    'tool': 'dispatch_to_agent',
    'action': 'dry-run',
    'lot': '${LOT_ID}',
    'domain': '${DOMAIN}',
    'agent': '${AGENT_NAME}',
    'agent_id': '${AGENT_ID}',
    'profile': '${AGENT_PROFILE}',
    'mode': 'local' if ${USE_LOCAL} else 'api',
    'status': 'dry-run'
}, indent=2))
" > "${LOG_FILE}"
  echo "[dispatch] Log: ${LOG_FILE}"
  exit 0
fi

# ── Call agent ────────────────────────────────────────────────────────

RESPONSE=""
ERROR=""
LATENCY_MS=0

if [[ "${USE_LOCAL}" -eq 1 ]]; then
  # Local Ollama call — zero API cost
  PAYLOAD="$(python3 -c "
import json
print(json.dumps({
    'model': '${LOCAL_MODEL}',
    'messages': [{'role': 'user', 'content': $(python3 -c "import json; print(json.dumps('${DISPATCH_PROMPT//\'/\\\'}'))")}],
    'stream': False,
    'options': {'num_predict': 1024}
}))
")"

  T0="$(python3 -c 'import time; print(time.time())')"
  RAW="$(curl -s --max-time "${TIMEOUT}" \
    -H "Content-Type: application/json" \
    -d "${PAYLOAD}" \
    "${OLLAMA_HOST}/api/chat" 2>/dev/null)" || RAW=""
  T1="$(python3 -c 'import time; print(time.time())')"
  LATENCY_MS="$(python3 -c "print(round((${T1} - ${T0}) * 1000, 1))")"

  if [[ -n "${RAW}" ]]; then
    RESPONSE="$(python3 -c "
import json, sys
try:
    data = json.loads('''${RAW}''')
    print(data.get('message', {}).get('content', ''))
except:
    print('')
" 2>/dev/null)" || RESPONSE=""
  fi

  if [[ -z "${RESPONSE}" ]]; then
    ERROR="Local Ollama call failed or returned empty"
  fi

else
  # Mistral API call (Beta Conversations)
  if [[ -z "${API_KEY}" ]]; then
    echo "ERROR: No Mistral API key found" >&2
    exit 1
  fi

  PAYLOAD="$(python3 -c "
import json
print(json.dumps({
    'agent_id': '${AGENT_ID}',
    'inputs': [{'role': 'user', 'content': $(python3 -c "import json; print(json.dumps('${DISPATCH_PROMPT//\'/\\\'}'))")}],
}))
")"

  T0="$(python3 -c 'import time; print(time.time())')"
  RAW="$(curl -s --max-time "${TIMEOUT}" \
    -H "Authorization: Bearer ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d "${PAYLOAD}" \
    "${MISTRAL_BASE}/conversations" 2>/dev/null)" || RAW=""
  T1="$(python3 -c 'import time; print(time.time())')"
  LATENCY_MS="$(python3 -c "print(round((${T1} - ${T0}) * 1000, 1))")"

  if [[ -n "${RAW}" ]]; then
    RESPONSE="$(python3 -c "
import json
try:
    data = json.loads('''${RAW}''')
    outputs = data.get('outputs', [])
    for o in outputs:
        if o.get('role') == 'assistant':
            c = o.get('content', '')
            if isinstance(c, str):
                print(c)
            elif isinstance(c, list):
                for item in c:
                    if isinstance(item, dict):
                        print(item.get('text', ''))
                    elif isinstance(item, str):
                        print(item)
            break
    else:
        choices = data.get('choices', [])
        if choices:
            print(choices[0].get('message', {}).get('content', ''))
except:
    print('')
" 2>/dev/null)" || RESPONSE=""
  fi

  if [[ -z "${RESPONSE}" ]]; then
    ERROR="Mistral API call failed or returned empty"
  fi
fi

# ── Output ────────────────────────────────────────────────────────────

if [[ -n "${ERROR}" ]]; then
  echo "[dispatch] ERROR: ${ERROR}"
else
  echo "[dispatch] Response (${LATENCY_MS}ms):"
  echo "---"
  echo "${RESPONSE}"
  echo "---"
fi

# ── Write log ─────────────────────────────────────────────────────────

python3 - "${LOT_ID}" "${DOMAIN}" "${AGENT_NAME}" "${AGENT_ID}" "${AGENT_PROFILE}" \
  "${LATENCY_MS}" "${ERROR}" "${LOG_FILE}" "${STAMP}" "${USE_LOCAL}" "${LOCAL_MODEL}" <<'PY'
import json
import sys

lot = sys.argv[1]
domain = sys.argv[2]
agent = sys.argv[3]
agent_id = sys.argv[4]
profile = sys.argv[5]
latency = float(sys.argv[6])
error = sys.argv[7] if sys.argv[7] else None
log_file = sys.argv[8]
stamp = sys.argv[9]
use_local = sys.argv[10] == "1"
local_model = sys.argv[11]

report = {
    "contract": "cockpit-v1",
    "tool": "dispatch_to_agent",
    "timestamp": stamp,
    "lot": lot,
    "domain": domain,
    "agent": agent,
    "agent_id": agent_id,
    "profile": profile,
    "mode": "local-ollama" if use_local else "mistral-api",
    "model": local_model if use_local else "agent-default",
    "latency_ms": latency,
    "status": "error" if error else "ok",
    "error": error,
}

with open(log_file, "w") as f:
    json.dump(report, f, indent=2, ensure_ascii=False)

print(f"[dispatch] Log written: {log_file}")
PY

echo "[dispatch] Done."
