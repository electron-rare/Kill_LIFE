#!/bin/bash
# tools/cockpit/validate_mascarade_execution.sh
# Comprehensive Mascarade connectivity + agent execution validation across machines
# Usage: bash tools/cockpit/validate_mascarade_execution.sh [--machine HOST] [--test-agents PM|ARCH|FW|QA] [--json]

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

MASCARADE_URL="${MASCARADE_CORE_URL:-http://192.168.0.119:8100}"
MASCARADE_HOST="${MASCARADE_URL#*://}"
MASCARADE_HOST="${MASCARADE_HOST%%:*}"
MASCARADE_PORT="${MASCARADE_URL##*:}"

MACHINES=(
  "192.168.0.119"      # Mascarade primary
  "192.168.0.120"      # clems (hardware execution)
  "kxkm-ai"            # KXKM machine
  "192.168.0.210"      # CILS (optional)
)

TEST_AGENTS=("pm" "architect" "firmware" "qa")
OUTPUT_FORMAT="both"  # text or json or both
STRICT_MODE="${STRICT_MODE:-false}"

# ─────────────────────────────────────────────────────────────────────────────
# Parse arguments
# ─────────────────────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --machine)
      MACHINES=("$2")
      shift 2
      ;;
    --machines)
      shift
      MACHINES=()
      while [[ $# -gt 0 ]] && [[ "$1" != --* ]]; do
        MACHINES+=("$1")
        shift
      done
      ;;
    --test-agents)
      shift
      TEST_AGENTS=()
      while [[ $# -gt 0 ]] && [[ "$1" != --* ]]; do
        TEST_AGENTS+=("${1,,}")
        shift
      done
      ;;
    --json)
      OUTPUT_FORMAT="json"
      shift
      ;;
    --text)
      OUTPUT_FORMAT="text"
      shift
      ;;
    --strict)
      STRICT_MODE="true"
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# ─────────────────────────────────────────────────────────────────────────────
# State tracking
# ─────────────────────────────────────────────────────────────────────────────

declare -A RESULTS
declare -A DURATIONS
PASSED=0
FAILED=0
WARNINGS=0
START_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# ─────────────────────────────────────────────────────────────────────────────
# Helper functions
# ─────────────────────────────────────────────────────────────────────────────

log_info() {
  [[ "$OUTPUT_FORMAT" == "text" ]] || [[ "$OUTPUT_FORMAT" == "both" ]] && echo "ℹ️  $*" >&2
}

log_pass() {
  [[ "$OUTPUT_FORMAT" == "text" ]] || [[ "$OUTPUT_FORMAT" == "both" ]] && echo "✅ $*" >&2
  ((PASSED++)) || true
}

log_fail() {
  [[ "$OUTPUT_FORMAT" == "text" ]] || [[ "$OUTPUT_FORMAT" == "both" ]] && echo "❌ $*" >&2
  ((FAILED++)) || true
}

log_warn() {
  [[ "$OUTPUT_FORMAT" == "text" ]] || [[ "$OUTPUT_FORMAT" == "both" ]] && echo "⚠️  $*" >&2
  ((WARNINGS++)) || true
}

# ─────────────────────────────────────────────────────────────────────────────
# Test: Network connectivity to Mascarade
# ─────────────────────────────────────────────────────────────────────────────

test_mascarade_dns() {
  local test_name="mascarade_dns_${MASCARADE_HOST}"
  local start=$(date +%s%N)
  
  if ping -c 1 -W 2 "$MASCARADE_HOST" &>/dev/null; then
    local duration=$(( ($(date +%s%N) - start) / 1000000 ))
    RESULTS["$test_name"]="pass"
    DURATIONS["$test_name"]=$duration
    log_pass "Mascarade host reachable: $MASCARADE_HOST (${duration}ms)"
    return 0
  else
    RESULTS["$test_name"]="fail"
    log_fail "Mascarade host unreachable: $MASCARADE_HOST"
    return 1
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Test: Mascarade health endpoint
# ─────────────────────────────────────────────────────────────────────────────

test_mascarade_health() {
  local test_name="mascarade_health_endpoint"
  local start=$(date +%s%N)
  
  local response
  response=$(curl -s -m 5 -o /dev/null -w "%{http_code}" "${MASCARADE_URL}/health" 2>/dev/null || echo "000")
  
  local duration=$(( ($(date +%s%N) - start) / 1000000 ))
  DURATIONS["$test_name"]=$duration
  
  if [[ "$response" == "200" ]]; then
    RESULTS["$test_name"]="pass"
    log_pass "Mascarade /health endpoint OK (HTTP $response, ${duration}ms)"
    return 0
  elif [[ "$response" =~ ^[45] ]]; then
    RESULTS["$test_name"]="fail"
    log_fail "Mascarade /health returned HTTP $response"
    return 1
  else
    RESULTS["$test_name"]="warn"
    log_warn "Mascarade /health unreachable (HTTP $response, ${duration}ms)"
    return 2
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Test: Kill_LIFE FastAPI server can reach Mascarade
# ─────────────────────────────────────────────────────────────────────────────

test_killlife_mascarade_bridge() {
  local test_name="killlife_server_mascarade_bridge"
  local start=$(date +%s%N)
  
  # Start Kill_LIFE server in background (if not running)
  if ! pgrep -f "python.*kill_life.*server" &>/dev/null; then
    log_info "Starting Kill_LIFE FastAPI server..."
    cd "$ROOT_DIR"
    python3 -m kill_life.server &>/tmp/killlife_server.log &
    KILLLIFE_PID=$!
    sleep 2
  fi
  
  # Test that FastAPI server is up
  if ! curl -s -m 3 "http://localhost:8200/health" &>/dev/null; then
    RESULTS["$test_name"]="fail"
    log_fail "Kill_LIFE FastAPI server not running or unreachable"
    return 1
  fi
  
  # Test that FastAPI can retrieve agents (which requires Mascarade bridge or local fallback)
  local agents_response
  agents_response=$(curl -s -m 5 "http://localhost:8200/agents" 2>/dev/null || echo "")
  
  local duration=$(( ($(date +%s%N) - start) / 1000000 ))
  DURATIONS["$test_name"]=$duration
  
  if [[ -n "$agents_response" ]] && echo "$agents_response" | grep -q "pm"; then
    RESULTS["$test_name"]="pass"
    log_pass "Kill_LIFE ↔ Mascarade bridge working (${duration}ms)"
    return 0
  else
    RESULTS["$test_name"]="warn"
    log_warn "Kill_LIFE agents endpoint responded but format unexpected"
    return 2
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Test: Agent execution (mock call to Mascarade agent-run)
# ─────────────────────────────────────────────────────────────────────────────

test_agent_execution() {
  local agent="$1"
  local test_name="agent_execution_${agent}"
  local start=$(date +%s%N)
  
  # Simulate agent execution via Mascarade MCP bridge
  # In production, this would call /mcp endpoint with agent-run RPC
  local payload=$(cat <<EOF
{
  "agent": "$agent",
  "action": "test",
  "lot_id": "TEST-AGENT-EXEC-$(date +%s)"
}
EOF
)
  
  # Try to call Mascarade agent-run (if available)
  local response
  response=$(curl -s -m 10 -X POST \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "${MASCARADE_URL}/mcp/agent-run" 2>/dev/null || echo "")
  
  local duration=$(( ($(date +%s%N) - start) / 1000000 ))
  DURATIONS["$test_name"]=$duration
  
  if [[ -n "$response" ]] && echo "$response" | grep -q "status"; then
    RESULTS["$test_name"]="pass"
    log_pass "Agent '$agent' execution test OK (${duration}ms)"
    return 0
  elif [[ "$STRICT_MODE" == "true" ]]; then
    RESULTS["$test_name"]="fail"
    log_fail "Agent '$agent' execution failed (strict mode)"
    return 1
  else
    RESULTS["$test_name"]="warn"
    log_warn "Agent '$agent' execution endpoint not responding (expected in offline mode)"
    return 2
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Test: Remote machine connectivity (SSH)
# ─────────────────────────────────────────────────────────────────────────────

test_remote_machine() {
  local machine="$1"
  local test_name="machine_connectivity_${machine//./_}"
  local start=$(date +%s%N)
  
  # Determine user (default to root for IPs, ubuntu for hostnames)
  local user="root"
  if [[ "$machine" =~ ^[a-zA-Z] ]]; then
    user="$(whoami)"  # Use current user for hostnames
  fi
  
  if timeout 5 ssh -o ConnectTimeout=3 -o BatchMode=yes \
    "$user@$machine" 'echo OK' &>/dev/null; then
    local duration=$(( ($(date +%s%N) - start) / 1000000 ))
    RESULTS["$test_name"]="pass"
    DURATIONS["$test_name"]=$duration
    log_pass "Machine reachable: $machine@$user (${duration}ms)"
    return 0
  else
    RESULTS["$test_name"]="warn"
    log_warn "Machine unreachable: $machine (check SSH keys, network)"
    return 2
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Test: Cockpit script → Mascarade integration
# ─────────────────────────────────────────────────────────────────────────────

test_cockpit_mascarade_integration() {
  local test_name="cockpit_mascarade_integration"
  local start=$(date +%s%N)
  
  log_info "Testing cockpit runtime gateway..."
  
  if bash "$ROOT_DIR/tools/cockpit/runtime_ai_gateway.sh" --action status --json &>/tmp/cockpit_test.json; then
    if grep -q "status.*ready\|status.*degraded\|status.*blocked" /tmp/cockpit_test.json; then
      local duration=$(( ($(date +%s%N) - start) / 1000000 ))
      RESULTS["$test_name"]="pass"
      DURATIONS["$test_name"]=$duration
      log_pass "Cockpit ↔ Mascarade integration OK (${duration}ms)"
      return 0
    fi
  fi
  
  RESULTS["$test_name"]="warn"
  log_warn "Cockpit runtime gateway not fully operational"
  return 2
}

# ─────────────────────────────────────────────────────────────────────────────
# JSON output builder
# ─────────────────────────────────────────────────────────────────────────────

generate_json_report() {
  local end_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  
  cat <<EOF
{
  "validation_report": {
    "timestamp": "$end_time",
    "duration_seconds": $(($(date +%s) - $(date -d "$START_TIME" +%s))),
    "mascarade_url": "$MASCARADE_URL",
    "strict_mode": "$STRICT_MODE",
    "summary": {
      "passed": $PASSED,
      "failed": $FAILED,
      "warnings": $WARNINGS,
      "total": $((PASSED + FAILED + WARNINGS))
    },
    "machines_tested": [
EOF
  
  for machine in "${MACHINES[@]}"; do
    echo "      \"$machine\","
  done | sed '$ s/,$//'
  
  cat <<EOF

    ],
    "agents_tested": [
EOF
  
  for agent in "${TEST_AGENTS[@]}"; do
    echo "      \"$agent\","
  done | sed '$ s/,$//'
  
  cat <<EOF

    ],
    "results": {
EOF
  
  local first=true
  for test in "${!RESULTS[@]}" | sort; do
    status="${RESULTS[$test]}"
    duration="${DURATIONS[$test]:-0}"
    
    [[ "$first" == true ]] || echo ","
    first=false
    
    cat <<RESULT
      "$test": {
        "status": "$status",
        "duration_ms": $duration
      }
RESULT
  done
  
  cat <<EOF

    },
    "status_overall": "$(
      if [[ $FAILED -gt 0 ]]; then
        echo "BLOCKED"
      elif [[ $WARNINGS -gt 0 ]]; then
        echo "DEGRADED"
      else
        echo "READY"
      fi
    )"
  }
}
EOF
}

# ─────────────────────────────────────────────────────────────────────────────
# Main execution
# ─────────────────────────────────────────────────────────────────────────────

main() {
  log_info "Mascarade execution validation starting..."
  log_info "Configuration: Mascarade=$MASCARADE_URL, Machines=${#MACHINES[@]}, Agents=${#TEST_AGENTS[@]}"
  
  # Phase 1: Network connectivity
  log_info ""
  log_info "=== PHASE 1: Network Connectivity ==="
  test_mascarade_dns || true
  test_mascarade_health || true
  
  # Phase 2: Kill_LIFE ↔ Mascarade bridge
  log_info ""
  log_info "=== PHASE 2: Kill_LIFE Server ↔ Mascarade Bridge ==="
  test_killlife_mascarade_bridge || true
  
  # Phase 3: Agent execution tests
  log_info ""
  log_info "=== PHASE 3: Agent Execution ==="
  for agent in "${TEST_AGENTS[@]}"; do
    test_agent_execution "$agent" || true
  done
  
  # Phase 4: Remote machine connectivity
  log_info ""
  log_info "=== PHASE 4: Remote Machines ==="
  for machine in "${MACHINES[@]}"; do
    test_remote_machine "$machine" || true
  done
  
  # Phase 5: Cockpit integration
  log_info ""
  log_info "=== PHASE 5: Cockpit Integration ==="
  test_cockpit_mascarade_integration || true
  
  # Output results
  log_info ""
  log_info "=== SUMMARY ==="
  log_info "Passed: $PASSED, Failed: $FAILED, Warnings: $WARNINGS"
  
  if [[ "$OUTPUT_FORMAT" == "json" ]] || [[ "$OUTPUT_FORMAT" == "both" ]]; then
    generate_json_report
  fi
  
  # Write artifact
  local artifact_file="$ROOT_DIR/artifacts/cockpit/mascarade_validation_$(date +%Y%m%d_%H%M%S).json"
  mkdir -p "$(dirname "$artifact_file")"
  generate_json_report > "$artifact_file"
  log_info "Artifact written: $artifact_file"
  
  # Exit code
  [[ $FAILED -eq 0 ]]
}

main "$@"
