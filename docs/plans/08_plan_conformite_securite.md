# 8) Plan de conformité & sécurité

## Objectif
Valider les profils, auditer les scripts/workflows, appliquer la politique anti‑prompt‑injection, et définir le sandboxing.

## Labels recommandés
- `type:compliance` + `ai:plan`

## Étapes

### 1. Profils conformité
- [ ] Choisir un profil (ex : `iot_wifi_eu`)
- [ ] Vérifier les exigences : radio, EMC, LVD, étiquetage

### 2. Audit CI & secrets
- [ ] Vérifier permissions des workflows (`permissions:` minimales)
- [ ] Vérifier usage secrets (pas d’echo, pas de logs)
- [ ] Activer branch protection + checks requis

### 3. Anti prompt injection
- [ ] Sanitizer activé avant injection prompt
- [ ] Scope guard par label `ai:*`
- [ ] Denylist pour chemins sensibles
- [ ] Procédure incident (`ai:hold`)

### 4. Sandboxing
- [ ] Les agents write‑capable passent via safe outputs
- [ ] OpenClaw : VM/Docker isolé, actions non destructives

### 5. Evidence pack
- [ ] Checklists remplies
- [ ] Export du profil compliance
- [ ] Résultats gates CI

## Gates
- Label enforcement + scope guard
- Compliance checks (si activés)

## Critère de sortie
✅ Profil choisi, politiques en place, CI verrouillée, et runbook incident validé.

## Références
- `docs/COMPLIANCE.md`
- `docs/security/anti_prompt_injection_policy.md`