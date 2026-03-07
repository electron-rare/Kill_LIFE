# MCP ecosystem matrix

Last updated: 2026-03-07

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
| `notion` | `Kill_LIFE` + `mascarade` | serveur MCP | `tools/run_notion_mcp.sh` | supporte avec dependance externe | MCP local branche sur `mascarade/core/mascarade/integrations/notion.py`; garde le bridge HTTP existant |
| `github-dispatch` | `Kill_LIFE` + `mascarade` | serveur MCP | `tools/run_github_dispatch_mcp.sh` | supporte avec dependance externe | MCP local branche sur `mascarade/core/mascarade/integrations/github_dispatch.py`; garde l'API directe existante |
| `component_database` | `mascarade` | micro-serveur MCP | `python3 -m mcp_servers.component_db` | supporte avec dependance externe | serveur auxiliaire; depend du cache KiCad v10 et du repo compagnon |
| `kicad_tools` | `mascarade` | micro-serveur MCP | `python3 -m mcp_servers.kicad_tools` | supporte avec dependance externe | serveur auxiliaire; depend des fichiers KiCad reels et du repo compagnon |
| `nexar_api` | `mascarade` | micro-serveur MCP | `python3 -m mcp_servers.nexar` | experimental | serveur auxiliaire; mode demo sans token, validation live encore ouverte |

## 2. Consommateurs et configs MCP

| Surface | Repo principal | Type | Point d'entree | Statut | Notes |
| --- | --- | --- | --- | --- | --- |
| `mcp.json` | `Kill_LIFE` | config consommateur MCP | `mcp.json` | supporte | reference `kicad`, `validate-specs`, `notion` et `github-dispatch` |
| `MCP setup` | `Kill_LIFE` | doc operateur MCP | `docs/MCP_SETUP.md` | supporte | source de verite d'usage local |
| `KiCad plugin MCP config` | `mascarade` | config plugin MCP | `finetune/kicad_kic_ai/plugins/mcp_config.json` | supporte avec dependance externe | concerne les micro-serveurs auxiliaires, pas le runtime canonique |
| `ops MCP probe` | `mascarade` | observabilite synthetique | `/api/ops/summary` via `api/src/routes/ops.ts` | supporte avec dependance externe | expose l'etat agrege de `kicad`, `validate-specs`, `notion` et `github-dispatch`, plus le detail par serveur |
| `crazy_life MCP positionnement` | `crazy_life` | doc de non-ownership | `docs/MCP_PLAN_2026-03-07.md` | supporte | `crazy_life` ne porte pas de serveur MCP |

## 3. Integrations tierces non-MCP

| Surface | Repo principal | Type | Point d'entree | Dependance | Statut | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `Notion bridge` | `mascarade` | API HTTP interne | `/api/notion/*` via `api/src/routes/notion.ts` | `NOTION_API_KEY` | supporte | bridge backend vers le client Notion, conserve en parallele du MCP `notion` |
| `Notion client core` | `mascarade` | integration SDK | `core/mascarade/integrations/notion.py` | `NOTION_API_KEY` | supporte | source de verite backend Notion |
| `NotionBrowser UI` | `crazy_life` | UI consommatrice | `src/pages/NotionBrowser.tsx` | backend `mascarade` | supporte | consomme encore le bridge HTTP Notion; migration MCP possible ensuite |
| `GitHub dispatch` | `mascarade` | API GitHub directe | `api/src/lib/killlife.ts` | `KILL_LIFE_GITHUB_TOKEN` ou `GITHUB_TOKEN` | supporte | lance `workflow_dispatch`, conserve en parallele du MCP `github-dispatch` |
| `GitHub dispatch` | `crazy_life` | API GitHub directe | `api/src/lib/killlife.ts` | `KILL_LIFE_GITHUB_TOKEN` ou `GITHUB_TOKEN` | supporte | miroir cote repo canonique frontend/API; migration MCP possible ensuite |
| `KillLife workflow editors` | `mascarade` + `crazy_life` | UI orchestration | `web/src/pages/KillLifeWorkflowEditor.tsx`, `src/pages/KillLifeWorkflowEditor.tsx`, `src/pages/CrazyLaneEditor.tsx` | backend API | supporte | exposent `github-dispatch` comme type de noeud, pas comme MCP |

## 4. Surfaces infra-only ou migration

| Surface | Repo principal | Type | Point d'entree | Statut | Notes |
| --- | --- | --- | --- | --- | --- |
| `openmemory-mcp / mem0` | `mascarade` | conteneur MCP tiers | `deploy/migration/compose.tools.ai.yml` | infra-only | profil `heavy`, non documente comme point d'entree canonique, non observe en execution sur cette machine |
| `kicad-sch-mcp` | docs historiques | ancien serveur MCP externe | documentation seulement | non supporte | pas package ni retenu dans le workspace actuel |

## 5. Conclusion

- le point d'entree operateur MCP de `Kill_LIFE` reste la surface `kicad` lancee par `tools/hw/run_kicad_mcp.sh`
- `Notion` et `GitHub dispatch` disposent aussi d'un serveur MCP local, mais leur logique applicative reste fournie par `mascarade`
- `crazy_life` consomme des surfaces applicatives, mais n'own pas de serveur MCP
- `mem0/openmemory-mcp` reste une brique d'infra optionnelle, hors chaine operateur canonique
- les surfaces auxiliaires `kicad_kic_ai` ne doivent pas etre lues comme equivalentes au point d'entree operateur `kicad`
