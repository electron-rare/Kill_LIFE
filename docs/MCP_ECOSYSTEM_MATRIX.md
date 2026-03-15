# MCP ecosystem matrix

Last updated: 2026-03-14

Matrice transverse des surfaces MCP et non-MCP observees dans `Kill_LIFE`, `mascarade` et `crazy_life`.

## Statuts

- `supporte`: surface active ou officiellement maintenue dans le workspace
- `supporte avec dependance externe`: surface maintenue mais dependante d'un autre repo, d'un cache ou d'un runtime compagnon
- `experimental`: surface presente mais pas encore validee comme chemin stable
- `infra-only`: composant d'infra ou de migration, pas un point d'entree operateur
- `non supporte`: historique, doc-only ou chemin non retenu

## Provenance

- `officiel`: surface publiee par le projet ou l'organisation qui own l'outil, ou referencee par une source officielle
- `community valide`: projet tiers etabli, retenu comme reference ou benchmark
- `custom local`: launcher, wrapper, service, probe ou integration maintenu dans `Kill_LIFE` ou un repo compagnon du workspace

## 1. Serveurs MCP reels

| Surface | Repo principal | Type | Point d'entree | Statut | Provenance | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `kicad` | `Kill_LIFE` + `mascarade` | serveur MCP | `tools/hw/run_kicad_mcp.sh` | supporte | custom local | runtime KiCad canonique; implementation dans `mascarade/finetune/kicad_mcp_server` |
| `validate-specs` | `Kill_LIFE` | serveur MCP | `python3 tools/validate_specs.py --mcp` | supporte | custom local | validation repo/specs; pas un runtime CAD |
| `knowledge-base` | `Kill_LIFE` + `mascarade` | serveur MCP | `tools/run_knowledge_base_mcp.sh` | supporte avec dependance externe | custom local | serveur MCP de compat sur la knowledge base configuree (`memos` ou `docmost`) |
| `github-dispatch` | `Kill_LIFE` + `mascarade` | serveur MCP | `tools/run_github_dispatch_mcp.sh` | supporte avec dependance externe | custom local | serveur stable, validation live fermee via token GitHub persiste dans `runtime-secrets` |
| `freecad` | `Kill_LIFE` + `mascarade` | serveur MCP | `tools/run_freecad_mcp.sh` | supporte | custom local | serveur MCP headless local base sur `FreeCADCmd` |
| `openscad` | `Kill_LIFE` + `mascarade` | serveur MCP | `tools/run_openscad_mcp.sh` | supporte | custom local | serveur MCP headless local stateless base sur `openscad` |
| `huggingface` | `Kill_LIFE` | serveur MCP distant | `https://huggingface.co/mcp` | supporte avec dependance externe | officiel | endpoint MCP distant officiel, versionne dans `mcp.json` |
| `component_database` | `mascarade` | micro-serveur MCP | `python3 -m mcp_servers.component_db` | supporte avec dependance externe | custom local | serveur auxiliaire; depend du cache KiCad v10 et du repo compagnon |
| `kicad_tools` | `mascarade` | micro-serveur MCP | `python3 -m mcp_servers.kicad_tools` | supporte avec dependance externe | custom local | serveur auxiliaire; depend des fichiers KiCad reels et du repo compagnon |
| `nexar_api` | `Kill_LIFE` + `mascarade` | micro-serveur MCP | `tools/run_nexar_mcp.sh` | supporte avec dependance externe | custom local | chemin live valide, mais encore borne par un quota externe |

## 2. Consommateurs et configs MCP

| Surface | Repo principal | Type | Point d'entree | Statut | Provenance | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `mcp.json` | `Kill_LIFE` | config consommateur MCP | `mcp.json` | supporte | custom local | reference `kicad`, `validate-specs`, `knowledge-base`, `github-dispatch`, `freecad`, `openscad` et `huggingface` |
| `MCP setup` | `Kill_LIFE` | doc operateur MCP | `docs/MCP_SETUP.md` | supporte | custom local | source de verite d'usage local et de provenance operatoire |
| `ops MCP probe` | `mascarade` | observabilite synthetique | `/api/ops/summary` via `api/src/routes/ops.ts` | supporte avec dependance externe | custom local | expose l'etat agrege des surfaces MCP locales et distantes suivies par le cockpit |
| `crazy_life MCP positionnement` | `crazy_life` | doc de non-ownership / cockpit | `docs/MCP_PLAN_2026-03-07.md` | supporte | custom local | `crazy_life` consomme l'etat MCP et les probes, sans porter de serveur |

## 3. Integrations tierces non-MCP

| Surface | Repo principal | Type | Point d'entree | Dependance | Statut | Provenance | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `Knowledge base bridge` | `mascarade` | API HTTP interne | `/api/knowledge-base/*` via `api/src/routes/knowledgeBase.ts` | provider actif + credentials associes | supporte | custom local | bridge HTTP de compat vers la knowledge base configuree |
| `Knowledge base core` | `mascarade` | integration provider-aware | `core/mascarade/integrations/knowledge_base.py` | provider actif + credentials associes | supporte | custom local | source de verite backend pour `memos` et `docmost` |
| `GitHub dispatch` | `mascarade` | API GitHub directe | `api/src/lib/killlife.ts` | `KILL_LIFE_GITHUB_TOKEN` ou `GITHUB_TOKEN` | supporte | custom local | lance `workflow_dispatch`, conserve en parallele du MCP `github-dispatch` |
| `FreeCAD agent` | `mascarade` | agent metier | `core/mascarade/agents/freecad_agent.py` | backend LLM | supporte | custom local | reste un agent de guidance; l'execution outillee passe par le MCP `freecad` pour la suite cible |
| `Workflow editors` | `mascarade` + `crazy_life` | UI orchestration | `web/src/pages/KillLifeWorkflowEditor.tsx`, `src/pages/KillLifeWorkflowEditor.tsx`, `src/pages/CrazyLaneEditor.tsx` | backend API | supporte | custom local | exposent `github-dispatch` comme type de noeud, pas comme serveur MCP |

## 4. Surfaces infra-only ou migration

| Surface | Repo principal | Type | Point d'entree | Statut | Provenance | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `openmemory-mcp / mem0` | `mascarade` | conteneur MCP tiers | `deploy/migration/compose.tools.ai.yml` | infra-only | community valide | profil `heavy`, non documente comme point d'entree canonique |
| `kicad-sch-mcp` | docs historiques | ancien serveur MCP externe | documentation seulement | non supporte | community valide | pas package ni retenu dans le workspace actuel |

## 5. Conclusion

- `Kill_LIFE` porte des MCP locaux supportes pour `kicad`, `validate-specs`, `knowledge-base`, `github-dispatch`, `freecad` et `openscad`, tous classes `custom local`
- `huggingface` reste la surface MCP distante officielle suivie dans `mcp.json`
- `mascarade` porte l'agregation ops et les integrations applicatives encore existantes en parallele
- `crazy_life` consomme et supervise, mais n'own pas de serveur MCP
- les references `community valide` restent des apports de benchmark ou d'infra, pas des runtimes canoniques par defaut
