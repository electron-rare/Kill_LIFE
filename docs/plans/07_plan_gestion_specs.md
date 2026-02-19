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
- [ ] Créer `specs/<id>-<slug>/`
- [ ] Écrire RFC2119 + AC + NFR

### 2. Validation
- [ ] Review humaine
- [ ] Lint spec (CI)

### 3. Injection dans l’exécution
- [ ] `ai:plan` génère architecture + ADR
- [ ] `ai:tasks` produit une checklist

### 4. Traçabilité
- [ ] Table “Requirement → Tests → Modules” (dans `verification.md`)
- [ ] Dans la PR d’impl : lien vers la spec + AC cochés

## Gates
- Gate spec lint (bloque `ai:impl` si spec invalide)
- Scope guard `ai:spec` (limite fichiers)

## Critère de sortie
✅ Specs versionnées, validées, reliées aux tests et aux PR.

## Références
- `docs/AI_WORKFLOWS.md`
- `docs/templates/ValidationPlan.md`