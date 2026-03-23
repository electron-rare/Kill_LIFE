#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────
# e2e_agents_test.sh — Tests E2E Mistral Agents (Lot 23 T-MA-025)
#
# Scénarios:
#   1. Sentinelle health-check → diagnostic
#   2. Devstral code review → fix suggestion
#   3. Handoff Sentinelle → Devstral (détection anomalie → correction auto)
#   4. Tower email generation → validation template
#   5. Forge dataset validation → score
#
# Usage:
#   bash e2e_agents_test.sh --action all
#   bash e2e_agents_test.sh --action sentinelle
#   bash e2e_agents_test.sh --action handoff
#   bash e2e_agents_test.sh --json
#
# Contract: cockpit-v1
# Owner: QA + PM-Mesh
# Date: 2026-03-21
# ──────────────────────────────────────────────────────────────────────────

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts/e2e_agents_test"
mkdir -p "${ARTIFACTS_DIR}"

# shellcheck source=/dev/null
source "${ROOT_DIR}/tools/cockpit/load_mistral_governance_env.sh"

STAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${ARTIFACTS_DIR}/e2e_${STAMP}.log"

ACTION=""
JSON_MODE=0
VERBOSE=0
TIMEOUT=30

MISTRAL_BASE="${MISTRAL_BASE:-https://api.mistral.ai/v1}"
API_KEY="${MISTRAL_GOVERNANCE_API_KEY:-${MISTRAL_API_KEY:-${MISTRAL_AGENTS_API_KEY:-}}}"

# Agent IDs (from lot 23)
SENTINELLE_ID="${MISTRAL_AGENT_SENTINELLE_ID:-ag_019d124c302375a8bf06f9ff8a99fb5f}"
TOWER_ID="${MISTRAL_AGENT_TOWER_ID:-ag_019d124e760877359ad3ff5031179ebc}"
FORGE_ID="${MISTRAL_AGENT_FORGE_ID:-ag_019d1251023f73258b80ac73f90458f6}"
DEVSTRAL_ID="${MISTRAL_AGENT_DEVSTRAL_ID:-ag_019d125348eb77e880df33acbd395efa}"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0

usage() {
  cat <<'EOF'
Usage: e2e_agents_test.sh --action <all|sentinelle|tower|forge|devstral|handoff> [options]

Options:
  --action <name>       Test suite to run (default: all)
  --api-mode <mode>     API mode: beta (conversations) or deprecated (agents/completions)
  --json                Emit JSON report
  --timeout <sec>       API timeout in seconds (default: 30)
  --verbose             Show full API responses
  --help                Show this help
EOF
}

log_info()  { printf "${CYAN}[INFO]${NC}  %s\n" "$*"; }
log_warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
log_pass()  { printf "${GREEN}[PASS]${NC}  %s\n" "$*"; ((PASS++)); }
log_fail()  { printf "${RED}[FAIL]${NC}  %s\n" "$*"; ((FAIL++)); }
log_skip()  { printf "${YELLOW}[SKIP]${NC}  %s\n" "$*"; ((SKIP++)); }

check_api_key() {
  if [[ -z "${API_KEY}" ]]; then
    log_fail "MISTRAL_API_KEY ou MISTRAL_AGENTS_API_KEY non défini"
    return 1
  fi
  return 0
}

# API Mode: "beta" (conversations/completions) or "deprecated" (agents/completions)
API_MODE="${API_MODE:-beta}"

# ── Agent Chat Helper ─────────────────────────────────────────────────────
build_beta_payload() {
  local agent_id="$1"
  local message="$2"
  python3 - "$agent_id" "$message" <<'PY'
import json
import sys

agent_id = sys.argv[1]
message = sys.argv[2]
print(json.dumps({
    "agent_id": agent_id,
    "inputs": [{"role": "user", "content": message}],
}))
PY
}

build_deprecated_payload() {
  local message="$1"
  python3 - "$message" <<'PY'
import json
import sys

message = sys.argv[1]
print(json.dumps({
    "messages": [{"role": "user", "content": message}],
}))
PY
}

_call_api() {
  local endpoint="$1"
  local payload="$2"
  local label="${3:-agent}"

  local response
  response=$(curl -s -w "\n%{http_code}" \
    --max-time "${TIMEOUT}" \
    -H "Authorization: Bearer ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d "${payload}" \
    "${MISTRAL_BASE}/${endpoint}" 2>/dev/null) || true

  local http_code
  http_code=$(echo "${response}" | tail -1)
  local body
  body=$(echo "${response}" | sed '$d')

  if [[ "${VERBOSE}" -eq 1 ]]; then
    printf "[%s] HTTP %s -> %s\n%s\n" "${label}" "${http_code}" "${endpoint}" "${body}" >&2
  fi

  if [[ "${http_code}" == "200" ]]; then
    echo "${body}"
    return 0
  else
    echo "HTTP_ERROR:${http_code}:${body}"
    return 1
  fi
}

call_agent() {
  local agent_id="$1"
  local message="$2"
  local label="${3:-agent}"
  local beta_payload
  local deprecated_payload
  local result=""

  beta_payload="$(build_beta_payload "${agent_id}" "${message}")"
  deprecated_payload="$(build_deprecated_payload "${message}")"

  # Try Beta Conversations API first
  if [[ "${API_MODE}" == "beta" ]]; then
    if result=$(_call_api "conversations" "${beta_payload}" "${label}" 2>/dev/null); then
      printf "${CYAN}[INFO]${NC}  %s\n" "  -> Beta API (/conversations)" >&2
      echo "${result}"
      return 0
    fi
    printf "${YELLOW}[WARN]${NC}  %s\n" "  -> Beta API failed, fallback deprecated" >&2
  fi

  # Deprecated API (fallback or explicit mode)
  if result=$(_call_api "agents/${agent_id}/completions" "${deprecated_payload}" "${label}" 2>/dev/null); then
    printf "${CYAN}[INFO]${NC}  %s\n" "  -> Deprecated API (/agents/${agent_id}/completions)" >&2
    echo "${result}"
    return 0
  fi

  echo "${result}"
  return 1
}

extract_content() {
  local response="$1"
  python3 - "$response" <<'PY' 2>/dev/null || echo ""
import json
import sys

raw = sys.argv[1]

def render_content(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        chunks = []
        for item in content:
            if isinstance(item, str):
                if item:
                    chunks.append(item)
                continue
            if not isinstance(item, dict):
                continue
            text = item.get("text")
            if isinstance(text, str) and text:
                chunks.append(text)
        return "\n".join(chunks)
    return ""

try:
    data = json.loads(raw)
    outputs = data.get("outputs", [])
    for out in outputs:
        if out.get("role") == "assistant":
            print(render_content(out.get("content", "")))
            raise SystemExit(0)
    choices = data.get("choices", [])
    if choices:
        print(render_content(choices[0].get("message", {}).get("content", "")))
    else:
        print("")
except Exception:
    print("")
PY
}

# ── Test Suites ───────────────────────────────────────────────────────────

test_sentinelle() {
  log_info "=== Test Suite: Sentinelle (Ops Monitoring) ==="

  # T1: Health check prompt
  log_info "T1: Sentinelle health diagnostic prompt"
  local resp
  if resp=$(call_agent "${SENTINELLE_ID}" \
    "Effectue un diagnostic rapide de l'état du système. Vérifie: CPU, RAM, services critiques. Réponds en JSON structuré." \
    "sentinelle-health" 2>/dev/null); then
    local content
    content=$(extract_content "${resp}")
    if [[ -n "${content}" && "${#content}" -gt 20 ]]; then
      log_pass "T1: Sentinelle a répondu (${#content} chars)"
    else
      log_fail "T1: Réponse Sentinelle vide ou trop courte"
    fi
  else
    log_fail "T1: Appel Sentinelle échoué (${resp})"
  fi

  # T2: Anomaly detection prompt
  log_info "T2: Sentinelle anomaly detection"
  if resp=$(call_agent "${SENTINELLE_ID}" \
    "Analyse ce log d'erreur et identifie la cause probable: 'ERROR 2026-03-21 05:32:12 mascarade.router: Provider timeout after 30s on mistral-large. Retry 3/3 failed. Circuit breaker OPEN.' Propose un fix." \
    "sentinelle-anomaly" 2>/dev/null); then
    local content
    content=$(extract_content "${resp}")
    if [[ -n "${content}" && "${#content}" -gt 50 ]]; then
      log_pass "T2: Sentinelle anomaly analysis OK (${#content} chars)"
    else
      log_fail "T2: Réponse anomaly insuffisante"
    fi
  else
    log_fail "T2: Appel Sentinelle anomaly échoué"
  fi
}

test_tower() {
  log_info "=== Test Suite: Tower (Commercial/CRM) ==="

  # T3: Email generation
  log_info "T3: Tower email generation"
  local resp
  if resp=$(call_agent "${TOWER_ID}" \
    "Génère un email de premier contact pour un prospect ingénieur en électronique qui a téléchargé notre guide KiCad. Nom: Jean Dupont, Entreprise: TechnoBoard SAS. Ton professionnel mais chaleureux." \
    "tower-email" 2>/dev/null); then
    local content
    content=$(extract_content "${resp}")
    if [[ -n "${content}" && "${content}" == *"@"* || "${content}" == *"Dupont"* || "${content}" == *"KiCad"* ]]; then
      log_pass "T3: Tower email généré avec contexte (${#content} chars)"
    elif [[ -n "${content}" && "${#content}" -gt 50 ]]; then
      log_pass "T3: Tower email généré (${#content} chars, contexte partiel)"
    else
      log_fail "T3: Tower email insuffisant"
    fi
  else
    log_fail "T3: Appel Tower échoué"
  fi
}

test_forge() {
  log_info "=== Test Suite: Forge (Fine-tune Pipeline) ==="

  # T4: Dataset quality evaluation
  log_info "T4: Forge dataset quality assessment"
  local resp
  if resp=$(call_agent "${FORGE_ID}" \
    "Évalue la qualité de ce dataset JSONL pour fine-tune Mistral. Stats: 5700 exemples, 12 duplicates, format ChatML, avg 450 tokens, domaine KiCad EDA. Score /10 et recommandations." \
    "forge-quality" 2>/dev/null); then
    local content
    content=$(extract_content "${resp}")
    if [[ -n "${content}" && "${#content}" -gt 30 ]]; then
      log_pass "T4: Forge dataset assessment OK (${#content} chars)"
    else
      log_fail "T4: Forge assessment insuffisant"
    fi
  else
    log_fail "T4: Appel Forge échoué"
  fi
}

test_devstral() {
  log_info "=== Test Suite: Devstral (Code/Dev Workflow) ==="

  # T5: Code review
  log_info "T5: Devstral code review"
  local resp
  if resp=$(call_agent "${DEVSTRAL_ID}" \
    "Review ce code Python et suggère des améliorations:
\`\`\`python
def process_data(data):
    result = []
    for item in data:
        if item['status'] == 'active':
            result.append({'id': item['id'], 'name': item['name'].upper()})
    return result
\`\`\`
Focus: performance, robustesse, type hints." \
    "devstral-review" 2>/dev/null); then
    local content
    content=$(extract_content "${resp}")
    if [[ -n "${content}" && "${#content}" -gt 50 ]]; then
      log_pass "T5: Devstral code review OK (${#content} chars)"
    else
      log_fail "T5: Devstral review insuffisant"
    fi
  else
    log_fail "T5: Appel Devstral échoué"
  fi
}

test_handoff() {
  log_info "=== Test Suite: Handoff Sentinelle → Devstral ==="

  # T6: Sentinelle détecte anomalie → Devstral génère fix
  log_info "T6: Phase 1 — Sentinelle détecte anomalie"
  local sentinelle_resp
  if sentinelle_resp=$(call_agent "${SENTINELLE_ID}" \
    "Analyse cette erreur et formule un diagnostic précis en une phrase pour transmission à l'agent de code: 'TypeError: NoneType has no attribute split in router/providers/mistral_agents_api.py line 142. Le champ agent_id peut être None quand l'env var est absente.'" \
    "handoff-sentinelle" 2>/dev/null); then
    local diagnosis
    diagnosis=$(extract_content "${sentinelle_resp}")
    if [[ -n "${diagnosis}" && "${#diagnosis}" -gt 20 ]]; then
      log_pass "T6.1: Sentinelle diagnostic OK"

      # Phase 2: Devstral reçoit le diagnostic et génère un fix
      log_info "T6: Phase 2 — Devstral génère fix basé sur diagnostic"
      local devstral_resp
      if devstral_resp=$(call_agent "${DEVSTRAL_ID}" \
        "Un agent de monitoring a détecté ce problème: ${diagnosis}. Génère un patch Python minimal pour corriger le bug (ajout d'une validation None-check avant l'appel .split())." \
        "handoff-devstral" 2>/dev/null); then
        local fix
        fix=$(extract_content "${devstral_resp}")
        if [[ -n "${fix}" && "${#fix}" -gt 30 ]]; then
          log_pass "T6.2: Devstral fix généré — Handoff complet ✓"
        else
          log_fail "T6.2: Devstral fix insuffisant"
        fi
      else
        log_fail "T6.2: Appel Devstral handoff échoué"
      fi
    else
      log_fail "T6.1: Sentinelle diagnostic vide"
    fi
  else
    log_fail "T6.1: Appel Sentinelle handoff échoué"
  fi
}

# ── Rapport ───────────────────────────────────────────────────────────────
emit_report() {
  local total=$((PASS + FAIL + SKIP))
  if [[ "${JSON_MODE}" -eq 1 ]]; then
    python3 -c "
import json
print(json.dumps({
    'contract': 'cockpit-v1',
    'tool': 'e2e_agents_test',
    'timestamp': '${STAMP}',
    'action': '${ACTION}',
    'results': {
        'total': ${total},
        'pass': ${PASS},
        'fail': ${FAIL},
        'skip': ${SKIP},
        'success_rate': round(${PASS} / max(${total}, 1) * 100, 1)
    },
    'agents_tested': {
        'sentinelle': '${SENTINELLE_ID}',
        'tower': '${TOWER_ID}',
        'forge': '${FORGE_ID}',
        'devstral': '${DEVSTRAL_ID}'
    },
    'api_mode': '${API_MODE}',
    'log_file': '${LOG_FILE}'
}, indent=2))
"
  else
    echo ""
    echo "══════════════════════════════════════════════"
    printf "  E2E Agents Test Report — %s\n" "${STAMP}"
    echo "══════════════════════════════════════════════"
    printf "  API Mode: %s\n" "${API_MODE}"
    printf "  Total: %d | ${GREEN}Pass: %d${NC} | ${RED}Fail: %d${NC} | ${YELLOW}Skip: %d${NC}\n" \
      "${total}" "${PASS}" "${FAIL}" "${SKIP}"
    printf "  Success rate: %.1f%%\n" "$(python3 -c "print(${PASS}/max(${total},1)*100)")"
    echo "  Log: ${LOG_FILE}"
    echo "══════════════════════════════════════════════"
  fi
}

# ── Main ──────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --action)    ACTION="${2:-}"; shift 2 ;;
    --api-mode)  API_MODE="${2:-beta}"; shift 2 ;;
    --json)      JSON_MODE=1; shift ;;
    --timeout)   TIMEOUT="${2:-30}"; shift 2 ;;
    --verbose)   VERBOSE=1; shift ;;
    --help)      usage; exit 0 ;;
    *)           printf 'Unknown: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "${ACTION}" ]]; then
  ACTION="all"
fi

exec > >(tee -a "${LOG_FILE}") 2>&1
printf '[e2e-agents-test] action=%s timestamp=%s\n' "${ACTION}" "${STAMP}"

if ! check_api_key; then
  emit_report
  exit 1
fi

case "${ACTION}" in
  all)
    test_sentinelle
    test_tower
    test_forge
    test_devstral
    test_handoff
    ;;
  sentinelle)  test_sentinelle ;;
  tower)       test_tower ;;
  forge)       test_forge ;;
  devstral)    test_devstral ;;
  handoff)     test_handoff ;;
  *)
    printf 'Unknown action: %s\n' "${ACTION}" >&2
    usage >&2
    exit 2
    ;;
esac

emit_report

# Exit code basé sur le résultat
if [[ "${FAIL}" -gt 0 ]]; then
  exit 1
fi
exit 0
