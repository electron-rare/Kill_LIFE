---
description: "Use when modifying or validating firmware workflows, PlatformIO targets, firmware tests, or hardware-in-the-loop checks in Kill_LIFE."
name: "Firmware Domain"
applyTo: "firmware/**"
---
# Firmware Domain Instructions

## Focus

- Keep changes scoped to firmware behavior and platform targets.
- Respect existing PlatformIO environments and test harness conventions.

## Verify With

- `cd firmware && pio run -e esp32s3_waveshare`
- `cd firmware && pio test -e native`
- `bash tools/test_python.sh --suite stable` when contracts or tooling are impacted.

## Review/Change Guardrails

- Avoid cross-domain refactors from firmware files.
- Preserve CI assumptions used by `.github/workflows/ci.yml`.
- If behavior changes, update related specs/tasks under `specs/`.
