# Tasks autonomie locale (execution)

Last updated: 2026-02-21

Format:

- `[ ]` non fait
- `[x]` fait
- `AC` = acceptance criteria
- `Evidence` = fichier/commande de preuve

## Sprint actuel

- [x] T-001 - Merger la PR autonomie ZeroClaw
  - AC: PR mergee sur `main`.
  - Evidence: `https://github.com/electron-rare/Kill_LIFE/pull/5`

- [x] T-002 - Fermer ou merger la PR miroir restante
  - AC: plus de PR redondante ouverte pour le meme scope.
  - Evidence: `gh pr list --state open`

- [x] T-003 - Configurer secret fallback OpenRouter local
  - AC: `~/.zeroclaw/env` present avec `OPENROUTER_API_KEY` et mode `600`.
  - Evidence: `ls -l ~/.zeroclaw/env`

- [x] T-004 - Installer backend Prometheus local
  - AC: commande `prometheus --version` disponible.
  - Evidence: sortie shell `prometheus, version ...`

- [x] T-005 - Stabiliser pairing bearer auto
  - AC: `artifacts/zeroclaw/pair_token.txt` utilisable pour webhook sans override manuel.
  - Evidence: `tools/ai/zeroclaw_webhook_send.sh --repo-hint rtc "pairing check"`
  - Status: `2026-02-21` done (401 resolved + webhook HTTP 200 after provider/model auto-fix in stack bootstrap).

- [x] T-006 - Activer fallback IA locale (macOS)
  - AC: `ollama` installe, service actif, modele local disponible, stack capable de le preferer.
  - Evidence: `tools/ai/ollama_local_setup.sh --no-pull --no-warmup` + config `default_provider = "ollama"`.
  - Status: `2026-02-21` done (`llama3.2:1b` local); mode local est optionnel via `ZEROCLAW_PREFER_LOCAL_AI=1` pour garder la fiabilite webhook par defaut.

- [x] T-007 - Renforcer mode local-only agentic (ZeroClaw + OpenClaw)
  - AC: `tools/ai/zeroclaw_dual_chat.sh <repo> --local-only --provider-check` choisit un provider local (`ollama` ou `lmstudio`) sinon exit explicite.
  - Evidence: sortie provider-check + `openclaw models status --plain`.
  - Status: `2026-02-21` done (`openclaw` default model force sur `ollama/llama3.2:1b`, fallbacks `openai-codex` puis `openrouter`).

- [x] T-008 - Scanner les options provider/agentic disponibles
  - AC: rapport local avec statut runtime `openclaw/ollama/lmstudio/litellm` et matrice providers ZeroClaw.
  - Evidence: `tools/ai/zeroclaw_provider_scan.sh --no-refresh` -> `artifacts/zeroclaw/provider_options.md`.
  - Status: `2026-02-21` done.

- [x] T-009 - Verrouiller le mapping matériel par cible
  - AC: la détection automatique affecte `zacus` aux ports `usbmodem`/S3 et `rtc` à l’Audio Kit (pas d’interversion habituelle).
  - Evidence:
    - `ZEROCLAW_ZACUS_UPLOAD_PORT_HINT="1a86,usbmodem,ch340,freenove" tools/ai/zeroclaw_hw_firmware_loop.sh zacus --port '' --monitor-secs 5`
    - `ZEROCLAW_RTC_UPLOAD_PORT_HINT="cp2102,10c4,esp32audiokit,audio" tools/ai/zeroclaw_hw_firmware_loop.sh rtc --port '' --monitor-secs 5`
  - Status: `2026-02-21` done (`usbmodem` prioritaire pour zacus, `usbmodem` pénalisé pour rtc).

## Boucle hardware RTC

- [x] T-101 - Discover hardware RTC
  - AC: au moins un port detecte pour carte RTC.
  - Evidence: `tools/ai/zeroclaw_dual_chat.sh rtc --hardware`

- [x] T-102 - Build firmware RTC
  - AC: `pio run -e esp32dev` termine sans erreur bloquante.
  - Evidence: logs build RTC.
  - Status: `2026-02-21` done.

- [x] T-103 - Upload + monitor RTC (forced default)
  - AC: `pio run -e esp32dev -t upload` puis monitor 60s executes.
  - Evidence: logs upload/monitor RTC.
  - Status: `2026-02-21` done (`ESP32-D0WD-V3` flash + serial monitor output captured).

- [x] T-104 - Trace webhook RTC
  - AC: une ligne JSONL avec `repo_hint=rtc` apparait.
  - Evidence: `artifacts/zeroclaw/conversations.jsonl`
  - Status: `2026-02-21` done (`http_status=200`, `ok=true`).

## Boucle hardware Zacus

- [x] T-201 - Discover hardware Zacus
  - AC: au moins un port detecte pour carte Zacus.
  - Evidence: `tools/ai/zeroclaw_dual_chat.sh zacus --hardware`

- [x] T-202 - Build firmware Zacus
  - AC: `pio run -e esp32dev` (dans `hardware/firmware`) termine sans erreur bloquante.
  - Evidence: logs build Zacus.
  - Status: `2026-02-21` done.

- [x] T-203 - Upload + monitor Zacus (forced default)
  - AC: `pio run -e <env valide> -t upload` puis monitor executes.
  - Evidence: logs upload/monitor Zacus.
  - Status: `2026-02-21` done (`ESP32-S3` detecte, env fallback `freenove_esp32s3`, flash + monitor OK).

- [x] T-204 - Trace webhook Zacus
  - AC: une ligne JSONL avec `repo_hint=zacus` apparait.
  - Evidence: `artifacts/zeroclaw/conversations.jsonl`
  - Status: `2026-02-21` done (`http_status=200`, `ok=true`).

## Observabilite et cout

- [x] T-301 - Stack endpoints smoke
  - AC: `3000/health`, `8788`, `9090/-/ready` tous OK.
  - Evidence: captures `curl`.

- [x] T-302 - Dry-run webhook budget
  - AC: `--dry-run` passe sans ecriture execution JSONL.
  - Evidence: sortie script + diff JSONL.
  - Status: `2026-02-21` done.

- [x] T-303 - Quota call limiter
  - AC: depassement quota bloque avec code non-zero.
  - Evidence: message `[budget] hourly call limit reached`.
  - Status: `2026-02-21` done (test sandbox local `max_calls=1`, second call blocked with exit 12).

- [x] T-304 - Quota chars limiter
  - AC: message trop long bloque avec code non-zero.
  - Evidence: message `[budget] message length ... exceeds ...`.
  - Status: `2026-02-21` done (`ZEROCLAW_WEBHOOK_MAX_CHARS=5`, exit 11).

## Integrations Open WebUI + n8n

- [x] T-401 - Ajouter API alerts + autotriage backend
  - AC: endpoints `/api/alerts`, `/api/alerts/ack`, `/api/pr/autotriage` disponibles.
  - Evidence: `tools/ai/zeroclaw_orchestrator_server.py`.

- [x] T-402 - Etendre WebUI orchestrateur
  - AC: panneau Alerts + Integrations status + action `PR autotriage now`.
  - Evidence: `tools/ai/zeroclaw_stack_up.sh`.

- [x] T-403 - Refactor Pipe Open WebUI en mapping mixte
  - AC: pipe expose `zc.router` + modeles dedies et parsing `/run`/`/pr`.
  - Evidence: `tools/ai/integrations/openwebui/zeroclaw_orchestrator_pipe.py`.

- [x] T-404 - Ajouter workflow n8n PR autotriage
  - AC: workflow avec Webhook + Cron fallback + alert/question outputs.
  - Evidence: `tools/ai/integrations/n8n/zeroclaw_pr_autotriage_workflow.json`.

- [x] T-405 - Ajouter provisioning local Docker integrations
  - AC: compose + scripts `up/down/status` + import n8n + assist Open WebUI.
  - Evidence:
    - `tools/ai/integrations/docker/docker-compose.openwebui-n8n.yml`
    - `tools/ai/zeroclaw_integrations_up.sh`
    - `tools/ai/zeroclaw_integrations_down.sh`
    - `tools/ai/zeroclaw_integrations_status.sh`
    - `tools/ai/zeroclaw_integrations_import_n8n.sh`
    - `tools/ai/zeroclaw_integrations_openwebui_assist.sh`

## Definition of done

- [x] Au moins une boucle complete RTC + Zacus executee en local.
- [x] Dashboard live exploitable pour suivi continu.
- [x] Prometheus disponible avec target gateway scrapee.
- [x] Logs et preuves archives dans `artifacts/zeroclaw/`.
- [x] Aucune commande documentee n'utilise `-e native` ou `-e test`.
