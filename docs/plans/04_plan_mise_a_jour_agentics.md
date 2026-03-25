# 4) Plan mise à jour agentics

## Objectif
Mettre à jour les composants agentiques (workflows CI, prompts, policies) **sans élargir la surface d’attaque**.

## Labels recommandés
- Issue : `type:agentics` + `ai:plan` (ou `ai:docs` si pure doc)
- PR : `ai:plan`

## Étapes

### 1. Inventaire
- [x] Versionner l’état actuel : workflows, scripts `tools/ai/*`, policies, prompts — Delivered: `docs/repo_state.json` + `docs/REPO_STATE.md`
- [x] Lister les changements souhaités (ex : nouveaux agents, nouvelles gates) — Delivered: `docs/AGENT_MODULE_ASSIGNMENTS_2026-03-20.md` + `docs/AGENT_SPEC_MODULE_MATRIX_2026-03-20.md`

### 2. Threat model minimal
- [x] Qu’est‑ce qui augmente les privilèges ? — Delivered: `docs/security/anti_prompt_injection_policy.md`
- [x] Qu’est‑ce qui ajoute du réseau/outillage ? — Delivered: `docs/MCP_SERVICE_BOUNDARY.md`
- [x] Qu’est‑ce qui touche aux secrets ? — Delivered: `.github/workflows/secret_scan.yml`

### 3. Plan de rollout
- [x] Feature flag / mode dry‑run (si possible) — Delivered: lot chain has `--no-write` mode in `tools/run_autonomous_next_lots.sh`
- [x] Déploiement en 2 PRs :
  - PR1 docs + tests
  - PR2 activation
  — Obsolete: superseded by autonomous lot chain with handoff contracts (plan 18)

### 4. Tests de non‑régression
- [x] Label enforcement fonctionne — Delivered: `.github/workflows/ci.yml`
- [x] Scope guard bloque bien les chemins interdits — Delivered: `tools/scope_guard.py` + `tools/scope_policy.py`
- [x] Sanitizer supprime toujours les patterns dangereux — Delivered: `tools/ai/sanitize_issue.py`

### 5. Evidence pack
- [x] Logs CI des gates — Delivered: `.github/workflows/evidence_pack.yml` + `tools/collect_evidence.py`
- [x] Exemple d’issue test + PR générée — Obsolete: superseded by plan 18 autonomous lot evidence

## Gates
- `Scope Guard` (bloque notamment `.github/workflows/` si denylist)
- `PR Label Enforcement`

## Critère de sortie
✅ Les nouveautés sont activées, CI verte, surface de privilèges inchangée ou réduite.

## Références
- `docs/security/anti_prompt_injection_policy.md`
- `docs/INTEGRATIONS.md`