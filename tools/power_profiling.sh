#!/usr/bin/env bash
# power_profiling.sh — Power consumption and timing measurement tool
# Collects power profiling data from hardware or estimates from firmware analysis.
#
# Usage:
#   ./tools/power_profiling.sh [--estimate]   # --estimate for software-only analysis
#
# Environment:
#   POWER_METER    Serial port of power meter (default: /dev/ttyUSB1)
#   SAMPLE_RATE    Samples per second (default: 1000)
#   DURATION       Measurement duration in seconds (default: 60)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

POWER_METER="${POWER_METER:-/dev/ttyUSB1}"
SAMPLE_RATE="${SAMPLE_RATE:-1000}"
DURATION="${DURATION:-60}"
ESTIMATE_MODE=false

for arg in "$@"; do
  case "$arg" in
    --estimate) ESTIMATE_MODE=true ;;
    --help|-h)
      echo "Usage: $0 [--estimate]"
      echo "  --estimate   Software-only power estimation (no meter required)"
      exit 0
      ;;
  esac
done

RESULTS_DIR="$ROOT/artifacts/power_profiling"
mkdir -p "$RESULTS_DIR"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT="$RESULTS_DIR/power_report_${TIMESTAMP}.json"

echo "=== Power Profiling & Timing Measurement ==="
echo "Mode:        $([ "$ESTIMATE_MODE" = true ] && echo 'ESTIMATE (software)' || echo 'HARDWARE METER')"
echo "Duration:    ${DURATION}s"
echo "Sample rate: ${SAMPLE_RATE} Hz"
echo ""

if [ "$ESTIMATE_MODE" = true ]; then
  echo "--- Software-based estimation ---"

  # Analyze firmware binary size
  FIRMWARE_BIN="$ROOT/firmware/.pio/build/esp32dev/firmware.bin"
  BIN_SIZE=0
  if [ -f "$FIRMWARE_BIN" ]; then
    BIN_SIZE=$(stat -f%z "$FIRMWARE_BIN" 2>/dev/null || stat --printf="%s" "$FIRMWARE_BIN" 2>/dev/null || echo 0)
    echo "  Firmware binary size: $BIN_SIZE bytes"
  else
    echo "  Firmware binary not found — build first with: python3 tools/build_firmware.py"
  fi

  # ESP32 typical power estimates (from datasheet)
  cat <<ESTIMATES

  === ESP32 Power Estimates (typical, from Espressif datasheet) ===
  Mode                  Current (mA)   Voltage (V)   Power (mW)
  -----------------------------------------------------------
  Active (Wi-Fi TX)     180-240        3.3           594-792
  Active (Wi-Fi RX)     95-100         3.3           314-330
  Active (BLE TX)       130            3.3           429
  Active (CPU only)     30-68          3.3           99-224
  Modem-sleep           20-30          3.3           66-99
  Light-sleep           0.8            3.3           2.6
  Deep-sleep            0.01           3.3           0.033
  Hibernation           0.005          3.3           0.017

  === Timing Estimates ===
  Boot to main():       ~300 ms (cold boot)
  Wi-Fi connect:        ~1-3 s (typical DHCP)
  MQTT connect+pub:     ~0.5-1 s
  Deep-sleep wakeup:    ~10 ms
ESTIMATES

  # Generate JSON report
  python3 -c "
import json
report = {
    'timestamp': '$TIMESTAMP',
    'mode': 'estimate',
    'firmware_binary_bytes': $BIN_SIZE,
    'power_estimates_mW': {
        'wifi_tx': {'min': 594, 'max': 792},
        'wifi_rx': {'min': 314, 'max': 330},
        'ble_tx': 429,
        'cpu_only': {'min': 99, 'max': 224},
        'modem_sleep': {'min': 66, 'max': 99},
        'light_sleep': 2.6,
        'deep_sleep': 0.033,
        'hibernation': 0.017
    },
    'timing_estimates_ms': {
        'boot_to_main': 300,
        'wifi_connect': {'min': 1000, 'max': 3000},
        'mqtt_connect_pub': {'min': 500, 'max': 1000},
        'deep_sleep_wakeup': 10
    },
    'battery_life_estimates': {
        'note': '1000mAh LiPo at 3.7V',
        'always_on_wifi_hours': 4.2,
        'duty_cycle_10pct_hours': 33,
        'deep_sleep_wake_1min_days': 347
    }
}
with open('$REPORT', 'w') as f:
    json.dump(report, f, indent=2)
print(f'Report written to: $REPORT')
"

else
  echo "--- Hardware measurement mode ---"
  echo "  Power meter: $POWER_METER"
  echo ""

  if [ ! -e "$POWER_METER" ]; then
    echo "ERROR: Power meter not found at $POWER_METER"
    echo "Hint: Use --estimate for software-only mode"
    exit 1
  fi

  echo "  Recording for ${DURATION}s at ${SAMPLE_RATE} Hz..."
  echo "  (Hardware meter integration is project-specific — extend this script)"
  echo ""
  echo "  Placeholder: connect your INA219/INA226 or Joulescope reader here."

  python3 -c "
import json
report = {
    'timestamp': '$TIMESTAMP',
    'mode': 'hardware',
    'meter': '$POWER_METER',
    'sample_rate_hz': $SAMPLE_RATE,
    'duration_s': $DURATION,
    'status': 'not_implemented',
    'note': 'Connect hardware power meter driver. See tools/power_profiling.sh for integration points.'
}
with open('$REPORT', 'w') as f:
    json.dump(report, f, indent=2)
print(f'Report written to: $REPORT')
"
fi

echo ""
echo "=== Done ==="
