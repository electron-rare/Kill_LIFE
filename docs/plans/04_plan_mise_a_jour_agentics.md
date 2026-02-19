# 4) Plan mise à jour agentics

## Objectif
Mettre à jour les composants agentiques (workflows CI, prompts, policies) **sans élargir la surface d’attaque**.

## Labels recommandés
- Issue : `type:agentics` + `ai:plan` (ou `ai:docs` si pure doc)
- PR : `ai:plan`

## Étapes

### 1. Inventaire
- [ ] Versionner l’état actuel : workflows, scripts `tools/ai/*`, policies, prompts
- [ ] Lister les changements souhaités (ex : nouveaux agents, nouvelles gates)

### 2. Threat model minimal
- [ ] Qu’est‑ce qui augmente les privilèges ?
- [ ] Qu’est‑ce qui ajoute du réseau/outillage ?
- [ ] Qu’est‑ce qui touche aux secrets ?

### 3. Plan de rollout
- [ ] Feature flag / mode dry‑run (si possible)
- [ ] Déploiement en 2 PRs :
  - PR1 docs + tests
  - PR2 activation

### 4. Tests de non‑régression
- [ ] Label enforcement fonctionne
- [ ] Scope guard bloque bien les chemins interdits
- [ ] Sanitizer supprime toujours les patterns dangereux

### 5. Evidence pack
- [ ] Logs CI des gates
- [ ] Exemple d’issue test + PR générée

## Gates
- `Scope Guard` (bloque notamment `.github/workflows/` si denylist)
- `PR Label Enforcement`

## Critère de sortie
✅ Les nouveautés sont activées, CI verte, surface de privilèges inchangée ou réduite.

## Références
- `docs/security/anti_prompt_injection_policy.md`
- `docs/INTEGRATIONS.md`