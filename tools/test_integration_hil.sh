#!/usr/bin/env bash
# test_integration_hil.sh — Hardware-In-the-Loop integration test runner
# Runs integration tests against real or simulated hardware targets.
#
# Usage:
#   ./tools/test_integration_hil.sh [--sim]   # --sim for simulated mode (no hardware)
#
# Environment:
#   HIL_TARGET    Serial port or IP of the DUT (default: /dev/ttyUSB0)
#   HIL_BAUD      Baud rate (default: 115200)
#   HIL_TIMEOUT   Per-test timeout in seconds (default: 30)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

HIL_TARGET="${HIL_TARGET:-/dev/ttyUSB0}"
HIL_BAUD="${HIL_BAUD:-115200}"
HIL_TIMEOUT="${HIL_TIMEOUT:-30}"
SIM_MODE=false

for arg in "$@"; do
  case "$arg" in
    --sim) SIM_MODE=true ;;
    --help|-h)
      echo "Usage: $0 [--sim]"
      echo "  --sim   Run in simulation mode (no hardware required)"
      exit 0
      ;;
  esac
done

RESULTS_DIR="$ROOT/artifacts/hil_results"
mkdir -p "$RESULTS_DIR"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT="$RESULTS_DIR/hil_report_${TIMESTAMP}.json"

echo "=== HIL Integration Tests ==="
echo "Mode:    $([ "$SIM_MODE" = true ] && echo 'SIMULATED' || echo 'HARDWARE')"
echo "Target:  $HIL_TARGET"
echo "Baud:    $HIL_BAUD"
echo "Timeout: ${HIL_TIMEOUT}s"
echo ""

PASS=0
FAIL=0
SKIP=0
RESULTS="[]"

run_test() {
  local name="$1"
  local description="$2"
  local cmd="$3"

  echo -n "  [$name] $description ... "

  if [ "$SIM_MODE" = true ] && echo "$cmd" | grep -q "REQUIRES_HW"; then
    echo "SKIP (no hardware)"
    SKIP=$((SKIP + 1))
    RESULTS=$(echo "$RESULTS" | python3 -c "
import json,sys
r=json.load(sys.stdin)
r.append({'name':'$name','status':'skip','reason':'no hardware'})
json.dump(r,sys.stdout)")
    return
  fi

  if timeout "$HIL_TIMEOUT" bash -c "$cmd" > /dev/null 2>&1; then
    echo "PASS"
    PASS=$((PASS + 1))
    RESULTS=$(echo "$RESULTS" | python3 -c "
import json,sys
r=json.load(sys.stdin)
r.append({'name':'$name','status':'pass'})
json.dump(r,sys.stdout)")
  else
    echo "FAIL"
    FAIL=$((FAIL + 1))
    RESULTS=$(echo "$RESULTS" | python3 -c "
import json,sys
r=json.load(sys.stdin)
r.append({'name':'$name','status':'fail'})
json.dump(r,sys.stdout)")
  fi
}

# --- Test Suite ---

# T1: Firmware builds successfully
run_test "T1_build" "Firmware compiles" \
  "cd '$ROOT' && python3 tools/build_firmware.py 2>&1"

# T2: Unit tests pass (native)
run_test "T2_unit" "Native unit tests pass" \
  "cd '$ROOT' && python3 tools/test_firmware.py 2>&1"

# T3: Serial boot banner (requires hardware)
run_test "T3_boot_banner" "DUT sends boot banner over serial" \
  "REQUIRES_HW && python3 '$ROOT/firmware/test/test_boot.py' --port '$HIL_TARGET' --baud '$HIL_BAUD'"

# T4: Wi-Fi association (requires hardware + AP)
run_test "T4_wifi" "DUT associates to Wi-Fi AP" \
  "REQUIRES_HW && echo 'wifi association check placeholder'"

# T5: MQTT publish (requires hardware + broker)
run_test "T5_mqtt" "DUT publishes MQTT heartbeat" \
  "REQUIRES_HW && echo 'mqtt publish check placeholder'"

# T6: OTA update acceptance (requires hardware)
run_test "T6_ota" "DUT accepts OTA firmware update" \
  "REQUIRES_HW && echo 'ota update check placeholder'"

# --- Report ---
echo ""
echo "=== Results: $PASS pass, $FAIL fail, $SKIP skip ==="

echo "$RESULTS" | python3 -c "
import json, sys
from datetime import datetime
results = json.load(sys.stdin)
report = {
    'timestamp': '$TIMESTAMP',
    'mode': 'simulated' if '$SIM_MODE' == 'true' else 'hardware',
    'target': '$HIL_TARGET',
    'summary': {'pass': $PASS, 'fail': $FAIL, 'skip': $SKIP},
    'tests': results
}
json.dump(report, sys.stdout, indent=2)
" > "$REPORT"

echo "Report: $REPORT"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
