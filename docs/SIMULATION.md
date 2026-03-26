# Kill_LIFE Firmware Simulation

Simulate the ESP32-S3 firmware without physical hardware for testing, debugging, and CI.

## Overview

The project uses a **3-level simulation strategy**, from fastest/simplest to most complete:

| Level | Tool | Speed | Coverage |
|-------|------|-------|----------|
| 1. Host tests | PlatformIO `native` | Instant | Pure logic only |
| 2. QEMU ESP32-S3 | Espressif QEMU (local, open source) | ~10s | Bootloader, app init, partial peripherals |
| 3. Wokwi CI | Wokwi CLI + GitHub Action | ~30s | Full ESP32-S3 with WiFi, LCD, I2S (planned) |

---

## Level 1: Host Tests (PlatformIO native)

Runs pure-logic unit tests on the host machine with no ESP32 toolchain required.

### Run

```bash
cd firmware
pio test -e native
```

### What is tested

39 Unity tests in `firmware/test/test_logic.cpp` covering functions from `firmware/include/firmware_utils.h`:

- `FwIdleSummary` -- LCD summary string formatting
- `FwShouldPublishPlaybackStarted` -- event publish logic
- `FwCompareVersions` -- semver comparison
- `FwIsValidWavHeader` -- WAV file header validation
- `FwIsValidBackendUrl` -- URL format checks
- `FwRssiQuality`, `FwWifiToJson`, `FwNetworkBetterSignal` -- WiFi scanner helpers

### Configuration

The `[env:native]` environment in `platformio.ini`:

```ini
[env:native]
platform = native
build_flags = -D UNIT_TEST=1
build_src_filter = -<*>
```

### Limitations

- No FreeRTOS, no Arduino framework, no ESP-IDF APIs
- No hardware peripherals (WiFi, I2S, LCD, GPIO)
- Only tests functions that compile with a standard C++ compiler

---

## Level 2: QEMU ESP32-S3 (local, open source)

Boots the full firmware binary in Espressif's QEMU fork. Useful for catching boot crashes, init sequence bugs, and debugging with GDB.

### Prerequisites

Installed in `tools/sim/`:

- **Espressif QEMU v9.2.2** -- `tools/sim/qemu-system-xtensa`
- **ROM file** -- `tools/sim/esp32s3_rev0_rom.bin`
- **esptool** -- available in `.pio-venv/bin/esptool` or system PATH

Download QEMU from: https://github.com/espressif/qemu/releases

### Quick start

```bash
# Run without rebuilding (uses existing .pio/build/esp32s3_waveshare/)
bash tools/qemu_boot.sh --timeout 10

# Build and run
bash tools/qemu_boot.sh --build --timeout 15
```

`tools/qemu_boot.sh` is the user-writable wrapper (fixes esptool shebang issue, logs to `/tmp/kl_sim/`).
`tools/sim/run_qemu_esp32s3.sh` is the root-owned original — use the wrapper above instead.

The script:
1. Builds firmware if `--build` is passed (`pio run -e esp32s3_waveshare`)
2. Merges bootloader + partitions + firmware into a 16MB flash image via `esptool`
3. Boots QEMU with serial output to stdout
4. Kills QEMU after the timeout and analyzes the log for crashes

### What works

- ESP32-S3 bootloader and second-stage boot
- Application startup and FreeRTOS scheduler
- LCD panel initialization (returns an error, but firmware handles it gracefully)
- WiFi initialization up to the "waiting for connection" state
- Serial/UART output captured in log

### What does not work

| Feature | Reason |
|---------|--------|
| WiFi connectivity | No WiFi radio emulation in QEMU |
| I2S audio | I2S peripheral not emulated |
| PSRAM | Not emulated; firmware continues without it |
| LCD display | No display hardware; init error is expected |
| Touch input | No touch controller emulation |

### GDB debugging

Start QEMU paused with a GDB server on port 1234:

```bash
bash tools/sim/run_qemu_esp32s3.sh --gdb
```

In a second terminal, connect GDB:

```bash
xtensa-esp32s3-elf-gdb \
    firmware/.pio/build/esp32s3_waveshare/firmware.elf \
    -ex "target remote :1234"
```

Then use standard GDB commands (`break`, `continue`, `bt`, `info registers`, etc.).

### Log output

Logs are saved to `artifacts/sim/` with a timestamped filename:

```
artifacts/sim/qemu_20260325_143022.log
```

The script prints a summary after each run:
- **"Firmware ran for Ns without crash"** -- boot completed successfully
- **"ABORT detected"** -- firmware called `abort()`, check the log for the backtrace
- **"Firmware rebooted"** -- crash or watchdog triggered a reboot

---

## Level 3: Wokwi CI

Wokwi provides full ESP32-S3 simulation with WiFi, LCD, and I2S support, integrated into GitHub Actions.

### Status

**Configured** — files are in place. Requires a `WOKWI_CLI_TOKEN` GitHub Actions variable to activate the CI job.

### Files

| File | Purpose |
|---|---|
| `firmware/wokwi.toml` | Simulation config — ELF/BIN path, board type |
| `firmware/diagram.json` | Virtual board — ESP32-S3-DevKitC-1, serial monitor |
| `firmware/scenario.yaml` | Boot scenario — serial assertion test |

### Scenario (firmware/scenario.yaml)

```yaml
name: Kill_LIFE Boot Test
steps:
  - wait-serial: "[main] Kill_LIFE"
    timeout: 5000
  - wait-serial: "[wifi]"
    timeout: 10000
```

### CI job

The `firmware-sim` job in `.github/workflows/ci.yml` uses `wokwi/wokwi-ci-action@v1`. It runs only when `vars.WOKWI_CLI_TOKEN` is set. Set it at: GitHub → repo Settings → Variables and secrets.

### To activate

```bash
# 1. Create a Wokwi account and get a CI token from https://wokwi.com/dashboard/ci
# 2. Add as GitHub Actions variable WOKWI_CLI_TOKEN
# 3. Push a commit — the firmware-sim job will run automatically
```

---

## Troubleshooting

### PSRAM initialization error

```
E (xxx) spiram: SPI RAM not detected
```

**Expected in QEMU.** PSRAM is not emulated. The firmware is compiled with `-D BOARD_HAS_PSRAM` but continues without it. No action needed.

### LCD panel init error

```
E (xxx) lcd_panel: esp_lcd_panel_init failed
```

**Expected in QEMU.** No display hardware is emulated. The firmware logs the error and continues. No action needed.

### I2S driver conflict (historical)

```
E (xxx) i2s: i2s_driver_install ... conflict
```

This was caused by the legacy I2S driver API (`i2s_driver_install`) conflicting with the new channel API. **Fixed** by migrating `I2sMic` to the new `i2s_channel_*` API. If this reappears, check that no code mixes legacy and new I2S APIs.

### QEMU not found

```
[sim] ERROR: QEMU not found at tools/sim/qemu-system-xtensa
```

Download the Espressif QEMU fork from https://github.com/espressif/qemu/releases (v9.2.2 or later), extract `qemu-system-xtensa` into `tools/sim/`, and make it executable:

```bash
chmod +x tools/sim/qemu-system-xtensa
```

### ROM file missing

```
[sim] ERROR: ROM file not found at tools/sim/esp32s3_rev0_rom.bin
```

The ROM file ships with the Espressif QEMU release. Copy `esp32s3_rev0_rom.bin` into `tools/sim/`.
