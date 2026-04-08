<!-- Parent: ../AGENTS.md -->
# firmware/ AGENTS

## Purpose
Embedded firmware for ESP32-S3 (multi-target: QEMU, Arduino, native unit tests). PlatformIO orchestration, Unity test framework.

## Directory Structure
```
firmware/
  platformio.ini        # 5 environments: esp32s3_waveshare, esp32s3_qemu, arduino, native
  src/
    main.cpp           # Entry point, setup(), loop()
    *.cpp              # Driver implementations
  include/
    *.h                # Headers, config.h
  test/
    test_*.cpp         # Unity unit tests
  lib/                 # Local libraries
  scenario.yaml        # Integration test scenarios
  diagram.json         # Wokwi simulator config
```

## Key Files
| File | Purpose |
|------|---------|
| platformio.ini | Build envs, compiler flags, dependencies, test config |
| src/main.cpp | Arduino setup/loop, hardware init, state machine |
| test/ | Unity C tests (runs natively + QEMU) |
| scenario.yaml | Multi-agent integration scenarios |
| diagram.json | Wokwi simulator circuit |

## Environments (platformio.ini)
| Env | Target | Use Case | CI |
|-----|--------|----------|-----|
| esp32s3_waveshare | Real hardware (Waveshare dev board) | Integration testing | manual |
| esp32s3_qemu | QEMU emulator | Automated CI, no hardware |  pytest ci_runtime.py |
| arduino | Arduino IDE compatible board | Alt hardware target | optional |
| native | x86_64 host CPU | Unit test execution | pytest |

## Build & Test
```bash
cd firmware && pio run                    # Build default (esp32s3_waveshare)
cd firmware && pio run -e esp32s3_qemu    # QEMU build
cd firmware && pio test -e native         # Unit tests (Unity)
cd firmware && pio run -e esp32s3_qemu && bash ../tools/qemu_boot.sh  # Boot QEMU
```

## Testing Strategy
- **Unit tests:** Unity framework in test/ (arithmetic, state machines, driver logic)
- **Integration:** scenario.yaml defines multi-step test flows
- **QEMU automation:** ci_runtime.py orchestrates QEMU boot + test
- **Hardware:** manual on Waveshare dev board (documented in docs/evidence/)

## Agent Workflow (Firmware Agent)
1. Read spec → specs/01_spec.md (MUST/SHOULD requirements)
2. Implement in src/ (add unit tests in test/)
3. Verify: `pio test -e native` passes
4. QEMU: `pio run -e esp32s3_qemu` + scenario.yaml execution
5. Evidence: screenshot/log to docs/evidence/

## CI Integration
- GitHub Actions dispatches firmware builds via MCP
- platformio_mcp.py provides ["build", "test", "upload"] tools
- ci_runtime.py monitors build status
- Scope guard: ai:impl label required for firmware/ PRs

## See Also
- ../CLAUDE.md for full build commands
- specs/01_spec.md for functional requirements
- test_firmware_evidence.py for CI contract validation
