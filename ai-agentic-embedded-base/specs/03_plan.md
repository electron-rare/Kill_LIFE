# Plan d'enchainement autonome des lots utiles

Last updated: 2026-03-09

## Objectif

Faire tourner une boucle locale simple:

1. detecter les lots auto-corrigeables,
2. les executer sans attente humaine inutile,
3. revalider le repo,
4. ne poser une question qu'au moment ou un vrai choix manuel devient necessaire.

## Scope

- `tools/cockpit/lot_chain.sh`
- `tools/autonomous_next_lots.py`
- `tools/run_autonomous_next_lots.sh`
- `tools/specs/sync_spec_mirror.sh`
- `tools/doc/readme_repo_coherence.sh`
- `tools/test_python.sh`
- `docs/plans/18_plan_enchainement_autonome_des_lots_utiles.md`
- `docs/plans/18_todo_enchainement_autonome_des_lots_utiles.md`
- `specs/03_plan.md`
- `specs/04_tasks.md`
- `specs/constraints.yaml`
- `ai-agentic-embedded-base/specs/`

## Regles d'enchainement

- Auto-fix avant validation.
- Validation stricte apres chaque lot.
- Plans/todos mis a jour depuis l'etat reel, pas a la main.
- Question operateur uniquement quand aucun lot auto n'est encore pertinent.

## Commandes canoniques

- `bash tools/cockpit/lot_chain.sh status`
- `bash tools/cockpit/lot_chain.sh all --yes`
- `bash tools/run_autonomous_next_lots.sh status`
- `bash tools/run_autonomous_next_lots.sh run`
- `bash tools/specs/sync_spec_mirror.sh all --yes`
- `bash tools/doc/readme_repo_coherence.sh all --yes`
- `python3 tools/validate_specs.py --strict --require-mirror-sync`
- `bash tools/test_python.sh --suite stable`

## Notes

- `specs/` reste la source de verite.
- `ai-agentic-embedded-base/specs/` reste un miroir exporte.
- `docs/plans/18_*` capture la lane runtime/MCP/CAD synchronisee par la boucle locale.
- Les choix manuels restants doivent etre surfaces via `artifacts/cockpit/next_question.md`.

## Statut auto

<!-- BEGIN AUTO LOT-CHAIN PLAN -->
- Auto-fix lots pending: `0`
- README/repo coherence: `done`
- Spec mirror sync: `done`
- MCP/CAD runtime lane sync: `synced`
- Strict spec contract: `passed`
- Stable Python suite: `passed`
- Next real need: none detected in the curated backlog list.
<!-- END AUTO LOT-CHAIN PLAN -->
