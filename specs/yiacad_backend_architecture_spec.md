# Spec - YiACAD backend architecture (T-ARCH-101)

## Probleme

YiACAD est desormais cadre comme une app independante, mais la resolution de contexte, la normalisation des sorties et l'acces aux moteurs CAD integres restent trop disperses. Cela freine `T-UX-004` et maintient une dependance trop forte au simple lancement de script.

## Objectifs

- Introduire une couche backend locale partagee pour le contexte YiACAD.
- Produire un artefact de contexte et un artefact de sortie normalisee pour chaque action YiACAD.
- Garder la compatibilite avec le shell YiACAD, les TUI existantes et les futures surfaces web.
- Exposer une frontiere d'integration explicite vers `KiCad`, `FreeCAD`, `KiBot`, `KiAuto` et les workers.
- Preparer la transition vers un backend YiACAD plus stable que le runner Python direct.
- Aligner la couche backend sur le SOT 2026:
  - `KiCad >= 10.0` via `IPC API`, `kicad-python`, `kicad-cli`
  - `FreeCAD >= 1.1` via Python API / workbench
  - `KiBot` et `KiAuto` en lanes Linux/Docker derriere des actions backend

## Non-objectifs

- faire des forks `KiCad` / `FreeCAD` la cible produit principale
- compiler un service embarque dans `KiCad` ou `FreeCAD` dans cette passe
- changer la semantique produit des actions deja exposees
- lancer une campagne de tests lourde

## Composants

- `tools/cad/yiacad_backend.py`
- `tools/cad/yiacad_backend_service.py`
- `tools/cad/yiacad_backend_client.py`
- `tools/cad/yiacad_native_ops.py`
- `specs/contracts/yiacad_context_broker.schema.json`
- `specs/contracts/yiacad_uiux_output.schema.json`
- runtime engines integres `KiCad`, `FreeCAD`, `KiBot`, `KiAuto`
- cadrage canonique:
  - `specs/yiacad_2026_stack_target_spec.md`
  - `specs/yiacad_adr_20260329_sot.md`
  - `specs/yiacad_plugin_workbench_ci_plan.md`

## Criteres d'acceptation

- chaque run YiACAD produit un `context.json`
- chaque run YiACAD produit un `uiux_output.json`
- la sortie JSON du runner peut etre demandee explicitement via `--json-output`
- une facade backend locale adressable existe pour l'operateur, l'app et les futurs clients
- les acces `KiCad` / `FreeCAD` / `KiBot` / `KiAuto` passent par une frontiere moteur explicite et non par la definition produit du shell
- les plans et TODOs pointent `T-ARCH-101` comme front architecture actif
- `T-UX-004` peut consommer les artefacts backend sans redefinir un nouveau contrat

## Prochaines tranches

1. `T-ARCH-101A`: backend local + context broker + contrats
2. `T-ARCH-101B`: facade backend locale adressable / transport interne YiACAD
3. `T-ARCH-101C`: branchement `service-first` des surfaces produit YiACAD
4. tranche suivante hors present lot: stabiliser les moteurs integres `KiCad` / `FreeCAD` / `KiBot` / `KiAuto` / workers

## Delta 2026-03-21 - T-ARCH-101C service-first

- `tools/cad/yiacad_backend_service.py` publie un backend HTTP local adressable.
- `tools/cad/yiacad_backend_client.py` apporte un chemin `service-first` avec auto-start et fallback direct.
- Norme produit `2026-03-29`: ce chemin `service-first` sert le shell YiACAD et ses moteurs integres; il ne suppose pas que `KiCad` ou `FreeCAD` soient les shells produit canoniques.

## Delta 2026-03-29 - engine boundary hardening

- Les surfaces produit doivent appeler le backend YiACAD, jamais `KiCad`, `FreeCAD`, `KiBot` ou `KiAuto` en direct.
- Le backend devient le seul endroit autorise pour faire respecter:
  - les floors de version `KiCad >= 10.0`, `FreeCAD >= 1.1`
  - la segregation `desktop authoring` / `web review` / `Linux manufacturing`
  - la publication de `engine_status`, `degraded_reasons`, `artifacts`, `next_steps`
