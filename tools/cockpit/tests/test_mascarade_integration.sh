#!/usr/bin/env bash
set -uo pipefail

# Integration tests for Mascarade cockpit scripts
# Validates that each script produces well-formed cockpit-v1 JSON output.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
COCKPIT_DIR="$ROOT_DIR/tools/cockpit"

PASSED=0
FAILED=0
TOTAL=0

# Colors (disabled if not a terminal)
if [[ -t 1 ]]; then
  GREEN=$'\033[0;32m'
  RED=$'\033[0;31m'
  BOLD=$'\033[1m'
  RESET=$'\033[0m'
else
  GREEN="" RED="" BOLD="" RESET=""
fi

pass() {
  PASSED=$((PASSED + 1))
  TOTAL=$((TOTAL + 1))
  printf "  ${GREEN}PASS${RESET}  %s\n" "$1"
}

fail() {
  FAILED=$((FAILED + 1))
  TOTAL=$((TOTAL + 1))
  printf "  ${RED}FAIL${RESET}  %s — %s\n" "$1" "$2"
}

# Require jq
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required but not found in PATH." >&2
  exit 1
fi

echo "${BOLD}Mascarade Integration Tests${RESET}"
echo "=========================="
echo ""

# ---------------------------------------------------------------------------
# Test 1: mascarade_runtime_health.sh --json
# ---------------------------------------------------------------------------
TEST_NAME="mascarade_runtime_health.sh --json"
SCRIPT="$COCKPIT_DIR/mascarade_runtime_health.sh"

if [[ ! -x "$SCRIPT" ]]; then
  fail "$TEST_NAME" "script not found or not executable"
else
  OUTPUT="$(bash "$SCRIPT" --json 2>/dev/null)" || true

  if [[ -z "$OUTPUT" ]]; then
    fail "$TEST_NAME" "no output produced"
  elif ! echo "$OUTPUT" | jq empty 2>/dev/null; then
    fail "$TEST_NAME" "output is not valid JSON"
  else
    # Verify cockpit-v1 structure
    CV="$(echo "$OUTPUT" | jq -r '.contract_version // empty')"
    COMP="$(echo "$OUTPUT" | jq -r '.component // empty')"
    STAT="$(echo "$OUTPUT" | jq -r '.status // empty')"
    CHECKS="$(echo "$OUTPUT" | jq -r '.checks // empty')"

    if [[ "$CV" != "cockpit-v1" ]]; then
      fail "$TEST_NAME" "contract_version is '$CV', expected 'cockpit-v1'"
    elif [[ -z "$COMP" ]]; then
      fail "$TEST_NAME" "missing .component field"
    elif [[ -z "$STAT" ]]; then
      fail "$TEST_NAME" "missing .status field"
    elif [[ "$CHECKS" == "" || "$CHECKS" == "null" ]]; then
      fail "$TEST_NAME" "missing .checks object"
    else
      pass "$TEST_NAME"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Test 2: mascarade_dispatch_mesh.sh --action route --profile heavy-code --json
# ---------------------------------------------------------------------------
TEST_NAME="mascarade_dispatch_mesh.sh --action route --profile heavy-code --json"
SCRIPT="$COCKPIT_DIR/mascarade_dispatch_mesh.sh"

if [[ ! -x "$SCRIPT" ]]; then
  fail "$TEST_NAME" "script not found or not executable"
else
  OUTPUT="$(bash "$SCRIPT" --action route --profile heavy-code --json 2>/dev/null)" || true

  if [[ -z "$OUTPUT" ]]; then
    fail "$TEST_NAME" "no output produced"
  elif ! echo "$OUTPUT" | jq empty 2>/dev/null; then
    fail "$TEST_NAME" "output is not valid JSON"
  else
    CV="$(echo "$OUTPUT" | jq -r '.contract_version // empty')"
    STAT="$(echo "$OUTPUT" | jq -r '.status // empty')"

    if [[ "$CV" != "cockpit-v1" ]]; then
      fail "$TEST_NAME" "contract_version is '$CV', expected 'cockpit-v1'"
    elif [[ -z "$STAT" ]]; then
      fail "$TEST_NAME" "missing .status field"
    else
      pass "$TEST_NAME"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Test 3: langfuse_health.sh --json
# ---------------------------------------------------------------------------
TEST_NAME="langfuse_health.sh --json"
SCRIPT="$COCKPIT_DIR/langfuse_health.sh"

if [[ ! -x "$SCRIPT" ]]; then
  fail "$TEST_NAME" "script not found or not executable"
else
  OUTPUT="$(bash "$SCRIPT" --json 2>/dev/null)" || true

  if [[ -z "$OUTPUT" ]]; then
    fail "$TEST_NAME" "no output produced"
  elif ! echo "$OUTPUT" | jq empty 2>/dev/null; then
    fail "$TEST_NAME" "output is not valid JSON"
  else
    # Even if Langfuse is unreachable, JSON structure must be valid
    CV="$(echo "$OUTPUT" | jq -r '.contract_version // empty')"
    COMP="$(echo "$OUTPUT" | jq -r '.component // empty')"
    STAT="$(echo "$OUTPUT" | jq -r '.status // empty')"
    HAS_REASONS="$(echo "$OUTPUT" | jq 'has("degraded_reasons")')"

    if [[ "$CV" != "cockpit-v1" ]]; then
      fail "$TEST_NAME" "contract_version is '$CV', expected 'cockpit-v1'"
    elif [[ -z "$COMP" ]]; then
      fail "$TEST_NAME" "missing .component field"
    elif [[ -z "$STAT" ]]; then
      fail "$TEST_NAME" "missing .status field"
    elif [[ "$HAS_REASONS" != "true" ]]; then
      fail "$TEST_NAME" "missing .degraded_reasons array"
    else
      pass "$TEST_NAME"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Test 4: runtime_ai_gateway.sh --action status --json
# ---------------------------------------------------------------------------
TEST_NAME="runtime_ai_gateway.sh --action status --json"
SCRIPT="$COCKPIT_DIR/runtime_ai_gateway.sh"

if [[ ! -x "$SCRIPT" ]]; then
  fail "$TEST_NAME" "script not found or not executable"
else
  OUTPUT="$(bash "$SCRIPT" --action status --json 2>/dev/null)" || true

  if [[ -z "$OUTPUT" ]]; then
    fail "$TEST_NAME" "no output produced"
  elif ! echo "$OUTPUT" | jq empty 2>/dev/null; then
    fail "$TEST_NAME" "output is not valid JSON"
  else
    CV="$(echo "$OUTPUT" | jq -r '.contract_version // empty')"
    STAT="$(echo "$OUTPUT" | jq -r '.status // empty')"

    if [[ "$CV" != "cockpit-v1" ]]; then
      fail "$TEST_NAME" "contract_version is '$CV', expected 'cockpit-v1'"
    elif [[ -z "$STAT" ]]; then
      fail "$TEST_NAME" "missing .status field"
    else
      pass "$TEST_NAME"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=========================="
printf "${BOLD}Results: %d/%d tests passed${RESET}\n" "$PASSED" "$TOTAL"

if [[ "$FAILED" -gt 0 ]]; then
  printf "${RED}%d test(s) failed.${RESET}\n" "$FAILED"
  exit 1
else
  printf "${GREEN}All tests passed.${RESET}\n"
  exit 0
fi
