#!/bin/bash
# ============================================================================
# integration_health_tui.sh — Health check complet de l'écosystème saillant.cc
# Contrat: cockpit-v1
# Lot: 23 — Intégration Mistral Agents
# Date: 2026-03-21
# ============================================================================

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

VM_HOST="${VM_HOST:-192.168.0.119}"
VM_USER="${VM_USER:-clement}"
TIMEOUT=5

# --- Services catalogue ---
declare -A SERVICES=(
  ["Authentik SSO"]="https://auth.saillant.cc"
  ["Mascarade API"]="https://mascarade.saillant.cc/health"
  ["Langfuse"]="https://langfuse.saillant.cc"
  ["Grafana"]="https://grafana.saillant.cc"
  ["Prometheus"]="https://prometheus.saillant.cc"
  ["Outline Wiki"]="https://wiki.saillant.cc"
  ["n8n Workflows"]="https://n8n.saillant.cc"
  ["Excalidraw"]="https://draw.saillant.cc"
  ["Dify AI"]="https://dify.saillant.cc"
  ["Gitea"]="https://git.saillant.cc"
  ["Portainer"]="https://portainer.saillant.cc"
  ["Uptime Kuma"]="https://uptime.saillant.cc"
  ["Homepage"]="https://home.saillant.cc"
  ["Audiobookshelf"]="https://audio.saillant.cc"
  ["Immich"]="https://photos.saillant.cc"
  ["Vaultwarden"]="https://vault.saillant.cc"
  ["Paperless"]="https://docs.saillant.cc"
  ["Metabase"]="https://metabase.saillant.cc"
  ["Listmonk"]="https://listmonk.saillant.cc"
  ["Changedetection"]="https://changes.saillant.cc"
  ["Bookmarks"]="https://bookmarks.saillant.cc"
)

# --- Fonctions ---
check_service() {
  local name="$1" url="$2"
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" \
    -L "$url" 2>/dev/null || echo "000")

  case "$http_code" in
    200|301|302|303|307|308)
      echo -e "  ${GREEN}●${NC} ${name}: ${GREEN}OK${NC} (${http_code})"
      return 0
      ;;
    401|403)
      echo -e "  ${GREEN}●${NC} ${name}: ${GREEN}AUTH-OK${NC} (${http_code} — SSO protégé)"
      return 0
      ;;
    502|503|504)
      echo -e "  ${RED}✗${NC} ${name}: ${RED}DOWN${NC} (${http_code})"
      return 1
      ;;
    000)
      echo -e "  ${RED}✗${NC} ${name}: ${RED}TIMEOUT${NC}"
      return 1
      ;;
    *)
      echo -e "  ${YELLOW}?${NC} ${name}: ${YELLOW}HTTP ${http_code}${NC}"
      return 1
      ;;
  esac
}

check_docker_containers() {
  echo -e "${BOLD}[Docker Containers — ${VM_HOST}]${NC}"

  local output
  output=$(ssh -o ConnectTimeout="$TIMEOUT" -o BatchMode=yes "${VM_USER}@${VM_HOST}" \
    "docker ps -a --format '{{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null" 2>/dev/null) || {
    echo -e "  ${RED}✗ SSH connection failed to ${VM_HOST}${NC}"
    return 1
  }

  local running=0 stopped=0 total=0

  while IFS=$'\t' read -r name status ports; do
    ((total++))
    if echo "$status" | grep -q "^Up"; then
      ((running++))
    else
      ((stopped++))
      echo -e "  ${RED}✗${NC} ${name}: ${RED}${status}${NC}"
    fi
  done <<< "$output"

  echo -e "  ${GREEN}●${NC} Running: ${GREEN}${running}${NC}/${total} | Stopped: ${RED}${stopped}${NC}"
  return 0
}

check_mistral_agents() {
  local api_key="${MISTRAL_API_KEY:-}"
  echo -e "${BOLD}[Mistral Agents]${NC}"

  if [ -z "$api_key" ]; then
    echo -e "  ${YELLOW}○${NC} MISTRAL_API_KEY not set — skip"
    return 0
  fi

  local agents=("sentinelle-ops-v1" "tower-commercial-v1" "forge-finetune-v1" "devstral-code-v1")
  local names=("Sentinelle" "Tower" "Forge" "Devstral")

  for i in "${!agents[@]}"; do
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" \
      -H "Authorization: Bearer $api_key" \
      "https://api.mistral.ai/v1/agents/${agents[$i]}" 2>/dev/null || echo "000")

    case "$http_code" in
      200) echo -e "  ${GREEN}●${NC} ${names[$i]}: ${GREEN}Active${NC}" ;;
      404) echo -e "  ${YELLOW}○${NC} ${names[$i]}: ${YELLOW}Not deployed${NC}" ;;
      *)   echo -e "  ${RED}✗${NC} ${names[$i]}: ${RED}Error (${http_code})${NC}" ;;
    esac
  done
}

# --- Action principale ---
action_full_health() {
  local ok=0 fail=0

  echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}${CYAN}║   Écosystème saillant.cc — Health Check      ║${NC}"
  echo -e "${BOLD}${CYAN}║   $(date '+%Y-%m-%d %H:%M:%S')                        ║${NC}"
  echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════╝${NC}"
  echo ""

  echo -e "${BOLD}[Web Services]${NC}"
  for name in $(echo "${!SERVICES[@]}" | tr ' ' '\n' | sort); do
    if check_service "$name" "${SERVICES[$name]}"; then
      ((ok++))
    else
      ((fail++))
    fi
  done
  echo ""

  check_docker_containers
  echo ""

  check_mistral_agents
  echo ""

  echo -e "${BOLD}[Résumé]${NC}"
  local total=$((ok + fail))
  local pct=0
  [ "$total" -gt 0 ] && pct=$((ok * 100 / total))

  if [ "$fail" -eq 0 ]; then
    echo -e "  ${GREEN}✓ ALL HEALTHY${NC} — ${ok}/${total} services OK (${pct}%)"
  elif [ "$fail" -le 3 ]; then
    echo -e "  ${YELLOW}⚠ DEGRADED${NC} — ${ok}/${total} services OK (${pct}%) | ${fail} down"
  else
    echo -e "  ${RED}✗ CRITICAL${NC} — ${ok}/${total} services OK (${pct}%) | ${fail} down"
  fi
  echo ""

  # JSON cockpit-v1 output
  cat <<EOF
{
  "contract_version": "cockpit-v1",
  "component": "ecosystem-health",
  "action": "full-check",
  "status": "$([ "$fail" -eq 0 ] && echo "healthy" || ([ "$fail" -le 3 ] && echo "degraded" || echo "critical"))",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "services_ok": $ok,
  "services_fail": $fail,
  "services_total": $total,
  "uptime_pct": $pct
}
EOF
}

# --- Main ---
case "${1:-}" in
  --json)
    action_full_health 2>/dev/null | grep -A 999 '{'
    ;;
  --help|-h)
    echo "Usage: $0 [--json] [--help]"
    echo ""
    echo "  (default)   Full health check with colored output"
    echo "  --json      Output cockpit-v1 JSON only"
    ;;
  *)
    action_full_health
    ;;
esac
