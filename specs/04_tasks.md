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

- [ ] T-005 - Stabiliser pairing bearer auto
  - AC: `artifacts/zeroclaw/pair_token.txt` utilisable pour webhook sans override manuel.
  - Evidence: `tools/ai/zeroclaw_webhook_send.sh --repo-hint rtc "pairing check"`

## Boucle hardware RTC

- [x] T-101 - Discover hardware RTC
  - AC: au moins un port detecte pour carte RTC.
  - Evidence: `tools/ai/zeroclaw_dual_chat.sh rtc --hardware`

- [ ] T-102 - Build firmware RTC
  - AC: `pio run -e esp32dev` termine sans erreur bloquante.
  - Evidence: logs build RTC.

- [ ] T-103 - Upload + monitor RTC (forced default)
  - AC: `pio run -e esp32dev -t upload` puis monitor 60s executes.
  - Evidence: logs upload/monitor RTC.

- [ ] T-104 - Trace webhook RTC
  - AC: une ligne JSONL avec `repo_hint=rtc` apparait.
  - Evidence: `artifacts/zeroclaw/conversations.jsonl`

## Boucle hardware Zacus

- [x] T-201 - Discover hardware Zacus
  - AC: au moins un port detecte pour carte Zacus.
  - Evidence: `tools/ai/zeroclaw_dual_chat.sh zacus --hardware`

- [ ] T-202 - Build firmware Zacus
  - AC: `pio run -e esp32dev` (dans `hardware/firmware`) termine sans erreur bloquante.
  - Evidence: logs build Zacus.

- [ ] T-203 - Upload + monitor Zacus (forced default)
  - AC: `pio run -e esp32dev -t upload` puis monitor 60s executes.
  - Evidence: logs upload/monitor Zacus.

- [ ] T-204 - Trace webhook Zacus
  - AC: une ligne JSONL avec `repo_hint=zacus` apparait.
  - Evidence: `artifacts/zeroclaw/conversations.jsonl`

## Observabilite et cout

- [x] T-301 - Stack endpoints smoke
  - AC: `3000/health`, `8788`, `9090/-/ready` tous OK.
  - Evidence: captures `curl`.

- [ ] T-302 - Dry-run webhook budget
  - AC: `--dry-run` passe sans ecriture execution JSONL.
  - Evidence: sortie script + diff JSONL.

- [ ] T-303 - Quota call limiter
  - AC: depassement quota bloque avec code non-zero.
  - Evidence: message `[budget] hourly call limit reached`.

- [ ] T-304 - Quota chars limiter
  - AC: message trop long bloque avec code non-zero.
  - Evidence: message `[budget] message length ... exceeds ...`.

## Definition of done

- [ ] Au moins une boucle complete RTC + Zacus executee en local.
- [ ] Dashboard live exploitable pour suivi continu.
- [ ] Prometheus disponible avec target gateway scrapee.
- [ ] Logs et preuves archives dans `artifacts/zeroclaw/`.
- [ ] Aucune commande documentee n'utilise `-e native` ou `-e test`.
