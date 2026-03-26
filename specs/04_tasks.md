# Tasks enchainement autonome des lots utiles

Last updated: 2026-03-22

## Cadre

- Plan actif: `specs/03_plan.md`
- Statut detaille: `artifacts/cockpit/useful_lots_status.md`
- Lane runtime/MCP/CAD: `docs/plans/18_plan_enchainement_autonome_des_lots_utiles.md`
- Question operateur si besoin reel: `artifacts/cockpit/next_question.md`

## Execution

- P0 — Refonte des spécifications et du plan (2026-03-20)
  - [x] T-RE-001 — Actualiser `specs/00_intake.md` en vrai besoin de refonte.
  - [x] T-RE-002 — Définir objectifs, AC et contraintes dans `specs/01_spec.md`.
  - [x] T-RE-003 — Formaliser l’architecture refonte et les ADR dans `specs/02_arch.md`.
  - [x] T-RE-004 — Mettre à jour `specs/03_plan.md` avec les objectifs refonte.

- P0 — Consolidation extensions et doc canonique (2026-03-21)
  - [x] T-EXT-301 — Faire de `kill-life-studio` le pilote produit avec projet actif, grounding chat, artefacts produit et tests d'extension.
  - [x] T-EXT-302 — Propager le socle validé vers `kill-life-mesh` avec commandes de sélection de projet et tests.
  - [x] T-EXT-303 — Propager le socle validé vers `kill-life-operator` avec commandes de sélection de projet et tests.
  - [x] T-DOC-301 — Réaligner `README.md`, `docs/index.md`, `tools/cockpit/README.md` et `specs/README.md` comme points d'entrée canoniques.
  - [x] T-DOC-302 — Publier un audit unique de consolidation avec matrice IA et carte de fonctionnalités.
    - Preuves:
      - `docs/KILL_LIFE_CONSOLIDATION_AUDIT_2026-03-21.md`
      - `docs/WEB_RESEARCH_OPEN_SOURCE_2026-03-20.md`
      - `docs/plans/12_plan_gestion_des_agents.md`
  - [x] T-QA-302 — Ajouter des tests de contrats JSON ciblés pour les scripts cockpit stables.
  - [x] T-QA-301 — Rejouer un smoke visuel multi-root des trois VSIX dans une session VS Code opérateur et archiver la preuve.
    - Preuves:
      - `artifacts/cockpit/vscode_smoke/T-QA-301_2026-03-21.md`
      - `artifacts/cockpit/vscode_smoke/kill-life-local-smoke-activity-bar-2026-03-21.png`
      - `artifacts/cockpit/vscode_smoke/extensions-2026-03-21.txt`
      - `artifacts/cockpit/vscode_smoke/exthost-2026-03-21.log`

- P0 — Integration intelligence agentique (2026-03-21)
  - [x] T-AI-301 — Publier une spec technique dediee a l'integration intelligence agentique.
  - [x] T-AI-302 — Publier une feature map Mermaid dediee.
  - [x] T-AI-303 — Publier un plan 22 et un TODO 22 pour la gouvernance intelligence.
  - [x] T-AI-304 — Ajouter une TUI cockpit dediee avec logs et contrat `cockpit-v1`.
  - [x] T-AI-305 — Raccorder la nouvelle surface a `docs/index.md`, `tools/cockpit/README.md`, `docs/AI_WORKFLOWS.md` et `refonte_tui.sh`.
  - [x] T-AI-306 — Ajouter une vue `next-actions` derivee automatiquement des TODOs ouverts.
  - [x] T-AI-307 — Publier une memoire cockpit intelligence (`latest.json` + `latest.md`) pour l'automation et la continuite operateur.
  - [x] T-AI-308 — Raccorder `runtime_ai_gateway.sh` a `intelligence_tui` et aux vues status du cockpit comme synthese unique runtime/MCP/IA.
    - Preuves:
      - `tools/cockpit/intelligence_tui.sh`
      - `tools/cockpit/runtime_ai_gateway.sh`
      - `tools/cockpit/lot_chain.sh`
      - `tools/autonomous_next_lots.py`
      - `tools/cockpit/intelligence_program_tui.sh`
      - `artifacts/cockpit/intelligence_program/latest.json`
      - `artifacts/cockpit/intelligence_program/latest.md`
      - `test/test_intelligence_tui_contract.py`
      - `test/test_runtime_ai_gateway_contract.py`
  - [x] T-AI-309 — Ajouter un scorecard documentaire avec score de fragmentation et maturite par lane.
    - Preuves:
      - `tools/cockpit/intelligence_tui.sh`
      - `artifacts/cockpit/intelligence_program/scorecard_latest.json`
      - `artifacts/cockpit/intelligence_program/scorecard_latest.md`
      - `test/test_intelligence_tui_contract.py`
  - [x] T-AI-310 — Ajouter une vue de comparaison entre `Kill_LIFE`, `ai-agentic-embedded-base` et les trois extensions.
    - Preuves:
      - `tools/cockpit/intelligence_tui.sh`
      - `artifacts/cockpit/intelligence_program/repo_comparison_latest.json`
      - `artifacts/cockpit/intelligence_program/repo_comparison_latest.md`
      - `test/test_intelligence_tui_contract.py`
  - [x] T-AI-311 — Introduire une file de recommandations IA priorisee a partir de la veille et de l'audit.
    - Preuves:
      - `tools/cockpit/intelligence_tui.sh`
      - `artifacts/cockpit/intelligence_program/recommendation_queue_latest.json`
      - `artifacts/cockpit/intelligence_program/recommendation_queue_latest.md`
      - `docs/WEB_RESEARCH_OPEN_SOURCE_2026-03-20.md`
      - `docs/KILL_LIFE_CONSOLIDATION_AUDIT_2026-03-21.md`
      - `test/test_intelligence_tui_contract.py`
  - [x] T-AI-312 — Realigner lot 22 (`spec`, `plan`, `todo`, `AI_WORKFLOWS`, `specs/04_tasks`) sur la realite du lot deja livre.
    - Preuves:
      - `docs/plans/22_plan_integration_intelligence_agentique.md`
      - `docs/plans/22_todo_integration_intelligence_agentique.md`
      - `specs/agentic_intelligence_integration_spec.md`
      - `specs/04_tasks.md`
      - `docs/AI_WORKFLOWS.md`
  - [x] T-AI-313 — Durcir `refonte_tui clean-logs` pour exiger `--yes-auto` en mode non interactif.
    - Preuves:
      - `tools/cockpit/refonte_tui.sh`
      - `tools/cockpit/README.md`
  - [x] T-AI-314 — Durcir `log_ops` pour garantir des sorties JSON stables sur des chemins atypiques et etendre la couverture de test associee.
    - Preuves:
      - `tools/cockpit/log_ops.sh`
      - `test/test_log_ops_contract.py`
  - [x] T-AI-315 — Rendre `intelligence_tui` stable hors `cwd` du repo et reduire la derive liee aux chemins dates.
    - Preuves:
      - `tools/cockpit/intelligence_tui.sh`
      - `test/test_intelligence_tui_contract.py`
  - [x] T-AI-316 — Rafraichir la veille officielle MCP/agentique/IA et convertir les signaux en decisions d'adoption explicites.
    - Preuves:
      - `docs/WEB_RESEARCH_OPEN_SOURCE_2026-03-20.md`
      - `docs/AI_WORKFLOWS.md`
      - `tools/cockpit/intelligence_tui.sh`
  - [x] T-AI-317 — Formaliser la politique de miroir entre `Kill_LIFE` et `ai-agentic-embedded-base` pour les surfaces docs/specs/outils.
    - Preuves:
      - `specs/README.md`
      - `docs/AI_WORKFLOWS.md`
      - `docs/plans/22_plan_integration_intelligence_agentique.md`
      - `specs/agentic_intelligence_integration_spec.md`
  - [x] T-AI-318 — Prioriser le chemin firmware/CAD/MCP a raccorder ensuite a `summary-short/v1` et `runtime-mcp-ia-gateway/v1`.
    - Preuves:
      - `docs/AI_WORKFLOWS.md`
      - `docs/plans/22_plan_integration_intelligence_agentique.md`
      - `specs/agentic_intelligence_integration_spec.md`
      - `firmware/src/main.cpp`
      - `firmware/src/voice_controller.cpp`
      - `tools/cockpit/runtime_ai_gateway.sh`
      - `artifacts/cockpit/runtime_ai_gateway/firmware_cad_summary_short_latest.json`
  - [x] T-AI-319 — Rendre `runtime_ai_gateway.sh --refresh` fail-fast quand une probe runtime/mesh dépasse un délai raisonnable.
    - Preuves:
      - `tools/cockpit/runtime_ai_gateway.sh`
      - `test/test_runtime_ai_gateway_contract.py`
  - [x] T-AI-320 — Etendre la lane intelligence aux sources `web/` et au backlog `plan 23`.
    - Preuves:
      - `specs/agentic_intelligence_integration_spec.md`
      - `docs/plans/22_plan_integration_intelligence_agentique.md`
      - `docs/plans/22_todo_integration_intelligence_agentique.md`
      - `docs/plans/23_plan_yiacad_git_eda_platform.md`
      - `docs/plans/23_todo_yiacad_git_eda_platform.md`
      - `tools/cockpit/intelligence_tui.sh`
  - [x] T-AI-321 — Publier un audit, une veille et une feature map `2026-03-22` alignes sur `web/`, MCP et l'integration intelligence.
    - Preuves:
      - `docs/KILL_LIFE_CONSOLIDATION_AUDIT_2026-03-22.md`
      - `docs/WEB_RESEARCH_OPEN_SOURCE_2026-03-22.md`
      - `docs/AGENTIC_INTELLIGENCE_FEATURE_MAP_2026-03-22.md`
  - [x] T-AI-322 — Affecter explicitement les owners et sous-agents de `web/*` et de la lane Git EDA dans les plans canoniques.
    - Preuves:
      - `docs/plans/12_plan_gestion_des_agents.md`
      - `docs/AGENT_SPEC_MODULE_MATRIX_2026-03-20.md`
  - [x] T-AI-323 — Faire remonter le statut `queue/worker/realtime` du produit web dans la memoire intelligence et preparer le pont vers `runtime_ai_gateway.sh`.
    - Preuves:
      - `tools/cockpit/intelligence_tui.sh` → `web_platform_health()` probe Next.js :3000, Yjs :1234, Redis :6379
      - `artifacts/cockpit/intelligence_program/latest.json` → `web_platform_health` key présent, refreshed 2026-03-26
      - `tools/cockpit/runtime_ai_gateway.sh` → `build_web_platform_surface()` lit le snapshot, expose `web_platform=degraded; 1/3 probes up`
  - [x] T-AI-324 — Remplacer les placeholders Git/PR/artifacts de `web/` par un read model derive de Git et de la CI.
    - Preuves:
      - `web/lib/git-project.ts`
      - `web/lib/project-store.ts`
      - `web/lib/graphql/schema.ts`
      - `web/app/api/artifacts/[...segments]/route.ts`
      - `web/components/project-shell.tsx`
      - `web/components/pcb-workbench.tsx`
      - `web/components/pr-review-shell.tsx`
      - `web/workers/eda-worker.mjs`
  - [x] T-AI-325 — Binder Excalidraw a `Yjs` tout en gardant le save manuel comme snapshot Git.
    - Preuves:
      - `web/lib/use-yjs-excalidraw.ts` — hook `useYjsExcalidraw(roomName)`: `Y.Doc` + `WebsocketProvider` + `Y.Array<excalidraw-elements>`, observer remote, `pushElements()` pour sync locale
      - `web/components/excalidraw-canvas.tsx` — consomme `useYjsExcalidraw`
      - `web/components/project-shell.tsx` — `saveDiagram()` via GraphQL mutation → `project-store.ts` → sauvegarde Git-tracked `.excalidraw`
      - `web/realtime/server.mjs` — serveur `y-websocket` port 1234
  - [x] T-AI-326 — Formaliser le boundary `MCP/service-first` pour `EDA worker`, `parts search`, `CI trigger`, `artifact fetch` et `review hints`.
    - Preuves:
      - `specs/agentic_intelligence_integration_spec.md` → section `F8 - Boundary MCP/service-first` avec table des 6 surfaces, modes autorisés, statuts MCP et règles d'arbitrage

<!-- BEGIN AUTO LOT-CHAIN TASKS -->
- [x] T-LC-001 - Keep the README/repo coherence lot clean via the dedicated audit loop.
  - Evidence: `artifacts/doc/readme_repo_audit.md`
- [x] T-LC-002 - Keep the exported spec mirror synchronized with the canonical `specs/` tree.
  - Evidence: `artifacts/specs/mirror_sync_report.md`
- [x] T-LC-003 - Keep the upstream MCP/CAD runtime lane docs synchronized with the current local state.
  - Evidence: `docs/plans/18_plan_enchainement_autonome_des_lots_utiles.md`
- [x] T-LC-004 - Revalidate the strict spec contract after each auto-fix run.
  - Evidence: `python3 tools/validate_specs.py --strict --require-mirror-sync`
- [x] T-LC-005 - Re-run the stable Python suite after the chained lots.
  - Evidence: `bash tools/test_python.sh --suite stable`
- [x] T-LC-006 - Choose the next manual lot once automation reaches a real fork.
  - Evidence: `artifacts/cockpit/next_question.md`
<!-- END AUTO LOT-CHAIN TASKS -->

- P1 — Gouvernance et intégration AI
  - [x] T-RE-101 — Mettre à jour `docs/plans/12_plan_gestion_des_agents.md` avec sous-agents et compétences.
  - [x] T-RE-102 — Mettre à jour les objectifs d’agents/sous-agents dans `docs/AGENTIC_LANDSCAPE.md`.
  - [x] T-RE-105 — Générer et mettre à jour la matrice d’assignation des agents/sous-agents (plans + preuves associées).
  - [x] T-RE-106 — Publier la matrice explicite `spec/module -> agent dédié -> sous-agent -> skills/capacités -> write_set`.
    - Preuves:
      - `docs/AGENT_SPEC_MODULE_MATRIX_2026-03-20.md`
      - `docs/plans/12_plan_gestion_des_agents.md`
      - `docs/AGENTIC_LANDSCAPE.md`

- P2 — TUI + logs + web research
  - [x] T-RE-201 — Ajouter le script opératoire TUI `tools/cockpit/refonte_tui.sh`.
  - [x] T-RE-202 — Mettre en place purge/analyse logs avec rétention documentée.
  - [x] T-RE-203 — Finaliser `docs/WEB_RESEARCH_OPEN_SOURCE_2026-03-20.md` et relier la référence docs.
    - Référence dédiée CAD: `docs/OSS_AI_NATIVE_CAD_RESEARCH_2026-03-20.md`.
  - [x] T-RE-203-b — Faire ressortir le score de similarité OSS par surface (MCP, CAD, embedded, workflow).
- [x] T-RE-204 — Redémarrer le daemon Docker local et relancer `zeroclaw-integrations`.
  - Statut: Docker Desktop relancé et conteneur `mascarade-n8n` reprovisionné le `2026-03-20`.
  - Résultat:
    - `bash tools/ai/zeroclaw_integrations_import_n8n.sh --json` -> `import_action=imported`, `publish_action=published`, `active=true`
    - `bash tools/ai/zeroclaw_integrations_lot.sh verify --json` -> `overall_status=ready`
  - Correctif appliqué: `tools/ai/zeroclaw_integrations_import_n8n.sh` cible `publish:workflow` en priorité, avec fallback legacy `update:workflow --active=true`.
  - [x] T-RE-205 — Documenter la matrice IA d’intégration et le plan de reprise après divergence mesh.
  - [x] T-RE-206 — Appliquer une passe de log_ops en TUI et valider `stale=0`.
  - [x] T-RE-207 — Ajouter purge contrôlée standard `--days 14` puis `--days 7` avec conservation des artefacts utiles.
    - Preuves:
      - `bash tools/cockpit/log_ops.sh --action purge --retention-days 14 --apply`
      - `bash tools/cockpit/log_ops.sh --action purge --retention-days 7 --apply`
      - `bash tools/cockpit/refonte_tui.sh --action clean-logs --days 14 --yes`
      - `bash tools/cockpit/refonte_tui.sh --action clean-logs --days 7 --yes`
- [x] T-RE-208 — Harmoniser les procédures de logs entre `refonte_tui`, `log_ops` et `run_alignment_daily`.
  - Preuves:
    - `bash tools/cockpit/refonte_tui.sh --action logs`
    - `bash tools/cockpit/refonte_tui.sh --action log-ops`
    - `bash tools/cockpit/refonte_tui.sh --action clean-logs --days 7 --yes`
- [x] T-RE-212 — Étendre la TUI UI/UX pour lire, lister et purger les logs sans casser le mode non interactif.
  - Preuves:
    - `tools/cockpit/yiacad_uiux_tui.sh --action logs-summary`
    - `tools/cockpit/yiacad_uiux_tui.sh --action logs-list`
    - `tools/cockpit/yiacad_uiux_tui.sh --action logs-latest`
    - `tools/cockpit/yiacad_uiux_tui.sh --action purge-logs --days 14 --yes`
- [x] T-RE-213 — Normaliser un contrat JSON unique pour les scripts cockpit/TUI (`status`, `component`, `action`, `artifacts`, `degraded_reasons`, `next_steps`).
  - Cible:
    - `tools/cockpit/ssh_healthcheck.sh`
    - `tools/cockpit/mesh_health_check.sh`
    - `tools/cockpit/run_alignment_daily.sh`
    - `tools/cockpit/log_ops.sh`
    - `tools/cockpit/full_operator_lane.sh`
  - Preuves:
    - `tools/cockpit/json_contract.sh`
    - `bash tools/cockpit/log_ops.sh --action summary --json`
    - `bash tools/cockpit/ssh_healthcheck.sh --json`
    - `bash tools/cockpit/mesh_health_check.sh --json --load-profile tower-first`
    - `bash tools/cockpit/run_alignment_daily.sh --json --mesh-load-profile tower-first`
    - `bash tools/cockpit/full_operator_lane.sh status --json`
- [x] T-RE-214 — Extraire un registre machine/capacité unique consommable par les scripts de mesh et de runbook.
  - Cible:
    - rôles / ports / priorité / poids de charge / interdictions de placement
    - politique `tower-first` / `photon-safe`
    - source de vérité partagée entre doc et scripts
  - Avancement:
    - registre canonique publié
    - CLI/TUI cockpit dédiée ajoutée pour lecture et ciblage par machine
    - `mesh_sync_preflight.sh` lit désormais rôles, ports, priorités, placement, cible réserve et repos critiques depuis le registre canonique
    - `ssh_healthcheck.sh` charge désormais ses cibles SSH directement depuis le registre canonique
    - `run_alignment_daily.sh` capture désormais un résumé JSON du registre dans ses artefacts de synthèse
  - Preuves:
    - `specs/contracts/machine_registry.schema.json`
    - `specs/contracts/machine_registry.mesh.json`
    - `docs/MACHINE_REGISTRY_2026-03-20.md`
    - `tools/cockpit/machine_registry.sh`
    - `tools/cockpit/mesh_sync_preflight.sh`
    - `tools/cockpit/ssh_healthcheck.sh`
    - `tools/cockpit/run_alignment_daily.sh`
    - `bash tools/cockpit/mesh_sync_preflight.sh --json --load-profile tower-first`
    - `bash tools/cockpit/ssh_healthcheck.sh --json`
    - `bash tools/cockpit/run_alignment_daily.sh --json --skip-mesh --skip-log-ops --no-purge`
- [x] T-RE-215 — Publier un catalogue de profils modeles Mascarade pour `kxkm-ai` afin de couvrir code, site, reflexion, recherche web, analyse, planification et mode degrade.
  - Cible:
    - source de verite machine-readable pour les profils
    - TUI cockpit pour lecture/export des profils
    - branchement direct du smoke runtime sur `--profile`
    - reutilisation du chat Mascarade existant sur `kxkm-ai` via des agents dynamiques `kxkm-*`
  - Preuves:
    - `specs/contracts/mascarade_model_profiles.kxkm_ai.json`
    - `docs/MASCARADE_MODEL_PROFILES_KXKM_AI_2026-03-20.md`
    - `tools/cockpit/mascarade_models_tui.sh`
    - `tools/ops/sync_mascarade_agents_kxkm.sh`
    - `python3 tools/ops/operator_live_provider_smoke.py --profile analysis`
    - `bash tools/ops/sync_mascarade_agents_kxkm.sh --action sync --apply --json`
- [x] T-RE-216 — Étendre `kxkm-ai` avec une seconde vague d’agents Mascarade spécialisés (`firmware`, `cad`, `ops`, `docs`, `security`, `fine-tune`).
  - Cible:
    - enrichir le catalogue de profils runtime
    - réutiliser le même mécanisme de seed `kxkm-*`
    - garder la continuité avec le chat Mascarade existant
  - Preuves:
    - `specs/contracts/mascarade_model_profiles.kxkm_ai.json`
    - `docs/MASCARADE_MODEL_PROFILES_KXKM_AI_2026-03-20.md`
    - `bash tools/ops/sync_mascarade_agents_kxkm.sh --action sync --apply --json`
- [x] T-RE-217 — Ajouter une troisième vague d’agents métier `kxkm-*` par surface projet (`kill-life-firmware`, `yiacad-cad`, `mesh-syncops`, `docs-specs`).
  - Cible:
    - profils plus proches des modules et plans du repo
    - continuité directe avec le chat Mascarade existant
    - seed prêt pour le prochain reload runtime
  - Preuves:
    - `specs/contracts/mascarade_model_profiles.kxkm_ai.json`
    - `docs/MASCARADE_MODEL_PROFILES_KXKM_AI_2026-03-20.md`
    - `bash tools/ops/sync_mascarade_agents_kxkm.sh --action sync --apply --json`
- [x] T-RE-218 — Realigner les profils `kxkm-*` sur les modeles Ollama effectivement presents sur `kxkm-ai` et stabiliser le runtime live Mascarade.
  - Cible:
    - supprimer la derive `openai` / `anthropic` / `apple-coreml` des agents `kxkm-*` seeds quand le runtime cible ne les expose pas
    - reutiliser les modeles locaux deja presents sur `kxkm-ai`
    - rendre `kxkm-analysis` et `kxkm-firmware` executables depuis le chat Mascarade live
  - Resultat:
    - catalogue `ollama-first` applique
    - runtime `mascarade-ollama-runtime` en `0.18.2` publie sur le reseau Mascarade avec les modeles locaux montes
    - smoke live valide sur `kxkm-analysis` et `kxkm-firmware` (`200`)
  - Preuves:
    - `specs/contracts/mascarade_model_profiles.kxkm_ai.json`
    - `docs/MASCARADE_MODEL_PROFILES_KXKM_AI_2026-03-20.md`
    - `bash tools/ops/sync_mascarade_agents_kxkm.sh --action sync --apply --json`
    - `docker run --name mascarade-ollama-runtime ... ollama/ollama:0.18.2`
    - `POST http://127.0.0.1:3100/api/agents/kxkm-analysis/run`
    - `POST http://127.0.0.1:3100/api/agents/kxkm-firmware/run`
- [x] T-RE-219 — Industrialiser le smoke live des agents `kxkm-*` avec artefacts JSON locaux.
  - Cible:
    - disposer d'un smoke reusable sans repasser par des commandes SSH ad hoc
    - capturer des artefacts locaux horodates
    - couvrir la vague critique `code`, `cad`, `ops`, `fallback-safe`
  - Resultat:
    - script reusable ajoute
    - artefact local `artifacts/ops/mascarade_agent_smoke/latest.json` produit
    - smoke consolide valide en `200` sur `kxkm-analysis`, `kxkm-firmware`, `kxkm-code`, `kxkm-cad`, `kxkm-ops`, `kxkm-fallback-safe`
  - Preuves:
    - `tools/ops/smoke_mascarade_agents_kxkm.sh`
    - `bash tools/ops/smoke_mascarade_agents_kxkm.sh --json`
    - `artifacts/ops/mascarade_agent_smoke/latest.json`
- [x] T-RE-220 — Retirer le bridge transitoire `kxkm-ollama-bridge.service` maintenant que le runtime `mascarade-ollama-runtime` suffit.
  - Cible:
    - supprimer la dependance au port `21434`
    - conserver uniquement le runtime Ollama Docker comme chemin actif pour Mascarade
    - reverifier le smoke consolide sans le bridge
  - Resultat:
    - `kxkm-ollama-bridge.service` desactive
    - smoke consolide toujours valide en `200` sur les `6` agents critiques
  - Preuves:
    - `systemctl --user disable --now kxkm-ollama-bridge.service`
    - `bash tools/ops/smoke_mascarade_agents_kxkm.sh --agents kxkm-analysis,kxkm-firmware,kxkm-code,kxkm-cad,kxkm-ops,kxkm-fallback-safe --json`
    - `artifacts/ops/mascarade_agent_smoke/latest.json`
- [x] T-RE-221 — Exposer des presets UI explicites pour les agents `kxkm-*` dans la page `Agents` de Mascarade.
  - Cible:
    - afficher les lanes critiques directement dans l'interface
    - ouvrir le detail agent en un clic depuis le registre
    - republier le front public apres integration
  - Resultat:
    - panneau `KXKM presets for live dispatch` ajoute sur la page `Agents`
    - build public regenere dans `api/public`
    - la surface live s'aligne avec les agents critiques deja verifies en smoke
  - Preuves:
    - `/home/kxkm/mascarade-main/web/src/pages/Agents.tsx`
    - `npm run build:api-public`
    - `bash tools/ops/smoke_mascarade_agents_kxkm.sh --agents kxkm-analysis,kxkm-firmware,kxkm-code,kxkm-cad,kxkm-ops,kxkm-fallback-safe --json`
- [x] T-RE-222 — Brancher un health-check runtime Mascarade/Ollama dans le runbook daily.
  - Cible:
    - ajouter `tools/cockpit/mascarade_runtime_health.sh` avec sortie JSON `cockpit-v1`
    - intégrer l'etat runtime dans `tools/cockpit/run_alignment_daily.sh`
    - exposer provider, model, artefact et statut Mascarade dans le resume consolide
  - Resultat:
    - health-check Mascarade/Ollama ajoute avec smoke agent low-cost et artefacts `latest.*`
    - `run_alignment_daily.sh` execute desormais `mascarade_runtime_health_json` avant le preflight mesh
    - le resume daily exporte `mascarade_health_status`, `mascarade_runtime_status`, `mascarade_provider`, `mascarade_model` et `mascarade_health_artifact`
  - Preuves:
    - `bash tools/cockpit/mascarade_runtime_health.sh --json`
    - `bash tools/cockpit/run_alignment_daily.sh --json --skip-mesh`
- [x] T-RE-223 — Documenter la veille OSS sur les chats multi-agents, presets et personas.
  - Cible:
    - comparer des briques open source reutilisables pour Mascarade/Kill_LIFE
    - documenter les apports UI, agent builder, orchestration et presets
  - Resultat:
    - mini-cartographie ajoutee pour `Open WebUI`, `LibreChat`, `LobeChat`, `AnythingLLM` et `LangGraph`
    - recommandations d'usage reliees aux agents `kxkm-*`, a la surface chat et a l'orchestration `PM / Architect / SyncOps`
  - Preuves:
    - `docs/WEB_RESEARCH_OPEN_SOURCE_2026-03-20.md`
    - `https://docs.openwebui.com/features/`
    - `https://www.librechat.ai/docs/configuration/librechat_yaml/object_structure/agents`
    - `https://github.com/lobehub/lobe-chat`

- [x] T-RE-225 — Publier le bundle global YiACAD (`audit + IA + feature map + OSS + spec + plan + TODO + TUI`).
  - Preuves:
    - `docs/YIACAD_GLOBAL_REFACTOR_AUDIT_2026-03-20.md`
    - `docs/YIACAD_GLOBAL_AI_INTEGRATION_ASSESSMENT_2026-03-20.md`
    - `docs/YIACAD_GLOBAL_FEATURE_MAP_2026-03-20.md`
    - `docs/YIACAD_GLOBAL_OSS_RESEARCH_2026-03-20.md`
    - `specs/yiacad_global_refonte_spec.md`
    - `docs/plans/21_plan_refonte_globale_yiacad.md`
    - `docs/plans/21_todo_refonte_globale_yiacad.md`
    - `tools/cockpit/yiacad_refonte_tui.sh`

- [x] T-UX-004B — Normaliser le contrat de sortie UX commun YiACAD.
  - Preuves:
    - `docs/YIACAD_UIUX_OUTPUT_CONTRACT_2026-03-20.md`
    - `specs/contracts/yiacad_uiux_output.schema.json`
    - `specs/contracts/examples/yiacad_uiux_output.example.json`
    - `specs/yiacad_tux004_orchestration_spec.md`

- [x] T-ARCH-101 — Formaliser le backend YiACAD cible derriere `tools/cad/yiacad_native_ops.py`.
  - Cible:
    - service local ou couche embarquee plus stable que le runner Python direct
    - resolution de contexte projet unifiee KiCad/FreeCAD/artefacts/runtime
    - contrat de sortie reutilisable par shells natifs et TUI
  - Resultat:
    - `yiacad_backend.py` formalise le `context broker` et la sortie UX commune
    - `yiacad_native_ops.py` produit `context.json` et `uiux_output.json`
    - `yiacad_backend_service.py` fournit une facade backend locale adressable pour les futures surfaces shell
  - Preuves:
    - `tools/cad/yiacad_backend.py`
    - `tools/cad/yiacad_native_ops.py`
    - `tools/cad/yiacad_backend_service.py`
    - `docs/YIACAD_BACKEND_ARCHITECTURE_2026-03-20.md`
    - `specs/yiacad_backend_architecture_spec.md`
    - `python3 tools/cad/yiacad_backend_service.py status`
- [x] T-ARCH-101A — Poser le backend local YiACAD, le `context broker` et les contrats associes.
  - Preuves:
    - `tools/cad/yiacad_backend.py`
    - `docs/YIACAD_BACKEND_ARCHITECTURE_2026-03-20.md`
    - `specs/yiacad_backend_architecture_spec.md`

## Delta 2026-03-21 - T-ARCH-101C tranche KiCad facade

- [x] T-ARCH-101C-A — Rerouter la jonction shell KiCad vers la facade backend locale sans ouvrir de hotspot compile.
  - Resultat:
    - `yiacad_kicad_plugin/_native_common.py` privilegie maintenant `tools/cad/yiacad_backend_service.py`
    - le fallback vers `tools/cad/yiacad_native_ops.py` reste disponible si la facade locale est absente
  - Preuves:
    - `.runtime-home/cad-ai-native-forks/kicad-ki/scripting/plugins/yiacad_kicad_plugin/_native_common.py`
    - `python3 tools/cad/yiacad_backend_service.py status`
    - `python3 tools/cad/yiacad_backend_service.py invoke status`

## Delta 2026-03-21 - T-RE-209 hygiene locale

- [x] T-RE-209A — Aligner les surfaces repo-locales autour du blocage runtime reel.
  - Resultat:
    - `tools/cockpit/refonte_tui.sh` propage `--days` vers `yiacad-fusion:clean-logs`
    - `tools/cockpit/render_weekly_refonte_summary.sh` rend explicite que le blocage `kicad-host-entrypoint` reste externe a `Kill_LIFE`
    - `docs/CAD_AI_NATIVE_FORK_STRATEGY.md` documente la frontiere exacte entre hygiene locale fermee et blocage runtime restant
  - Etat:
    - `T-RE-209` parent reste ouvert tant que `mascarade-main/finetune/kicad_mcp_server/dist/index.js` n'est pas materialise ou qu'un fallback conteneur supporte n'est pas acte
  - Preuves:
    - `tools/cockpit/refonte_tui.sh`
    - `tools/cockpit/render_weekly_refonte_summary.sh`
    - `docs/CAD_AI_NATIVE_FORK_STRATEGY.md`

- [x] T-ARCH-101C-B — Rerouter le helper principal FreeCAD vers la facade backend locale sans ouvrir les hotspots compiles.
  - Resultat:
    - `.runtime-home/cad-ai-native-forks/freecad-ki/src/Mod/YiACADWorkbench/yiacad_freecad_gui.py` privilegie maintenant `tools/cad/yiacad_backend_service.py`
    - les call sites UI `Status / ERC-DRC / BOM / Sync` restent inchanges et continuent a consommer un payload YiACAD deforme de la meme maniere
    - le fallback vers `tools/cad/yiacad_native_ops.py` reste disponible
  - Preuves:
    - `.runtime-home/cad-ai-native-forks/freecad-ki/src/Mod/YiACADWorkbench/yiacad_freecad_gui.py`
    - `python3 -m py_compile .runtime-home/cad-ai-native-forks/freecad-ki/src/Mod/YiACADWorkbench/yiacad_freecad_gui.py`
    - `python3 tools/cad/yiacad_backend_service.py status`

- [x] T-ARCH-101C-C — Publier une preuve operateur unifiee `KiCad + FreeCAD -> facade backend -> uiux_output`.
  - Resultat:
    - un runbook canonique `tools/cockpit/yiacad_backend_proof.sh` produit des artefacts horodates
    - la preuve couvre la facade backend locale, le transport helper KiCad, le transport helper FreeCAD et le contrat `uiux_output`
    - `yiacad_uiux_tui.sh` et `yiacad_operator_index.sh` exposent maintenant cette preuve sans commande ad hoc
  - Preuves:
    - `tools/cockpit/yiacad_backend_proof.sh`
    - `docs/YIACAD_BACKEND_OPERATOR_PROOF_2026-03-21.md`
    - `bash tools/cockpit/yiacad_backend_proof.sh --action run`

- [x] T-UX-006A — Poser une session de revue persistante sur les surfaces Python YiACAD.
  - Resultat:
    - le plugin KiCad restaure et persiste la derniere session de revue via `artifacts/cad-ai-native/latest_review_session.json`
    - le workbench FreeCAD persiste et recharge la meme session au niveau de ses helpers Python
    - `yiacad_uiux_tui.sh` expose la lecture de cette session via `--action review-session`
  - Preuves:
    - `.runtime-home/cad-ai-native-forks/kicad-ki/scripting/plugins/yiacad_kicad_plugin/yiacad_action.py`
    - `.runtime-home/cad-ai-native-forks/freecad-ki/src/Mod/YiACADWorkbench/yiacad_freecad_gui.py`
    - `docs/YIACAD_REVIEW_SESSION_2026-03-21.md`
    - `bash tools/cockpit/yiacad_uiux_tui.sh --action review-session`

- [x] T-UX-006B — Ajouter un historique de revue et une taxonomie légère sur les surfaces Python YiACAD.
  - Resultat:
    - KiCad et FreeCAD appendent maintenant un historique commun `artifacts/cad-ai-native/review_history.json`
    - chaque entrée est classée en `review | analysis | sync | status | artifacts`
    - `yiacad_uiux_tui.sh` et `yiacad_operator_index.sh` exposent la lecture de cet historique
  - Preuves:
    - `.runtime-home/cad-ai-native-forks/kicad-ki/scripting/plugins/yiacad_kicad_plugin/yiacad_action.py`
    - `.runtime-home/cad-ai-native-forks/freecad-ki/src/Mod/YiACADWorkbench/yiacad_freecad_gui.py`
    - `docs/YIACAD_REVIEW_SESSION_2026-03-21.md`
    - `bash tools/cockpit/yiacad_uiux_tui.sh --action review-history`
    - `bash tools/cockpit/yiacad_operator_index.sh --action review-history`

- [x] T-UX-006C — Exposer une vue opérateur de taxonomie de revue.
  - Resultat:
    - `yiacad_uiux_tui.sh` calcule un resume lisible de `review_history.json`
    - `yiacad_operator_index.sh` relaye cette vue sans commande ad hoc
    - la taxonomie devient exploitable operatoirement avant toute UI compilee plus profonde
  - Preuves:
    - `tools/cockpit/yiacad_uiux_tui.sh`
    - `tools/cockpit/yiacad_operator_index.sh`
    - `bash tools/cockpit/yiacad_uiux_tui.sh --action review-taxonomy`
    - `bash tools/cockpit/yiacad_operator_index.sh --action review-taxonomy`
    - `specs/contracts/yiacad_context_broker.schema.json`
    - `specs/contracts/examples/yiacad_context_broker.example.json`
- [x] T-ARCH-101B — Produire `context.json` et `uiux_output.json` depuis `yiacad_native_ops.py`.
  - Preuves:
    - `tools/cad/yiacad_native_ops.py`
    - `specs/contracts/yiacad_uiux_output.schema.json`
    - `specs/contracts/examples/yiacad_uiux_output.example.json`
- [x] T-ARCH-101C — Remplacer l'appel CLI direct par un backend YiACAD local plus stable et adressable.
  - Resultat:
    - facade locale publiee dans `tools/cad/yiacad_backend_service.py`
    - client `service-first` publie dans `tools/cad/yiacad_backend_client.py`
    - helpers KiCad / FreeCAD et TUI UI/UX reroutes sur le backend local avec fallback direct conserve
    - preuve operateur unifiee archivee via `tools/cockpit/yiacad_backend_proof.sh`
  - Preuves:
    - `tools/cad/yiacad_backend_service.py`
    - `tools/cad/yiacad_backend_client.py`
    - `tools/cockpit/yiacad_uiux_tui.sh`
    - `tools/cockpit/yiacad_backend_proof.sh`
    - `bash tools/cockpit/yiacad_uiux_tui.sh --action status --json`
    - `bash tools/cockpit/yiacad_backend_proof.sh --action run --json`

- [x] T-OPS-118 — Rationaliser les entrees TUI YiACAD pour reduire la fragmentation operateur.
  - Cible:
    - index canonique `refonte` vs `uiux`
    - lecture courte du prochain lot
    - retention logs et resumés plus lisibles
  - Resultat:
    - `tools/cockpit/yiacad_operator_index.sh` devient l'entree operateur canonique
    - l'index route explicitement vers `yiacad_uiux_tui.sh` et `yiacad_refonte_tui.sh`
    - la doc d'entree est publiee dans `docs/YIACAD_OPERATOR_INDEX_2026-03-21.md`
  - Preuves:
    - `bash tools/cockpit/yiacad_operator_index.sh --action status`
    - `bash tools/cockpit/yiacad_operator_index.sh --action uiux`
    - `bash tools/cockpit/yiacad_operator_index.sh --action global`
    - `bash tools/cockpit/yiacad_operator_index.sh --action logs-summary --json`
    - `docs/YIACAD_OPERATOR_INDEX_2026-03-21.md`

## Consolidation canonique 2026-03-20

- `T-UX-003`:
  - direct native hooks livres sur `KiCad Manager`, `pcbnew`, `eeschema` et `YiACADWorkbench`
  - runner intermediaire `yiacad_ai_bridge.py` retire du chemin principal
- `T-UX-004`:
  - lot ouvert et distribue
  - `T-UX-004B` ferme cote contrat/sortie
  - implementation produit restante sur palette, review center et inspector persistant
- `T-ARCH-101` parent est ferme
  - `T-ARCH-101A` et `T-ARCH-101B` livres
  - facade locale, client `service-first` et preuve operateur publies
  - le front suivant se deplace vers `T-UX-004`, `T-UX-003` et `T-RE-209`
- [x] T-RE-224 — Étendre le health-check Mascarade/Ollama aux surfaces opérateur.
  - Cible:
    - intégrer le check runtime dans `full_operator_lane.sh`
    - exposer une action TUI dédiée dans `refonte_tui.sh`
    - conserver un contrat JSON exploitable avec artefacts et statut runtime
  - Resultat:
    - `full_operator_lane.sh status --json` expose maintenant le résumé health Mascarade/Ollama
    - en cas d'API locale indisponible, `full_operator_lane.sh` génère encore un JSON cockpit avec `summary.status=failed` au lieu d'un crash `curl`
    - `refonte_tui.sh --action mascarade-health` déclenche le check dédié en TUI
    - le lot `all` de `refonte_tui.sh` inclut désormais ce contrôle avant la suite opératoire
  - Preuves:
    - `bash tools/cockpit/full_operator_lane.sh status --json`
    - `bash tools/cockpit/refonte_tui.sh --action mascarade-health`
- [x] T-RE-225 — Ajouter une TUI dédiée pour lire/analyser/purger les logs Mascarade/Ollama.
  - Cible:
    - créer `tools/cockpit/mascarade_logs_tui.sh`
    - brancher l'action dans `refonte_tui.sh`
    - rendre `full_operator_lane` plus explicite sur les erreurs d'API locale
  - Resultat:
    - `mascarade_logs_tui.sh` expose `summary|list|latest|purge [--apply]`
    - `refonte_tui.sh --action mascarade-logs` ouvre la vue opératoire dédiée
    - `full_operator_lane.sh --json` remonte maintenant `status-api-unreachable` au lieu d'une raison générique
  - Preuves:
    - `bash tools/cockpit/mascarade_logs_tui.sh --action summary --json`
    - `bash tools/cockpit/refonte_tui.sh --action mascarade-logs`
    - `bash tools/cockpit/full_operator_lane.sh status --json`
- [x] T-RE-226 — Raccorder le résumé/purge `mascarade-logs` à la lane opérateur.
  - Cible:
    - intégrer `mascarade_logs_tui.sh` dans `full_operator_lane.sh`
    - rendre `dry-run|live|all` plus bavards en cas d'API locale indisponible
    - enrichir le JSON opérateur avec `mascarade_logs_status|stale|purged`
  - Resultat:
    - `full_operator_lane.sh --json` embarque désormais `mascarade_logs_file`, `mascarade_logs_status`, `mascarade_logs_stale`, `mascarade_logs_purged`
    - `purge` pilote aussi la purge des artefacts Mascarade/Ollama via la lane opérateur
    - les erreurs `status-api-unreachable|validate-api-unreachable|run-api-unreachable|poll-api-unreachable` remontent avec `hint` et `suggested_command`
  - Preuves:
    - `bash tools/cockpit/full_operator_lane.sh status --json`
    - `bash tools/cockpit/full_operator_lane.sh purge --json`
- [x] T-RE-227 — Ajouter un mode `logs` natif à `full_operator_lane.sh`.
  - Cible:
    - exposer `summary|latest|purge` via `--logs-action`
    - conserver un JSON opérateur unique sans repasser par `refonte_tui`
    - corriger le texte statique de purge pour inclure les artefacts `full_operator_lane_mascarade_logs_*`
  - Resultat:
    - `full_operator_lane.sh logs --json --logs-action summary|latest|list|purge` est maintenant disponible
    - la sortie JSON opérateur inclut `logs_action`
    - la purge native liste bien aussi `full_operator_lane_mascarade_logs_*.json`
  - Preuves:
    - `bash tools/cockpit/full_operator_lane.sh logs --json --logs-action summary`
    - `bash tools/cockpit/full_operator_lane.sh logs --json --logs-action latest`
    - `bash tools/cockpit/full_operator_lane.sh logs --json --logs-action list`
    - `bash tools/cockpit/full_operator_lane.sh logs --json --logs-action purge`
- [x] T-RE-228 — Rerouter `refonte_tui` vers la surface logs native de la lane opérateur.
  - Cible:
    - faire de `refonte_tui.sh --action mascarade-logs` un raccourci vers `full_operator_lane.sh logs`
    - éviter la divergence entre TUI cockpit et lane opérateur
  - Resultat:
    - `cmd_mascarade_logs` appelle maintenant la surface opérateur native
    - la TUI cockpit et la lane opérateur partagent le même contrat JSON pour les logs Mascarade/Ollama
  - Preuves:
    - `bash tools/cockpit/refonte_tui.sh --action mascarade-logs`
    - `bash tools/cockpit/full_operator_lane.sh logs --json --logs-action summary`
- [x] T-RE-229 — Ajouter des raccourcis TUI dédiés pour `summary|latest|list|purge`.
  - Cible:
    - exposer des actions explicites `mascarade-logs-summary|latest|list|purge`
    - refléter ces entrées dans le menu TUI
  - Resultat:
    - `refonte_tui.sh` propose maintenant 4 raccourcis logs Mascarade/Ollama distincts
    - le menu interactif distingue `summary`, `latest`, `list` et `purge`
  - Preuves:
    - `bash tools/cockpit/refonte_tui.sh --action mascarade-logs-summary`
    - `bash tools/cockpit/refonte_tui.sh --action mascarade-logs-latest`
    - `bash tools/cockpit/refonte_tui.sh --action mascarade-logs-list`
    - `bash tools/cockpit/refonte_tui.sh --action mascarade-logs-purge`
- [x] T-RE-230 — Capturer automatiquement un snapshot `logs latest` après `dry-run|live|all`.
  - Cible:
    - enrichir la lane opérateur avec un snapshot post-run Mascarade/Ollama
    - conserver cet état dans les artefacts et le contrat JSON opérateur
  - Resultat:
    - `full_operator_lane.sh` déclenche désormais `capture_post_run_logs` après `dry-run|live|all`
    - `logs_action` bascule sur `latest` pour les contrats JSON post-run
  - Preuves:
    - `bash tools/cockpit/full_operator_lane.sh dry-run --json`
    - `bash tools/cockpit/full_operator_lane.sh live --json`
    - `bash tools/cockpit/full_operator_lane.sh all --json`
- [x] T-RE-231 — Ajouter un snapshot `mascarade-logs latest` à la routine quotidienne cockpit.
  - Cible:
    - enrichir `run_alignment_daily.sh` avec un artefact logs Mascarade/Ollama
    - faire remonter cet état dans `machine_alignment_daily_latest.log` et le JSON daily
  - Resultat:
    - `run_alignment_daily.sh` exporte maintenant `mascarade_logs_status` et `mascarade_logs_artifact`
    - le résumé daily inclut aussi les lignes `mascarade_logs_*`
  - Preuves:
    - `bash tools/cockpit/run_alignment_daily.sh --json --skip-mesh`
- [x] T-RE-232 — Générer un brief Markdown court des incidents Mascarade/Ollama.
  - Cible:
    - créer `tools/cockpit/render_mascarade_incident_brief.sh`
    - produire un artefact Markdown latest pour la revue opérateur
    - raccorder ce brief à la routine quotidienne
  - Resultat:
    - brief Markdown exporté dans `artifacts/cockpit/mascarade_incident_brief_latest.md`
    - `run_alignment_daily.sh` exporte `mascarade_brief_status`, `mascarade_brief_artifact`, `mascarade_brief_markdown`
  - Preuves:
    - `bash tools/cockpit/render_mascarade_incident_brief.sh --json`
    - `bash tools/cockpit/run_alignment_daily.sh --json --skip-mesh`
- [x] T-RE-233 — Ajouter un registre d’incidents Mascarade/Ollama horodaté.
  - Cible:
    - créer `tools/cockpit/mascarade_incident_registry.sh`
    - agréger briefs cockpit et incidents lane opérateur
    - produire des artefacts latest Markdown/JSON
  - Resultat:
    - registre d'incidents exporté dans `artifacts/cockpit/mascarade_incident_registry_latest.md`
    - format exploitable pour revue opérateur et handoff agentique
  - Preuves:
    - `bash tools/cockpit/mascarade_incident_registry.sh --json`
- [x] T-RE-234 — Intégrer le brief et le registre Mascarade à la synthèse hebdomadaire.
  - Cible:
    - enrichir `render_weekly_refonte_summary.sh`
    - inclure les références brief/registry dans le markdown hebdo
  - Resultat:
    - la synthèse hebdomadaire embarque maintenant une section `Latest Mascarade incident brief`
    - la synthèse hebdomadaire embarque aussi une section `Mascarade incident registry`
  - Preuves:
    - `bash tools/cockpit/render_weekly_refonte_summary.sh`
- [x] T-RE-235 — Documenter la veille OSS sur l’observabilité légère et les incidents.
  - Cible:
    - produire une note dédiée sur les options OSS les plus pertinentes
    - comparer monitoring léger, incidents, status pages et observabilité
  - Resultat:
    - note dédiée créée pour `Uptime Kuma`, `Gatus`, `OpenObserve`, `Grafana OnCall OSS`, `Netdata`
    - décision de lot explicitée: continuer en priorité avec la voie locale légère
  - Preuves:
    - `docs/WEB_RESEARCH_MASCARADE_OBSERVABILITY_2026-03-21.md`
- [x] T-RE-236 — Générer une synthèse opérateur quotidienne Mascarade.
  - Cible:
    - créer `tools/cockpit/render_daily_operator_summary.sh`
    - consolider daily log, brief et registre dans un markdown latest
    - raccorder cette synthèse à `run_alignment_daily.sh`
  - Resultat:
    - `daily_operator_summary_latest.md` est désormais généré dans `artifacts/cockpit/`
    - `run_alignment_daily.sh` exporte `daily_operator_summary_status`, `daily_operator_summary_artifact`, `daily_operator_summary_markdown`
  - Preuves:
    - `bash tools/cockpit/render_daily_operator_summary.sh --json`
    - `bash tools/cockpit/run_alignment_daily.sh --json --skip-mesh`
- [x] T-RE-237 — Ajouter une feature map Mermaid pour la couche Mascarade ops/observability.
  - Cible:
    - cartographier runtime, logs, lane opérateur, briefs, registre, daily et weekly
    - documenter les affectations agents/sous-agents et les paliers P0/P1/P2
  - Resultat:
    - feature map Mermaid ajoutée dans `docs/MASCARADE_OPS_OBSERVABILITY_FEATURE_MAP_2026-03-21.md`
  - Preuves:
    - `docs/MASCARADE_OPS_OBSERVABILITY_FEATURE_MAP_2026-03-21.md`
- [x] T-RE-238 — Brancher la synthèse opérateur quotidienne dans la lane native.
  - Cible:
    - intégrer `render_daily_operator_summary.sh` à `full_operator_lane.sh`
    - exposer `daily_operator_summary_*` dans le JSON opérateur
  - Resultat:
    - `full_operator_lane.sh` embarque désormais la synthèse opérateur quotidienne dans `status|dry-run|live|all|logs`
  - Preuves:
    - `bash tools/cockpit/full_operator_lane.sh status --json`
- [x] T-RE-239 — Ajouter une grille de sévérité/priorité au registre d’incidents Mascarade.
  - Cible:
    - classifier les incidents par sévérité et priorité
    - enrichir le markdown et le JSON registry
  - Resultat:
    - le registre inclut maintenant un résumé `high|medium|low` et `P1|P2|P3`
    - chaque entrée exporte `severity` et `priority`
  - Preuves:
    - `bash tools/cockpit/mascarade_incident_registry.sh --json`
- [x] T-RE-240 — Remonter la sévérité/priorité dans la synthèse hebdomadaire.
  - Cible:
    - intégrer le snapshot `high|medium|low` et `P1|P2|P3` dans `render_weekly_refonte_summary.sh`
  - Resultat:
    - la synthèse hebdomadaire affiche maintenant un résumé de sévérité issu du registre d'incidents Mascarade
  - Preuves:
    - `bash tools/cockpit/render_weekly_refonte_summary.sh`
- [x] T-RE-241 — Ajouter une vue TUI `incidents` dédiée dans `refonte_tui.sh`.
  - Cible:
    - créer `tools/cockpit/mascarade_incidents_tui.sh`
    - exposer `summary|brief|registry|daily` depuis `refonte_tui`
  - Resultat:
    - `refonte_tui.sh` propose désormais une vue incidents Mascarade dédiée
    - accès direct au brief, au registre et à la synthèse quotidienne depuis la TUI cockpit
  - Preuves:
    - `bash tools/cockpit/mascarade_incidents_tui.sh --action summary --json`
    - `bash tools/cockpit/refonte_tui.sh --action mascarade-incidents`
- [x] T-RE-242 — Exporter une file d’incidents Mascarade/Ollama triée par `priority`, `severity` puis récence.
  - Cible:
    - compléter le triptyque `brief -> registry -> queue`
    - produire un artefact Markdown/JSON stable pour l’handoff quotidien
    - réutiliser le registre latest comme source de vérité
  - Resultat:
    - `render_mascarade_incident_queue.sh` ajoute une queue horodatée et un alias `latest`
    - `run_alignment_daily.sh` capture désormais `mascarade_queue_status`, `mascarade_queue_artifact` et `mascarade_queue_markdown`
  - Preuves:
    - `tools/cockpit/render_mascarade_incident_queue.sh`
    - `tools/cockpit/run_alignment_daily.sh`
- [x] T-RE-243 — Faire refléter la synthèse opérateur quotidienne dans le statut final du daily.
  - Cible:
    - recalculer `result` et `contract_status` après `daily_operator_summary`
    - conserver `machine_alignment_daily_latest.log` cohérent avec l’état final
    - exposer aussi les signaux `daily_operator_summary_*` et `mascarade_queue_*` dans la sortie daily
  - Resultat:
    - `run_alignment_daily.sh` réévalue son statut final après la synthèse quotidienne
    - les raisons de dégradation et prochaines actions couvrent maintenant aussi la synthèse opérateur et la queue d’incidents
  - Preuves:
    - `tools/cockpit/run_alignment_daily.sh`
    - `tools/cockpit/render_daily_operator_summary.sh`
- [x] T-RE-244 — Étendre la surface incidents TUI à la file d’incidents priorisée.
  - Cible:
    - exposer `queue` dans `mascarade_incidents_tui.sh`
    - brancher le raccourci `mascarade-incidents-queue` dans `refonte_tui.sh`
    - garder une navigation homogène entre brief, registre, queue et daily
  - Resultat:
    - la TUI incidents couvre désormais `summary|brief|registry|queue|daily`
    - le menu `refonte_tui` expose une entrée dédiée pour la queue d’incidents
  - Preuves:
    - `tools/cockpit/mascarade_incidents_tui.sh`
    - `tools/cockpit/refonte_tui.sh`
- [x] T-RE-245 — Intégrer la queue d’incidents aux synthèses quotidienne et hebdomadaire.
  - Cible:
    - inclure la queue dans `render_daily_operator_summary.sh`
    - inclure la queue dans `render_weekly_refonte_summary.sh`
    - rendre visible la priorisation opératoire dans les handoffs Markdown
  - Resultat:
    - le daily affiche désormais `brief + registry + queue`
    - la synthèse hebdo embarque aussi la dernière queue d’incidents Mascarade
  - Preuves:
    - `tools/cockpit/render_daily_operator_summary.sh`
    - `tools/cockpit/render_weekly_refonte_summary.sh`
- [x] T-RE-246 — Brancher la file d’incidents Mascarade dans la lane opérateur native.
  - Cible:
    - exposer `mascarade_queue_*` dans `full_operator_lane.sh`
    - régénérer la queue avant la synthèse quotidienne dans `status|dry-run|live|all|logs`
    - conserver un JSON opérateur unique pour health, logs, queue et daily
  - Resultat:
    - `full_operator_lane.sh` embarque désormais la queue d’incidents dans son contrat JSON natif
    - la purge lane opérateur prend aussi en compte `full_operator_lane_mascarade_queue_*.json`
  - Preuves:
    - `tools/cockpit/full_operator_lane.sh`
- [x] T-RE-247 — Ajouter un rollup P1/P2/P3 ultra-court dans la synthèse opérateur quotidienne.
  - Cible:
    - remonter `priority_counts` et `severity_counts` dans `render_daily_operator_summary.sh`
    - accélérer la lecture du handoff quotidien sans ouvrir le registre complet
  - Resultat:
    - le daily affiche désormais un résumé `priority P1/P2/P3` et `severity high/medium/low`
    - la sortie JSON du daily expose aussi `priority_counts` et `severity_counts`
  - Preuves:
    - `tools/cockpit/render_daily_operator_summary.sh`
- [x] T-RE-248 — Ajouter une vue TUI `incident-watch` ultra-courte pour la garde opérateur.
  - Cible:
    - exposer un résumé `priority/severity`
    - montrer les premiers incidents de la queue
    - garder une vue terminal rapide avec les `next_steps`
  - Resultat:
    - `mascarade_incidents_tui.sh` expose désormais l'action `watch`
    - `refonte_tui.sh` ajoute le raccourci `mascarade-incidents-watch`
  - Preuves:
    - `tools/cockpit/mascarade_incidents_tui.sh`
    - `tools/cockpit/refonte_tui.sh`
- [x] T-RE-249 — Remonter le rollup d’incidents au niveau top-level dans la lane opérateur native.
  - Cible:
    - promouvoir `priority_counts` et `severity_counts` dans `full_operator_lane.sh --json`
    - éviter d’ouvrir le daily complet pour lire l’état de garde
  - Resultat:
    - la lane opérateur native expose désormais directement les comptes `P1/P2/P3` et `high/medium/low`
  - Preuves:
    - `tools/cockpit/full_operator_lane.sh`
- [x] T-RE-250 — Publier un artefact `incident-watch` court dans la routine daily.
  - Cible:
    - générer un artefact plus court que le `daily_operator_summary`
    - exposer `mascarade_watch_*` dans `run_alignment_daily.sh`
    - garder un point d’entrée garde compatible Markdown et JSON
  - Resultat:
    - `render_mascarade_incident_watch.sh` produit un watchboard court
    - `run_alignment_daily.sh` publie désormais `mascarade_watch_status`, `mascarade_watch_artifact` et `mascarade_watch_markdown`
    - `run_alignment_daily.sh` passe aussi explicitement `--queue-markdown` à la synthèse quotidienne
  - Preuves:
    - `tools/cockpit/render_mascarade_incident_watch.sh`
    - `tools/cockpit/run_alignment_daily.sh`
- [x] T-RE-251 — Consolider la veille officielle `watchboard/status page` pour la couche incident courte.
  - Cible:
    - benchmarker des patterns officiels de vue courte incident/status
    - documenter ce qui est léger vs lourd pour la suite Kill_LIFE
  - Resultat:
    - la note observabilité couvre maintenant aussi `OpenStatus` et `OneUptime`
    - le choix de lot reste une voie légère locale `incident-watch` en TUI
  - Preuves:
    - `docs/WEB_RESEARCH_MASCARADE_OBSERVABILITY_2026-03-21.md`
- [x] T-RE-252 — Brancher le watchboard court dans la lane opérateur native.
  - Cible:
    - exposer `mascarade_watch_*` dans `full_operator_lane.sh`
    - rafraîchir le watchboard après la synthèse quotidienne
    - garder un contrat JSON unique pour la garde opérateur
  - Resultat:
    - `full_operator_lane.sh` embarque désormais aussi `mascarade_watch_status`, `mascarade_watch_file`, `mascarade_watch_markdown`
    - la purge lane opérateur inclut aussi `full_operator_lane_mascarade_watch_*.json`
  - Preuves:
    - `tools/cockpit/full_operator_lane.sh`
- [x] T-RE-253 — Remonter le watchboard court dans la synthèse hebdomadaire.
  - Cible:
    - régénérer `render_mascarade_incident_watch.sh` avant la synthèse hebdo
    - afficher le dernier `incident-watch` dans `render_weekly_refonte_summary.sh`
  - Resultat:
    - la synthèse hebdomadaire embarque désormais aussi le watchboard incident court
  - Preuves:
    - `tools/cockpit/render_weekly_refonte_summary.sh`
    - `tools/cockpit/render_mascarade_incident_watch.sh`
- [x] T-RE-254 — Exposer `incident-watch` et `incident-history` dans l’index opérateur YiACAD.
  - Cible:
    - ajouter un point d’entrée ultra-court pour la garde
    - exposer aussi un historique lisible depuis l’index opérateur
    - garder un accès direct sans passer par plusieurs TUIs
  - Resultat:
    - `yiacad_operator_index.sh` route désormais `incident-watch` et `incident-history`
    - la vue `status` de l’index mentionne explicitement ces deux entrées
  - Preuves:
    - `tools/cockpit/yiacad_operator_index.sh`
- [x] T-RE-255 — Publier un historique `watch` horodaté pour suivre les `P1/P2/P3`.
  - Cible:
    - agréger les artefacts `mascarade_incident_watch_*.json`
    - produire un historique Markdown/JSON court et consultable
    - suivre l’évolution `priority_counts` et `severity_counts` sur plusieurs runs
  - Resultat:
    - `render_mascarade_watch_history.sh` publie désormais `mascarade_watch_history_latest.md` et `.json`
  - Preuves:
    - `tools/cockpit/render_mascarade_watch_history.sh`
- [x] T-RE-256 — Brancher l’historique `watch` dans la routine daily.
  - Cible:
    - produire l’historique après le watchboard courant
    - exposer `mascarade_watch_history_*` dans `run_alignment_daily.sh`
    - intégrer ce signal dans les raisons de dégradation et les prochains pas
  - Resultat:
    - `run_alignment_daily.sh` publie désormais `mascarade_watch_history_status`, `mascarade_watch_history_artifact` et `mascarade_watch_history_markdown`
  - Preuves:
    - `tools/cockpit/run_alignment_daily.sh`
    - `tools/cockpit/render_mascarade_watch_history.sh`
- [x] T-RE-257 — Remonter l’historique `watch` dans la synthèse hebdomadaire.
  - Cible:
    - régénérer l’historique `watch` avant la synthèse hebdo
    - afficher la dernière vue de tendance dans `render_weekly_refonte_summary.sh`
  - Resultat:
    - la synthèse hebdomadaire embarque désormais aussi `watch history`
  - Preuves:
    - `tools/cockpit/render_weekly_refonte_summary.sh`
    - `tools/cockpit/render_mascarade_watch_history.sh`
- [x] T-RE-209 — Implémenter et documenter le lot YiACAD (KiCad + FreeCAD) pour préparation, smoke, statut, logs, purge.
  - Resultat:
    - `tools/cad/yiacad_fusion_lot.sh` couvre `prepare`, `smoke`, `status`, `logs`, `clean-logs`
    - `tools/cockpit/refonte_tui.sh` route bien `yiacad-fusion:prepare|smoke|status|logs|clean-logs`
    - les snapshots `artifacts/cad-fusion/yiacad-fusion-last.log` et `yiacad-fusion-last-status.md` servent de preuve opératoire canonique
    - la documentation canonique du lot est alignée dans `docs/CAD_AI_NATIVE_FORK_STRATEGY.md`
  - Decision:
    - le lot est fermé comme `implémenté/documenté`
    - le blocage runtime restant devient une contrainte externe explicite, pas une dette d’implémentation locale
  - Preuves:
    - `bash tools/cad/yiacad_fusion_lot.sh --action prepare`
    - `bash tools/cad/yiacad_fusion_lot.sh --action smoke`
    - `bash tools/cad/yiacad_fusion_lot.sh --action status`
    - `bash tools/cad/yiacad_fusion_lot.sh --action logs`
    - `bash tools/cad/yiacad_fusion_lot.sh --action clean-logs --days 14`
    - `bash tools/cockpit/refonte_tui.sh --action yiacad-fusion:prepare`
    - `bash tools/cockpit/refonte_tui.sh --action yiacad-fusion:smoke`
    - `bash tools/cockpit/refonte_tui.sh --action yiacad-fusion:status`
    - `docs/CAD_AI_NATIVE_FORK_STRATEGY.md`
  - Statut:
    - `prepare`, `status`, `logs` et `clean-logs` sont validés
    - `smoke` reste volontairement `blocked` uniquement sur `KiCad MCP host smoke` car `mascarade-main` ne matérialise pas `finetune/kicad_mcp_server/dist/index.js`
    - le doctor KiCad recadre `REQUESTED_RUNTIME=auto` vers `SELECTED_RUNTIME=container`, ce qui garde un fallback supporté et traçable
- [x] T-RE-210 — Raccorder `yiacad-fusion` à `tools/autonomous_next_lots.py` et à la synthèse opératoire.
  - Preuves:
    - `python3 tools/autonomous_next_lots.py status`
    - `python3 tools/autonomous_next_lots.py json`
    - `bash tools/cockpit/render_weekly_refonte_summary.sh`
- [x] T-RE-211 — Ajouter une première surface GUI et des utilitaires IA natifs pour KiCad et FreeCAD.
  - Preuves:
    - `tools/cad/yiacad_ai_bridge.py`
    - `tools/cad/install_yiacad_native_gui.sh`
    - `tools/cad/integrations/kicad/yiacad_kicad_plugin/`
    - `tools/cad/integrations/freecad/YiACADWorkbench/`
    - `docs/CAD_AI_NATIVE_GUI_RUNBOOK_2026-03-20.md`
- [x] T-RE-215 — Documenter les points d’insertion natifs KiCad/FreeCAD pour la refonte shell compilée.
  - Preuves:
    - `docs/YIACAD_NATIVE_UI_INSERTION_POINTS_2026-03-20.md`
    - `docs/YIACAD_APPLE_UI_UX_AUDIT_2026-03-20.md`
- [x] T-RE-216 — Raccorder la gouvernance UI/UX Apple-native au README, au manifeste, à la matrice agentique et aux plans/todos vivants.
  - Preuves:
    - `README.md`
    - `docs/REFACTOR_MANIFEST_2026-03-20.md`
    - `docs/AGENT_SPEC_MODULE_MATRIX_2026-03-20.md`
    - `docs/plans/18_plan_enchainement_autonome_des_lots_utiles.md`
    - `docs/plans/18_todo_enchainement_autonome_des_lots_utiles.md`
    - `docs/AI_WORKFLOWS.md`

- P2-bis — Refonte UI/UX Apple-native
  - [x] T-UX-001 — Publier l’audit, la recherche, la feature map et la spec UI/UX Apple-native.
    - Preuves:
      - `docs/YIACAD_APPLE_UI_UX_AUDIT_2026-03-20.md`
      - `docs/YIACAD_APPLE_UI_UX_OSS_RESEARCH_2026-03-20.md`
      - `docs/YIACAD_APPLE_UI_UX_FEATURE_MAP_2026-03-20.md`
      - `specs/yiacad_uiux_apple_native_spec.md`
  - [x] T-UX-002 — Attribuer les owners et sous-agents de la refonte UI/UX aux specs et modules concernés.
    - Preuves:
      - `docs/plans/12_plan_gestion_des_agents.md`
      - `docs/AGENT_SPEC_MODULE_MATRIX_2026-03-20.md`
  - [x] T-UX-003 — Remonter les surfaces Python actuelles vers les points d’insertion natifs KiCad/FreeCAD documentés.
    - Preuves:
      - `.runtime-home/cad-ai-native-forks/kicad-ki/kicad/tools/kicad_manager_control.cpp`
      - `.runtime-home/cad-ai-native-forks/kicad-ki/pcbnew/toolbars_pcb_editor.cpp`
      - `.runtime-home/cad-ai-native-forks/kicad-ki/pcbnew/tools/board_editor_control.cpp`
      - `.runtime-home/cad-ai-native-forks/kicad-ki/eeschema/toolbars_sch_editor.cpp`
      - `.runtime-home/cad-ai-native-forks/kicad-ki/eeschema/tools/sch_editor_control.cpp`
      - `.runtime-home/cad-ai-native-forks/freecad-ki/src/Mod/YiACADWorkbench/yiacad_freecad_gui.py`
      - `.runtime-home/cad-ai-native-forks/freecad-ki/src/Gui/MainWindow.cpp`
      - `test/test_yiacad_native_surface_contract.py`
    - Avancement 2026-03-20:
      - canon normalise: `T-UX-003` couvre la montee native progressive vers les shells documentes; la TUI UI/UX reste un support ops deja livre, hors numerotation canonique `T-UX-003`.
      - decomposition active:
        - `T-UX-003A` = shell toolbars KiCad (`pcbnew`, `eeschema`)
        - `T-UX-003B` = dock/workbench FreeCAD (`yiacad_freecad_gui.py`)
        - `T-UX-003C` = parite control-layer KiCad (`board_editor_control.*`, `sch_editor_control.*`)
        - `T-UX-003D` = prochaine tranche shell FreeCAD (`MainWindow.cpp`)
      - KiCad Manager expose désormais `YiACAD Status` via `kicad/tools/kicad_manager_actions.*`, `kicad/tools/kicad_manager_control.*`, `kicad/menubar.cpp` et `kicad/toolbars_kicad_manager.cpp`.
      - `pcbnew` et `eeschema` regroupent maintenant les actions YiACAD sous un groupe shell `YiACAD Review` dans leurs toolbars natives.
      - garde-fou de lot: `common/eda_base_frame.cpp` est `no-touch`; la surface canonique reste `toolbars_*` + `*_editor_control.*`.
      - risque explicite: runners shell PCB/SCH toujours synchrones et encore dupliqués.
      - premier palier `T-UX-003C` livre: `board_editor_control.cpp` et `sch_editor_control.cpp` utilisent maintenant la meme resolution Python YiACAD (`settings`, `PYTHON_EXECUTABLE`, `python3`) et le meme pont canonique pour `status`.
      - FreeCAD expose désormais un `YiACAD Inspector` dockable via `src/Mod/YiACADWorkbench/InitGui.py` et `src/Mod/YiACADWorkbench/yiacad_freecad_gui.py`.
      - garde-fou FreeCAD: write-set sûr immédiat limité à `yiacad_freecad_gui.py`; plus petit write-set shell compilé acceptable = `src/Gui/MainWindow.cpp` seul.
      - `T-UX-003D` livre: `src/Gui/MainWindow.cpp` crée un dock shell `Std_YiACADShellView`, caché par défaut, avec toggle explicite `YiACAD Shell` et premiere carte shell alignee sur le contrat (`surface`, `status`, `severity`, `summary`, `artifacts`, `next_steps`).
      - `src/Gui/DockWindowManager.cpp` et `src/Gui/ComboView.cpp` restent `no-touch` à cette étape pour éviter double ownership et régression globale du shell.
      - lot clos 2026-03-21: les surfaces natives utiles sont en place et couvertes par un test de regression dédié.
      - le shell compilé plus profond reste un front séparé suivi sous `T-UX-007`, tandis que le blocage runtime hôte reste documenté sous `T-RE-209`.
  - [x] T-UX-004 — Introduire une command palette et un inspector contextuel persistants.
    - Preuves:
      - `.runtime-home/cad-ai-native-forks/kicad-ki/scripting/plugins/yiacad_kicad_plugin/yiacad_action.py`
      - `.runtime-home/cad-ai-native-forks/freecad-ki/src/Mod/YiACADWorkbench/yiacad_freecad_gui.py`
      - `docs/YIACAD_APPLE_UI_UX_FEATURE_MAP_2026-03-20.md`
      - `test/test_yiacad_native_surface_contract.py`
    - Avancement 2026-03-20:
      - lot sur engage d'abord dans les surfaces natives deja controlees par YiACAD: `freecad-ki/src/Mod/YiACADWorkbench/yiacad_freecad_gui.py` et `kicad-ki/scripting/plugins/yiacad_kicad_plugin/yiacad_action.py`.
      - objectif de cette passe: unifier le contrat `command palette / inspector / review center` sans ouvrir les hotspots `MainWindow.cpp`, `DockWindowManager.cpp` et `webview_panel.h`.
      - decomposition active:
        - `T-UX-004A` = palette legere + inspector/review center dans les surfaces deja YiACAD
        - `T-UX-004B` = contrat de sortie UX commun + preuves docs/mermaid
      - support operatoire:
        - `tools/cockpit/yiacad_uiux_tui.sh` expose maintenant `lane-status`, `owners`, `proofs`, `logs-summary` et `logs-latest` pour piloter la lane sans ambiguite.
        - lot `Support UI/UX Ops` ferme apres relecture operatoire des logs et verification TUI.
      - `T-UX-004B` livre:
        - `docs/YIACAD_UIUX_OUTPUT_CONTRACT_2026-03-20.md`
        - `specs/contracts/yiacad_uiux_output.schema.json`
        - `specs/contracts/examples/yiacad_uiux_output.example.json`
      - le contrat borne `status` a `done|degraded|blocked`, `severity` a `info|warning|error`, et rend `artifacts` + `next_steps` directement lisibles par l'UI.
      - le shell FreeCAD `MainWindow.cpp` commence a refléter ce contrat via un dock compile cache par defaut, sans ouvrir les hotspots shell restants.
      - lot clos 2026-03-21: plugin KiCad et workbench FreeCAD exposent palette, review center, session persistante et contexte de revue comme front produit canonique.
      - la propagation eventuelle vers `ComboView.cpp` ou `webview_panel.h` reste un approfondissement shell futur, pas un blocker du lot parent.

- P3 — Gouvernance agents / lots / mémoire opérationnelle
  - [x] T-RE-301 — Produire une routine automatisée de synthèse hebdomadaire à partir de `artifacts/refonte_tui/*`, `docs/MACHINE_SYNC_STATUS_2026-03-20.md`, `specs/04_tasks.md`.
    - Preuves:
      - `bash tools/cockpit/render_weekly_refonte_summary.sh`
      - `bash tools/cockpit/refonte_tui.sh --action weekly-summary`
  - [x] T-RE-302 — Ajouter des sous-tâches dédiées par lot (`docs/plans/12`, `docs/plans/19`, `docs/19`) avec propriétaire explicite.
    - Preuves:
      - `docs/plans/12_plan_gestion_des_agents.md`
      - `docs/plans/19_todo_mesh_tri_repo.md`
  - [x] T-RE-303 — Mettre à jour `SYNTHESE_AGENTIQUE.md` après chaque lot de refonte majeur.
    - Preuve: `SYNTHESE_AGENTIQUE.md`
  - [x] T-RE-304 — Mettre en place une checklist de sortie lot avec preuves log + statut mesh + preflight.
    - Preuves:
      - `docs/plans/18_plan_enchainement_autonome_des_lots_utiles.md`
      - `artifacts/cockpit/weekly_refonte_summary.md`


## P4 — Alignement long terme
  - [x] T-RE-401 — Ajouter un job de vérification CI pour la conformité des références docs (liens internes, sections attendues).

## Delta mesh tri-repo 2026-03-20

### P0

- [x] `T-MESH-001` Contrat mesh tri-repo versionne.
- [x] `T-MESH-002` Preflight `ready|degraded|blocked` pour convergence machines/repos.
- [x] `T-MESH-003` Overlay 8 agents / sous-agents et ownership de lots.
- [x] `T-MESH-004` Spec publique `MCP status`, `handoff`, `repo snapshot`, `workflow handshake`.
- [x] `T-MESH-005` Propagation du contrat dans `mascarade`.
  - Preuves:
    - `bash tools/cockpit/mesh_sync_preflight.sh --json`
    - `bash tools/cockpit/ssh_healthcheck.sh --json`
    - `bash tools/cockpit/refonte_tui.sh --action logs`
- [x] `T-MESH-006` Propagation du handshake schema dans `crazy_life`.
  - Preuves:
    - `bash tools/cockpit/mesh_sync_preflight.sh --json`
    - `bash tools/cockpit/refonte_tui.sh --action logs`

### P1

- [x] `T-LOG-001` TUI `log_ops` pour lecture/analyse/purge controlee.
- [x] `T-DOC-001` Delta README/index/manifeste/agents/MCP setup.
- [x] `T-CI-001` Validation CI du workflow schema handshake.
  - Preuves:
    - `.github/workflows/mesh_contracts.yml` valide les 3 schémas avec `tools/specs/mesh_contract_check.py`.
    - `python3 tools/specs/mesh_contract_check.py --schema specs/contracts/agent_handoff.schema.json --instance specs/contracts/examples/agent_handoff.mesh.json`
    - `python3 tools/specs/mesh_contract_check.py --schema specs/contracts/repo_snapshot.schema.json --instance specs/contracts/examples/repo_snapshot.mesh.json`
    - `python3 tools/specs/mesh_contract_check.py --schema specs/contracts/workflow_handshake.schema.json --instance specs/contracts/examples/workflow_handshake.mesh.json`
- [x] `T-LOT-001` Consommation du handoff contract par tous les lots autonomes.
  - Preuves:
    - `python3 tools/autonomous_next_lots.py json`
- [x] `T-MESH-007` Harmoniser les trackers de lots et plans ouverts avec la commande canonique de planification.
  - Preuves:
    - `bash tools/run_autonomous_next_lots.sh status`
    - `bash tools/cockpit/lot_chain.sh plan --yes`
  - Portee:
    - `docs/plans/12_plan_gestion_des_agents.md`
    - `docs/plans/18_plan_enchainement_autonome_des_lots_utiles.md`
    - `docs/plans/18_todo_enchainement_autonome_des_lots_utiles.md`
    - `docs/plans/19_todo_mesh_tri_repo.md`
    - `specs/03_plan.md`
    - `specs/04_tasks.md`

## Delta full operator lane hardening 2026-03-20

### P0

- [x] `T-OL-001` Valider `dry-run` et `live` sur `clems` avec un bridge runtime reel.
  - Preuves:
    - `bash tools/cockpit/full_operator_lane.sh dry-run --json`
    - `bash tools/cockpit/full_operator_lane.sh live --json`
  - Resultat:
    - `dry-run=success`
    - `live=success`
    - provider/model observes: `claude` / `claude-sonnet-4-6`
- [x] `T-OL-002` Propager le patchset `post-E2E hardening` et restaurer la visibilite preflight sur `clems`.
  - Preuves:
    - `bash tools/cockpit/full_operator_lane_sync.sh --json`
    - `bash tools/cockpit/mesh_sync_preflight.sh --json`
    - `bash tools/cockpit/mesh_dirtyset_sync.sh --json`
  - Statut:
    - visibilite preflight `clems` restauree
    - dirty-sets meshes realignes sur `local`, `clems`, `kxkm`, `root`, `cils`
    - `clems/mascarade-main` et `clems/crazy_life-main` remontent de nouveau en `ready` dans `mesh_sync_preflight`
    - le mesh global reste `degraded` pour des causes separees du patchset operateur (`cils-lockdown`, probe de charge `clems`, convergence dirty-counts)

### P1

- [x] `T-OL-003` Documenter le contrat provider/runtime reel a partir des preuves et des sources officielles.
  - Preuves:
    - `docs/PROVIDER_RUNTIME_COMPAT_2026-03-20.md`
    - `docs/FULL_OPERATOR_LANE_2026-03-20.md`
- [x] `T-OL-004` Ajouter une TUI de propagation pour le patchset operateur.
  - Preuves:
    - `tools/cockpit/full_operator_lane_sync.sh`
- [x] `T-OL-005` Requalifier l'usage d'un `model` explicite apres stabilisation du chemin par defaut.
  - Preuves:
    - `tools/ops/operator_live_provider_smoke.js`
    - `tools/ops/operator_live_provider_smoke.py`
    - `docs/PROVIDER_RUNTIME_COMPAT_2026-03-20.md`
    - `docs/FULL_OPERATOR_LANE_2026-03-20.md`
  - Resultat:
    - plus d'injection automatique de `model` depuis provider/profile dans les runners operateur
    - `model` n'est envoye que sur demande explicite de l'operateur

## Delta agent matrix / dirty-set 2026-03-20

### P0

- [x] `T-AG-001` Attribuer chaque specification `Kill_LIFE` a un agent, sous-agent, competences et write-set dedies.
  - Preuves:
    - `docs/AGENT_SPEC_MODULE_MATRIX_2026-03-20.md`
    - `docs/plans/12_plan_gestion_des_agents.md`
- [x] `T-AG-002` Attribuer chaque module majeur tri-repo a un agent dedie avec hotspots `single-writer`.
  - Preuves:
    - `docs/AGENT_SPEC_MODULE_MATRIX_2026-03-20.md`
- [x] `T-AG-003` Ajouter une TUI de lecture de la matrice et des taches ouvertes.
  - Preuves:
    - `tools/cockpit/agent_matrix_tui.sh`

### P1

- [x] `T-AG-101` Documenter la veille officielle agentic stack / orchestration / MCP.
  - Preuves:
    - `docs/WEB_RESEARCH_AGENTIC_STACK_2026-03-20.md`
- [x] `T-SYNC-101` Nettoyer et realigner les dirty-sets mesh inter-machines sans ecrasement large.
  - Preuves:
    - `tools/cockpit/mesh_dirtyset_sync.sh`
    - `docs/MESH_DIRTYSET_CLEANUP_2026-03-20.md`
- [x] `T-AG-102` Reporter la matrice d'owners dans les TODOs companions sans toucher aux hotspots `single-writer`.
  - Preuves:
    - `/Users/electron/Documents/Lelectron_rare/Github_Repos/Perso/mascarade-main/docs/TODO_MESH_TRI_REPO_2026-03-20.md`
    - `/Users/electron/Documents/Lelectron_rare/Github_Repos/Perso/crazy_life-main/docs/TODO_MESH_TRI_REPO_2026-03-20.md`
- [x] `T-AG-103` Étendre la matrice agentique et la TUI pour couvrir explicitement la lane UI/UX Apple-native et les forks CAD natifs.
  - Preuves:
    - `docs/AGENT_SPEC_MODULE_MATRIX_2026-03-20.md`
    - `tools/cockpit/agent_matrix_tui.sh`

## Delta lot 2026-03-20 - T-UX-003 KiCad native expansion
- `T-UX-003` progresse avec un palier compilé supplémentaire dans `kicad-ki`.
- Livré: `KiCad Manager`, `pcbnew` et `eeschema` exposent désormais une action native `YiACAD Status` dans le chrome KiCad.
- Livré: handlers natifs raccordés aux control layers `board_editor_control` et `sch_editor_control`.
- Livré: surfaces menu/toolbar reliées au bridge existant pour un premier statut contextuel sans nouveau backend.
- Reste ouvert: remplacement du bridge local par un hook backend natif YiACAD, palette de commandes plus profonde, review center persistante, extension FreeCAD au delà du workbench Python.
- Agents actifs sur ce lot: `Sagan` pour `kicad-ki`, `Peirce` pour `freecad-ki`, lane `DesignOps-UI` pour la coordination et les handoffs.

## Delta lot 2026-03-20 - T-UX-003 direct native runner
- `T-UX-003` franchit un second palier: les surfaces natives YiACAD ne ciblent plus `yiacad_ai_bridge.py`.
- Livré: `KiCad Manager`, `pcbnew` et `eeschema` appellent directement `tools/cad/yiacad_native_ops.py` pour `status`, `kicad-erc-drc`, `bom-review`, `ecad-mcad-sync`.
- Livré: le workbench FreeCAD appelle aussi directement `yiacad_native_ops.py` en mémoire via `importlib`.
- Livré: les actions natives exposées dans les shells sont maintenant `YiACAD Status`, `YiACAD ERC/DRC`, `YiACAD BOM Review`, `YiACAD ECAD/MCAD Sync`.
- Reste ouvert: remplacer le runner Python local par un backend YiACAD plus profond, fiabiliser la résolution de contexte projet, ouvrir `T-UX-004` pour palette de commandes et inspector persistant multi-surface.
- Agents actifs sur ce palier: `Godel` pour `kicad-ki`, `Locke` pour `freecad-ki`, lane `DesignOps-UI` pour coordination et documentation.

- 2026-03-20 17:07 +0100 - zeroclaw-integrations revalide: `bash tools/ai/zeroclaw_integrations_import_n8n.sh --json` => `publish_action=published`, `active=true`; `bash tools/ai/zeroclaw_integrations_lot.sh verify --json` => `overall_status=ready`.
- 2026-03-20 17:07 +0100 - T-LC-006 done: fork manuel retenu avec `yiacad-fusion` comme blocage principal et `yiacad-uiux-apple-native` comme lane parallele.

- 2026-03-20 17:08 +0100 - T-LC-001 done: boucle de coherence README/repo couverte par `bash tools/doc/readme_repo_coherence.sh audit` et par le workflow GitHub `.github/workflows/docs_reference_gate.yml`.

## Delta lot 2026-03-20 - ouverture canonique T-UX-004
- `T-UX-004` est priorise comme lot suivant majeur YiACAD.
- Sous-blocs identifies: `palette`, `review center`, `persistent inspector`, `output contract`, `context broker`.
- Artefacts de cadrage generes: `docs/YIACAD_EXHAUSTIVE_REFOUNTE_AUDIT_2026-03-20.md`, `specs/yiacad_tux004_orchestration_spec.md`, `docs/YIACAD_TUX004_FEATURE_MAP_2026-03-20.md`.
- TUI mise a jour: `bash tools/cockpit/yiacad_uiux_tui.sh --action program-audit|next-spec|next-feature-map`.

## Delta lot 2026-03-20 - refonte globale YiACAD
- `T-RE-217`: produire et maintenir le bundle global YiACAD (audit + AI assessment + feature map + research + spec).
- `T-RE-218`: maintenir la TUI globale `yiacad_refonte_tui.sh` et sa politique de logs.
- `T-ARCH-101`: formaliser un backend YiACAD plus stable que `yiacad_native_ops.py` seul.
- `T-UX-005`: ouvrir `T-UX-004` avec palette de commandes, review center et inspector persistant en s'appuyant sur le bundle global.

## Delta 2026-03-21 - operator index stable
- [x] T-OPS-119 — Publier une entree operateur YiACAD stable entre lane UI/UX et refonte globale.
  - Preuves:
    - `docs/YIACAD_OPERATOR_INDEX_2026-03-21.md`
    - `tools/cockpit/yiacad_operator_index.sh`
    - `tools/cockpit/yiacad_uiux_tui.sh`
    - `tools/cockpit/yiacad_refonte_tui.sh`

## Delta 2026-03-21 - T-UX-005 delivered
- [x] T-UX-005 — Enrichir le review center YiACAD sur les surfaces deja controlees.
  - Preuves:
    - `.runtime-home/cad-ai-native-forks/kicad-ki/scripting/plugins/yiacad_kicad_plugin/yiacad_action.py`
    - `.runtime-home/cad-ai-native-forks/freecad-ki/src/Mod/YiACADWorkbench/yiacad_freecad_gui.py`
  - Resultat:
    - sections lisibles `Status`, `Severity`, `Summary`, `Details`, `Context`, `Artifacts`, `Next steps`
    - fallback texte conserve
    - correction d'un bug de rafraichissement cote FreeCAD

## Delta 2026-03-21 - T-UX-006 persistence
- [x] T-UX-006 — Ajouter un inspector/context state plus persistant dans les surfaces deja YiACAD.
  - Preuves:
    - `.runtime-home/cad-ai-native-forks/kicad-ki/scripting/plugins/yiacad_kicad_plugin/yiacad_action.py`
    - `.runtime-home/cad-ai-native-forks/freecad-ki/src/Mod/YiACADWorkbench/yiacad_freecad_gui.py`
  - Resultat:
    - bandeau de session persistant
    - dernier contrat, dernier statut, dernier `context_ref`
    - trajet recent / continuite visuelle entre actions
    - fallback texte conserve

## Delta 2026-03-21 - T-ARCH-101C service-first
- [x] T-ARCH-101C — Introduire un backend YiACAD local plus stable et adressable pour les surfaces actives.
  - Preuves:
    - `tools/cad/yiacad_backend_service.py`
    - `tools/cad/yiacad_backend_client.py`
    - `docs/YIACAD_BACKEND_SERVICE_2026-03-21.md`
    - `tools/cockpit/yiacad_backend_service_tui.sh`
    - `.runtime-home/cad-ai-native-forks/kicad-ki/scripting/plugins/yiacad_kicad_plugin/yiacad_action.py`
    - `.runtime-home/cad-ai-native-forks/freecad-ki/src/Mod/YiACADWorkbench/yiacad_freecad_gui.py`
  - Resultat:
    - chemin `service-first`
    - auto-start du backend local
    - fallback direct conserve
    - surfaces actives Python recablees

## Delta 2026-03-21 - T-UX-006D review context
- [x] T-UX-006D — Exposer une vue compacte du contexte de revue YiACAD dans les surfaces Python et la TUI operateur.
  - Preuves:
    - `.runtime-home/cad-ai-native-forks/kicad-ki/scripting/plugins/yiacad_kicad_plugin/yiacad_action.py`
    - `.runtime-home/cad-ai-native-forks/freecad-ki/src/Mod/YiACADWorkbench/yiacad_freecad_gui.py`
    - `tools/cockpit/yiacad_uiux_tui.sh`
    - `tools/cockpit/yiacad_operator_index.sh`
    - `docs/YIACAD_REVIEW_SESSION_2026-03-21.md`
    - `docs/YIACAD_OPERATOR_INDEX_2026-03-21.md`
  - Resultat:
    - contexte de revue recent enrichi cote KiCad
    - synthese de taxonomie visible cote FreeCAD
    - vue courte `review-context` pour l'operateur

## Delta 2026-03-21 - T-UX-006E context_ref fallback
- [x] T-UX-006E — Rendre le `context_ref` de preuve/backend exploitable meme quand l'entree de preuve reste volontairement invalide.
  - Preuves:
    - `tools/cad/yiacad_backend.py`
    - `tools/cockpit/yiacad_backend_proof.sh`
    - `tools/cockpit/yiacad_uiux_tui.sh`
    - `artifacts/cad-ai-native/20260321T080409-bom-review/context.json`
  - Resultat:
    - `context_ref=project:tmp/nonexistent` dans les preuves recentes
    - `review-context` n'affiche plus `unknown / no context` en tete
    - la preuve backend unifiee reste `done`

## Delta 2026-03-21 - T-UX-006F proof fixtures
- [x] T-UX-006F — Stabiliser le contexte de preuve YiACAD avec des fixtures suivies dans le repo.
  - Preuves:
    - `tools/cad/proof_fixtures/yiacad_backend_proof/probe_board.kicad_pcb`
    - `tools/cad/proof_fixtures/yiacad_backend_proof/probe_model.FCStd`
    - `tools/cockpit/yiacad_backend_proof.sh`
    - `docs/YIACAD_BACKEND_OPERATOR_PROOF_2026-03-21.md`
  - Resultat:
    - le `context_ref` recent ne depend plus d'un chemin temporaire hors repo
    - la preuve backend reste `done`
    - `review-context` devient plus reproductible d'une machine a l'autre

## Delta 2026-03-21 - T-UX-006D contexte de revue

- [x] T-UX-006D — Exposer un contexte de revue synthétique dans les surfaces YiACAD déjà contrôlées.
  - write_set:
    - `.runtime-home/cad-ai-native-forks/kicad-ki/scripting/plugins/yiacad_kicad_plugin/yiacad_action.py`
    - `.runtime-home/cad-ai-native-forks/freecad-ki/src/Mod/YiACADWorkbench/yiacad_freecad_gui.py`
    - `tools/cockpit/yiacad_uiux_tui.sh`
    - `tools/cockpit/yiacad_operator_index.sh`
  - preuves:
    - `bash tools/cockpit/yiacad_uiux_tui.sh --action review-context`
    - `bash tools/cockpit/yiacad_operator_index.sh --action review-context`

## 2026-03-21 - Lot update
- `T-ARCH-101C` etendu: les surfaces KiCad compilees passent en `service-first` via `tools/cad/yiacad_backend_client.py`, avec auto-start du service local et fallback direct vers `tools/cad/yiacad_native_ops.py`.
- `T-OPS-119` consolide: `tools/cockpit/yiacad_operator_index.sh` devient l'entree operateur stable avec `status`, `uiux`, `global`, `backend`, `proofs` et des alias de compatibilite conserves.
- Risque residuel: aucune validation d'execution n'a ete lancee; l'extension aux call sites compiles restants doit etre traitee dans un lot separe.

## 2026-03-21 - Proofs lane
- Nouveau point d'entree: `bash tools/cockpit/yiacad_proofs_tui.sh --action status`.
- Objectif: centraliser `backend`, `review-session`, `review-history`, `review-taxonomy` et l'hygiene des logs dans une surface canonique sans casser les alias historiques.
- Documentation: `docs/YIACAD_PROOFS_TUI_2026-03-21.md`.

## 2026-03-21 - Canonical operator entry
- Entree publique recommandee: `bash tools/cockpit/yiacad_operator_index.sh --action status`.
- Surface de preuves: `bash tools/cockpit/yiacad_proofs_tui.sh --action status`.
- Surface de logs: `bash tools/cockpit/yiacad_logs_tui.sh --action status`.
- Les routes directes historiques restent compatibles, mais ne sont plus l'entree publique recommandee.

## Delta 2026-03-21 - T-RE-258 Tower runtime normalize
- [x] T-RE-258 - Normaliser la pile Mascarade/Ollama de Tower et publier les profils `tower-*`.
  - preuves:
    - `specs/contracts/mascarade_model_profiles.tower.json`
    - `tools/ops/sync_mascarade_agents_tower.sh`
    - `tools/ops/deploy_mascarade_tower_runtime.sh`
    - `docs/MASCARADE_TOWER_RUNTIME_2026-03-21.md`
  - resultat:
    - `tower` est traite comme runtime Mascarade actif et non plus comme cible implicite
    - profils `tower-code`, `tower-text`, `tower-research`, `tower-analysis` publies
    - seed distant prevu dans `/home/clems/mascarade-main/data/agents.json`

## Delta 2026-03-21 - T-RE-259 dispatch mesh heavy-first
- [x] T-RE-259 - Brancher un dispatch mesh explicite pour envoyer les charges lourdes vers `tower`, puis `kxkm`.
  - preuves:
    - `specs/contracts/mascarade_dispatch.mesh.json`
    - `tools/cockpit/mascarade_dispatch_mesh.sh`
    - `docs/MASCARADE_TOWER_RUNTIME_2026-03-21.md`
    - `tools/cockpit/README.md`
  - resultat:
    - familles lourdes `heavy-code`, `heavy-analysis`, `heavy-research` routees vers `tower -> kxkm`
    - texte/docs interactifs gardes sur `kxkm -> tower`
    - `cils` et `root-reserve` restent en bout de chaine

## Delta 2026-03-21 - T-RE-260 product contract consolidation
- [x] T-RE-260 - Publier le contrat produit commun `ops <-> Mascarade <-> kill_life`.
  - preuves:
    - `specs/contracts/ops_mascarade_kill_life.contract.json`
    - `docs/OPS_MASCARADE_KILL_LIFE_PRODUCT_CONTRACT_2026-03-21.md`
    - `tools/cockpit/README.md`
  - resultat:
    - contrat minimal commun defini
    - `trust_level`, `resume_ref`, `routing` et `memory_entry` identifies comme champs de convergence
    - la priorite produit bascule de l'extension de surface vers la consolidation de confiance et de continuite

## Delta 2026-03-21 - T-RE-261 contract projection operator lane
- [x] T-RE-261 - Projeter le contrat produit dans `full_operator_lane`.
  - preuves:
    - `tools/cockpit/full_operator_lane.sh`
    - `tools/cockpit/write_kill_life_memory_entry.sh`
  - resultat:
    - `owner`, `decision`, `resume_ref`, `trust_level`, `routing` et `memory_entry` exposes en JSON
    - la lane operateur ecrit aussi une trace de continuite `kill_life`

## Delta 2026-03-21 - T-RE-262 contract projection daily
- [x] T-RE-262 - Projeter le contrat produit dans `run_alignment_daily`.
  - preuves:
    - `tools/cockpit/run_alignment_daily.sh`
    - `tools/cockpit/write_kill_life_memory_entry.sh`
    - `tools/cockpit/README.md`
  - resultat:
    - la routine daily expose `routing`, `resume_ref`, `trust_level` et `memory_entry`
    - la memoire `kill_life` latest devient le point de reprise canonique pour les runs cockpit

## Delta 2026-03-21 - T-RE-263 contract projection Mascarade short surfaces
- [x] T-RE-263 - Aligner `mascarade_runtime_health` et `mascarade_incidents_tui` sur le contrat produit.
  - preuves:
    - `tools/cockpit/mascarade_runtime_health.sh`
    - `tools/cockpit/mascarade_incidents_tui.sh`
  - resultat:
    - les surfaces Mascarade courtes exposent `resume_ref`, `trust_level`, `routing` et `memory_entry`
    - la lecture de confiance n'est plus reservee aux seules lanes longues

## Delta 2026-03-21 - T-RE-264 handoff continuity markdown
- [x] T-RE-264 - Faire remonter la continuite `kill_life` dans les handoffs quotidiens et hebdomadaires.
  - preuves:
    - `tools/cockpit/render_daily_operator_summary.sh`
    - `tools/cockpit/render_weekly_refonte_summary.sh`
    - `tools/cockpit/README.md`
  - resultat:
    - `trust_level`, `resume_ref` et la cible de routing apparaissent dans les handoffs Markdown
    - l'operateur peut reprendre un run sans relire l'historique brut

## Delta 2026-03-21 - T-RE-265 micro-surfaces Mascarade
- [x] T-RE-265 - Aligner les micro-surfaces Mascarade sur la continuité `kill_life`.
  - preuves:
    - `tools/cockpit/render_mascarade_incident_brief.sh`
    - `tools/cockpit/render_mascarade_incident_queue.sh`
    - `tools/cockpit/render_mascarade_incident_watch.sh`
    - `tools/cockpit/render_mascarade_watch_history.sh`
  - resultat:
    - `trust_level`, `resume_ref`, `routing` et `memory_entry` remontent aussi dans les vues les plus courtes
    - le contexte de reprise est homogène entre JSON et Markdown

## Delta 2026-03-21 - T-RE-266 veille mémoire agentique
- [x] T-RE-266 - Documenter la veille primaire utile sur mémoire, reprise et confiance agentiques.
  - preuves:
    - `docs/WEB_RESEARCH_MASCARADE_OBSERVABILITY_2026-03-21.md`
  - resultat:
    - LangChain, LangGraph, AutoGen et OpenTelemetry recoupes comme sources primaires utiles
    - la marche suivante est clarifiée: stabiliser la mémoire latest avant tout store plus riche

## Delta 2026-03-21 - T-RE-267 kill_life writer fix
- [x] T-RE-267 - Corriger le writer `kill_life` pour persister réellement la liste des artefacts.
  - preuves:
    - `tools/cockpit/write_kill_life_memory_entry.sh`
  - resultat:
    - les `artifacts` sont maintenant correctement transmis à la charge Python
    - la mémoire `kill_life` latest devient exploitable comme inventaire réel de reprise

## Delta 2026-03-21 - T-RE-268 registry/logs continuity
- [x] T-RE-268 - Aligner le registre d'incidents et les vues logs sur la mémoire de reprise `kill_life`.
  - preuves:
    - `tools/cockpit/mascarade_incident_registry.sh`
    - `tools/cockpit/mascarade_logs_tui.sh`
    - `tools/cockpit/README.md`
  - resultat:
    - `trust_level`, `resume_ref`, `routing` et `memory_entry` remontent aussi dans le registre et les logs
    - l'opérateur garde la même lecture de confiance entre état, incidents et continuité

## Delta 2026-03-21 - T-RE-269 operator entry continuity
- [x] T-RE-269 - Exposer la continuité `kill_life` dans les points d'entrée opérateur.
  - preuves:
    - `tools/cockpit/yiacad_operator_index.sh`
    - `tools/cockpit/README.md`
  - resultat:
    - l'index opérateur YiACAD pointe explicitement vers la mémoire `kill_life` latest
    - la reprise n'est plus implicite au niveau des entrées opérateur

## Delta 2026-03-21 - T-RE-270 intelligence memory bridge
- [x] T-RE-270 - Relier la mémoire de gouvernance `intelligence_tui` à la mémoire de reprise `kill_life`.
  - preuves:
    - `tools/cockpit/intelligence_tui.sh`
    - `docs/WEB_RESEARCH_MASCARADE_OBSERVABILITY_2026-03-21.md`
  - resultat:
    - la mémoire intelligence expose aussi les artefacts `kill_life`
    - la gouvernance et la reprise opérateur partagent le même point de continuité

## Delta 2026-03-21 - T-RE-271 refonte_tui continuity
- [x] T-RE-271 - Exposer la continuité `kill_life` depuis l'entrée courte `refonte_tui`.
  - preuves:
    - `tools/cockpit/refonte_tui.sh`
    - `tools/cockpit/README.md`
  - resultat:
    - `refonte_tui.sh --action status` pointe explicitement vers la mémoire `kill_life` latest et le handoff quotidien
    - l'entrée courte cockpit garde le même point de reprise que les autres surfaces opérateur

## Delta 2026-03-21 - T-RE-272 lot_chain continuity bridge
- [x] T-RE-272 - Faire remonter la continuité `kill_life` dans la chaîne de lots cockpit et ses blocs auto-plan/todo.
  - preuves:
    - `tools/cockpit/lot_chain.sh`
    - `tools/cockpit/README.md`
  - resultat:
    - `useful_lots_status.md` affiche aussi la mémoire `kill_life`
    - le bloc auto-plan/todo rappelle le point de reprise commun à la chaîne de lots

## Delta 2026-03-21 - T-RE-273 product contract static audit
- [x] T-RE-273 - Ajouter un audit statique léger pour surveiller la cohérence du contrat `ops <-> Mascarade <-> kill_life`.
  - preuves:
    - `tools/cockpit/product_contract_audit.sh`
    - `artifacts/cockpit/product_contract_audit/latest.json`
    - `artifacts/cockpit/product_contract_audit/latest.md`
  - resultat:
    - la cohérence minimale des surfaces peut être contrôlée sans relancer toute la pile
    - les écarts de continuité deviennent visibles dans un artefact dédié

## Delta 2026-03-21 - T-RE-274 product feature map
- [x] T-RE-274 - Publier une carte de fonctionnalités Mermaid de la convergence produit `ops / Mascarade / kill_life`.
  - preuves:
    - `docs/OPS_MASCARADE_KILL_LIFE_FEATURE_MAP_2026-03-21.md`
    - `tools/cockpit/README.md`
  - resultat:
    - la frontière entre état réel, recommandation et mémoire de reprise devient explicite
    - la priorisation future peut se faire par couche sans réouvrir l'ambiguïté produit

## Delta 2026-03-21 - T-RE-275 durable execution research
- [x] T-RE-275 - Documenter la veille officielle sur contrôle humain et exécution durable pour la couche agentique.
  - preuves:
    - `docs/WEB_RESEARCH_MASCARADE_OBSERVABILITY_2026-03-21.md`
  - resultat:
    - LangGraph, AutoGen et OpenTelemetry recoupés comme sources primaires sur mémoire, HITL et observabilité d'agents
    - la stratégie retenue reste: stabiliser le contrat et la reprise avant toute instrumentation plus lourde

## Delta 2026-03-21 - T-RE-276 product contract handoff
- [x] T-RE-276 - Générer un handoff produit minimal entre audit, mémoire `kill_life` et synthèse quotidienne.
  - preuves:
    - `tools/cockpit/render_product_contract_handoff.sh`
    - `artifacts/cockpit/product_contract_handoff/latest.json`
    - `artifacts/cockpit/product_contract_handoff/latest.md`
  - resultat:
    - un seul point de reprise court résume l'état du contrat produit et le prochain pas opérateur
    - le socle `ops / Mascarade / kill_life` devient lisible sans navigation profonde

## Delta 2026-03-21 - T-RE-277 HITL handoff research
- [x] T-RE-277 - Compléter la veille officielle sur le lien entre HITL, interruption/reprise et handoff opérateur.
  - preuves:
    - `docs/WEB_RESEARCH_MASCARADE_OBSERVABILITY_2026-03-21.md`
  - resultat:
    - LangGraph HITL et incident.io Scribe sont recoupés comme références utiles pour le triplet `pause / resume / summary`
    - le handoff court est confirmé comme meilleur format de reprise avant toute pile plus lourde

## Delta 2026-03-21 - T-RE-278 handoff degraded-safe
- [x] T-RE-278 - Rendre le handoff produit honnête quand les artefacts `kill_life` ou `daily` sont absents.
  - preuves:
    - `tools/cockpit/render_product_contract_handoff.sh`
    - `artifacts/cockpit/product_contract_handoff/latest.json`
  - resultat:
    - le handoff ne remonte plus `ok` si la mémoire de reprise ou le handoff quotidien manquent
    - les prochains pas explicites pointent vers la régénération des artefacts manquants

## Delta 2026-03-21 - T-RE-279 handoff self-healing
- [x] T-RE-279 - Auto-régénérer les prérequis légers du handoff produit sans relancer de lane lourde.
  - preuves:
    - `tools/cockpit/render_product_contract_handoff.sh`
    - `artifacts/cockpit/product_contract_handoff/latest.json`
  - resultat:
    - le handoff tente maintenant de recréer `kill_life_memory/latest.*` et `daily_operator_summary_latest.*` par défaut
    - un mode strict `--no-refresh` reste disponible pour l'audit lecture seule

## Delta 2026-03-21 - T-RE-280 handoff operator integration
- [x] T-RE-280 - Exposer le handoff produit dans `run_alignment_daily` et `full_operator_lane`.
  - preuves:
    - `tools/cockpit/run_alignment_daily.sh`
    - `tools/cockpit/full_operator_lane.sh`
  - resultat:
    - les JSON opérateur remontent `product_contract_handoff_status`, `product_contract_handoff_artifact` et `product_contract_handoff_markdown`
    - le point de reprise canonique devient visible depuis les sorties opérateur principales

## Delta 2026-03-21 - T-RE-281 handoff entrypoint exposure
- [x] T-RE-281 - Afficher le handoff produit dans les points d'entrée opérateur courts.
  - preuves:
    - `tools/cockpit/yiacad_operator_index.sh`
    - `tools/cockpit/refonte_tui.sh`
    - `tools/cockpit/product_contract_audit.sh`
  - resultat:
    - l'opérateur voit le handoff canonique depuis `yiacad_operator_index` et `refonte_tui`
    - l'audit statique vérifie aussi cette exposition

## Delta 2026-03-21 - T-RE-282 handoff runtime/static split
- [x] T-RE-282 - Documenter et verrouiller la séparation audit statique / handoff runtime léger.
  - preuves:
    - `tools/cockpit/README.md`
    - `tools/cockpit/product_contract_audit.sh`
  - resultat:
    - la différence entre cohérence source et disponibilité runtime du point de reprise est explicitée
    - le garde-fou statique reste non-invasif

## Delta 2026-03-21 - T-RE-283 handoff producer fixes
- [x] T-RE-283 - Corriger les deux producteurs légers qui bloquaient le self-healing du handoff produit.
  - preuves:
    - `tools/cockpit/write_kill_life_memory_entry.sh`
    - `tools/cockpit/render_daily_operator_summary.sh`
    - `artifacts/cockpit/product_contract_handoff/latest.json`
  - resultat:
    - le writer `kill_life` ne casse plus sur sa génération Markdown
    - `render_daily_operator_summary.sh --json` n'émet plus deux fois le même payload

## Delta 2026-03-21 - T-RE-284 handoff markdown propagation
- [x] T-RE-284 - Réinjecter le chemin Markdown du handoff produit dans son contrat JSON.
  - preuves:
    - `tools/cockpit/render_product_contract_handoff.sh`
    - `artifacts/cockpit/product_contract_handoff/latest.json`
  - resultat:
    - les chemins opérateur peuvent relire `product_contract_handoff_markdown` sans valeur vide
    - la propagation `run_alignment_daily` / `full_operator_lane` retrouve un contrat complet

## Delta 2026-03-21 - T-RE-285 operator lane multi-json tolerance
- [x] T-RE-285 - Rendre `full_operator_lane` tolérant aux artefacts JSON concaténés hérités.
  - preuves:
    - `tools/cockpit/full_operator_lane.sh`
  - resultat:
    - le helper `json_get` sait relire le dernier objet JSON valide
    - la lane opérateur reste exploitable même si un artefact historique contient plusieurs payloads concaténés

### 2026-03-22 — ERP minimal / Ops bridge

- `T-RE-286` — create canonical `ERP / L'electronrare Ops` bridge contract
- `T-RE-287` — create machine/module/secret ownership registry in `specs/contracts/ops_kill_life_erp_registry.json`
- `T-RE-288` — add TUI registry surface `tools/cockpit/ops_erp_registry_tui.sh`
- `T-RE-289` — document OSS reference set for `PLM / ERP / WMS / MES / DCS`

### 2026-03-22 — WMS artifact index

- `T-RE-290` — create WMS artifact classification contract in `specs/contracts/artifact_wms_index_rules.json`
- `T-RE-291` — add artifact index TUI `tools/cockpit/artifact_wms_index_tui.sh`
- `T-RE-292` — document WMS artifact retrieval and unknown-group surfacing
- `T-RE-293` — extend digital factory research with WMS index and cockpit catalog references (`MLflow`, `Dagster`, `DVC`, `Backstage`, `Rundeck`)

## Delta 2026-03-22 - PCB AI / Forge / BOM / fabrication stack

- [x] T-RE-294 — Documenter la cartographie `PCB Designer AI / Quilter / kicad-happy` autour de `Forge + YiACAD + BOM + JLCPCB`.
  - Livrables:
    - `docs/PCB_AI_FAB_INTEGRATION_MAP_2026-03-22.md`
    - `specs/contracts/pcb_ai_fab_registry.json`
  - Lecture retenue:
    - `PCB Designer AI` = voie `fast-fab` potentielle, sous garde-fou package local.
    - `Quilter` = voie `canary-route` pour placement/routage sous contraintes physiques.
    - `kicad-happy` = reference de playbooks `review/BOM/sourcing/JLCPCB`.
- [x] T-RE-295 — Publier une surface TUI pour lire le registre `PCB AI / fabrication`.
  - Livrable:
    - `tools/cockpit/pcb_ai_fab_tui.sh`
- [ ] T-RE-296 — Executer un canary `Quilter` sur une carte pilote `Hypnoled` avec preuve de round-trip CAD.
- [x] T-RE-297 — Formaliser le contrat `fab package` (`Gerber + BOM + CPL + DRC + provenance`) avant toute lane `one-click fab`.
  - Preuves:
    - `specs/contracts/fab_package.schema.json` — schema JSON Draft 2020-12, `contract_version: fab-package-v1`, champs requis: `bom_file`, `cpl_file`, `gerber_dir`, `drill_file`, `drc_report`, `provenance`, `acceptance_gates`
    - `tools/cockpit/fab_package_tui.sh` — TUI de génération et validation du package
- [x] T-RE-298 — Traduire les patterns `kicad-happy` dans les playbooks `YiACAD / Forge / HW-BOM`.
  - Preuves:
    - `docs/playbooks/kicad_happy_hw_bom_forge.md` — 8 steps canoniques, ownership matrix (Forge/HW-BOM/Embedded-CAD), critères assembly-ready
    - Pilote validé sur Hypnoled: `artifacts/evals/hypnoled_playbook_2026-03-25.md`

## Delta 2026-03-22 - realignment lot 26 + fab package local

- [x] T-RE-299 — Realigner `Plan 26` et la cartographie ecosyteme sur l'etat reel du repo Mascarade actif.
  - preuves:
    - `docs/plans/26_todo_integration_eda_ai_tools.md`
    - `docs/references/github_ecosystem_map.md`
  - resultat:
    - `T-EDA-001` a `T-EDA-005` ne sont plus annonces comme livres sans fichiers reels dans `/Users/electron/Documents/Projets/mascarade`
    - les statuts EDA externes sont ramenes a `planned / not implemented in active repo`
- [x] T-RE-300 — Publier le contrat local `fab package` et sa TUI cockpit.
  - preuves:
    - `specs/contracts/fab_package.schema.json`
    - `docs/FAB_PACKAGE_CONTRACT_2026-03-22.md`
    - `tools/cockpit/fab_package_tui.sh`
  - resultat:
    - un package local standardise `BOM + CPL + Gerber + drill + DRC + provenance` est defini
    - la chaine locale peut sortir `ready|degraded|blocked` avec artefacts `latest.*`
- [x] T-RE-301 — Requalifier l'ordre d'execution Hypnoled autour du gate `fab package`.
  - preuves:
    - `docs/plans/25_todo_hypnoled_pilote.md`
  - resultat:
    - l'ordre strict `T-HP-013 -> T-RE-297 -> T-HP-035 -> T-HP-033 -> T-HP-034` est acte
    - les lots Hypnoled sont explicitement bloques tant que les assets ne sont pas presents dans le checkout courant
- [x] T-RE-302 — Reporter les lots VM Mistral apres fermeture de la chaine hardware/fab locale.
  - preuves:
    - `docs/plans/25_todo_hypnoled_pilote.md`
    - `tools/cockpit/pcb_ai_fab_tui.sh`
  - resultat:
    - la priorite produit reste `BOM/sourcing/fab package` avant `Quilter` et avant `fine-tune VM`
