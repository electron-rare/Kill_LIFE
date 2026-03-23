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

## Integrations (n8n)

- [x] I-202 - Add n8n PR autotriage workflow (webhook + cron fallback).
- [x] I-203 - Add local docker compose stack for n8n (`5678`).
- [x] I-204 - Add runtime scripts (`integrations_up/down/status`, `import_n8n`).
- [x] I-205 - Validate end-to-end import + activation on local Docker runtime.
  - status: `2026-03-09` done (`mascarade-n8n` healthy, `kill-life-n8n-smoke` active via local CLI import/publish path).
  - statut local courant: `2026-03-20` restauré sur cette machine.
  - détail: Docker Desktop relancé, conteneur `mascarade-n8n` auto-provisionné depuis `docker.n8n.io/n8nio/n8n`, HTTP local `5678` OK.
  - correction appliquée: le workflow smoke utilise désormais un `Schedule Trigger` annuel activable; le chemin CLI officiel `publish:workflow` reste prioritaire, avec fallback legacy `update:workflow --active=true`.
  - récupération locale `2026-03-21`: les scripts sondent maintenant `healthz`, échouent vite sur les timeouts Docker, et peuvent court-circuiter l'import si la DB n8n contient déjà le workflow conforme et actif.
  - incident local `2026-03-21`: un workflow historique `manualTrigger` restait stocké dans la base SQLite n8n et le runtime local a nécessité une réinitialisation contrôlée du conteneur/volume avec sauvegarde avant de repartir sur une DB saine.
  - résultat courant:
    - `python3 -m unittest discover -s test -p 'test_zeroclaw_n8n_workflow_contract.py'` -> `OK`
    - `bash tools/ai/zeroclaw_integrations_status.sh --json` -> `status=ready`
    - `bash tools/ai/zeroclaw_integrations_import_n8n.sh --json` -> `imported|skipped / published|skipped / active=true`
    - `bash tools/ai/zeroclaw_integrations_lot.sh verify --json` -> `overall_status=ready`
  - command: `bash tools/ai/zeroclaw_integrations_up.sh --json`
  - command: `bash tools/ai/zeroclaw_integrations_status.sh --json`
  - command: `bash tools/ai/zeroclaw_integrations_import_n8n.sh --json`
  - evidence:
    - `{"status":"ready","reason":"","container":"mascarade-n8n","host_http_ok":true,"internal_http_ok":true,"n8n_health_url":"http://127.0.0.1:5678/healthz"}`
    - `{"workflow_id":"kill-life-n8n-smoke","import_action":"imported|skipped","publish_action":"published|skipped","active":true}`
    - `artifacts/cockpit/zeroclaw_n8n_recovery_2026-03-21/live_volume_backup/`
