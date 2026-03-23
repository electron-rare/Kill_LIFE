# Plan 22 - integration intelligence agentique (2026-03-22)

## Intention

Le lot 22 a deja livre son socle contractuel minimal pour la gouvernance intelligence, reutilisable par les docs, le cockpit et les artefacts.

La phase active du `2026-03-22` n'est plus un lot purement documentaire: elle durcit les surfaces deja livrees (`intelligence_tui`, `runtime_ai_gateway`, `log_ops`, `refonte_tui`), remet en coherence la spec/le plan/le TODO avec la realite du code, integre une veille officielle MCP/agentique/IA exploitable dans les priorites du projet, et couvre maintenant explicitement la plateforme `web/` Git EDA YiACAD.

`owner_repo` du lot: `Kill_LIFE`

Les deux livrables canoniques du lot sont:

- `specs/contracts/summary_short.schema.json`
- `specs/contracts/runtime_mcp_ia_gateway.schema.json`

## Lanes actives

| Lane | owner_agent | owner_subagent | Competences | write_set principal | Priorite immediate |
| --- | --- | --- | --- | --- | --- |
| Program-Governance | `PM-Mesh` | `Plan-Orchestrator` | arbitrage, sequencing, lot hygiene | `specs/agentic_intelligence_integration_spec.md`, `docs/plans/22_plan_integration_intelligence_agentique.md`, `docs/plans/22_todo_integration_intelligence_agentique.md`, `specs/04_tasks.md` | rouvrir le backlog actif du lot 22 et aligner la memoire intelligence sur les nouvelles actions |
| Contracts | `Mesh-Contracts` | `Contract-View` | schemas JSON, versionnement, compatibilite | `specs/contracts/summary_short.schema.json`, `specs/contracts/runtime_mcp_ia_gateway.schema.json`, `tools/cockpit/intelligence_tui.sh`, `tools/cockpit/runtime_ai_gateway.sh` | garder les contrats stables tout en durcissant les sorties machine et les chemins canonique |
| Runtime-Gateway | `Runtime-Companion` | `MCP-Health` | sante runtime, MCP, IA, degraded-safe | `tools/cockpit/runtime_ai_gateway.sh`, `docs/AI_WORKFLOWS.md`, `specs/contracts/runtime_mcp_ia_gateway.schema.json` | fiabiliser le refresh et preparer l'integration des signaux firmware/CAD dans la gateway |
| Docs-Continuity | `Docs-Research` | `Runbook-Editor` | coherence documentaire, wording canonique, veille officielle | `README.md`, `docs/index.md`, `docs/AI_WORKFLOWS.md`, `docs/WEB_RESEARCH_OPEN_SOURCE_2026-03-20.md` | realigner le lot 22 avec la realite livree et mettre a jour les recommandations 2026 depuis les sources officielles |
| QA-Compliance | `QA-Compliance` | `Evidence-Pack` | evidence minimale, lisibilite automation, tests shell/TUI | `tools/cockpit/refonte_tui.sh`, `tools/cockpit/log_ops.sh`, `test/test_intelligence_tui_contract.py`, `test/test_log_ops_contract.py` | corriger les garde-fous de purge, fiabiliser les sorties JSON et etendre la couverture de test |
| Firmware-CAD-Bridge | `Arch-Mesh` | `CAD-Bridge` | firmware, CAD, MCP, evidence bridge | `firmware/*`, `tools/hw/*`, `tools/ai/zeroclaw_hw_firmware_loop.sh`, `mcp.json` | decider le chemin firmware canonique et preparer la remontee firmware/CAD dans les contrats intelligence |
| Web-Git-EDA-Overlay | `Web-CAD-Platform` | `Realtime-Collab` | Next.js produit, GraphQL, Yjs, BullMQ, Git-first review, MCP/service-first AI | `specs/yiacad_git_eda_platform_spec.md`, `docs/plans/23_plan_yiacad_git_eda_platform.md`, `docs/plans/23_todo_yiacad_git_eda_platform.md`, `docs/YIACAD_GIT_EDA_PLATFORM_2026-03-22.md`, `web/*` | aligner le backlog web avec la gouvernance intelligence et ouvrir le read model Git/CI/artifacts reel |

## Contrats attendus

### 1. `summary-short/v1`

But:

- publier une synthese courte stable d'un lot ou d'une lane
- rester exploitable dans une vue cockpit, un log, un `latest.json` ou une note d'handoff

Champs minimum:

- `contract_version`
- `generated_at`
- `component`
- `owner_repo`
- `owner_agent`
- `owner_subagent`
- `write_set`
- `status`
- `summary_short`
- `evidence`

### 2. `runtime-mcp-ia-gateway/v1`

But:

- exposer un etat global unique pour la sante intelligence
- rendre explicite quel sous-ensemble degrade entre `runtime`, `mcp` et `ia`

Champs minimum:

- `contract_version`
- `generated_at`
- `component`
- `owner_repo`
- `owner_agent`
- `owner_subagent`
- `write_set`
- `status`
- `summary_short`
- `evidence`
- `surfaces.runtime`
- `surfaces.mcp`
- `surfaces.ia`

## Sequence recommandee

1. realigner la spec, le plan, le TODO et `specs/04_tasks.md` sur la realite du lot 22 deja livre
2. durcir les surfaces cockpit deja en place (`refonte_tui`, `log_ops`, `intelligence_tui`)
3. rafraichir la veille officielle MCP/agentique/IA et convertir la veille en decisions d'adoption explicites
4. raccorder explicitement `specs/yiacad_git_eda_platform_spec.md`, `docs/plans/23_*`, `docs/YIACAD_GIT_EDA_PLATFORM_2026-03-22.md` et `web/README.md` a la memoire intelligence
5. rouvrir les prochaines actions firmware/CAD/MCP et web Git EDA a partir de l'audit exhaustif
6. rafraichir la memoire `intelligence_tui` et la gateway `runtime/mcp/ia` apres chaque passe structurante

## Decisions actees 2026-03-21

### Politique miroir

- `Kill_LIFE/specs/` est canonique; `ai-agentic-embedded-base/specs/` est un miroir exporte.
- Les surfaces `docs/`, `tools/`, `artifacts/` et `firmware/` restent root-first dans `Kill_LIFE`.
- La discipline de fermeture pour les lots spec-first est: modifier `specs/`, synchroniser le miroir, puis valider en `--require-mirror-sync`.

### Chemin firmware prioritaire

- Le chemin firmware executable prioritaire reste `firmware/platformio.ini` avec `firmware/src/main.cpp`.
- La stack `voice_controller` reste en pre-integration tant qu'elle n'est ni branchee au `main.cpp`, ni couverte par une boucle de build/test/release explicite.
- Le raccord futur a `summary-short/v1` et `runtime-mcp-ia-gateway/v1` doit partir des preuves du `firmware/` racine, puis ajouter les statuts `voice`/`cad` seulement apres preuve exploitable.

## Evidence minimale du lot

- la spec de lot est a jour et ne contredit plus l'existence des TUIs/tests deja livres
- le plan 22 et le TODO 22 portent des actions ouvertes exploitables par `intelligence_tui`
- le plan 23 et le TODO 23 remontent aussi dans la memoire et les `next_steps`
- `docs/AI_WORKFLOWS.md` reference les contrats et les garde-fous operatoires effectivement en place
- les corrections cockpit critiques sont couvertes par des tests ciblés ou une verification manuelle explicite
- la veille officielle 2026 est documentee avec dates, sources et decisions d'adoption

## Risques a contenir

- confusion entre `cockpit-v1` et les nouveaux contrats de gouvernance
- inflation de schemas si `summary-short` devient un dump complet au lieu d'un resume court
- overlap non explicite entre sante globale mesh et sante `runtime/mcp/ia`
- backlog faux-negatif si le TODO 22 reste tout en `[x]`
- backlog faux-negatif si le plan 23 reste hors memoire intelligence
- purge non interactive trop permissive dans les TUIs
- derive entre repo racine et miroir `ai-agentic-embedded-base`
- confusion entre firmware executable canonique et stack voice encore non branchee
- glissement entre demo `web/` locale et plateforme Git-first multi-tenant si le read model Git/CI/artefacts n'est pas documente comme backlog ouvert

## Critere de sortie

- les deux schemas versionnes existent et restent les contrats de reference
- les lanes actives ont un `owner_agent`, un `owner_subagent`, un `write_set` et une priorite immediate coherente
- `docs/AI_WORKFLOWS.md`, le plan 22, le TODO 22, le plan 23, le TODO 23 et `specs/04_tasks.md` racontent la meme phase de travail
- `intelligence_tui` remonte des actions ouvertes utiles au lieu d'un faux statut termine
- les purges non interactives exigent un opt-in explicite et les sorties JSON critiques restent parseables
- les docs suffisent a reconstruire les contrats et les artefacts sans lire le shell
