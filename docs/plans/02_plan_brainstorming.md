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
- [ ] Fixer une durée (30/60/90 min)
- [ ] Définir un “owner” de la décision

### 3. Sortie attendue
- [ ] Une recommandation claire
- [ ] Une décision explicite (ADR léger)
- [ ] Une issue “Feature” créée à partir de la décision

### 4. Transition vers agentics
Quand prêt :
- [ ] Ajouter `ai:spec` sur l’issue Feature issue (pas sur Brainstorm)

## Gates
- Pas de gate CI ici
- Gate humain : décision écrite + création de l’issue Feature

## Critère de sortie
✅ Une décision (ADR) + une issue Feature “spec‑ready”.

## Références
- `docs/templates/ADR.md`
- `docs/workflows/consulting.md`