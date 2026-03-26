#!/usr/bin/env bash
# Kill_LIFE — QEMU ESP32-S3 Firmware Simulation
# Usage: bash tools/sim/run_qemu_esp32s3.sh [--timeout N] [--build]
#
# Prerequisites:
#   - QEMU Xtensa (Espressif fork) in tools/sim/qemu-system-xtensa
#   - ROM file in tools/sim/esp32s3_rev0_rom.bin (or -L path)
#   - Built firmware in firmware/.pio/build/esp32s3_waveshare/
#
# Options:
#   --timeout N   Seconds to run before killing QEMU (default: 10)
#   --build       Build firmware before running simulation
#   --gdb         Start QEMU with GDB server on port 1234

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
QEMU="$SCRIPT_DIR/qemu-system-xtensa"
ROM_DIR="$SCRIPT_DIR"
FW_DIR="$REPO_ROOT/firmware"
BUILD_DIR="$FW_DIR/.pio/build/esp32s3_waveshare"
FLASH_IMG="/tmp/kill_life_qemu_flash.bin"
TIMEOUT=10
DO_BUILD=0
GDB_OPTS=""
LOG_FILE="$REPO_ROOT/artifacts/sim/qemu_$(date +%Y%m%d_%H%M%S).log"

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --timeout) TIMEOUT="$2"; shift 2 ;;
        --build)   DO_BUILD=1; shift ;;
        --gdb)     GDB_OPTS="-s -S"; shift ;;
        *)         echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Checks
if [[ ! -x "$QEMU" ]]; then
    echo "[sim] ERROR: QEMU not found at $QEMU"
    echo "       Install: download from github.com/espressif/qemu/releases"
    exit 1
fi

if [[ ! -f "$ROM_DIR/esp32s3_rev0_rom.bin" ]]; then
    echo "[sim] ERROR: ROM file not found at $ROM_DIR/esp32s3_rev0_rom.bin"
    exit 1
fi

# Build if requested
if [[ "$DO_BUILD" -eq 1 ]]; then
    echo "[sim] Building firmware..."
    cd "$FW_DIR"
    "$REPO_ROOT/.pio-venv/bin/pio" run -e esp32s3_waveshare
fi

# Check firmware exists
if [[ ! -f "$BUILD_DIR/firmware.bin" ]]; then
    echo "[sim] ERROR: Firmware not found. Run with --build or: pio run -e esp32s3_waveshare"
    exit 1
fi

# Create merged flash image (16MB)
echo "[sim] Creating flash image..."
ESPTOOL="$REPO_ROOT/.pio-venv/bin/esptool"
if [[ ! -x "$ESPTOOL" ]]; then
    ESPTOOL="$(which esptool 2>/dev/null || echo "")"
fi
if [[ -z "$ESPTOOL" ]]; then
    echo "[sim] ERROR: esptool not found. Install: pip install esptool"
    exit 1
fi

"$ESPTOOL" --chip esp32s3 merge-bin \
    -o "$FLASH_IMG.tmp" \
    --flash-mode dio \
    --flash-size 16MB \
    0x0 "$BUILD_DIR/bootloader.bin" \
    0x8000 "$BUILD_DIR/partitions.bin" \
    0x10000 "$BUILD_DIR/firmware.bin" \
    2>/dev/null

# Pad to exactly 16MB
truncate -s 16M "$FLASH_IMG"
dd if="$FLASH_IMG.tmp" of="$FLASH_IMG" conv=notrunc 2>/dev/null
rm -f "$FLASH_IMG.tmp"

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")"

# Run QEMU
echo "[sim] Booting Kill_LIFE firmware in QEMU ESP32-S3..."
echo "[sim] Timeout: ${TIMEOUT}s | Log: $LOG_FILE"
echo "[sim] Flash: $(du -h "$FLASH_IMG" | cut -f1) | GDB: ${GDB_OPTS:-disabled}"
echo "---"

timeout "$TIMEOUT" "$QEMU" \
    -nographic \
    -machine esp32s3 \
    -drive "file=$FLASH_IMG,if=mtd,format=raw" \
    -serial mon:stdio \
    -no-reboot \
    -L "$ROM_DIR" \
    $GDB_OPTS \
    2>&1 | tee "$LOG_FILE"

EXIT_CODE=${PIPESTATUS[0]}
echo ""
echo "---"
echo "[sim] QEMU exited (code=$EXIT_CODE). Log saved: $LOG_FILE"

# Quick analysis
if grep -q "abort() was called" "$LOG_FILE" 2>/dev/null; then
    echo "[sim] RESULT: ABORT detected in firmware"
    ABORT_LINE=$(grep "abort() was called" "$LOG_FILE" | head -1)
    echo "[sim]   $ABORT_LINE"
elif grep -q "Rebooting" "$LOG_FILE" 2>/dev/null; then
    echo "[sim] RESULT: Firmware rebooted (crash or watchdog)"
else
    echo "[sim] RESULT: Firmware ran for ${TIMEOUT}s without crash"
fi
