# TODO: Dual hardware autonomy runbook (RTC + Zacus)

Last updated: 2026-02-21

## Immediate now

- [x] I-001 - Merge autonomie stack into `main` (`PR #5`).
- [x] I-002 - Configure local secret file `~/.zeroclaw/env` (`OPENROUTER_API_KEY` placeholder + mode `600`).
- [x] I-003 - Ensure local Prometheus backend exists (`prometheus` binary installed).
- [x] I-004 - Resolve open mirror PR redundancy (`PR #7` merge/close decision).
- [x] I-005 - Enable local AI fallback (`ollama` + local model) for credit savings.
- [x] I-006 - Enforce local-only chat mode option (`--local-only`) with `ollama/lmstudio` detection.
- [x] I-007 - Align OpenClaw default model to local `ollama/llama3.2:1b` + cloud fallbacks for continuity.
- [x] I-008 - Add provider/agentic scanner (`tools/ai/zeroclaw_provider_scan.sh`) for live capability matrix.

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

- [x] D-006 - Corriger l'association cible↔port
  - `RTC_UPLOAD_PORT_HINT` cible Audio Kit (`cp2102`, `esp32audiokit`, `audio`).
  - `ZACUS_UPLOAD_PORT_HINT` cible Freenove/S3 (`usbmodem`, `1a86`, `ch340`, `freenove`).
  - status: `2026-02-21` done.

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

## Integrations (Open WebUI + n8n)

- [x] I-201 - Add mixed Open WebUI Pipe mapping (`zc.router` + dedicated models).
- [x] I-202 - Add n8n PR autotriage workflow (webhook + cron fallback).
- [x] I-203 - Add local docker compose stack for Open WebUI (`3001`) and n8n (`5678`).
- [x] I-204 - Add runtime scripts (`integrations_up/down/status`, `import_n8n`, `openwebui_assist`).
- [ ] I-205 - Validate end-to-end import + activation on local Docker runtime.
  - command: `tools/ai/zeroclaw_integrations_up.sh`
  - command: `tools/ai/zeroclaw_integrations_status.sh`
  - command: `tools/ai/zeroclaw_integrations_import_n8n.sh`
