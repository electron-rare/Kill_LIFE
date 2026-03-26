# Training Example: ESP32-S3 QEMU Boot Validation
date: 2026-03-25
domain: firmware/simulation/qemu
type: setup_and_verification
outcome: BOOT_OK — ESP-ROM loads, firmware starts, graceful hardware fallbacks

## Summary

Set up Espressif QEMU 9.2.2 for ESP32-S3 firmware simulation without physical hardware.
Verified full boot sequence: ROM → bootloader → firmware application, with expected
peripheral failures (PSRAM, LCD) handled gracefully by the firmware.

## Context

- Tool: QEMU Xtensa (Espressif fork) v9.2.2, `tools/sim/qemu-system-xtensa`
- ROM: `tools/sim/esp32s3_rev0_rom.bin` (384KB, ESP32-S3 rev0)
- Firmware: `firmware/.pio/build/esp32s3_waveshare/firmware.bin` (Arduino + ESP-IDF)
- Flash: 16MB merged image (esptool merge-bin: bootloader + partitions + app)

---

## Setup Process

### Step 1: Verify QEMU binary

```bash
tools/sim/qemu-system-xtensa --version
# QEMU emulator version 9.2.2 (esp_develop_9.2.2_20250817)

tools/sim/qemu-system-xtensa -machine help | grep esp
# esp32   Espressif ESP32 machine
# esp32s3 Espressif ESP32S3 machine
```

### Step 2: Build merged flash image

```bash
# Use venv python directly — esptool shebang wrapper can fail in some shell contexts
VENV_PY=".pio-venv/bin/python3"
"$VENV_PY" -m esptool --chip esp32s3 merge-bin \
    -o /tmp/flash.bin \
    --flash-mode dio --flash-size 16MB \
    0x0     firmware/.pio/build/esp32s3_waveshare/bootloader.bin \
    0x8000  firmware/.pio/build/esp32s3_waveshare/partitions.bin \
    0x10000 firmware/.pio/build/esp32s3_waveshare/firmware.bin
truncate -s 16M /tmp/flash.bin
```

**Key fix**: Use `python3 -m esptool` instead of `esptool` wrapper script.
The wrapper has a shebang pointing to the venv python which may not resolve
correctly in all execution contexts (exit code 127 / "not found").

### Step 3: Boot QEMU

```bash
tools/sim/qemu-system-xtensa \
    -nographic \
    -machine esp32s3 \
    -drive "file=/tmp/flash.bin,if=mtd,format=raw" \
    -no-reboot \
    -L tools/sim/
```

---

## Expected Output

```
Adding SPI flash device
ESP-ROM:esp32s3-20210327
Build:Mar 27 2021
rst:0x1 (POWERON),boot:0x4 (SPI_FLASH_BOOT)
SPIWP:0xee
mode:DIO, clock div:1
load:0x3fce2820,len:0x10cc
load:0x403c8700,len:0xc2c
load:0x403cb700,len:0x30c0
entry 0x403c88b8
E (139) octal_psram: PSRAM chip is not connected, or wrong PSRAM line mode
E (139) esp_psram: PSRAM enabled but initialization failed. Bailing out.
E cpu_start: Failed to init external RAM; continuing without it.
[E][Panel][esp_panel_board.cpp:0250](begin): Init failed
```

---

## What the Output Means

| Line | Status | Explanation |
|---|---|---|
| `ESP-ROM:esp32s3-20210327` | ✅ OK | Boot ROM loaded from `esp32s3_rev0_rom.bin` |
| `load:0x3fce2820...` | ✅ OK | Bootloader + app segments loaded into RAM |
| `E octal_psram: PSRAM chip is not connected` | ⚠️ Expected | QEMU doesn't emulate octal PSRAM (ESP32-S3-WROOM-1-N16R8 has it) |
| `Failed to init external RAM; continuing without it` | ⚠️ Expected | Firmware has no PSRAM guard — continues with heap only |
| `[E][Panel]: Init failed` | ⚠️ Expected | ST77916 LCD not emulated; main.cpp handles `!g_lcd.Begin()` gracefully |

---

## QEMU Limitations vs Hardware

| Feature | QEMU | Notes |
|---|---|---|
| CPU Xtensa LX7 | ✅ Emulated | Boot ROM + FreeRTOS scheduler work |
| Flash (SPI, 16MB) | ✅ Emulated | MTD drive interface |
| UART/Serial | ✅ Emulated | `-nographic` routes UART0 to stdio |
| PSRAM (octal SPI) | ❌ Not emulated | Firmware continues without PSRAM |
| LCD (SPI/QSPI) | ❌ Not emulated | Init returns error, firmware handles |
| WiFi (802.11) | ❌ Not emulated | WifiManager.Begin() starts but never connects |
| I2S (output/input) | ❌ Not emulated | RadioPlayer and I2sMic unavailable |
| GPIO/Button | ❌ Not emulated | Push-to-talk path untestable |

---

## Wrapper Script

Created `tools/qemu_boot.sh` (user-writable, since `tools/sim/` is root-owned):

```bash
bash tools/qemu_boot.sh --timeout 10   # Quick boot test
bash tools/qemu_boot.sh --build --timeout 15  # Rebuild then test
bash tools/qemu_boot.sh --gdb         # Start QEMU with GDB server on :1234
```

Result summary:
- `RESULT=BOOT_OK` → boot ROM started, no crash
- `RESULT=ABORT` → firmware called `abort()`, check logs
- `RESULT=CRASH` → Guru Meditation / watchdog reset

---

## PlatformIO Integration

`[env:esp32s3_qemu]` in `firmware/platformio.ini`:
- Extends `esp32s3_waveshare`
- Removes `-D BOARD_HAS_PSRAM` (no PSRAM in QEMU)
- Adds `-D QEMU_BUILD=1` (future use: guard WiFi/I2S in firmware)
- Adds `-D CORE_DEBUG_LEVEL=3` (verbose logging for simulation)
- `debug_tool = custom` → uses QEMU GDB server on localhost:1234

---

## Files

- QEMU binary: `tools/sim/qemu-system-xtensa`
- ROM: `tools/sim/esp32s3_rev0_rom.bin`
- Boot wrapper: `tools/qemu_boot.sh`
- Documentation: `docs/SIMULATION.md`
- PlatformIO env: `firmware/platformio.ini [env:esp32s3_qemu]`
- Boot logs: `/tmp/kl_sim/qemu_YYYYMMDD_HHMMSS.log`
