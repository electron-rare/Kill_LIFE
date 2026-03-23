#!/bin/bash
# ============================================================================
# sentinelle_cron.sh — Cron daily health-check via Sentinelle agent
# Contrat: cockpit-v1
# Lot: 23 — T-MA-022
# Date: 2026-03-21
#
# Usage: Ajouter au crontab:
#   0 6 * * * /path/to/sentinelle_cron.sh >> /var/log/sentinelle-health.log 2>&1
#
# Ou via n8n: HTTP Request node → POST /webhook/sentinelle-health
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=/dev/null
source "${ROOT_DIR}/tools/cockpit/load_mistral_governance_env.sh"
LOG_DIR="${LOG_DIR:-/var/log/mascarade}"
REPORT_FILE="${LOG_DIR}/sentinelle-health-$(date +%Y%m%d).json"
MISTRAL_API_KEY="${MISTRAL_GOVERNANCE_API_KEY:-${MISTRAL_API_KEY:-}}"
SENTINELLE_AGENT_ID="${MISTRAL_AGENT_SENTINELLE_ID:-ag_019d124c302375a8bf06f9ff8a99fb5f}"
MISTRAL_BASE="https://api.mistral.ai/v1"
API_MODE="${MISTRAL_AGENTS_API_MODE:-beta}"
SENTINELLE_ANALYSIS_API_MODE="not-requested"

# Services à checker
MASCARADE_URL="${MASCARADE_URL:-https://mascarade.saillant.cc}"
LANGFUSE_URL="${LANGFUSE_URL:-https://langfuse.saillant.cc}"
GRAFANA_URL="${GRAFANA_URL:-https://grafana.saillant.cc}"

# Alerting
ALERT_WEBHOOK="${ALERT_WEBHOOK:-}"  # n8n ou Slack webhook
ALERT_EMAIL="${ALERT_EMAIL:-c.saillant@gmail.com}"

# --- Fonctions ---

mkdir -p "$LOG_DIR" 2>/dev/null || true

timestamp() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

check_url() {
  local name="$1" url="$2"
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 -L "$url" 2>/dev/null || echo "000")
  echo "{\"service\":\"$name\",\"url\":\"$url\",\"http_code\":$http_code,\"healthy\":$([ "$http_code" -ge 200 ] && [ "$http_code" -lt 500 ] && echo "true" || echo "false")}"
}

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
    "max_tokens": 500,
}))
PY
}

call_mistral_api() {
  local endpoint="$1"
  local payload="$2"
  local response
  response=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $MISTRAL_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    --max-time 60 \
    "${MISTRAL_BASE}/${endpoint}" 2>/dev/null) || true

  local http_code body
  http_code=$(printf '%s\n' "$response" | tail -1)
  body=$(printf '%s\n' "$response" | sed '$d')

  if [ "$http_code" = "200" ]; then
    printf '%s\n' "$body"
    return 0
  fi

  printf 'HTTP_ERROR:%s:%s\n' "$http_code" "$body"
  return 1
}

extract_agent_content() {
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
        print(data.get("error", "no response"))
except Exception:
    print("")
PY
}

# --- Health Checks ---

run_health_checks() {
  log "Starting daily health check..."

  local checks=()

  # Core services
  checks+=("$(check_url "mascarade" "$MASCARADE_URL/health")")
  checks+=("$(check_url "langfuse" "$LANGFUSE_URL")")
  checks+=("$(check_url "grafana" "$GRAFANA_URL")")
  checks+=("$(check_url "authentik" "https://auth.saillant.cc")")
  checks+=("$(check_url "outline" "https://wiki.saillant.cc")")
  checks+=("$(check_url "n8n" "https://n8n.saillant.cc")")
  checks+=("$(check_url "gitea" "https://git.saillant.cc")")
  checks+=("$(check_url "uptime-kuma" "https://uptime.saillant.cc")")
  checks+=("$(check_url "portainer" "https://portainer.saillant.cc")")

  # Count healthy
  local total=${#checks[@]}
  local healthy=0
  for c in "${checks[@]}"; do
    if echo "$c" | grep -q '"healthy":true'; then
      ((healthy++))
    fi
  done

  local status="healthy"
  [ "$healthy" -lt "$total" ] && status="degraded"
  [ "$healthy" -lt $((total / 2)) ] && status="critical"

  # Build JSON array
  local checks_json=""
  for i in "${!checks[@]}"; do
    [ "$i" -gt 0 ] && checks_json="${checks_json},"
    checks_json="${checks_json}${checks[$i]}"
  done

  # Generate report
  cat <<EOF > "$REPORT_FILE"
{
  "contract_version": "cockpit-v1",
  "component": "sentinelle-daily-health",
  "timestamp": "$(timestamp)",
  "status": "$status",
  "services_healthy": $healthy,
  "services_total": $total,
  "uptime_pct": $(( healthy * 100 / total )),
  "checks": [$checks_json]
}
EOF

  log "Health check complete: $healthy/$total healthy ($status)"
  echo "$status"
}

# --- Sentinelle Agent Analysis ---

ask_sentinelle() {
  local report="$1"

  if [ -z "$MISTRAL_API_KEY" ]; then
    log "MISTRAL_API_KEY not set — skipping Sentinelle analysis"
    return
  fi

  log "Sending report to Sentinelle agent for analysis..."

  local report_content
  report_content=$(cat "$report")
  local message
  message="Daily health check report for saillant.cc ecosystem.
Analyze this report and provide:
1. A brief status summary (1-2 lines)
2. Any issues that need immediate attention
3. Recommendations for the next 24h
4. Risk level: LOW/MEDIUM/HIGH/CRITICAL

Report:
${report_content}"

  local beta_payload
  local deprecated_payload
  local response=""
  local analysis=""
  local api_mode="failed"

  beta_payload="$(build_beta_payload "$SENTINELLE_AGENT_ID" "$message")"
  deprecated_payload="$(build_deprecated_payload "$message")"

  if [ "$API_MODE" = "beta" ]; then
    if response=$(call_mistral_api "conversations" "$beta_payload" 2>/dev/null); then
      api_mode="beta"
    else
      log "Beta API failed for Sentinelle — fallback deprecated"
    fi
  fi

  if [ "$api_mode" = "failed" ]; then
    if response=$(call_mistral_api "agents/${SENTINELLE_AGENT_ID}/completions" "$deprecated_payload" 2>/dev/null); then
      api_mode="deprecated"
    else
      response='{"error":"timeout"}'
    fi
  fi

  if [[ "$response" == HTTP_ERROR:* ]]; then
    analysis="$response"
  else
    analysis=$(extract_agent_content "$response")
  fi

  if [ -z "$analysis" ]; then
    analysis="no analysis"
  fi

  SENTINELLE_ANALYSIS_API_MODE="$api_mode"

  # Append analysis to report
  python3 - "$report" "$analysis" "$api_mode" <<'PY' 2>/dev/null || true
import json
import sys

report_path = sys.argv[1]
analysis = sys.argv[2]
api_mode = sys.argv[3]

with open(report_path, "r", encoding="utf-8") as handle:
    data = json.load(handle)

data["sentinelle_analysis"] = analysis
data["sentinelle_api_mode"] = api_mode

with open(report_path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
PY

  log "Sentinelle analysis appended to report"
}

# --- Alerting ---

send_alert() {
  local status="$1" report="$2"

  # Only alert on degraded or critical
  if [ "$status" = "healthy" ]; then
    return
  fi

  log "Sending alert for status: $status"

  # Webhook alert (n8n, Slack, etc.)
  if [ -n "$ALERT_WEBHOOK" ]; then
    curl -s -X POST "$ALERT_WEBHOOK" \
      -H "Content-Type: application/json" \
      -d @"$report" \
      --max-time 10 2>/dev/null || log "Webhook alert failed"
  fi

  # Console output for cron email
  echo ""
  echo "=== SENTINELLE ALERT: $status ==="
  echo "Date: $(date)"
  echo "Report: $report"
  cat "$report"
  echo "================================="
}

# --- Main ---

main() {
  local status
  status=$(run_health_checks)

  ask_sentinelle "$REPORT_FILE"

  send_alert "$status" "$REPORT_FILE"

  # Cleanup old reports (keep 30 days)
  find "$LOG_DIR" -name "sentinelle-health-*.json" -mtime +30 -delete 2>/dev/null || true

  log "Daily health check finished (status: $status, report: $REPORT_FILE)"

  # Output JSON for cockpit-v1
  cat <<EOF
{
  "contract_version": "cockpit-v1",
  "component": "sentinelle-cron",
  "action": "daily-health",
  "status": "$status",
  "timestamp": "$(timestamp)",
  "report_file": "$REPORT_FILE",
  "analysis_api_mode": "$SENTINELLE_ANALYSIS_API_MODE"
}
EOF
}

case "${1:-}" in
  --help|-h)
    echo "Usage: $0 [--help]"
    echo ""
    echo "Daily health check via Sentinelle agent."
    echo ""
    echo "Env vars:"
    echo "  MISTRAL_API_KEY          Mistral API key"
    echo "  MISTRAL_AGENT_SENTINELLE_ID  Sentinelle agent ID"
    echo "  LOG_DIR                  Log directory (default: /var/log/mascarade)"
    echo "  ALERT_WEBHOOK            Webhook URL for alerts"
    echo "  ALERT_EMAIL              Email for alerts"
    echo ""
    echo "Crontab example:"
    echo "  0 6 * * * $0 >> /var/log/sentinelle-cron.log 2>&1"
    ;;
  *)
    main
    ;;
esac
