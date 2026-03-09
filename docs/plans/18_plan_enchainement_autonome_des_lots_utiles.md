# 18) Plan d'enchainement autonome des lots utiles

Last updated: 2026-03-09 06:29:16

Ce plan est regenere localement par `tools/autonomous_next_lots.py`.

## Objectif

Detecter les deltas utiles a traiter, prioriser le prochain lot executable,
mettre a jour un plan/todo operateur, puis relancer les validations associees.

## Regles de priorite

1. lot dirty avec validations requises cassables
2. lot dirty avec validations advisory ou docs
3. repo clean mais en retard sur le remote
4. regime stable sans lot local detecte

## Etat Git courant

- branche: `## main...origin/main`
- dirty paths: `10`
- ahead: `0`
- behind: `0`

### Fichiers dirty detectes

- `ai-agentic-embedded-base/specs/03_plan.md`
- `ai-agentic-embedded-base/specs/04_tasks.md`
- `docs/plans/18_plan_enchainement_autonome_des_lots_utiles.md`
- `docs/plans/18_todo_enchainement_autonome_des_lots_utiles.md`
- `specs/03_plan.md`
- `specs/04_tasks.md`
- `tools/ai/integrations/n8n/README.md`
- `tools/autonomous_next_lots.py`
- `tools/cockpit/README.md`
- `tools/cockpit/lot_chain.sh`

## Lots detectes

### 1. `zeroclaw-integrations` — Runtime local ZeroClaw / n8n

Fermer la lane d'integrations locales ZeroClaw/n8n, les evidences I-205 associees, puis resynchroniser les plans versionnes d'enchainement autonome et le cockpit local.

- references: `specs/zeroclaw_dual_hw_todo.md`, `docs/plans/18_plan_enchainement_autonome_des_lots_utiles.md`
- validations: `3` done, `0` advisory, `0` blocked

## Questions a poser seulement si besoin reel

- Aucune question bloquante detectee sur ce cycle.

## Commandes operateur

- `bash tools/run_autonomous_next_lots.sh status`
- `bash tools/run_autonomous_next_lots.sh run`
- `bash tools/run_autonomous_next_lots.sh json`

