# TODO: Dual hardware autonomy runbook (RTC + Zacus)

Last updated: 2026-02-21

## Immediate now

- [x] I-001 - Merge autonomie stack into `main` (`PR #5`).
- [x] I-002 - Configure local secret file `~/.zeroclaw/env` (`OPENROUTER_API_KEY` placeholder + mode `600`).
- [x] I-003 - Ensure local Prometheus backend exists (`prometheus` binary installed).
- [x] I-004 - Resolve open mirror PR redundancy (`PR #7` merge/close decision).
- [x] I-005 - Enable local AI fallback (`ollama` + local model) for credit savings.

## Daily autonomous sequence

- [x] D-001 - `tools/ai/zeroclaw_stack_down.sh` then `ZEROCLAW_PROM_MODE=auto tools/ai/zeroclaw_stack_up.sh`.
- [x] D-002 - Smoke endpoints:
  - `curl -fsS http://127.0.0.1:3000/health`
  - `curl -fsS http://127.0.0.1:8788/`
  - `curl -fsS http://127.0.0.1:9090/-/ready`
- [x] D-003 - RTC loop:
  - `tools/ai/zeroclaw_dual_chat.sh rtc --provider-check`
  - `tools/ai/zeroclaw_dual_chat.sh rtc --hardware`
  - `tools/ai/zeroclaw_hw_firmware_loop.sh rtc` (build+upload+monitor forced default)
  - webhook trace with `--repo-hint rtc`
  - status: `2026-02-21` done (flash + monitor + webhook HTTP 200).
- [x] D-004 - Zacus loop:
  - `tools/ai/zeroclaw_dual_chat.sh zacus --provider-check`
  - `tools/ai/zeroclaw_dual_chat.sh zacus --hardware`
  - `tools/ai/zeroclaw_hw_firmware_loop.sh zacus` (build+upload+monitor forced default)
  - webhook trace with `--repo-hint zacus`
  - status: `2026-02-21` done (ESP32-S3 mismatch auto-corrected to `freenove_esp32s3`).
- [x] D-005 - Review `artifacts/zeroclaw/gateway.log` + `conversations.jsonl`.

## Hardware safety gates

- [x] H-001 - Flash/upload/monitor are forced by default when a board is detected.
- [x] H-002 - Resolve stable serial target before upload.
- [x] H-003 - Keep per-run logs under `artifacts/zeroclaw/`.

## Cost/control gates

- [x] C-001 - Validate `tools/ai/zeroclaw_webhook_send.sh --dry-run`.
- [x] C-002 - Validate hourly quota guard (`ZEROCLAW_WEBHOOK_MAX_CALLS_PER_HOUR`).
- [x] C-003 - Validate message length guard (`ZEROCLAW_WEBHOOK_MAX_CHARS`).

## Exit criteria

- [x] E-001 - One successful complete loop RTC in local hardware.
- [x] E-002 - One successful complete loop Zacus in local hardware.
- [x] E-003 - Dashboard live usable for continuous supervision.
- [x] E-004 - Prometheus target scrape confirmed on gateway metrics.
