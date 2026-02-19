# 12) Plan de gestion des agents

## Objectif
Définir rôles, prompts, rituels, gates, handoffs et evidence pack pour garder un système agentique stable.

## Labels recommandés
- `type:agentics` + `ai:plan`

## Étapes

### 1. Rôles
- [ ] PM
- [ ] Architect
- [ ] Firmware
- [ ] Hardware
- [ ] QA
- [ ] Doc

### 2. Prompts standard
Chaque prompt doit définir :
- Entrées (sanitisées)
- Sorties attendues (artefacts)
- Contraintes (scope, denylist)
- Format de rapport

### 3. Handoffs
- [ ] Handoff Firmware
- [ ] Handoff Hardware
- [ ] Handoff Design
- [ ] Handoff Creative

### 4. Gates
- [ ] Label enforcement
- [ ] Scope guard
- [ ] Build/test
- [ ] Compliance (si applicable)

### 5. Evidence pack
- [ ] Logs CI
- [ ] Diffs
- [ ] Décisions (ADR)

## Critère de sortie
✅ Les agents sont utiles, prédictibles, et “safe by default”.

## Références
- `docs/handoffs/*`
- `docs/rituals/*`