# Plan d'execution autonome local (RTC + Zacus)

Last updated: 2026-02-21

## Objectif

Atteindre une boucle autonome locale stable sur les deux repos branches au hardware:

- `RTC_BL_PHONE`
- `le-mystere-professeur-zacus`

avec:

- stack ZeroClaw local operationnel (`3000`, `8788`, `9090`),
- dev/test reproductible sur chaque repo,
- preflight hardware systematique avant toute action firmware,
- traces et preuves dans `artifacts/zeroclaw/`.

## Criteres de succes

- `tools/ai/zeroclaw_stack_up.sh` lance gateway + follow + Prometheus (binary ou docker fallback).
- `http://127.0.0.1:8788/` affiche les conversations et logs en live.
- `http://127.0.0.1:9090/targets` est reachable (Prometheus up).
- `tools/ai/zeroclaw_dual_chat.sh rtc --provider-check` et `... zacus --provider-check` passent.
- Au moins une boucle dev/test complete par repo est executee et tracee.

## Contraintes

- Local only (loopback `127.0.0.1`), pas d'exposition publique.
- Secrets hors git (`~/.zeroclaw/env`, mode `600`).
- Cout modele borne par quotas webhook locaux.
- Flash/upload/serial monitor forces par defaut apres detection hardware valide.
- Jamais de commande `pio` sur un env non declare dans `platformio.ini`.

## Plan par phases

## Phase 0 - Preflight (auth + outils)

Actions:

1. Verifier `gh auth status`.
2. Verifier `zeroclaw auth status`.
3. Verifier `~/.zeroclaw/env` contient `OPENROUTER_API_KEY=...` et permissions `600`.
4. Verifier backend Prometheus local:
   - binaire `prometheus`, sinon docker daemon.

Sortie attendue:

- environnement provider OK,
- fallback Prometheus disponible.

## Phase 1 - Stack local ZeroClaw

Actions:

1. `tools/ai/zeroclaw_stack_down.sh`
2. `ZEROCLAW_PROM_MODE=auto tools/ai/zeroclaw_stack_up.sh`
3. Verifs:
   - `curl -fsS http://127.0.0.1:3000/health`
   - `curl -fsS http://127.0.0.1:8788/`
   - `curl -fsS http://127.0.0.1:9090/-/ready`

Sortie attendue:

- gateway healthy,
- dashboard live actif,
- Prometheus ready.

## Phase 2 - Boucle autonome RTC

Actions:

1. Provider check: `tools/ai/zeroclaw_dual_chat.sh rtc --provider-check`
2. Hardware discover: `tools/ai/zeroclaw_dual_chat.sh rtc --hardware`
3. Build/test firmware repo RTC:
   - `cd /Users/cils/Documents/Lelectron_rare/RTC_BL_PHONE`
   - `pio run -e esp32dev`
   - `pio run -e esp32dev -t upload`
   - `pio device monitor -p <port> -b 115200` (capture 60s)
   - ou commande unique: `tools/ai/zeroclaw_hw_firmware_loop.sh rtc`
4. Trace webhook:
   - `tools/ai/zeroclaw_webhook_send.sh --repo-hint rtc "rtc loop status ..."`

Sortie attendue:

- build RTC passe ou echec documente avec logs,
- ligne JSONL enrichie pour la boucle RTC.

## Phase 3 - Boucle autonome Zacus

Actions:

1. Provider check: `tools/ai/zeroclaw_dual_chat.sh zacus --provider-check`
2. Hardware discover: `tools/ai/zeroclaw_dual_chat.sh zacus --hardware`
3. Build/test firmware repo Zacus:
   - `cd /Users/cils/Documents/Lelectron_rare/le-mystere-professeur-zacus/hardware/firmware`
   - `pio run -e esp32dev`
   - `pio run -e esp32dev -t upload`
   - `pio device monitor -p <port> -b 115200` (capture 60s)
   - ou commande unique: `tools/ai/zeroclaw_hw_firmware_loop.sh zacus`
   - statut tests: `blocked` tant que dossier `test/` absent
4. Trace webhook:
   - `tools/ai/zeroclaw_webhook_send.sh --repo-hint zacus "zacus loop status ..."`

Sortie attendue:

- build Zacus passe ou echec documente avec logs,
- ligne JSONL enrichie pour la boucle Zacus.

## Phase 4 - Stabilisation autonomie

Actions:

1. Dry-run budget: `tools/ai/zeroclaw_webhook_send.sh --dry-run "budget probe"`
2. Verifier quota state: `artifacts/zeroclaw/webhook_budget.json`
3. Verifier logs:
   - `artifacts/zeroclaw/gateway.log`
   - `artifacts/zeroclaw/conversations.jsonl`
4. Mettre a jour TODO (`specs/04_tasks.md` + `specs/zeroclaw_dual_hw_todo.md`).

Sortie attendue:

- boucles previsibles,
- cout controle,
- preuves a jour.

## Cadence autonome quotidienne

1. Preflight auth + hardware.
2. Stack up + smoke endpoints.
3. RTC loop (build + upload + monitor + webhook trace).
4. Zacus loop (build + upload + monitor + webhook trace).
5. Review logs + correction ciblée.
6. Commit/PR petit lot.
