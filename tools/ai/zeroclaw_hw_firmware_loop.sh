#!/usr/bin/env bash
set -euo pipefail

RTC_REPO="${ZEROCLAW_RTC_REPO:-/Users/cils/Documents/Lelectron_rare/RTC_BL_PHONE}"
ZACUS_REPO="${ZEROCLAW_ZACUS_REPO:-/Users/cils/Documents/Lelectron_rare/le-mystere-professeur-zacus}"

RTC_FW_DIR="$RTC_REPO"
ZACUS_FW_DIR="$ZACUS_REPO/hardware/firmware"

RTC_ENV_DEFAULT="${ZEROCLAW_RTC_PIO_ENV:-esp32dev}"
ZACUS_ENV_DEFAULT="${ZEROCLAW_ZACUS_PIO_ENV:-esp32dev}"
MONITOR_SECS_DEFAULT="${ZEROCLAW_MONITOR_SECS:-60}"
BAUD_DEFAULT="${ZEROCLAW_SERIAL_BAUD:-115200}"

usage() {
  cat <<USAGE
Usage:
  $(basename "$0") <rtc|zacus> [--env <platformio_env>] [--port <serial_port>] [--baud <baud>] [--monitor-secs <n>]

Behavior:
  - Build is always executed.
  - Upload/flash is forced by default.
  - Serial monitor is forced by default for monitor-secs (default: ${MONITOR_SECS_DEFAULT}s).
USAGE
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

target="$1"
shift

FW_DIR=""
ENV_NAME=""
case "$target" in
  rtc)
    FW_DIR="$RTC_FW_DIR"
    ENV_NAME="$RTC_ENV_DEFAULT"
    ;;
  zacus)
    FW_DIR="$ZACUS_FW_DIR"
    ENV_NAME="$ZACUS_ENV_DEFAULT"
    ;;
  *)
    echo "[fail] unsupported target: $target (expected rtc|zacus)" >&2
    exit 1
    ;;
esac

PORT="${ZEROCLAW_UPLOAD_PORT:-}"
BAUD="$BAUD_DEFAULT"
MONITOR_SECS="$MONITOR_SECS_DEFAULT"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV_NAME="${2:-}"
      shift 2
      ;;
    --port)
      PORT="${2:-}"
      shift 2
      ;;
    --baud)
      BAUD="${2:-}"
      shift 2
      ;;
    --monitor-secs)
      MONITOR_SECS="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[fail] unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! -d "$FW_DIR" ]]; then
  echo "[fail] firmware directory not found: $FW_DIR" >&2
  exit 1
fi

if [[ ! -f "$FW_DIR/platformio.ini" ]]; then
  echo "[fail] platformio.ini not found in: $FW_DIR" >&2
  exit 1
fi

if ! command -v pio >/dev/null 2>&1; then
  echo "[fail] platformio (pio) not found in PATH." >&2
  exit 1
fi

if ! rg -q "^\[env:${ENV_NAME}\]" "$FW_DIR/platformio.ini"; then
  echo "[fail] invalid PlatformIO env '${ENV_NAME}' for $target." >&2
  echo "[info] valid envs:" >&2
  rg "^\[env:" "$FW_DIR/platformio.ini" >&2 || true
  exit 1
fi

if [[ -z "$PORT" ]]; then
  PORT="$(cd "$FW_DIR" && pio device list --json-output 2>/dev/null | python3 -c 'import json,sys
raw=sys.stdin.read().strip()
try:
  arr=json.loads(raw) if raw else []
except Exception:
  arr=[]
for d in arr:
  p=d.get("port")
  if p:
    print(p)
    raise SystemExit(0)
raise SystemExit(1)' || true)"
fi

if [[ -z "$PORT" ]]; then
  echo "[fail] no serial port detected. Upload/monitor are forced by default." >&2
  exit 2
fi

UPLOAD_ARGS=()
MONITOR_ARGS=()
if [[ -n "$PORT" ]]; then
  UPLOAD_ARGS+=(--upload-port "$PORT")
  MONITOR_ARGS+=(-p "$PORT")
fi
if [[ -n "$BAUD" ]]; then
  MONITOR_ARGS+=(-b "$BAUD")
fi

echo "[info] target=$target fw_dir=$FW_DIR env=$ENV_NAME port=$PORT baud=$BAUD monitor_secs=$MONITOR_SECS"
echo "[step] build"
(cd "$FW_DIR" && pio run -e "$ENV_NAME")

echo "[step] upload/flash (forced default)"
(cd "$FW_DIR" && pio run -e "$ENV_NAME" -t upload "${UPLOAD_ARGS[@]}")

echo "[step] serial monitor (forced default)"
python3 - "$FW_DIR" "$MONITOR_SECS" "${MONITOR_ARGS[@]}" <<'PY'
import os
import signal
import subprocess
import sys
import time

fw_dir = sys.argv[1]
monitor_secs = int(sys.argv[2])
monitor_args = sys.argv[3:]
cmd = ["pio", "device", "monitor", *monitor_args]
print(f"[info] monitor command: {' '.join(cmd)} (timeout={monitor_secs}s)")

proc = subprocess.Popen(cmd, cwd=fw_dir, preexec_fn=os.setsid)
try:
    time.sleep(monitor_secs)
finally:
    if proc.poll() is None:
        os.killpg(proc.pid, signal.SIGTERM)
        try:
            proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            os.killpg(proc.pid, signal.SIGKILL)
            proc.wait(timeout=2)
PY

echo "[ok] loop complete for $target ($ENV_NAME)."
