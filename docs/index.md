# Kill_LIFE — Documentation opérateur canonique

Cette page est l'entrée opérateur recommandée pour `Kill_LIFE`. Elle sert de table de routage entre le cockpit shell/TUI, les preuves, les runbooks et les documents de décision.

## Entrées canoniques

| Surface | Rôle | Entrée |
| --- | --- | --- |
| Produit / programme | vision, périmètre, arbitrages | `README.md` |
| Audit consolidé | forces, faiblesses, opportunités, risques, IA | `docs/KILL_LIFE_CONSOLIDATION_AUDIT_2026-03-22.md` |
| Cockpit opérateur | shell/TUI, contrats JSON, statut runtime | `bash tools/cockpit/yiacad_operator_index.sh --action status` |
| Gouvernance intelligence | owners, mémoire, prochaines actions | `bash tools/cockpit/intelligence_tui.sh --action status --json` |
| Gateway runtime/MCP/IA | synthèse consolidée des signaux runtime | `bash tools/cockpit/runtime_ai_gateway.sh --action status --refresh --json` |
| Refonte cockpit | raccourcis historiques et lots | `bash tools/cockpit/refonte_tui.sh --action status` |
| Lane opérateur | exécution consolidée, logs, preuves | `bash tools/cockpit/full_operator_lane.sh status --json` |
| Ops unifié | logs + weekly + lane en un seul point | `bash tools/cockpit/unified_ops_entry.sh --action all --json` |
| Routine quotidienne | health-check, logs, mesh, synthèse | `bash tools/cockpit/run_alignment_daily.sh --json` |
| Evidence packs | consolidation multi-repo | `bash tools/cockpit/evidence_pack_builder.sh --json` |
| Pilotage lots | workflow guidé lot lifecycle | `bash tools/cockpit/lot_pilot_assistant.sh --action status` |
| Chaîne spec-first | source de vérité documentaire | `specs/README.md` |

## Navigation rapide

### Démarrage

- Installation: `docs/INSTALL.md`
- Quickstart: `docs/QUICKSTART.md`
- Runbook opérateur: `docs/RUNBOOK.md`
- FAQ: `docs/FAQ.md`
- Runtime home: `docs/RUNTIME_HOME.md`

### Gouvernance et consolidation

- Audit consolidé: `docs/KILL_LIFE_CONSOLIDATION_AUDIT_2026-03-21.md`
- Audit consolidé 2026-03-22: `docs/KILL_LIFE_CONSOLIDATION_AUDIT_2026-03-22.md`
- Audit workspace 2026-03-24: `docs/workspace_audit_2026-03-24/README.md`
- Manifeste refonte: `docs/REFACTOR_MANIFEST_2026-03-20.md`
- Contrat tri-repo: `docs/TRI_REPO_MESH_CONTRACT_2026-03-20.md`
- Gestion des agents: `docs/plans/12_plan_gestion_des_agents.md`
- Checklist multi-agent: `docs/GLOBAL_MULTI_AGENT_CHECKLIST.md`
- Plan integration intelligence: `docs/plans/22_plan_integration_intelligence_agentique.md`
- TODO integration intelligence: `docs/plans/22_todo_integration_intelligence_agentique.md`
- Plan YiACAD Git EDA: `docs/plans/23_plan_yiacad_git_eda_platform.md`
- TODO YiACAD Git EDA: `docs/plans/23_todo_yiacad_git_eda_platform.md`
- Plan Factory 4.0: `docs/plans/27_plan_factory_4_0_mcp_opcua_mqtt.md`
- TODO Factory 4.0: `docs/plans/27_todo_factory_4_0_mcp_opcua_mqtt.md`
- Vue canonique subsystems: `docs/CANONICAL_SUBSYSTEM_VIEW.md`
- MCP/Service boundary: `docs/MCP_SERVICE_BOUNDARY.md`
- Project template: `docs/PROJECT_TEMPLATE.md`
- Hypnoled status: `docs/HYPNOLED_STATUS_2026-03-25.md`
- Mistral Studio status: `docs/MISTRAL_STUDIO_STATUS_2026-03-25.md`
- Backlog canonique: `specs/04_tasks.md`
- Plan d'enchaînement autonome: `docs/plans/18_plan_enchainement_autonome_des_lots_utiles.md`

### Cockpit, preuves et santé runtime

- Cockpit README: `tools/cockpit/README.md`
- Intelligence program TUI: `bash tools/cockpit/intelligence_tui.sh --action status`
- Memoire intelligence: `bash tools/cockpit/intelligence_tui.sh --action memory --json`
- Scorecard intelligence: `bash tools/cockpit/intelligence_tui.sh --action scorecard --json`
- Comparaison inter-repos: `bash tools/cockpit/intelligence_tui.sh --action comparison --json`
- File recommandations IA: `bash tools/cockpit/intelligence_tui.sh --action recommendations --json`
- Gateway runtime/MCP/IA: `bash tools/cockpit/runtime_ai_gateway.sh --action status --refresh --json`
- Index opérateur YiACAD: `bash tools/cockpit/yiacad_operator_index.sh --action status`
- Santé mesh: `bash tools/cockpit/mesh_health_check.sh --json`
- Santé SSH: `bash tools/cockpit/ssh_healthcheck.sh --json`
- Santé Mascarade/Ollama: `bash tools/cockpit/mascarade_runtime_health.sh --json`
- Surface de preuves: `bash tools/cockpit/yiacad_proofs_tui.sh --action status`
- Surface de logs: `bash tools/cockpit/yiacad_logs_tui.sh --action status`

### Specs, plans et tâches

- Chaîne canonique: `specs/README.md`
- Intake: `specs/00_intake.md`
- Spec: `specs/01_spec.md`
- Architecture: `specs/02_arch.md`
- Plan: `specs/03_plan.md`
- Tâches: `specs/04_tasks.md`

### Outils libres (alternatives gratuites aux API payantes)

- Fine-tune local QLoRA (Unsloth, RTX 4090): `python3 tools/mistral/local_finetune.py --help`
- Modelfile Ollama template: `tools/mistral/Modelfile.template`
- OCR datasheet pipeline (marker/surya/pypdf2): `python3 tools/industrial/ocr_pipeline.py --help`
- STT pipeline (whisper.cpp/whisper/vosk): `python3 tools/industrial/stt_pipeline.py --help`
- Freerouting bridge (KiCad DSN autorouting): `python3 tools/industrial/freerouting_bridge.py --help`

### Veille et benchmark

- Veille OSS principale: `docs/WEB_RESEARCH_OPEN_SOURCE_2026-03-20.md`
- Veille OSS / agentic / MCP 2026-03-22: `docs/WEB_RESEARCH_OPEN_SOURCE_2026-03-22.md`
- Veille CAD IA-native: `docs/OSS_AI_NATIVE_CAD_RESEARCH_2026-03-20.md`
- Workflows IA: `docs/AI_WORKFLOWS.md`
- Paysage agentique: `docs/AGENTIC_LANDSCAPE.md`
- Plateforme web Git EDA: `docs/YIACAD_GIT_EDA_PLATFORM_2026-03-22.md`
- Phase active 2026-03-22: alignement lot 22 + plan 23, durcissement cockpit/logs, veille officielle MCP/agentique/IA, priorisation Git/CI/artifacts/collab pour `web/`.

## Routines recommandées

### Routine quotidienne

```bash
bash tools/cockpit/run_alignment_daily.sh --json
bash tools/cockpit/log_ops.sh --action summary --json
bash tools/cockpit/mesh_health_check.sh --json --load-profile tower-first
```

### Revue de lots

```bash
bash tools/run_autonomous_next_lots.sh status
bash tools/cockpit/refonte_tui.sh --action lots-status
bash tools/cockpit/refonte_tui.sh --action weekly-summary
```

### Gouvernance intelligence

```bash
bash tools/cockpit/lot_chain.sh status
bash tools/cockpit/intelligence_tui.sh --action next-actions
bash tools/cockpit/intelligence_tui.sh --action memory --json
bash tools/cockpit/intelligence_tui.sh --action scorecard --json
bash tools/cockpit/intelligence_tui.sh --action comparison --json
bash tools/cockpit/intelligence_tui.sh --action recommendations --json
bash tools/cockpit/runtime_ai_gateway.sh --action status --refresh --json
```

### Validation locale stable

```bash
bash tools/test_python.sh --suite stable
python3 tools/validate_specs.py --strict --require-mirror-sync
```

## Pilotage des extensions VS Code

Les extensions ne vivent pas dans ce repo, mais `Kill_LIFE` reste leur source de vérité documentaire et opératoire:

- `kill-life-studio`: produit, specs, décisions, critères d'acceptation
- `kill-life-mesh`: orchestration multi-repo, contrats, dépendances, ownership
- `kill-life-operator`: runbooks, checks, preuves, exécution

Le socle commun validé côté extensions est documenté dans `docs/KILL_LIFE_CONSOLIDATION_AUDIT_2026-03-21.md`.

## Références mémoire et preuves

- Synthèse globale: `SYNTHESE_AGENTIQUE.md`
- Evidence pack: `docs/evidence/evidence_pack.md`
- Handoffs: `docs/handoffs/`
- Templates: `docs/templates/`
- Tests: `test/`
