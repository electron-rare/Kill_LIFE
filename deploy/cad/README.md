# CAD Stack

Stack Docker CAD/EDA integree directement dans `Kill_LIFE`.

Backlogs canoniques associes:

- plan modelling local: `docs/plans/16_plan_cad_modeling_stack.md`
- TODO modelling local: `specs/cad_modeling_tasks.md`
- backlog cible MCP/agentics: `specs/mcp_agentics_target_backlog.md`

## Direction retenue

- `KiCad headless`: `kicad-cli` via une image KiCad 10
- `KiCad MCP`: `tools/hw/run_kicad_mcp.sh` et l'alias `tools/hw/cad_stack.sh mcp`
- `FreeCAD headless`: `FreeCADCmd`
- `OpenSCAD headless`: `openscad`
- `PlatformIO`: `pio` dans un conteneur Python leger

## Usage rapide

```bash
tools/hw/cad_stack.sh up
tools/hw/cad_stack.sh doctor
tools/hw/cad_stack.sh kicad-cli version
tools/hw/cad_stack.sh freecad-cmd -c "import FreeCAD; print('.'.join(FreeCAD.Version()[:3]))"
tools/hw/cad_stack.sh openscad --version
tools/hw/cad_stack.sh pio system info
tools/hw/cad_stack.sh mcp
python3 tools/hw/freecad_smoke.py --json
python3 tools/hw/openscad_smoke.py --json
```

Le workspace monte dans les conteneurs est la racine de `Kill_LIFE` par defaut.

## Statut modelling local

- `FreeCAD`: supporte en headless, avec smoke versionne `python3 tools/hw/freecad_smoke.py --json`
- `OpenSCAD`: supporte en headless, avec smoke versionne `python3 tools/hw/openscad_smoke.py --json`

Limites explicites:

- headless seulement
- pas d'UI graphique supportee dans cette stack locale
- les serveurs MCP `FreeCAD` et `OpenSCAD` restent des surfaces MCP separees; ils ne remplacent pas les wrappers CLI locaux

## MCP CAD locaux

Launchers supportes:

```bash
bash tools/run_freecad_mcp.sh --doctor
bash tools/run_openscad_mcp.sh --doctor
python3 tools/freecad_mcp_smoke.py --json
python3 tools/openscad_mcp_smoke.py --json
```

Statut:

- `freecad`: supporte en `stdio` local, visible aussi dans `python3 tools/mcp_runtime_status.py --json`
- `openscad`: supporte en `stdio` local, visible aussi dans `python3 tools/mcp_runtime_status.py --json`

## Variables utiles

- `KICAD_DOCKER_IMAGE`: image KiCad 10 a utiliser
- `CAD_WORKSPACE_DIR`: workspace monte dans `/workspace`
- `KILL_LIFE_RUNTIME_HOME` ou `KILL_LIFE_RUNTIME_BASE_DIR`: surcharge du runtime home des wrappers locaux et MCP

## Gouvernance

- la couche modelling locale `FreeCAD/OpenSCAD` reste gouvernee dans `specs/cad_modeling_tasks.md`
- la trajectoire MCP/agentics reste gouvernee dans `specs/mcp_agentics_target_backlog.md`
- `mcp_tasks.md` reste reserve au backlog KiCad MCP et auxiliaires associes
