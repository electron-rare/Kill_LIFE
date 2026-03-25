# 7) Plan de gestion des specs

## Objectif
Mettre en place un process stable pour rédiger, valider et injecter les specs dans le workflow (sans dérive).

## Principes
- La spec est la **source de vérité**
- Toute implémentation doit référencer une spec
- Chaque exigence doit être **vérifiable**

## Labels recommandés
- `ai:spec` → produire/normaliser la spec
- `ai:plan` → architecture + verification plan
- `ai:tasks` → découpage exécutable
- `ai:impl` → code + tests

## Process

### 1. Rédaction
- [x] Créer `specs/<id>-<slug>/` — Delivered: 20+ spec files in `specs/`
- [x] Écrire RFC2119 + AC + NFR — Delivered: `specs/01_spec.md` + `specs/constraints.yaml`

### 2. Validation
- [x] Review humaine — Delivered: process in place
- [x] Lint spec (CI) — Delivered: `tools/validate_specs.py` + `tools/validate_specs_mcp_smoke.py`

### 3. Injection dans l’exécution
- [x] `ai:plan` génère architecture + ADR — Delivered: `specs/02_arch.md` + `specs/03_plan.md`
- [x] `ai:tasks` produit une checklist — Delivered: `specs/04_tasks.md`

### 4. Traçabilité
- [x] Table “Requirement → Tests → Modules” (dans `verification.md`) — Delivered: `docs/AGENT_SPEC_MODULE_MATRIX_2026-03-20.md`
- [x] Dans la PR d’impl : lien vers la spec + AC cochés — Delivered: `.github/pull_request_template.md` (PR template with spec link + AC checklist)

## Gates
- Gate spec lint (bloque `ai:impl` si spec invalide)
- Scope guard `ai:spec` (limite fichiers)

## Critère de sortie
✅ Specs versionnées, validées, reliées aux tests et aux PR.

## Références
- `docs/AI_WORKFLOWS.md`
- `docs/templates/ValidationPlan.md`