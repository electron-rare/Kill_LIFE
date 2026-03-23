#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────
# infra_container_health.sh — Infrastructure Container Health Check & Fix
#
# Vérifie l'état de tous les containers Docker sur la VM photon-docker
# et propose des actions correctives pour les containers down.
#
# Usage:
#   bash infra_container_health.sh --action status
#   bash infra_container_health.sh --action fix --target metabase
#   bash infra_container_health.sh --action fix-all --yes
#   bash infra_container_health.sh --action web-check
#   bash infra_container_health.sh --json
#
# Contract: cockpit-v1
# Owner: Sentinelle + PM-Mesh
# Date: 2026-03-21
# ──────────────────────────────────────────────────────────────────────────

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts/infra_container_health"
mkdir -p "${ARTIFACTS_DIR}"

STAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${ARTIFACTS_DIR}/health_${STAMP}.log"

ACTION=""
TARGET=""
JSON_MODE=0
VERBOSE=0
YES=0

# VM Configuration
VM_HOST="${VM_HOST:-192.168.0.119}"
VM_USER="${VM_USER:-clement}"
SSH_OPTS="-o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes"

# Known services and their expected container names/web endpoints
declare -A SERVICE_URLS=(
  ["mascarade"]="https://mascarade.saillant.cc"
  ["langfuse"]="https://langfuse.saillant.cc"
  ["grafana"]="https://grafana.saillant.cc"
  ["authentik"]="https://auth.saillant.cc"
  ["outline"]="https://outline.saillant.cc"
  ["n8n"]="https://n8n.saillant.cc"
  ["gitea"]="https://gitea.saillant.cc"
  ["uptime-kuma"]="https://uptime.saillant.cc"
  ["portainer"]="https://portainer.saillant.cc"
  ["metabase"]="https://metabase.saillant.cc"
  ["listmonk"]="https://listmonk.saillant.cc"
  ["changedetection"]="https://changedetection.saillant.cc"
  ["bookmarks"]="https://bookmarks.saillant.cc"
  ["dify"]="https://dify.saillant.cc"
)

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
  cat <<'EOF'
Usage: infra_container_health.sh --action <status|fix|fix-all|web-check|docker-status|restart> [options]

Actions:
  status         Full health report (web + docker)
  web-check      Check web endpoints only (no SSH required)
  docker-status  Check Docker containers via SSH
  fix            Restart a specific container (requires --target)
  fix-all        Restart all down containers (requires --yes)
  restart        Restart a specific container (alias for fix)

Options:
  --action <name>   Action to run
  --target <name>   Container name for fix/restart
  --json            Emit JSON report
  --yes             Confirm destructive actions
  --verbose         Show detailed output
  --help            Show this help
EOF
}

log_info()  { printf "${CYAN}[INFO]${NC}  %s\n" "$*"; }
log_ok()    { printf "${GREEN}[ OK ]${NC}  %s\n" "$*"; }
log_warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
log_err()   { printf "${RED}[FAIL]${NC}  %s\n" "$*"; }

# ── Web Health Check ──────────────────────────────────────────────────────
check_web_endpoint() {
  local name="$1"
  local url="$2"
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 -L "${url}" 2>/dev/null) || http_code="000"

  local status="down"
  if [[ "${http_code}" =~ ^(200|301|302|303|307|401|403)$ ]]; then
    status="up"
  fi

  echo "${name}|${url}|${http_code}|${status}"
}

action_web_check() {
  log_info "Checking web endpoints..."
  local up=0 down=0 results=()

  for name in $(echo "${!SERVICE_URLS[@]}" | tr ' ' '\n' | sort); do
    local url="${SERVICE_URLS[$name]}"
    local result
    result=$(check_web_endpoint "${name}" "${url}")
    results+=("${result}")

    local http_code status
    http_code=$(echo "${result}" | cut -d'|' -f3)
    status=$(echo "${result}" | cut -d'|' -f4)

    if [[ "${status}" == "up" ]]; then
      log_ok "${name} — HTTP ${http_code} (${url})"
      ((up++))
    else
      log_err "${name} — HTTP ${http_code} (${url})"
      ((down++))
    fi
  done

  local total=$((up + down))
  echo ""
  printf "═══ Web Health: %d/%d up " "${up}" "${total}"
  if [[ "${down}" -gt 0 ]]; then
    printf "(${RED}%d down${NC})" "${down}"
  else
    printf "(${GREEN}all healthy${NC})"
  fi
  echo " ═══"

  if [[ "${JSON_MODE}" -eq 1 ]]; then
    python3 -c "
import json
results = []
for r in '''$(printf '%s\n' "${results[@]}")'''.strip().split('\n'):
    parts = r.split('|')
    if len(parts) == 4:
        results.append({'name': parts[0], 'url': parts[1], 'http_code': int(parts[2]) if parts[2].isdigit() else 0, 'status': parts[3]})
print(json.dumps({
    'contract': 'cockpit-v1',
    'tool': 'infra_container_health',
    'action': 'web-check',
    'timestamp': '${STAMP}',
    'total': ${total},
    'up': ${up},
    'down': ${down},
    'services': results
}, indent=2))
"
  fi
}

# ── Docker Status via SSH ─────────────────────────────────────────────────
action_docker_status() {
  log_info "Checking Docker containers on ${VM_HOST}..."

  local ssh_result
  if ! ssh_result=$(ssh ${SSH_OPTS} "${VM_USER}@${VM_HOST}" \
    "docker ps -a --format '{{.Names}}|{{.Status}}|{{.Image}}|{{.Ports}}'" 2>/dev/null); then
    log_err "SSH connection to ${VM_HOST} failed"
    return 1
  fi

  local running=0 stopped=0 total=0

  echo ""
  printf "%-30s %-15s %s\n" "CONTAINER" "STATE" "IMAGE"
  printf "%s\n" "$(printf '─%.0s' {1..80})"

  while IFS='|' read -r name status image ports; do
    [[ -z "${name}" ]] && continue
    ((total++))

    local state="stopped"
    if [[ "${status}" == *"Up"* ]]; then
      state="running"
      ((running++))
      printf "${GREEN}%-30s${NC} %-15s %s\n" "${name}" "${state}" "${image}"
    else
      ((stopped++))
      printf "${RED}%-30s${NC} %-15s %s\n" "${name}" "${state}" "${image}"
    fi
  done <<< "${ssh_result}"

  echo ""
  printf "═══ Docker: %d/%d running " "${running}" "${total}"
  if [[ "${stopped}" -gt 0 ]]; then
    printf "(${RED}%d stopped${NC})" "${stopped}"
  else
    printf "(${GREEN}all running${NC})"
  fi
  echo " ═══"
}

# ── Fix / Restart ─────────────────────────────────────────────────────────
action_fix() {
  if [[ -z "${TARGET}" ]]; then
    log_err "Missing --target <container_name>"
    return 1
  fi

  log_info "Attempting to restart container: ${TARGET}"

  # Try docker compose first, then docker restart
  local compose_result
  if ssh ${SSH_OPTS} "${VM_USER}@${VM_HOST}" \
    "cd /opt/docker && docker compose up -d ${TARGET}" 2>/dev/null; then
    log_ok "Container ${TARGET} restarted via docker compose"
  elif ssh ${SSH_OPTS} "${VM_USER}@${VM_HOST}" \
    "docker restart ${TARGET}" 2>/dev/null; then
    log_ok "Container ${TARGET} restarted via docker restart"
  else
    log_err "Failed to restart ${TARGET}"
    return 1
  fi

  # Verify
  sleep 3
  local status
  status=$(ssh ${SSH_OPTS} "${VM_USER}@${VM_HOST}" \
    "docker inspect -f '{{.State.Status}}' ${TARGET}" 2>/dev/null) || status="unknown"
  log_info "Post-restart status: ${status}"
}

action_fix_all() {
  if [[ "${YES}" -ne 1 ]]; then
    log_err "Requires --yes flag to restart all down containers"
    return 1
  fi

  log_info "Finding stopped containers..."
  local stopped
  stopped=$(ssh ${SSH_OPTS} "${VM_USER}@${VM_HOST}" \
    "docker ps -a --filter 'status=exited' --filter 'status=created' --format '{{.Names}}'" 2>/dev/null) || {
    log_err "SSH connection failed"
    return 1
  }

  if [[ -z "${stopped}" ]]; then
    log_ok "No stopped containers found"
    return 0
  fi

  local count=0
  while IFS= read -r name; do
    [[ -z "${name}" ]] && continue
    log_info "Restarting: ${name}"
    if ssh ${SSH_OPTS} "${VM_USER}@${VM_HOST}" "docker start ${name}" 2>/dev/null; then
      log_ok "Started: ${name}"
      ((count++))
    else
      log_err "Failed to start: ${name}"
    fi
  done <<< "${stopped}"

  log_info "Restarted ${count} containers"
}

# ── Full Status ───────────────────────────────────────────────────────────
action_status() {
  echo "╔══════════════════════════════════════════════════╗"
  echo "║     Infrastructure Health Report — ${STAMP}     ║"
  echo "╚══════════════════════════════════════════════════╝"
  echo ""

  action_web_check
  echo ""
  action_docker_status
}

# ── Main ──────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --action)  ACTION="${2:-}"; shift 2 ;;
    --target)  TARGET="${2:-}"; shift 2 ;;
    --json)    JSON_MODE=1; shift ;;
    --yes)     YES=1; shift ;;
    --verbose) VERBOSE=1; shift ;;
    --help)    usage; exit 0 ;;
    *)         printf 'Unknown: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -z "${ACTION}" ]] && { usage >&2; exit 2; }

exec > >(tee -a "${LOG_FILE}") 2>&1
printf '[infra-container-health] action=%s timestamp=%s\n' "${ACTION}" "${STAMP}"

case "${ACTION}" in
  status)        action_status ;;
  web-check)     action_web_check ;;
  docker-status) action_docker_status ;;
  fix|restart)   action_fix ;;
  fix-all)       action_fix_all ;;
  *)
    printf 'Unknown action: %s\n' "${ACTION}" >&2
    usage >&2
    exit 2
    ;;
esac
