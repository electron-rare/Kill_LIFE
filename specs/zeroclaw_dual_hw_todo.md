# TODO: Dual hardware autonomy runbook (RTC + Zacus)

Last updated: 2026-02-21

## Immediate now

- [x] I-001 - Merge autonomie stack into `main` (`PR #5`).
- [x] I-002 - Configure local secret file `~/.zeroclaw/env` (`OPENROUTER_API_KEY` placeholder + mode `600`).
- [x] I-003 - Ensure local Prometheus backend exists (`prometheus` binary installed).
- [x] I-004 - Resolve open mirror PR redundancy (`PR #7` merge/close decision).

## Daily autonomous sequence

- [ ] D-001 - `tools/ai/zeroclaw_stack_down.sh` then `ZEROCLAW_PROM_MODE=auto tools/ai/zeroclaw_stack_up.sh`.
- [ ] D-002 - Smoke endpoints:
  - `curl -fsS http://127.0.0.1:3000/health`
  - `curl -fsS http://127.0.0.1:8788/`
  - `curl -fsS http://127.0.0.1:9090/-/ready`
- [ ] D-003 - RTC loop:
  - `tools/ai/zeroclaw_dual_chat.sh rtc --provider-check`
  - `tools/ai/zeroclaw_dual_chat.sh rtc --hardware`
  - repo build/test
  - webhook trace with `--repo-hint rtc`
- [ ] D-004 - Zacus loop:
  - `tools/ai/zeroclaw_dual_chat.sh zacus --provider-check`
  - `tools/ai/zeroclaw_dual_chat.sh zacus --hardware`
  - repo build/test
  - webhook trace with `--repo-hint zacus`
- [ ] D-005 - Review `artifacts/zeroclaw/gateway.log` + `conversations.jsonl`.

## Hardware safety gates

- [ ] H-001 - No flash/upload if `--hardware` detect returns no board.
- [ ] H-002 - Resolve stable serial target before upload.
- [ ] H-003 - Keep per-run logs under `artifacts/zeroclaw/`.

## Cost/control gates

- [ ] C-001 - Validate `tools/ai/zeroclaw_webhook_send.sh --dry-run`.
- [ ] C-002 - Validate hourly quota guard (`ZEROCLAW_WEBHOOK_MAX_CALLS_PER_HOUR`).
- [ ] C-003 - Validate message length guard (`ZEROCLAW_WEBHOOK_MAX_CHARS`).

## Exit criteria

- [ ] E-001 - One successful complete loop RTC in local hardware.
- [ ] E-002 - One successful complete loop Zacus in local hardware.
- [ ] E-003 - Dashboard live usable for continuous supervision.
- [ ] E-004 - Prometheus target scrape confirmed on gateway metrics.
