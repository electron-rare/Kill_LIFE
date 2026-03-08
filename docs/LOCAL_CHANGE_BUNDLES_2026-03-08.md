# Local Change Bundles — 2026-03-08

But: sortir le worktree `Kill_LIFE` en lots publiables reellement alignes sur
le delta courant, et non plus seulement "reviewables par sujet".

## Etat courant

Le delta `Kill_LIFE` se lit maintenant en `3` lots publiables plus un reliquat
runtime local non versionnable:

1. `mcp-runtime`
2. `cad-mcp`
3. `python-local`
4. `.mascarade/` = runtime local genere, a exclure des commits

Le helper de revue associe reste:

```bash
bash tools/review_local_change_bundle.sh <bundle> [status|diff|paths]
```

## Lot 1 — `mcp-runtime`

Objet:

- remplacer les anciennes surfaces `notion` par `knowledge-base`
- figer le `runtime home` local et le statut MCP courant
- aligner GitHub dispatch et la doc MCP sur le contrat reel

Fichiers:

- `README.md`
- `ai-agentic-embedded-base/specs/README.md`
- `ai-agentic-embedded-base/specs/knowledge_base_mcp_spec.md`
- `ai-agentic-embedded-base/specs/mcp_tasks.md`
- `ai-agentic-embedded-base/specs/notion_mcp_conversion_spec.md`
- `ai-agentic-embedded-base/specs/zeroclaw_dual_hw_todo.md`
- `docs/LOCAL_CHANGE_BUNDLES_2026-03-08.md`
- `docs/MCP_ECOSYSTEM_MATRIX.md`
- `docs/MCP_SETUP.md`
- `docs/MCP_SUPPORT_MATRIX.md`
- `docs/RUNTIME_HOME.md`
- `docs/plans/15_plan_mcp_runtime_alignment.md`
- `docs/plans/README.md`
- `mcp.json`
- `specs/README.md`
- `specs/knowledge_base_mcp_spec.md`
- `specs/mcp_tasks.md`
- `specs/notion_mcp_conversion_spec.md`
- `test/test_knowledge_base_mcp.py`
- `test/test_notion_mcp.py`
- `tools/github_dispatch_mcp_smoke.py`
- `tools/knowledge_base_mcp.py`
- `tools/knowledge_base_mcp_smoke.py`
- `tools/lib/runtime_home.sh`
- `tools/mcp_runtime_status.py`
- `tools/mcp_smoke_common.py`
- `tools/notion_mcp.py`
- `tools/notion_mcp_smoke.py`
- `tools/review_local_change_bundle.sh`
- `tools/run_github_dispatch_mcp.sh`
- `tools/run_knowledge_base_mcp.sh`
- `tools/run_notion_mcp.sh`

Validation minimale:

```bash
cd /home/clems/Kill_LIFE && bash tools/test_python.sh --suite stable
cd /home/clems/Kill_LIFE && python3 tools/validate_specs.py --json
```

## Lot 2 — `cad-mcp`

Objet:

- pile CAD/MCP locale (`FreeCAD`, `OpenSCAD`, compose CAD, runtime status)
- specs, plans et docs operateur associes
- smokes et launchers dedies a cette pile

Fichiers:

- `Makefile`
- `ai-agentic-embedded-base/specs/cad_modeling_tasks.md`
- `ai-agentic-embedded-base/specs/mcp_agentics_target_backlog.md`
- `deploy/cad/README.md`
- `deploy/cad/Dockerfile.openscad-headless`
- `deploy/cad/docker-compose.yml`
- `docs/plans/16_plan_cad_modeling_stack.md`
- `docs/plans/17_plan_target_architecture_mcp_agentics_2028.md`
- `specs/cad_modeling_tasks.md`
- `specs/mcp_agentics_target_backlog.md`
- `test/test_freecad_mcp.py`
- `test/test_openscad_mcp.py`
- `tools/cad_runtime.py`
- `tools/freecad_mcp.py`
- `tools/freecad_mcp_smoke.py`
- `tools/hw/cad_stack.sh`
- `tools/hw/freecad_smoke.py`
- `tools/hw/openscad_smoke.py`
- `tools/mcp_telemetry.py`
- `tools/openscad_mcp.py`
- `tools/openscad_mcp_smoke.py`
- `tools/run_freecad_mcp.sh`
- `tools/run_openscad_mcp.sh`

Validation minimale:

```bash
cd /home/clems/Kill_LIFE && bash tools/hw/cad_stack.sh doctor
cd /home/clems/Kill_LIFE && bash tools/hw/cad_stack.sh doctor-mcp
```

## Lot 3 — `python-local`

Objet:

- garder un chemin de test repo-local stable et publiable
- maintenir la commande Python minimale supportee dans le delta courant

Fichiers:

- `tools/test_python.sh`

Validation repo-locale:

```bash
cd /home/clems/Kill_LIFE && bash tools/test_python.sh --suite stable
```

## Exclusion explicite

Ne pas versionner le runtime local genere:

- `.mascarade/mcp/github-dispatch/*.json`

Ces fichiers servent d'evidence locale runtime, pas de source de verite repo.

## Ordre recommande

1. publier `mcp-runtime`
2. publier `cad-mcp`
3. publier `python-local`

Ce decoupage evite de melanger:

- la migration `notion -> knowledge-base` et la hygiene runtime MCP
- la pile CAD/MCP et ses smokes associes
- le contrat Python repo-local minimal
