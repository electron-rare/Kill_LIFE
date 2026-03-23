# CAD Stack

Last updated: 2026-03-14

Stack Docker CAD/EDA integree directement dans `Kill_LIFE`.

Important:

- cette stack reste la base headless et containerisee;
- YiACAD ajoute des surfaces GUI natives utilisateur dans KiCad et FreeCAD;
- la strategie GUI/native est documentee dans `docs/CAD_AI_NATIVE_GUI_RUNBOOK_2026-03-20.md`, `docs/CAD_AI_NATIVE_HOOKS_2026-03-20.md` et `docs/YIACAD_APPLE_UI_UX_AUDIT_2026-03-20.md`.

Backlogs canoniques associes:

- plan modelling local: `docs/plans/16_plan_cad_modeling_stack.md`
- TODO modelling local: `specs/cad_modeling_tasks.md`
- backlog cible MCP/agentics: `specs/mcp_agentics_target_backlog.md`
- backlog MCP/provenance: `specs/mcp_tasks.md`
- benchmark KiCad adjacent: `docs/KICAD_BENCHMARK_MATRIX.md`

## Direction retenue

- `KiCad headless`: `kicad-cli` via une image KiCad 10
- `KiCad MCP`: `tools/hw/run_kicad_mcp.sh` et l'alias `tools/hw/cad_stack.sh mcp`
- `FreeCAD headless`: `FreeCADCmd`
- `OpenSCAD headless`: `openscad`
- `PlatformIO`: `pio` dans un conteneur Python leger

## Provenance outillage CAD

- `officiel`: surface publiee par le projet ou l'organisation qui own l'outil
- `community valide`: projet tiers etabli, retenu comme reference ou benchmark
- `custom local`: wrapper, launcher ou garde-fou maintenu dans `Kill_LIFE`

| Surface / outil | Provenance | Statut | Usage retenu |
| --- | --- | --- | --- |
| `KiCad.app` + `kicad-cli` + image KiCad 10 | officiel | supporte | source de verite headless pour ERC/DRC/export |
| `FreeCADCmd` + releases FreeCAD | officiel | supporte | modelling headless et backend du serveur `freecad` |
| `OpenSCAD` CLI + releases/snapshots | officiel | supporte | rendu/export headless et backend du serveur `openscad` |
| `KiAuto` | community valide | benchmark outille | appoint opt-in si un lot concret demande plus de checks/export que `kicad-cli` + `kicad-mcp` |
| `kicad-automation-scripts` | community valide | benchmark classe | reference historique pour patterns Docker/doc; pas de promotion runtime par defaut |
| `InteractiveHtmlBom` | community valide | reference utile | BOM interactive offline si la couche doc/fabrication le justifie |
| `tools/hw/cad_stack.sh`, `tools/hw/run_kicad_mcp.sh`, `tools/run_freecad_mcp.sh`, `tools/run_openscad_mcp.sh`, `tools/tui/cad_mcp_audit.sh`, `tools/tui/kicad_benchmark_review.sh` | custom local | supporte | wrappers, garde-fou et helper doc benchmark operateur `Kill_LIFE` |

Le classement `custom local` ne change jamais la source de verite runtime: les wrappers `Kill_LIFE` restent bornes par les binaires officiels detectes ou par les fallbacks conteneurises supportes.

## Usage rapide

```bash
tools/hw/cad_stack.sh up
tools/hw/cad_stack.sh doctor
tools/hw/cad_stack.sh kicad-cli version
tools/hw/cad_stack.sh freecad-cmd -c "import FreeCAD; print('.'.join(FreeCAD.Version()[:3]))"
tools/hw/cad_stack.sh openscad --version
tools/hw/cad_stack.sh pio system info
tools/hw/cad_stack.sh mcp
bash tools/tui/kicad_benchmark_review.sh report
bash tools/tui/kicad_benchmark_review.sh purge --yes
python3 tools/hw/freecad_smoke.py --json
python3 tools/hw/openscad_smoke.py --json
```

Le workspace monte dans les conteneurs est la racine de `Kill_LIFE` par defaut.

## Statut modelling local

- `FreeCAD`: supporte en headless, avec smoke versionne `python3 tools/hw/freecad_smoke.py --json`
- `OpenSCAD`: supporte en headless, avec smoke versionne `python3 tools/hw/openscad_smoke.py --json`

Limites explicites:

- la stack Docker documentee ici reste headless par nature
- l'UI graphique YiACAD ne passe pas par ces conteneurs, mais par les surfaces natives utilisateur KiCad/FreeCAD
- les serveurs MCP `FreeCAD` et `OpenSCAD` restent des surfaces MCP separees; ils ne remplacent ni les wrappers CLI locaux ni les surfaces GUI YiACAD

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
- `mcp_tasks.md` porte le lot provenance MCP/CAD; `docs/KICAD_BENCHMARK_MATRIX.md` fixe la decision benchmark `KiAuto` / `kicad-automation-scripts`
- `bash tools/tui/cad_mcp_audit.sh audit` reste le garde-fou minimal avant toute promotion documentaire ou operateur du lot MCP/CAD
