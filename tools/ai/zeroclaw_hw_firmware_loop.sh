#!/usr/bin/env bash
set -euo pipefail

RTC_REPO="${ZEROCLAW_RTC_REPO:-/Users/cils/Documents/Lelectron_rare/RTC_BL_PHONE}"
ZACUS_REPO="${ZEROCLAW_ZACUS_REPO:-/Users/cils/Documents/Lelectron_rare/le-mystere-professeur-zacus}"
RTC_UPLOAD_PORT_HINT_DEFAULT="${ZEROCLAW_RTC_PORT_HINT:-${ZEROCLAW_UPLOAD_PORT_HINT:-cp2102,10c4,esp32audiokit,audio,audiokit,slab_usb}}"
ZACUS_UPLOAD_PORT_HINT_DEFAULT="${ZEROCLAW_ZACUS_PORT_HINT:-${ZEROCLAW_UPLOAD_PORT_HINT:-1a86,usbserial,ch340,freenove,esp32s3,esp32-s3,usbmodem}}"
RTC_UPLOAD_PORT_HINT="${ZEROCLAW_RTC_UPLOAD_PORT_HINT:-$RTC_UPLOAD_PORT_HINT_DEFAULT}"
ZACUS_UPLOAD_PORT_HINT="${ZEROCLAW_ZACUS_UPLOAD_PORT_HINT:-$ZACUS_UPLOAD_PORT_HINT_DEFAULT}"

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

pick_port_for_target() {
  local pick_target="$1"
  local pick_hint="$2"
  local devices_json

  devices_json="$(cd "$FW_DIR" && pio device list --json-output 2>/dev/null || true)"

  ZEROCLAW_TARGET="$pick_target" \
  ZEROCLAW_TARGET_HINT="$pick_hint" \
  ZEROCLAW_DEVICE_LIST_JSON="$devices_json" \
  python3 - <<'PY'
import os
import json

target = (os.environ.get("ZEROCLAW_TARGET", "rtc") or "rtc").strip().lower()
hint = (os.environ.get("ZEROCLAW_TARGET_HINT", "") or "").strip().lower()
raw = (os.environ.get("ZEROCLAW_DEVICE_LIST_JSON", "") or "").strip()

try:
    devices = json.loads(raw) if raw else []
except Exception:
    devices = []


if not isinstance(devices, list):
    devices = []


score_board = {
    "rtc": ["cp210", "10c4", "cp2102", "audio", "esp32 audio", "esp32audio", "esp32audiokit", "audio kit", "slab_usb"],
    "zacus": ["1a86", "ch340", "freenove", "usb single serial", "usbserial", "esp32-s3", "esp32s3", "usbmodem"],
}
penalty_board = {
    "rtc": ["1a86", "ch340", "freenove", "usbmodem"],
    "zacus": ["10c4", "cp2102", "cp210"],
}


def norm(value):
    return (value or "").strip().lower()


def contains_any(text, needles):
    return any(needle in text for needle in needles if needle)


preferred = score_board.get(target, score_board["rtc"])
penalize = penalty_board.get(target, penalty_board["rtc"])
hint_tokens = [token.strip().lower() for token in hint.split(",") if token.strip()]

best_port = ""
best_score = -10 ** 9

for idx, device in enumerate(devices):
    if not isinstance(device, dict):
        continue
    port_raw = device.get("port", "")
    port = norm(port_raw)
    if not port:
        continue
    desc = norm(device.get("description", ""))
    hwid = norm(device.get("hwid", ""))
    board = norm(device.get("board", ""))
    low = f"{port} {desc} {hwid} {board}"

    score = 0
    if hwid and hwid != "n/a":
        score += 50
    if "usb" in low:
        score += 20
    if "uart" in low:
        score += 15
    if "bluetooth" in low:
        score -= 80

    if contains_any(low, preferred):
        score += 120
    if contains_any(low, penalize):
        score -= 80

    for token in hint_tokens:
        if token in low:
            score += 200

    if "/dev/cu." in port and hwid == "n/a":
        score -= 40

    if score > best_score:
        best_score = score
        best_port = port_raw

if best_port:
    print(best_port)
    raise SystemExit(0)
raise SystemExit(1)
PY
}

if ! env_exists "$ENV_NAME"; then
  echo "[fail] invalid PlatformIO env '${ENV_NAME}' for $target." >&2
  echo "[info] valid envs:" >&2
  rg "^\[env:" "$FW_DIR/platformio.ini" >&2 || true
  exit 1
fi

target_port_hint=""
if [[ "$target" == "rtc" ]]; then
  target_port_hint="$RTC_UPLOAD_PORT_HINT"
else
  target_port_hint="$ZACUS_UPLOAD_PORT_HINT"
fi

if [[ -z "$PORT" ]]; then
  if [[ -n "$target_port_hint" ]]; then
    PORT="$(pick_port_for_target "$target" "$target_port_hint" || true)"
  else
    PORT="$(pick_port_for_target "$target" "" || true)"
  fi

  if [[ -z "$PORT" ]]; then
    PORT=""
  fi
fi
echo "[info] serial port resolved for $target: ${PORT}"

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

port_still_present() {
  local expected_port="$1"
  local list
  if [[ -z "$expected_port" ]]; then
    return 1
  fi
  list="$(cd "$FW_DIR" && pio device list --json-output 2>/dev/null || true)"
  if [[ -z "$list" ]]; then
    return 1
  fi
  python3 - "$expected_port" "$list" <<'PY'
import json
import sys

def norm(value):
    return (value or "").strip().lower()

port = norm(sys.argv[1])
raw = sys.argv[2].strip()

try:
    devices = json.loads(raw)
except Exception:
    sys.exit(1)

if not isinstance(devices, list):
    sys.exit(1)

for device in devices:
    if not isinstance(device, dict):
        continue
    if norm(device.get("port", "")) == port:
        sys.exit(0)
sys.exit(1)
PY
}

upload_target_with_retries() {
  local env_name="$1"
  local max_retries="${2:-1}"
  local attempts=0
  local output

  while true; do
    if ! port_still_present "$PORT"; then
      echo "[warn] selected port $PORT is not visible anymore; re-detecting."
      PORT="$(pick_port_for_target "$target" "$target_port_hint" || true)"
      if [[ -z "$PORT" ]]; then
        PORT=""
      fi
      UPLOAD_ARGS=()
      MONITOR_ARGS=()
      if [[ -n "$PORT" ]]; then
        UPLOAD_ARGS+=(--upload-port "$PORT")
        MONITOR_ARGS+=(-p "$PORT")
      fi
      if [[ -n "$PORT" ]]; then
        echo "[info] serial port re-resolved for $target: $PORT"
      else
        echo "[warn] no serial port re-detected; upload might fail."
      fi
    fi

    upload_once "$env_name"
    rc=$?
    output="${UPLOAD_LAST_OUTPUT:-}"

    if [[ $rc -eq 0 ]]; then
      return 0
    fi

    if [[ $attempts -ge $max_retries ]]; then
      return $rc
    fi

    if printf '%s' "$output" | rg -qi "(Could not connect|No such file|No such device|not found|not ready|in use|busy|Permission denied|Device or resource busy|No such file or directory)"; then
      attempts=$((attempts + 1))
      echo "[warn] upload failure likely linked to transient serial port state; retry ${attempts}/${max_retries}."
      continue
    fi

    return $rc
  done
}

echo "[step] upload/flash (forced default)"
UPLOAD_LAST_OUTPUT=""
if ! upload_target_with_retries "$ACTIVE_ENV" 1; then
  fallback_env="$(resolve_env_fallback "$ACTIVE_ENV" "$UPLOAD_LAST_OUTPUT" || true)"
  if [[ -n "$fallback_env" ]]; then
    echo "[warn] detected chip/env mismatch for $ACTIVE_ENV; retrying with '$fallback_env'."
    ACTIVE_ENV="$fallback_env"
    echo "[step] rebuild (fallback env)"
    (cd "$FW_DIR" && pio run -e "$ACTIVE_ENV")
    echo "[step] upload/flash retry (forced default)"
    if ! upload_target_with_retries "$ACTIVE_ENV" 1; then
      exit 3
    fi
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
