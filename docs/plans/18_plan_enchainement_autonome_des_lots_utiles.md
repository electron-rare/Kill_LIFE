# 18) Plan d'enchainement autonome des lots utiles

Last updated: 2026-03-09 06:06:59

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

- branche: `## feat/mac-mcp-cad-host-bootstrap`
- dirty paths: `16`
- ahead: `0`
- behind: `0`

### Fichiers dirty detectes

- `docs/MCP_SETUP.md`
- `docs/plans/README.md`
- `mcp.json`
- `tools/bootstrap_mac_mcp.sh`
- `tools/hw/cad_stack.sh`
- `tools/hw/run_kicad_mcp.sh`
- `tools/lib/runtime_home.sh`
- `tools/mcp_smoke_common.py`
- `tools/run_github_dispatch_mcp.sh`
- `tools/run_knowledge_base_mcp.sh`
- `tools/validate_specs_mcp_smoke.py`
- `docs/plans/18_plan_enchainement_autonome_des_lots_utiles.md`
- `docs/plans/18_todo_enchainement_autonome_des_lots_utiles.md`
- `tools/autonomous_next_lots.py`
- `tools/run_autonomous_next_lots.sh`
- `tools/run_validate_specs_mcp.sh`

## Lots detectes

### 1. `mcp-runtime` — Alignement MCP runtime local

Stabiliser les launchers MCP, le bootstrap Mac, la resolution du repo compagnon et la doc operateur associee.

- references: `docs/plans/15_plan_mcp_runtime_alignment.md`, `docs/plans/17_plan_target_architecture_mcp_agentics_2028.md`
- validations: `3` done, `2` advisory, `0` blocked

### 2. `cad-mcp-host` — Runtime CAD host-first

Qualifier KiCad, FreeCAD et OpenSCAD en host-first sur macOS tout en gardant le fallback conteneur operable.

- references: `docs/plans/16_plan_cad_modeling_stack.md`, `docs/plans/17_plan_target_architecture_mcp_agentics_2028.md`
- validations: `4` done, `0` advisory, `0` blocked

### 3. `python-local` — Execution Python repo-locale

Garder les scripts et smokes sur l'interpreteur repo-local plutot que sur le Python systeme.

- references: `docs/plans/15_plan_mcp_runtime_alignment.md`
- validations: `1` done, `0` advisory, `0` blocked

## Questions a poser seulement si besoin reel

- Aucune question bloquante detectee sur ce cycle.

## Commandes operateur

- `bash tools/run_autonomous_next_lots.sh status`
- `bash tools/run_autonomous_next_lots.sh run`
- `bash tools/run_autonomous_next_lots.sh json`

