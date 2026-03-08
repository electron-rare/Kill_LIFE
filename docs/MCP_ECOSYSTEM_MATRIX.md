# MCP ecosystem matrix

Last updated: 2026-03-08

Matrice transverse des surfaces MCP et non-MCP observees dans `Kill_LIFE`, `mascarade` et `crazy_life`.

## Statuts

- `supporte`: surface active ou officiellement maintenue dans le workspace
- `supporte avec dependance externe`: surface maintenue mais dependante d'un autre repo, d'un cache ou d'un runtime compagnon
- `experimental`: surface presente mais pas encore validee comme chemin stable
- `infra-only`: composant d'infra ou de migration, pas un point d'entree operateur
- `non supporte`: historique, doc-only ou chemin non retenu

## 1. Serveurs MCP reels

| Surface | Repo principal | Type | Point d'entree | Statut | Notes |
| --- | --- | --- | --- | --- | --- |
| `kicad` | `Kill_LIFE` + `mascarade` | serveur MCP | `tools/hw/run_kicad_mcp.sh` | supporte | runtime KiCad canonique; implementation dans `mascarade/finetune/kicad_mcp_server` |
| `validate-specs` | `Kill_LIFE` | serveur MCP | `python3 tools/validate_specs.py --mcp` | supporte | validation repo/specs; pas un runtime CAD |
| `knowledge-base` | `Kill_LIFE` + `mascarade` | serveur MCP | `tools/run_knowledge_base_mcp.sh` | supporte avec dependance externe | serveur MCP de compat sur la knowledge base configuree (`memos` ou `docmost`); validation live fermee sur le provider actif `memos` auto-heberge |
| `github-dispatch` | `Kill_LIFE` + `mascarade` | serveur MCP | `tools/run_github_dispatch_mcp.sh` | supporte avec dependance externe | serveur stable, validation live fermee via token GitHub persiste dans `runtime-secrets` |
| `freecad` | `Kill_LIFE` + `mascarade` | serveur MCP | `tools/run_freecad_mcp.sh` | supporte | serveur MCP headless local base sur `FreeCADCmd` |
| `openscad` | `Kill_LIFE` + `mascarade` | serveur MCP | `tools/run_openscad_mcp.sh` | supporte | serveur MCP headless local stateless base sur `openscad` |
| `component_database` | `mascarade` | micro-serveur MCP | `python3 -m mcp_servers.component_db` | supporte avec dependance externe | serveur auxiliaire; depend du cache KiCad v10 et du repo compagnon |
| `kicad_tools` | `mascarade` | micro-serveur MCP | `python3 -m mcp_servers.kicad_tools` | supporte avec dependance externe | serveur auxiliaire; depend des fichiers KiCad reels et du repo compagnon |
| `nexar_api` | `Kill_LIFE` + `mascarade` | micro-serveur MCP | `tools/run_nexar_mcp.sh` | experimental | mode demo sans token; validation live encore ouverte |

## 2. Consommateurs et configs MCP

| Surface | Repo principal | Type | Point d'entree | Statut | Notes |
| --- | --- | --- | --- | --- | --- |
| `mcp.json` | `Kill_LIFE` | config consommateur MCP | `mcp.json` | supporte | reference `kicad`, `validate-specs`, `knowledge-base`, `github-dispatch`, `freecad`, `openscad` |
| `MCP setup` | `Kill_LIFE` | doc operateur MCP | `docs/MCP_SETUP.md` | supporte | source de verite d'usage local |
| `ops MCP probe` | `mascarade` | observabilite synthetique | `/api/ops/summary` via `api/src/routes/ops.ts` | supporte avec dependance externe | expose l'etat agrege de `kicad`, `validate-specs`, `knowledge-base`, `github-dispatch`, `freecad`, `openscad` et des surfaces distantes suivies par le cockpit |
| `crazy_life MCP positionnement` | `crazy_life` | doc de non-ownership / cockpit | `docs/MCP_PLAN_2026-03-07.md` | supporte | `crazy_life` consomme l'etat MCP et les probes, sans porter de serveur |

## 3. Integrations tierces non-MCP

| Surface | Repo principal | Type | Point d'entree | Dependance | Statut | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `Knowledge base bridge` | `mascarade` | API HTTP interne | `/api/knowledge-base/*` via `api/src/routes/knowledgeBase.ts` | provider actif + credentials associes | supporte | bridge HTTP de compat vers la knowledge base configuree |
| `Knowledge base core` | `mascarade` | integration provider-aware | `core/mascarade/integrations/knowledge_base.py` | provider actif + credentials associes | supporte | source de verite backend pour `memos` et `docmost` |
| `GitHub dispatch` | `mascarade` | API GitHub directe | `api/src/lib/killlife.ts` | `KILL_LIFE_GITHUB_TOKEN` ou `GITHUB_TOKEN` | supporte | lance `workflow_dispatch`, conserve en parallele du MCP `github-dispatch` |
| `FreeCAD agent` | `mascarade` | agent metier | `core/mascarade/agents/freecad_agent.py` | backend LLM | supporte | reste un agent de guidance; l'execution outillee passe par le MCP `freecad` pour la suite cible |
| `Workflow editors` | `mascarade` + `crazy_life` | UI orchestration | `web/src/pages/KillLifeWorkflowEditor.tsx`, `src/pages/KillLifeWorkflowEditor.tsx`, `src/pages/CrazyLaneEditor.tsx` | backend API | supporte | exposent `github-dispatch` comme type de noeud, pas comme serveur MCP |

## 4. Surfaces infra-only ou migration

| Surface | Repo principal | Type | Point d'entree | Statut | Notes |
| --- | --- | --- | --- | --- | --- |
| `openmemory-mcp / mem0` | `mascarade` | conteneur MCP tiers | `deploy/migration/compose.tools.ai.yml` | infra-only | profil `heavy`, non documente comme point d'entree canonique |
| `kicad-sch-mcp` | docs historiques | ancien serveur MCP externe | documentation seulement | non supporte | pas package ni retenu dans le workspace actuel |

## 5. Conclusion

- `Kill_LIFE` porte maintenant des MCP locaux supportes pour `kicad`, `validate-specs`, `knowledge-base`, `github-dispatch`, `freecad` et `openscad`
- `mascarade` porte l'agregation ops et les integrations applicatives encore existantes en parallele
- `crazy_life` consomme et supervise, mais n'own pas de serveur MCP
- `A2A` reste ferme tant que l'orchestrateur n'est pas branche sur les MCP specialises et que l'observabilite MCP n'est pas completement homogene
