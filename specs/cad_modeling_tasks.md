# Tasks CAD modelling local

Last updated: 2026-03-08

Backlog canonique pour `FreeCAD` et `OpenSCAD` dans `Kill_LIFE`.

References:

- doc operateur: `deploy/cad/README.md`
- launcher: `tools/hw/cad_stack.sh`
- plan canonique: `docs/plans/16_plan_cad_modeling_stack.md`
- backlog MCP/agentics: `specs/mcp_agentics_target_backlog.md`

Format:

- `[ ]` non fait
- `[x]` fait

## Etat courant

- `FreeCAD` est supporte en headless via `freecadcmd`
- `OpenSCAD` est supporte en headless via `openscad`
- les deux runtimes ont un smoke JSON versionne
- le lot modelling local v1 est ferme; la suite MCP est suivie ailleurs

## Backlog

- [x] C-001 — Fixer un plan canonique `FreeCAD/OpenSCAD`
  - AC: un plan unique existe et renvoie vers un backlog executable sans dupliquer le backlog MCP.

- [x] C-002 — Fixer un backlog canonique `FreeCAD/OpenSCAD`
  - AC: `specs/cad_modeling_tasks.md` devient la source de verite des taches modelling locales.

- [x] C-003 — Documenter explicitement le statut reel `FreeCAD` / `OpenSCAD`
  - AC: `deploy/cad/README.md` indique clairement les statuts supportes et leurs limites.

- [x] C-004 — Ajouter un smoke `FreeCAD` versionne
  - AC: `python3 tools/hw/freecad_smoke.py --json` verifie version, creation d'un document minimal et sauvegarde headless.

- [x] C-005 — Declarer `FreeCAD` supporte avec smoke
  - AC: la doc operateur classe `FreeCAD` comme supporte apres smoke vert.

- [x] C-006 — Ajouter le runtime `OpenSCAD` headless
  - AC: `Dockerfile.openscad-headless` et un service `openscad-headless` existent dans `deploy/cad/`.

- [x] C-007 — Etendre `cad_stack.sh` avec `openscad`
  - AC: `tools/hw/cad_stack.sh openscad --version` passe sur la machine de reference.

- [x] C-008 — Ajouter un smoke `OpenSCAD` versionne
  - AC: `python3 tools/hw/openscad_smoke.py --json` verifie version CLI, rendu minimal et export local.

- [x] C-009 — Classer `OpenSCAD` comme supporte ou experimental
  - AC: la doc operateur porte un statut explicite. Statut retenu: `supporte` en headless local.

- [x] C-010 — Garder le lot hors backlog MCP
  - AC: la gouvernance modelling local reste separee de `mcp_tasks.md`; les suites MCP vont dans `specs/mcp_agentics_target_backlog.md`.

## Prochaine sequence canonique

Le lot modelling local v1 est clos.

La suite se deplace dans `specs/mcp_agentics_target_backlog.md`:

1. maintenir les smokes `FreeCAD/OpenSCAD`
2. garder la doc operateur et le compose CAD alignes
3. traiter les evolutions MCP dans le backlog cible, pas ici
