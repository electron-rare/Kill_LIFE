# Spec - YiACAD backend architecture (T-ARCH-101)

## Probleme

YiACAD dispose deja de shells natifs et d'un runner local utile, mais la resolution de contexte, la normalisation des sorties et la lecture des artefacts restent trop dispersées. Cela freine `T-UX-004` et maintient une dependance trop forte au simple lancement de script.

## Objectifs

- Introduire une couche backend locale partagee pour le contexte YiACAD.
- Produire un artefact de contexte et un artefact de sortie normalisee pour chaque action YiACAD.
- Garder la compatibilite avec les shells natifs actuels et les TUI existantes.
- Preparer la transition vers un backend YiACAD plus stable que le runner Python direct.

## Non-objectifs

- compiler un service natif KiCad/FreeCAD complet dans cette passe
- changer la semantique produit des actions deja exposees
- lancer une campagne de tests lourde

## Composants

- `tools/cad/yiacad_backend.py`
- `tools/cad/yiacad_backend_service.py`
- `tools/cad/yiacad_native_ops.py`
- `specs/contracts/yiacad_context_broker.schema.json`
- `specs/contracts/yiacad_uiux_output.schema.json`

## Criteres d'acceptation

- chaque run YiACAD produit un `context.json`
- chaque run YiACAD produit un `uiux_output.json`
- la sortie JSON du runner peut etre demandee explicitement via `--json-output`
- une facade backend locale adressable existe pour l’operateur et les futurs shells
- les plans et TODOs pointent `T-ARCH-101` comme front architecture actif
- `T-UX-004` peut consommer les artefacts backend sans redefinir un nouveau contrat

## Prochaines tranches

1. `T-ARCH-101A`: backend local + context broker + contrats
2. `T-ARCH-101B`: facade backend locale adressable / transport interne YiACAD
3. `T-ARCH-101C`: branchement natif de `palette`, `review center`, `inspector`

## Delta 2026-03-21 - T-ARCH-101C service-first

- `tools/cad/yiacad_backend_service.py` publie un backend HTTP local adressable.
- `tools/cad/yiacad_backend_client.py` apporte un chemin `service-first` avec auto-start et fallback direct.
- les surfaces actives Python YiACAD sont maintenant recablees sur le client backend.
