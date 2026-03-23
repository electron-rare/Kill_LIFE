#!/bin/bash
# ============================================================================
# mistral_agents_tui.sh — TUI pour gérer les 4 agents Mistral
# Contrat: cockpit-v1
# Lot: 23 — Intégration Mistral Agents
# Date: 2026-03-21
# MAJ: 2026-03-22 — Migration Beta Conversations API (T-MA-037)
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MISTRAL_API_KEY="${MISTRAL_API_KEY:-}"
MISTRAL_BASE="https://api.mistral.ai/v1"

# API mode: beta (Conversations API) ou deprecated (agents/completions)
API_MODE="${MISTRAL_API_MODE:-beta}"

# Couleurs
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

# Agents avec IDs réels (console.mistral.ai)
AGENTS=(
  "ag_019d124c302375a8bf06f9ff8a99fb5f:Sentinelle:Ops/Monitoring:mistral-medium-latest:0.1"
  "ag_019d124e760877359ad3ff5031179ebc:Tower:Commercial/CRM:magistral-medium-latest:0.4"
  "ag_019d1251023f73258b80ac73f90458f6:Forge:Fine-tune Pipeline:codestral-latest:0.21"
  "ag_019d125348eb77e880df33acbd395efa:Devstral:Code/Dev Workflow:devstral-latest:0.17"
)

# --- Fonctions utilitaires ---
log_json() {
  local component="$1" action="$2" status="$3"
  shift 3
  local artifacts="${*:-}"
  cat <<EOF
{
  "contract_version": "cockpit-v1",
  "component": "$component",
  "action": "$action",
  "status": "$status",
  "api_mode": "$API_MODE",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "artifacts": [${artifacts}]
}
EOF
}

check_api_key() {
  if [ -z "$MISTRAL_API_KEY" ]; then
    echo -e "${RED}ERREUR: MISTRAL_API_KEY non définie${NC}" >&2
    echo "  export MISTRAL_API_KEY=your_key" >&2
    return 1
  fi
}

# --- API Abstraction Layer ---
# Appel agent via Beta Conversations API (préféré)
_call_beta() {
  local agent_id="$1" message="$2" timeout="${3:-30}"
  curl -s -X POST "${MISTRAL_BASE}/conversations" \
    -H "Authorization: Bearer $MISTRAL_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{
      \"agent_id\": \"${agent_id}\",
      \"inputs\": [{\"role\": \"user\", \"content\": ${message}}]
    }" \
    --max-time "$timeout" 2>/dev/null || echo '{"error":"timeout"}'
}

# Appel agent via deprecated agents/completions (fallback)
_call_deprecated() {
  local agent_id="$1" message="$2" timeout="${3:-30}"
  curl -s -X POST "${MISTRAL_BASE}/agents/${agent_id}/completions" \
    -H "Authorization: Bearer $MISTRAL_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"messages\":[{\"role\":\"user\",\"content\":${message}}]}" \
    --max-time "$timeout" 2>/dev/null || echo '{"error":"timeout"}'
}

# Appel unifié avec fallback automatique
call_agent() {
  local agent_id="$1" message="$2" timeout="${3:-30}"

  if [ "$API_MODE" = "beta" ]; then
    local response
    response=$(_call_beta "$agent_id" "$message" "$timeout")
    # Si erreur Beta, fallback vers deprecated
    if echo "$response" | grep -q '"error"' || echo "$response" | grep -q '"object":"error"'; then
      echo -e "  ${DIM}(beta → fallback deprecated)${NC}" >&2
      response=$(_call_deprecated "$agent_id" "$message" "$timeout")
    fi
    echo "$response"
  else
    _call_deprecated "$agent_id" "$message" "$timeout"
  fi
}

# Extraire le contenu de la réponse (compatible beta + deprecated)
extract_content() {
  python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    # Beta Conversations API format
    if 'outputs' in d:
        for out in d['outputs']:
            if out.get('role') == 'assistant':
                print(out.get('content', 'no content'))
                sys.exit(0)
    # Deprecated agents/completions format
    choices = d.get('choices', [])
    if choices:
        print(choices[0].get('message', {}).get('content', 'no content'))
        sys.exit(0)
    # Error
    print(d.get('message', d.get('error', 'no response')))
except Exception as e:
    print(f'parse error: {e}')
" 2>/dev/null || echo "parse error"
}

# --- Actions ---
action_status() {
  check_api_key || return 1
  echo -e "${BOLD}${CYAN}=== Mistral Agents Status ===${NC}"
  echo -e "  Date: $(date '+%Y-%m-%d %H:%M:%S')"
  echo -e "  API: ${BOLD}${API_MODE}${NC} (Conversations API)"
  echo ""

  local ok=0 fail=0 missing=0

  for entry in "${AGENTS[@]}"; do
    IFS=':' read -r id name role model temp <<< "$entry"

    # Ping rapide via une question minimale
    local response
    response=$(call_agent "$id" '"ping"' 10 2>/dev/null)

    if echo "$response" | grep -q '"error"'; then
      local err_msg
      err_msg=$(echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('message',d.get('error','unknown')))" 2>/dev/null || echo "unknown")
      if echo "$err_msg" | grep -qi "not found\|404"; then
        echo -e "  ${YELLOW}○${NC} ${BOLD}${name}${NC} [${model} t=${temp}] (${role}) — ${YELLOW}Not deployed${NC}"
        ((missing++))
      else
        echo -e "  ${RED}✗${NC} ${BOLD}${name}${NC} [${model} t=${temp}] (${role}) — ${RED}Error: ${err_msg}${NC}"
        ((fail++))
      fi
    else
      echo -e "  ${GREEN}●${NC} ${BOLD}${name}${NC} [${model} t=${temp}] (${role}) — ${GREEN}Active${NC}"
      ((ok++))
    fi
  done

  echo ""
  echo -e "  Active: ${GREEN}${ok}${NC} | Missing: ${YELLOW}${missing}${NC} | Error: ${RED}${fail}${NC}"
  echo ""

  log_json "mistral-agents" "status" "$([ "$fail" -eq 0 ] && echo "ok" || echo "degraded")"
}

action_deploy() {
  check_api_key || return 1
  local target="${1:-all}"
  echo -e "${BOLD}${CYAN}=== Deploy Mistral Agents ===${NC}"
  echo -e "  ${DIM}Note: Les agents sont créés via console.mistral.ai, pas via API.${NC}"
  echo -e "  ${DIM}IDs réels configurés dans ce script.${NC}"
  echo ""

  for entry in "${AGENTS[@]}"; do
    IFS=':' read -r id name role model temp <<< "$entry"

    if [ "$target" != "all" ] && [ "$target" != "$name" ]; then
      continue
    fi

    echo -e "  ${GREEN}●${NC} ${BOLD}${name}${NC} — ${id}"
    echo -e "    Model: ${model} | Temp: ${temp} | Role: ${role}"
  done

  echo ""
  echo -e "  ${YELLOW}→${NC} Pour modifier un agent, aller sur https://console.mistral.ai/build/agents"
  log_json "mistral-agents" "deploy" "info"
}

action_test() {
  check_api_key || return 1
  echo -e "${BOLD}${CYAN}=== Smoke Test Agents (${API_MODE}) ===${NC}"
  echo ""

  local pass=0 total=0

  for entry in "${AGENTS[@]}"; do
    IFS=':' read -r id name role model temp <<< "$entry"
    echo -ne "  ${YELLOW}→${NC} Testing ${BOLD}${name}${NC} [${model}]... "
    ((total++))

    local msg
    msg=$(python3 -c 'import json; print(json.dumps("Health check: respond OK + your role in 10 words max"))')

    local response
    response=$(call_agent "$id" "$msg" 30 2>/dev/null)

    if echo "$response" | grep -q '"error"'; then
      echo -e "${RED}FAIL${NC}"
      local err
      err=$(echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('message',d.get('error','?')))" 2>/dev/null || echo "?")
      echo -e "    ${DIM}${err}${NC}"
    else
      local reply
      reply=$(echo "$response" | extract_content | head -c 80)
      echo -e "${GREEN}OK${NC} → ${reply}"
      ((pass++))
    fi
  done

  echo ""
  echo -e "  Results: ${GREEN}${pass}/${total}${NC} passed"
  echo ""

  log_json "mistral-agents" "test" "$([ "$pass" -eq "$total" ] && echo "ok" || echo "degraded")"
}

action_chat() {
  check_api_key || return 1
  echo -e "${BOLD}${CYAN}=== Agent Chat (${API_MODE}) ===${NC}"
  echo ""

  echo "Agents disponibles:"
  local i=1
  for entry in "${AGENTS[@]}"; do
    IFS=':' read -r id name role model temp <<< "$entry"
    echo "  ${i}) ${name} (${role}) [${model}]"
    ((i++))
  done

  read -p "Choix (1-4): " choice
  local idx=$((choice - 1))
  if [ "$idx" -lt 0 ] || [ "$idx" -ge "${#AGENTS[@]}" ]; then
    echo -e "${RED}Choix invalide${NC}"
    return 1
  fi

  IFS=':' read -r id name role model temp <<< "${AGENTS[$idx]}"
  echo -e "Chat avec ${BOLD}${name}${NC} (${model}, API=${API_MODE}). Tapez 'quit' pour sortir."
  echo ""

  local conversation_id=""

  while true; do
    read -p "${name}> " user_input
    [ "$user_input" = "quit" ] && break

    local msg
    msg=$(echo "$user_input" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read().strip()))')

    local response
    response=$(call_agent "$id" "$msg" 60 2>/dev/null)

    # Capturer conversation_id pour les tours suivants (Beta API)
    if [ "$API_MODE" = "beta" ] && [ -z "$conversation_id" ]; then
      conversation_id=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('conversation_id',''))" 2>/dev/null || true)
    fi

    local reply
    reply=$(echo "$response" | extract_content)

    echo -e "${CYAN}${reply}${NC}"
    echo ""
  done
}

action_handoff() {
  check_api_key || return 1
  echo -e "${BOLD}${CYAN}=== Agent Handoff Test ===${NC}"
  echo ""

  # Sentinelle diagnostique → Devstral corrige
  local from_id from_name to_id to_name
  IFS=':' read -r from_id from_name _ _ _ <<< "${AGENTS[0]}"
  IFS=':' read -r to_id to_name _ _ _ <<< "${AGENTS[3]}"

  echo -e "  ${YELLOW}→${NC} Handoff: ${BOLD}${from_name}${NC} → ${BOLD}${to_name}${NC}"

  local msg1
  msg1=$(python3 -c 'import json; print(json.dumps("Diagnostic: le service mascarade retourne HTTP 503. Identifie la cause probable en 2 lignes."))')

  echo -ne "  ${from_name} analyse... "
  local resp1
  resp1=$(call_agent "$from_id" "$msg1" 30 2>/dev/null)
  local diag
  diag=$(echo "$resp1" | extract_content)
  echo -e "${GREEN}OK${NC}"
  echo -e "  ${DIM}${diag}${NC}"

  local msg2
  msg2=$(python3 -c "import json; print(json.dumps('Basé sur ce diagnostic: ' + '''$diag''' + ' — Propose un fix en 3 lignes de code.'))")

  echo -ne "  ${to_name} corrige... "
  local resp2
  resp2=$(call_agent "$to_id" "$msg2" 30 2>/dev/null)
  local fix
  fix=$(echo "$resp2" | extract_content)
  echo -e "${GREEN}OK${NC}"
  echo -e "  ${DIM}${fix}${NC}"

  echo ""
  log_json "mistral-agents" "handoff" "completed" "\"${from_name}→${to_name}\""
}

# --- Menu principal ---
show_menu() {
  echo -e "${BOLD}${CYAN}"
  echo "╔══════════════════════════════════════════╗"
  echo "║   Mistral Agents — Control Panel v2      ║"
  echo "║   Lot 23 · cockpit-v1 · Beta API         ║"
  echo "╠══════════════════════════════════════════╣"
  echo "║  1) Status   — État des 4 agents         ║"
  echo "║  2) Deploy   — Info agents déployés       ║"
  echo "║  3) Test     — Smoke test (${API_MODE})            ║"
  echo "║  4) Chat     — Conversation interactive   ║"
  echo "║  5) Handoff  — Test Sentinelle→Devstral   ║"
  echo "║  6) API Mode — Toggle beta/deprecated     ║"
  echo "║  q) Quit                                 ║"
  echo "╚══════════════════════════════════════════╝"
  echo -e "${NC}"
}

# --- Main ---
case "${1:-menu}" in
  --action)
    case "${2:-status}" in
      status)  action_status ;;
      deploy)  action_deploy "${3:-all}" ;;
      test)    action_test ;;
      chat)    action_chat ;;
      handoff) action_handoff ;;
      *)       echo "Actions: status|deploy|test|chat|handoff" ;;
    esac
    ;;
  --json)
    action_status 2>/dev/null | grep -A 999 '{' | head -n -0
    ;;
  --api-mode)
    API_MODE="${2:-beta}"
    echo "API mode: $API_MODE"
    ;;
  --help|-h)
    echo "Usage: $0 [--action status|deploy|test|chat|handoff] [--json] [--api-mode beta|deprecated] [--help]"
    echo ""
    echo "  --action status    Check all 4 Mistral agents"
    echo "  --action deploy    Show deployed agents info"
    echo "  --action test      Run smoke tests"
    echo "  --action chat      Interactive chat with an agent"
    echo "  --action handoff   Test Sentinelle→Devstral handoff"
    echo "  --json             Output cockpit-v1 JSON only"
    echo "  --api-mode MODE    Set API mode: beta (default) or deprecated"
    echo ""
    echo "Environment:"
    echo "  MISTRAL_API_KEY       Required. Mistral API key."
    echo "  MISTRAL_API_MODE      API mode: beta (default) or deprecated."
    ;;
  *)
    show_menu
    read -p "Choix: " choice
    case "$choice" in
      1) action_status ;;
      2) action_deploy ;;
      3) action_test ;;
      4) action_chat ;;
      5) action_handoff ;;
      6) if [ "$API_MODE" = "beta" ]; then API_MODE="deprecated"; else API_MODE="beta"; fi
         echo -e "API mode: ${BOLD}${API_MODE}${NC}"
         ;;
      q|Q) exit 0 ;;
      *) echo "Choix invalide" ;;
    esac
    ;;
esac
