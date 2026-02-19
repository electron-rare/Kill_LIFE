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
- [ ] Créer les labels `ai:*` et `type:*` (voir `docs/LABELS.md`)
- [ ] Vérifier que les Actions sont activées
- [ ] Vérifier les secrets nécessaires (si utilisés) : `OPENAI_API_KEY`, `COPILOT_GITHUB_TOKEN`

### 2. Setup local (5–10 min)
- [ ] Créer un venv Python
- [ ] Installer PlatformIO
- [ ] Vérifier que `pio` fonctionne

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
- [ ] Ouvrir une issue “Hello World” (ex : “Ajouter un heartbeat LED + log boot”) via template Feature
- [ ] Ajouter `ai:spec` → attendre la PR
- [ ] Relire la PR (spec RFC2119 + critères d’acceptation)
- [ ] Ajouter `ai:impl` sur la PR (ou sur l’issue, selon votre config) → attendre mise à jour

### 4. Vérifier CI / sécurité
- [ ] Label enforcement passe (PR contient au moins un `ai:*`)
- [ ] Scope guard passe (pas de fichiers hors scope)
- [ ] Build/test passent (ou sont “SKIP” justifié)

### 5. Evidence pack minimal
- [ ] La PR contient :
  - [ ] lien vers l’issue
  - [ ] logs CI pertinents (artefacts)
  - [ ] capture du comportement (si UI/hardware)

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