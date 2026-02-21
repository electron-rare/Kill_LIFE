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

env_exists() {
  local env_name="$1"
  rg -q "^\[env:${env_name}\]" "$FW_DIR/platformio.ini"
}

if ! env_exists "$ENV_NAME"; then
  echo "[fail] invalid PlatformIO env '${ENV_NAME}' for $target." >&2
  echo "[info] valid envs:" >&2
  rg "^\[env:" "$FW_DIR/platformio.ini" >&2 || true
  exit 1
fi

if [[ -z "$PORT" ]]; then
  if ! PORT="$(
    cd "$FW_DIR"
    pio device list --json-output 2>/dev/null | python3 -c 'import json,sys
raw=sys.stdin.read().strip()
try:
  arr=json.loads(raw) if raw else []
except Exception:
  arr=[]
best=None
best_score=-10**9
for d in arr:
  p=str(d.get("port",""))
  desc=str(d.get("description",""))
  hwid=str(d.get("hwid",""))
  if not p:
    continue
  score=0
  low=f\"{p} {desc} {hwid}\".lower()
  if hwid and hwid.lower() != \"n/a\":
    score += 50
  if \"usb\" in low:
    score += 30
  if \"cp210\" in low or \"ch340\" in low or \"uart\" in low:
    score += 20
  if \"bluetooth\" in low:
    score -= 100
  if \"/cu.urt\" in p.lower() and hwid.lower() == \"n/a\":
    score -= 120
  if score > best_score:
    best_score=score
    best=p
if best:
  print(best)
  raise SystemExit(0)
raise SystemExit(1)'
  )"; then
    PORT=""
  fi
fi

if [[ -z "$PORT" ]]; then
  echo "[fail] no serial port detected. Upload/monitor are forced by default." >&2
  exit 2
fi

pick_s3_env() {
  local candidate
  if [[ "$target" == "rtc" ]]; then
    for candidate in esp32-s3-devkitc-1 freenove_esp32s3 freenove_esp32s3_full_with_ui; do
      if env_exists "$candidate"; then
        echo "$candidate"
        return 0
      fi
    done
  else
    for candidate in freenove_esp32s3 freenove_esp32s3_full_with_ui esp32-s3-devkitc-1; do
      if env_exists "$candidate"; then
        echo "$candidate"
        return 0
      fi
    done
  fi
  return 1
}

pick_esp32_env() {
  local candidate
  for candidate in esp32dev esp32_release; do
    if env_exists "$candidate"; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

upload_once() {
  local env_name="$1"
  local tmp_out
  tmp_out="$(mktemp)"
  set +e
  (cd "$FW_DIR" && pio run -e "$env_name" -t upload "${UPLOAD_ARGS[@]}") >"$tmp_out" 2>&1
  local rc=$?
  set -e
  UPLOAD_LAST_OUTPUT="$(cat "$tmp_out")"
  cat "$tmp_out"
  rm -f "$tmp_out"
  return "$rc"
}

resolve_env_fallback() {
  local failed_env="$1"
  local output="$2"
  local fallback=""

  if printf '%s' "$output" | rg -qi "This chip is ESP32-S3, not ESP32"; then
    fallback="$(pick_s3_env || true)"
  elif printf '%s' "$output" | rg -qi "This chip is ESP32, not ESP32-S3"; then
    fallback="$(pick_esp32_env || true)"
  fi

  if [[ -n "$fallback" && "$fallback" != "$failed_env" ]]; then
    printf '%s\n' "$fallback"
    return 0
  fi
  return 1
}

UPLOAD_ARGS=()
MONITOR_ARGS=()
if [[ -n "$PORT" ]]; then
  UPLOAD_ARGS+=(--upload-port "$PORT")
  MONITOR_ARGS+=(-p "$PORT")
fi
if [[ -n "$BAUD" ]]; then
  MONITOR_ARGS+=(-b "$BAUD")
fi

ACTIVE_ENV="$ENV_NAME"

echo "[info] target=$target fw_dir=$FW_DIR env=$ACTIVE_ENV port=$PORT baud=$BAUD monitor_secs=$MONITOR_SECS"
echo "[step] build"
(cd "$FW_DIR" && pio run -e "$ACTIVE_ENV")

echo "[step] upload/flash (forced default)"
UPLOAD_LAST_OUTPUT=""
if ! upload_once "$ACTIVE_ENV"; then
  fallback_env="$(resolve_env_fallback "$ACTIVE_ENV" "$UPLOAD_LAST_OUTPUT" || true)"
  if [[ -n "$fallback_env" ]]; then
    echo "[warn] detected chip/env mismatch for $ACTIVE_ENV; retrying with '$fallback_env'."
    ACTIVE_ENV="$fallback_env"
    echo "[step] rebuild (fallback env)"
    (cd "$FW_DIR" && pio run -e "$ACTIVE_ENV")
    echo "[step] upload/flash retry (forced default)"
    upload_once "$ACTIVE_ENV"
  else
    exit 3
  fi
fi

echo "[step] serial monitor (forced default)"
python3 - "$FW_DIR" "$MONITOR_SECS" "${MONITOR_ARGS[@]}" <<'PY'
import os
import platform
import signal
import shutil
import subprocess
import sys
import time

fw_dir = sys.argv[1]
monitor_secs = int(sys.argv[2])
monitor_args = sys.argv[3:]
base_cmd = ["pio", "device", "monitor", *monitor_args]
if platform.system() == "Darwin" and shutil.which("script"):
    cmd = ["script", "-q", "/dev/null", *base_cmd]
else:
    cmd = base_cmd
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

echo "[ok] loop complete for $target ($ACTIVE_ENV)."
