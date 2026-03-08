# 17) Plan cible 2026 -> 2028 (`MCP` + `agentics` + `A2A`)

Last updated: 2026-03-08

Ce fichier fixe la trajectoire cible pour la pile `MCP` / `agentics` / `A2A` des trois repos.

Sources de verite associees:

- `specs/mcp_agentics_target_backlog.md`
- `specs/mcp_tasks.md`
- `specs/cad_modeling_tasks.md`
- `mascarade/docs/MCP_AGENTICS_ARCHITECTURE.md`

## Objectif

Converger vers une architecture cible ou:

- `MCP` devient le plan d'acces aux outils et systemes
- `mascarade` porte l'orchestration agentique et l'agregation ops
- `Kill_LIFE` porte les launchers, smokes, specs et runbooks canoniques
- `crazy_life` reste le client UI et cockpit
- `A2A` n'est introduit qu'apres stabilisation des MCP specialises

## Etat de depart requalifie

- `kicad` reste le MCP CAD principal et reste suivi dans `specs/mcp_tasks.md`
- `knowledge-base` et `github-dispatch` sont valides en live sur la machine de reference
- `freecad` et `openscad` existent maintenant comme runtimes headless locaux qualifies
- `freecad-mcp` et `openscad-mcp` existent maintenant en v1 locale et sont visibles dans `/api/ops/summary`
- `OpsHub`, `Logs` et `Orchestrate` exposent le statut MCP et les actions de reprobe
- `A2A` reste ferme

## Decisions figees

- ne pas dupliquer `KiCad` dans ce plan: son backlog reste `specs/mcp_tasks.md`
- `FreeCAD` et `OpenSCAD` ont chacun leur serveur MCP dedie
- `GitHub dispatch` et `knowledge-base` restent de petits serveurs MCP specialises
- `A2A` reste hors v1; il ne s'ouvre qu'apres stabilisation live et observabilite suffisante
- `Kill_LIFE` reste la source de verite methodologique; `ai-agentic-embedded-base` reste un miroir exporte

## Architecture cible

### Tool plane

Les serveurs MCP specialises portent l'acces aux outils:

- `kicad`
- `validate-specs`
- `knowledge-base`
- `github-dispatch`
- `freecad`
- `openscad`

### Execution plane

`mascarade` porte:

- l'orchestrateur
- les secrets runtime
- l'agregation ops
- la couche de supervision

Etat courant:

- la supervision ops est en place
- les probes MCP synthetiques sont maintenant exportees en OTLP par `ops-agent` vers Loki
- `/api/ops/logs/query` et la page `Logs` savent maintenant filtrer `source=mcp-probe` ainsi que `mcp_server`, `mcp_tool`, `mcp_status`
- le dashboard Grafana `Mascarade AI Runtime` expose maintenant des panneaux MCP pour probes, erreurs et volume d'appels
- un client MCP interne existe maintenant dans le core pour `knowledge-base`, `github-dispatch`, `freecad`, `openscad`
- `knowledge-base` et `github-dispatch` ont deja bascule sur ce client pour leurs chemins canoniques verifies
- `FreeCAD` et `OpenSCAD` ont maintenant eux aussi des routes core/API metier sur ce client, avec `run_id` propage et erreurs MCP explicites
- les integrations directes residuelles restent de la compatibilite ou du test, pas le chemin runtime canonique

### Operator plane

`crazy_life` et `mascarade/web` portent:

- le detail par serveur MCP
- les probes manuelles
- la supervision par `run_id`

### Coordination plane

`A2A` reste differe par decision tant qu'aucun besoin inter-runtime multi-agent reel n'est etabli.

## Sequence restante

1. garder la ligne `MCP/agentics` fermee localement tant qu'aucun besoin concret ne reapparait
2. ne rejouer `K-012` que si le host-native devient une exigence runtime
3. n'ouvrir un chantier `nexar_api` supplementaire que si un token/plan Nexar avec quota de parts non nul est requis en production
4. ne rouvrir `A2A` que si un besoin inter-runtime reel apparait

## Criteres de sortie

- chaque serveur MCP a un launcher, un smoke, un statut et un owner repo explicites
- l'orchestrateur ne depend plus de bridges ad hoc caches pour la knowledge base, `GitHub`, `FreeCAD` ou `OpenSCAD`
- `crazy_life` sait superviser les serveurs et lancer les probes sans les reimplementer
- `A2A` reste explicitement differe tant qu'aucun besoin inter-runtime multi-agent n'est prouve
- sur la machine de reference actuelle, il n'y a plus de blocage MCP/agentics local actif; `K-012` reste une validation host-native optionnelle et `nexar_api` est valide en live mais limite par un quota Nexar externe
