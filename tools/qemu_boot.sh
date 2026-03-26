#!/usr/bin/env bash
# Kill_LIFE — QEMU ESP32-S3 boot (wraps tools/sim/ with fixed esptool invocation)
# Usage: bash tools/qemu_boot.sh [--timeout N] [--build] [--gdb]
#
# Expected output on success:
#   ESP-ROM:esp32s3-20210327         <- boot ROM loaded
#   E octal_psram: PSRAM chip...     <- expected (QEMU, no PSRAM)
#   [E][Panel]: Init failed          <- expected (QEMU, no LCD)
#   [main] ...                       <- firmware running
#
# QEMU limitations: no PSRAM, no LCD, no WiFi, no I2S

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SIM_DIR="$REPO_ROOT/tools/sim"
QEMU="$SIM_DIR/qemu-system-xtensa"
BUILD_DIR="$REPO_ROOT/firmware/.pio/build/esp32s3_waveshare"
FLASH_IMG="/tmp/kl_qemu_$$.bin"
TIMEOUT=10
DO_BUILD=0
GDB_FLAG=0
LOG_DIR="/tmp/kl_sim"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --timeout) TIMEOUT="$2"; shift 2 ;;
        --build)   DO_BUILD=1; shift ;;
        --gdb)     GDB_FLAG=1; shift ;;
        *)         echo "Unknown option: $1"; exit 1 ;;
    esac
done

[[ -x "$QEMU" ]] || { echo "[sim] ERROR: $QEMU not found"; exit 1; }
[[ -f "$SIM_DIR/esp32s3_rev0_rom.bin" ]] || { echo "[sim] ERROR: ROM not found"; exit 1; }

if [[ "$DO_BUILD" -eq 1 ]]; then
    echo "[sim] Building firmware..."
    "$REPO_ROOT/.pio-venv/bin/pio" run -e esp32s3_waveshare -C "$REPO_ROOT/firmware"
fi

[[ -f "$BUILD_DIR/firmware.bin" ]] || {
    echo "[sim] ERROR: No firmware binary. Run: pio run -e esp32s3_waveshare"
    exit 1
}

echo "[sim] Creating flash image..."
VENV_PY="$REPO_ROOT/.pio-venv/bin/python3"
[[ -x "$VENV_PY" ]] || VENV_PY="$(which python3)"

"$VENV_PY" -m esptool --chip esp32s3 merge-bin \
    -o "$FLASH_IMG" \
    --flash-mode dio \
    --flash-size 16MB \
    0x0    "$BUILD_DIR/bootloader.bin" \
    0x8000 "$BUILD_DIR/partitions.bin" \
    0x10000 "$BUILD_DIR/firmware.bin" \
    2>/dev/null

truncate -s 16M "$FLASH_IMG"

mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/qemu_$(date +%Y%m%d_%H%M%S).log"

GDB_OPTS=""
[[ "$GDB_FLAG" -eq 1 ]] && GDB_OPTS="-s -S"

echo "[sim] Booting ESP32-S3 in QEMU (timeout=${TIMEOUT}s) | Log: $LOG_FILE"
echo "---"

set +e
timeout "$TIMEOUT" "$QEMU" \
    -nographic \
    -machine esp32s3 \
    -drive "file=$FLASH_IMG,if=mtd,format=raw" \
    -no-reboot \
    -L "$SIM_DIR" \
    $GDB_OPTS \
    2>&1 | tee "$LOG_FILE"
PIPE_EXIT=${PIPESTATUS[0]}
set -e

rm -f "$FLASH_IMG"
echo ""
echo "--- [sim] exit=$PIPE_EXIT ---"

RESULT="UNKNOWN"
if grep -q "abort() was called" "$LOG_FILE" 2>/dev/null; then
    RESULT="ABORT"
elif grep -q "Guru Meditation" "$LOG_FILE" 2>/dev/null; then
    RESULT="CRASH"
elif grep -q "ESP-ROM:esp32s3" "$LOG_FILE" 2>/dev/null; then
    RESULT="BOOT_OK"
fi

echo "[sim] RESULT=$RESULT | log=$LOG_FILE"

if [[ "$RESULT" == "ABORT" || "$RESULT" == "CRASH" ]]; then
    exit 1
fi
# exit 124 = timeout (expected), exit 0 = clean exit — both OK for boot test
exit 0
