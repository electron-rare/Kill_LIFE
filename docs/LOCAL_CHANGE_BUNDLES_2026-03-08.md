# Local Change Bundles — 2026-03-08

But: reduire la derive locale de `Kill_LIFE` en regroupant le worktree en lots revus/publies par sujet.

## Etat courant

Le worktree local n'est plus un melange de dizaines de sujets heterogenes. Il se lit maintenant en `2` lots principaux:

1. `mcp-runtime`
2. `python-local`

Le helper de revue associe est:

```bash
bash tools/review_local_change_bundle.sh <bundle> [status|diff|paths]
```

## Lot 1 — `mcp-runtime`

Objet:

- `runtime home` local explicite pour les launchers MCP et CAD
- smokes MCP alignes sur les modes d'auth reels
- doc operateur associee

Fichiers:

- `.gitignore`
- `ai-agentic-embedded-base/specs/mcp_tasks.md`
- `docs/QUICKSTART.md`
- `docs/index.md`
- `docs/RUNTIME_HOME.md`
- `tools/github_dispatch_mcp_smoke.py`
- `tools/hw/kicad_cli.sh`
- `tools/hw/run_kicad_mcp.sh`
- `tools/lib/runtime_home.sh`
- `tools/notion_mcp.py`
- `tools/notion_mcp_smoke.py`
- `tools/run_github_dispatch_mcp.sh`
- `tools/run_nexar_mcp.sh`
- `tools/run_notion_mcp.sh`

Revue:

```bash
bash tools/review_local_change_bundle.sh mcp-runtime status
bash tools/review_local_change_bundle.sh mcp-runtime diff
```

## Lot 2 — `python-local`

Objet:

- bootstrap Python repo-local stable
- commande de tests repo-locale stable
- harness de tests ajustes pour ce chemin supporte

Fichiers:

- `README.md`
- `test/test_openclaw_sanitizer.py`
- `tools/bootstrap_python_env.sh`
- `tools/hw/schops/tests/test_rules_engine.py`
- `tools/test_python.sh`

Revue:

```bash
bash tools/review_local_change_bundle.sh python-local status
bash tools/review_local_change_bundle.sh python-local diff
```

Validation repo-locale:

```bash
bash tools/bootstrap_python_env.sh
bash tools/test_python.sh --suite stable
```

## Ordre recommande

1. publier ou reviewer `mcp-runtime`
2. publier ou reviewer `python-local`

Ce decoupage evite de melanger:

- la hygiene runtime des launchers MCP
- le contrat operateur Python repo-local

## Note

Les tests MCP d'integration (`--suite mcp`) restent un lot de verification distinct du chemin repo-local stable. Ils dependent encore des launchers et des runtimes compagnons, donc ils ne servent pas de gate minimale pour le lot `python-local`.
