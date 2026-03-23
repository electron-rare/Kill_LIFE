# TODO 22 - integration intelligence agentique (2026-03-21)

## P0

- [x] Publier une spec technique dediee a l'integration intelligence agentique
- [x] Publier une feature map Mermaid dediee
- [x] Publier un plan 22 avec lanes, owners, write-sets et priorites
- [x] Ajouter une TUI cockpit dediee avec logs, memoire et contrat JSON
- [x] Raccorder la nouvelle surface a `refonte_tui.sh`
- [x] Mettre a jour `docs/index.md`, `tools/cockpit/README.md` et `docs/AI_WORKFLOWS.md`
- [x] Ajouter un test de contrat pour la nouvelle TUI
- [x] Ajouter une vue `next-actions` deduite des TODOs ouverts

## P1

- [x] Raccorder la TUI aux resynchronisations `lot_chain` si un write-set evolue
- [x] Ajouter une synthese JSON courte pour consommation par les extensions terminales/VS Code
- [x] Rendre le bridge runtime/MCP plus lisible dans une source unique

## P2

- [x] Ajouter un score de fragmentation documentaire et un score de maturite par lane
- [x] Ajouter une vue de comparaison entre `Kill_LIFE`, `ai-agentic-embedded-base` et les trois extensions
- [x] Introduire une file de recommandations IA priorisee a partir de la veille et de l'audit

## Cycle 2 - audit exhaustif et durcissement (ouvert)

### P0

- [x] Realigner `specs/agentic_intelligence_integration_spec.md`, `docs/plans/22_plan_integration_intelligence_agentique.md`, `docs/AI_WORKFLOWS.md` et `specs/04_tasks.md` sur la realite du lot 22 livre
- [x] Rouvrir des actions utiles dans `TODO 22` pour que `intelligence_tui` remonte un backlog vivant et non un faux statut termine
- [x] Durcir `tools/cockpit/refonte_tui.sh` pour exiger `--yes-auto` sur `clean-logs` non interactif
- [x] Durcir `tools/cockpit/log_ops.sh` pour garantir des sorties JSON parseables meme avec des chemins atypiques
- [x] Rendre `tools/cockpit/intelligence_tui.sh` stable hors `cwd` du repo et reduire la fragilite aux chemins dates

### P1

- [x] Rafraichir `docs/WEB_RESEARCH_OPEN_SOURCE_2026-03-20.md` depuis les sources officielles MCP, VS Code AI extensibility, OpenAI Agents SDK et LangGraph
- [x] Documenter explicitement les decisions d'adoption 2026 avec dates et liens source dans `docs/AI_WORKFLOWS.md`
- [x] Ajouter une passe de test ou verification ciblee pour les corrections cockpit introduites dans ce cycle
- [x] Formaliser la politique racine vs miroir `ai-agentic-embedded-base` pour les surfaces docs/specs/outils qui derivent

### P2

- [x] Decider le chemin firmware canonique (`main.cpp` minimal vs stack voice) et rattacher cette decision au plan intelligence
- [x] Preparer la remontee des statuts firmware/CAD vers les contrats `summary-short/v1` et `runtime-mcp-ia-gateway/v1`
- [x] Evaluer si `runtime_ai_gateway.sh --refresh` doit degrad-er vite en cas de probes runtime/mesh trop longues

## Evidences

- `specs/agentic_intelligence_integration_spec.md`
- `docs/AGENTIC_INTELLIGENCE_FEATURE_MAP_2026-03-21.md`
- `docs/plans/22_plan_integration_intelligence_agentique.md`
- `tools/cockpit/intelligence_tui.sh`
- `tools/cockpit/intelligence_program_tui.sh`
- `tools/cockpit/runtime_ai_gateway.sh`
- `tools/cockpit/lot_chain.sh`
- `tools/autonomous_next_lots.py`
- `artifacts/cockpit/intelligence_program/latest.json`
- `artifacts/cockpit/intelligence_program/latest.md`
- `artifacts/cockpit/intelligence_program/scorecard_latest.json`
- `artifacts/cockpit/intelligence_program/scorecard_latest.md`
- `artifacts/cockpit/intelligence_program/repo_comparison_latest.json`
- `artifacts/cockpit/intelligence_program/repo_comparison_latest.md`
- `artifacts/cockpit/intelligence_program/recommendation_queue_latest.json`
- `artifacts/cockpit/intelligence_program/recommendation_queue_latest.md`
- `test/test_intelligence_tui_contract.py`
- `test/test_runtime_ai_gateway_contract.py`

## Cycle 3 - integration intelligence 2026 pour la plateforme web Git EDA (ouvert)

### P0

- [x] Etendre `tools/cockpit/intelligence_tui.sh` pour couvrir `specs/yiacad_git_eda_platform_spec.md`, `docs/plans/23_*`, `docs/YIACAD_GIT_EDA_PLATFORM_2026-03-22.md` et `web/README.md`.
- [x] Publier un audit, une veille et une feature map `2026-03-22` alignes sur la plateforme `web/` et l'overlay MCP/agentique/IA.
- [x] Affecter explicitement les owners/subagents `Web-CAD-Platform`, `Realtime-Collab`, `EDA-CI-Orchestrator` et `Review-Assist` dans les plans et la matrice agentique.

### P1

- [x] Raccorder `docs/AI_WORKFLOWS.md`, `docs/index.md`, `README.md` et `tools/cockpit/README.md` au backlog commun `TODO 22 + TODO 23`.
- [ ] Faire remonter le statut `queue/worker/realtime` du produit web dans la memoire intelligence et preparer son pont vers `runtime_ai_gateway.sh`.
- [x] Remplacer les placeholders Git/PR/artifacts de `web/` par un read model derive de Git et de la CI reelle.

### P2

- [ ] Binder la scene Excalidraw a `Yjs` tout en gardant le save manuel comme snapshot Git.
- [ ] Formaliser le boundary `MCP/service-first` pour `EDA worker`, `parts search`, `CI trigger`, `artifact fetch` et `review hints`.

## Evidence cycle 3

- `docs/KILL_LIFE_CONSOLIDATION_AUDIT_2026-03-22.md`
- `docs/WEB_RESEARCH_OPEN_SOURCE_2026-03-22.md`
- `docs/AGENTIC_INTELLIGENCE_FEATURE_MAP_2026-03-22.md`
- `specs/agentic_intelligence_integration_spec.md`
- `specs/yiacad_git_eda_platform_spec.md`
- `docs/plans/22_plan_integration_intelligence_agentique.md`
- `docs/plans/23_plan_yiacad_git_eda_platform.md`
- `docs/plans/23_todo_yiacad_git_eda_platform.md`
- `docs/AI_WORKFLOWS.md`
- `docs/plans/12_plan_gestion_des_agents.md`
- `docs/AGENT_SPEC_MODULE_MATRIX_2026-03-20.md`
- `tools/cockpit/intelligence_tui.sh`
- `tools/cockpit/README.md`
