# Spec - YiACAD UI/UX Apple-native

## Contexte

`YiACAD` est une app independante pilotee par la lane IA-native de `Kill_LIFE`. `KiCad`, `FreeCAD` et les runtimes CAD restent des moteurs integres de la plateforme YiACAD. La presente spec cadre la refonte UI/UX Apple-native du shell YiACAD.

Ancrages canoniques `2026-03-29`:

- `specs/yiacad_2026_stack_target_spec.md`
- `specs/yiacad_adr_20260329_sot.md`
- `specs/yiacad_90_day_delivery_plan.md`

## Objectifs

- unifier l'experience YiACAD desktop, web et cockpit autour d'une architecture coherente;
- rendre les actions `review`, `sync`, `inspect` et `artifacts` immédiatement accessibles;
- intégrer l’IA comme assistance contextualisée, traçable et révocable;
- aligner la hiérarchie visuelle sur les patterns Apple/macOS actuels.

## Non-objectifs

- ne pas réécrire immédiatement les noyaux ECAD/MCAD;
- ne pas faire de `KiCad` ou `FreeCAD` le shell produit principal;
- ne pas auto-appliquer des correctifs IA sur les modèles CAD.

## Principes UX

- `clarity`: navigation lisible, faible bruit, labels explicites;
- `context`: détails et suggestions dans l’inspector, pas dans des modales en cascade;
- `focus`: toolbar courte, actions primaires visibles, secondaires dans la palette;
- `traceability`: chaque sortie IA renvoie vers les artefacts et preuves;
- `reversibility`: aucune action destructive implicite.

## Architecture fonctionnelle

```mermaid
flowchart LR
  Sidebar["Sidebar taches"] --> Canvas["YiACAD project view"]
  Toolbar["Toolbar"] --> Canvas
  Palette["Palette commandes"] --> Canvas
  Canvas --> Inspector["Inspector contextuel"]
  Inspector --> AI["IA contextualisée"]
  AI --> Artifacts["Artifacts / logs / preuves"]
```

## Capacités clés

| Capability | Description | Entrée | Sortie |
| --- | --- | --- | --- |
| `review.erc_drc` | lancer et résumer `ERC` + `DRC` | board + schematic | rapports JSON + digest |
| `review.bom` | exporter et auditer une BOM | schematic | CSV + résumé des champs vides |
| `sync.ecad_mcad` | exporter les artefacts STEP croisés | board + document FreeCAD | STEP + résumé de sync |
| `status.surface` | exposer l’état YiACAD | artefacts existants | snapshot markdown |
| `ai.explain` | expliquer un warning/signal | sélection utilisateur | explication + provenance |

## Contrat d’intégration IA

- l’IA n’est qu’une couche d’assistance;
- toutes les suggestions doivent être rattachées à une preuve ou à un artefact;
- les commandes doivent rester utilisables sans modèle distant;
- les sorties doivent être enregistrées dans `artifacts/cad-ai-native/`.

## Instrumentation

- surfaces utilisateur: shell YiACAD, TUI cockpit et futurs clients web;
- utilitaires concrets: `tools/cad/yiacad_native_ops.py`;
- backend partage: `tools/cad/yiacad_backend_service.py` et `tools/cad/yiacad_backend_client.py`;
- TUI de pilotage: `tools/cockpit/yiacad_uiux_tui.sh`;
- documentation de référence: `docs/YIACAD_APPLE_UI_UX_*`.

## Mesures de succès

- temps moyen pour lancer une review réduit;
- nombre d’étapes manuelles entre CAD et artefacts réduit;
- état et provenance compréhensibles sans lire les scripts;
- convergence visuelle entre le shell YiACAD, le web et le cockpit.

## Plan de livraison

### Phase 1

- audit, spec, feature map, recherche, plan et TODO;
- shell app autonome + contrats de sortie;
- TUI dédiée UI/UX.
- socle `desktop-first authoring` sur `KiCad >= 10.0` et `FreeCAD >= 1.1`.

### Phase 2

- command palette;
- review center;
- inspector contextuel.

### Phase 3

- stabilisation des moteurs integres CAD et des imports/exports;
- extension vers App Intents / automatisation locale lorsque la pile est prete;
- raccord complet plugin `KiCad`, workbench `FreeCAD`, et lanes Linux `KiBot` / `KiAuto`.
