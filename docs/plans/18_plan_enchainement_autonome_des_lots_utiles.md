# 18) Plan d'enchainement autonome des lots utiles

Last updated: 2026-03-09 06:29:29

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
- dirty paths: `0`
- ahead: `0`
- behind: `0`

## Lots detectes

- Aucun lot local utile detecte.
- Si le repo est clean et a jour, le prochain lot utile devient un chantier decide par l'operateur.

## Questions a poser seulement si besoin reel

- Aucune question bloquante detectee sur ce cycle.

## Commandes operateur

- `bash tools/run_autonomous_next_lots.sh status`
- `bash tools/run_autonomous_next_lots.sh run`
- `bash tools/run_autonomous_next_lots.sh json`

