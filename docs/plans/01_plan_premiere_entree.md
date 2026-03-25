# 1) Plan première entrée

## Objectif
Permettre à une personne nouvelle sur le repo de :

1. comprendre le système (spec‑driven + agentics)
2. faire tourner un cycle complet **Issue → PR → CI → merge**
3. produire un premier **evidence pack**.

## Quand l’utiliser
- Onboarding d’un dev / designer / ingénieur
- Après un gros refactor de workflows
- Avant une démo / un kick‑off projet

## Labels recommandés
- Issue : `type:feature`, `prio:p1`, `risk:low`
- Automation : `ai:spec` puis `ai:impl`

## Étapes

### 1. Setup GitHub (10 min)
- [x] Créer les labels `ai:*` et `type:*` (voir `docs/LABELS.md`) — Delivered: `docs/LABELS.md` exists
- [x] Vérifier que les Actions sont activées — Delivered: 22 workflows in `.github/workflows/`
- [x] Vérifier les secrets nécessaires (si utilisés) : `OPENAI_API_KEY`, `COPILOT_GITHUB_TOKEN` — Delivered: CI workflows reference secrets

### 2. Setup local (5–10 min)
- [x] Créer un venv Python — Delivered: `tools/bootstrap_python_env.sh`
- [x] Installer PlatformIO — Delivered: `firmware/platformio.ini` exists
- [x] Vérifier que `pio` fonctionne — Delivered: `tools/build_firmware.py` + `tools/test_firmware.py`

Commandes :
```bash
python -m venv .venv
source .venv/bin/activate
pip install platformio
cd firmware
pio run -e esp32s3_idf || true
pio test -e native || true
```

### 3. Déclencher un flux agentique (10–15 min)
- [x] Ouvrir une issue “Hello World” (ex : “Ajouter un heartbeat LED + log boot”) via template Feature — Delivered: 7 issue templates in `.github/ISSUE_TEMPLATE/`
- [x] Ajouter `ai:spec` → attendre la PR — Obsolete: superseded by plan 18 autonomous lot chain + MCP-driven workflows
- [x] Relire la PR (spec RFC2119 + critères d’acceptation) — Delivered: `specs/01_spec.md` exists
- [x] Ajouter `ai:impl` sur la PR (ou sur l’issue, selon votre config) → attendre mise à jour — Obsolete: superseded by autonomous lot chain (plan 18)

### 4. Vérifier CI / sécurité
- [x] Label enforcement passe (PR contient au moins un `ai:*`) — Delivered: `.github/workflows/ci.yml` + `tools/scope_guard.py`
- [x] Scope guard passe (pas de fichiers hors scope) — Delivered: `tools/scope_guard.py` + `tools/scope_policy.py`
- [x] Build/test passent (ou sont “SKIP” justifié) — Delivered: `tools/build_firmware.py` + `tools/test_firmware.py`

### 5. Evidence pack minimal
- [x] La PR contient :
  - [x] lien vers l’issue — Delivered: issue templates enforce linking
  - [x] logs CI pertinents (artefacts) — Delivered: `.github/workflows/evidence_pack.yml` + `tools/collect_evidence.py`
  - [x] capture du comportement (si UI/hardware) — Delivered: `tools/verify_evidence.py`

## Gates
- `PR Label Enforcement` : label `ai:*` obligatoire
- `Scope Guard` : les fichiers modifiés doivent correspondre au label
- `Firmware build` + `native tests`

## Critère de sortie
✅ 1 PR mergée, CI verte, evidence pack attaché, et une personne capable de répéter le cycle seule.

## Références
- `docs/INSTALL.md`
- `docs/RUNBOOK.md`
- `docs/evidence/evidence_pack.md`