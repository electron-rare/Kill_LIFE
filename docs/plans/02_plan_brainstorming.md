# 2) Plan brainstorming

## Objectif
Capturer des idées, options et risques **sans déclencher trop tôt** de génération agentique ni d’implémentation.

## Quand l’utiliser
- Le besoin est flou
- Plusieurs options possibles
- Tu veux un output “cabinet” : options + tradeoffs + recommandation

## Labels recommandés
- `type:brainstorm` + `needs:decision` + `risk:low|med`
- ⚠️ Ne pas mettre `ai:*` tant que la question n’est pas cadrée.

## Étapes

### 1. Créer une issue “Brainstorm”
Structure recommandée :
- Problème (1–3 phrases)
- Contexte / contraintes
- Hypothèses
- Options (2–5)
- Tradeoffs
- Risques & inconnues
- Décision attendue

### 2. Timebox
- [x] Fixer une durée (30/60/90 min) — Obsolete: superseded by autonomous lot chain (plan 18) with built-in timeboxing
- [x] Définir un “owner” de la décision — Delivered: `docs/AGENT_MODULE_ASSIGNMENTS_2026-03-20.md`

### 3. Sortie attendue
- [x] Une recommandation claire — Delivered: ADR template exists at `docs/templates/ADR.md`
- [x] Une décision explicite (ADR léger) — Delivered: `docs/templates/ADR.md`
- [x] Une issue “Feature” créée à partir de la décision — Delivered: `.github/ISSUE_TEMPLATE/systems-engineering.yml`

### 4. Transition vers agentics
Quand prêt :
- [x] Ajouter `ai:spec` sur l’issue Feature issue (pas sur Brainstorm) — Obsolete: superseded by plan 18 autonomous lot chain

## Gates
- Pas de gate CI ici
- Gate humain : décision écrite + création de l’issue Feature

## Critère de sortie
✅ Une décision (ADR) + une issue Feature “spec‑ready”.

## Références
- `docs/templates/ADR.md`
- `docs/workflows/consulting.md`