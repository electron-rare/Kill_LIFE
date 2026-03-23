# 16) Plan de stack CAD modelling locale (`FreeCAD` + `OpenSCAD`)

Last updated: 2026-03-08

Plan canonique cote `Kill_LIFE` pour la couche modelling locale hors KiCad MCP.

Sources de verite associees:

- `deploy/cad/README.md`
- `tools/hw/cad_stack.sh`
- `specs/cad_modeling_tasks.md`
- `specs/mcp_agentics_target_backlog.md`

## Objectif

Faire de `Kill_LIFE` la source de verite operateur pour une stack modelling locale simple:

- `FreeCAD` pour le scripting Python parametrique et les verifications headless
- `OpenSCAD` pour le rendu declaratif CLI et les exports non interactifs

Le lot couvre la couche locale non-MCP. Les serveurs MCP dedies sont suivis dans le backlog cible `MCP` / `agentics`.

Important:

- ce plan couvre la stack modelling locale `FreeCAD/OpenSCAD` hors shell GUI YiACAD;
- les surfaces GUI natives KiCad/FreeCAD et la refonte UI/UX Apple-native sont suivies dans `docs/plans/20_plan_refonte_ui_ux_yiacad_apple_native.md`.

## Etat actuel

- `FreeCAD` est supporte en headless via `freecadcmd`
- `OpenSCAD` est supporte en headless via `openscad`
- `tools/hw/cad_stack.sh` expose `freecad-cmd` et `openscad`
- `python3 tools/hw/freecad_smoke.py --json` est vert
- `python3 tools/hw/openscad_smoke.py --json` est vert

## Decisions figees

- `Kill_LIFE` reste le repo canonique de la stack CAD locale
- `FreeCAD` et `OpenSCAD` sont supportes en headless local
- ce lot reste distinct de `mcp_tasks.md`
- la suite MCP se traite dans `specs/mcp_agentics_target_backlog.md`
- la couche GUI YiACAD est geree separement et ne remet pas en cause ce contrat headless

## Resultat v1 livre

### FreeCAD

1. wrapper operateur stable via `tools/hw/cad_stack.sh freecad-cmd`
2. smoke versionne:
   - import `FreeCAD`
   - creation d'un document minimal
   - sauvegarde locale
3. statut explicite: `supporte`

### OpenSCAD

1. runtime headless `openscad-headless`
2. wrapper operateur stable via `tools/hw/cad_stack.sh openscad`
3. smoke versionne:
   - version CLI
   - rendu d'un modele minimal
   - export local
4. statut explicite: `supporte`

## Travail restant

Le lot modelling local v1 est ferme.

Le travail restant est du maintien:

1. garder les smokes verts
2. garder `deploy/cad/README.md` et `cad_stack.sh` alignes
3. traiter les evolutions MCP dans `specs/mcp_agentics_target_backlog.md`

## Criteres de sortie

- `Kill_LIFE` publie une doc operateur claire pour `FreeCAD` et `OpenSCAD`
- `FreeCAD` a un smoke versionne et un statut supporte explicite
- `OpenSCAD` a un conteneur, un wrapper CLI et un smoke versionne
- aucun lecteur ne confond ce lot avec le backlog KiCad MCP
