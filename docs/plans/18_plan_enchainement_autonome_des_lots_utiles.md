# 18) Plan d'enchainement autonome des lots utiles

Last updated: 2026-03-21 15:02:39

Ce plan est regenere localement par `tools/autonomous_next_lots.py`.

## Cycle lot opérationnel

1. detection: `bash tools/run_autonomous_next_lots.sh status`
2. run: `bash tools/run_autonomous_next_lots.sh run`
3. proof JSON: `bash tools/run_autonomous_next_lots.sh json`
4. mise a jour plan/todo
5. revue owner + routing lot suivant
6. synthese operateur + lot exit checklist

## Objectif

Detecter les deltas utiles a traiter, prioriser le prochain lot executable,
mettre a jour un plan/todo operateur, puis relancer les validations associees.

## Regles de priorite

1. lot dirty avec validations requises cassables
2. lot dirty avec validations advisory ou docs
3. repo clean mais en retard sur le remote
4. regime stable sans lot local detecte

## Etat Git courant

- branche: `## main...origin/main`
- dirty paths: `179`
- ahead: `0`
- behind: `0`

### Fichiers dirty detectes

- `.github/workflows/repo_state_header_gate.yml`
- `README.md`
- `SYNTHESE_AGENTIQUE.md`
- `ai-agentic-embedded-base/specs/00_intake.md`
- `ai-agentic-embedded-base/specs/01_spec.md`
- `ai-agentic-embedded-base/specs/02_arch.md`
- `ai-agentic-embedded-base/specs/03_plan.md`
- `ai-agentic-embedded-base/specs/04_tasks.md`
- `ai-agentic-embedded-base/specs/README.md`
- `ai-agentic-embedded-base/specs/zeroclaw_dual_hw_orchestration_spec.md`
- `ai-agentic-embedded-base/specs/zeroclaw_dual_hw_todo.md`
- `deploy/cad/README.md`
- `docs/AGENTIC_LANDSCAPE.md`
- `docs/AI_WORKFLOWS.md`
- `docs/KILL_LIFE_FEATURE_MAP_2026-03-11.md`
- `docs/KILL_LIFE_WORKFLOW_GITHUB_SEQUENCE_2026-03-11.md`
- `docs/KILL_LIFE_WORKFLOW_LOCAL_SEQUENCE_2026-03-11.md`
- `docs/MCP_SETUP.md`
- `docs/QUICKSTART.md`
- `docs/REPO_STATE.md`
- `docs/REPO_STATE_HEADER_CONTRACT.md`
- `docs/RUNBOOK.md`
- `docs/handoffs/handoff_design.md`
- `docs/index.md`
- `docs/plans/12_plan_gestion_des_agents.md`
- `docs/plans/16_plan_cad_modeling_stack.md`
- `docs/plans/README.md`
- `docs/plans/REPO_DEEP_ANALYSIS_2026-03-11.md`
- `docs/repo_state.json`
- `docs/templates/DesignReview.md`
- `docs/templates/PlaytestReport.md`
- `specs/00_intake.md`
- `specs/01_spec.md`
- `specs/02_arch.md`
- `specs/03_plan.md`
- `specs/04_tasks.md`
- `specs/README.md`
- `specs/zeroclaw_dual_hw_orchestration_spec.md`
- `specs/zeroclaw_dual_hw_todo.md`
- `tools/ai/integrations/n8n/README.md`
- `tools/ai/integrations/n8n/kill_life_smoke_workflow.json`
- `tools/ai/zeroclaw_dual_bootstrap.sh`
- `tools/ai/zeroclaw_dual_chat.sh`
- `tools/ai/zeroclaw_hw_firmware_loop.sh`
- `tools/ai/zeroclaw_integrations_down.sh`
- `tools/ai/zeroclaw_integrations_import_n8n.sh`
- `tools/ai/zeroclaw_integrations_lot.sh`
- `tools/ai/zeroclaw_integrations_status.sh`
- `tools/ai/zeroclaw_integrations_up.sh`
- `tools/ai/zeroclaw_stack_up.sh`
- `tools/auto_check_ci_cd.py`
- `tools/autonomous_next_lots.py`
- `tools/bootstrap_mac_mcp.sh`
- `tools/cockpit/README.md`
- `tools/cockpit/cockpit.py`
- `tools/cockpit/lot_chain.sh`
- `tools/github_dispatch_mcp.py`
- `tools/hw/cad_stack.sh`
- `tools/hw/hw_diff.py`
- `tools/hw/kicad_host_mcp_smoke.py`
- `tools/hw/run_kicad_mcp.sh`
- `tools/knowledge_base_mcp.py`
- `tools/lib/runtime_home.sh`
- `tools/repo_state/lint_header_contract.py`
- `tools/repo_state/repo_refresh.sh`
- `tools/run_github_dispatch_mcp.sh`
- `tools/run_knowledge_base_mcp.sh`
- `tools/test_python.sh`
- `.github/workflows/docs_reference_gate.yml`
- `.github/workflows/mesh_contracts.yml`
- `.platformio-local/`
- `ai-agentic-embedded-base/specs/agentic_intelligence_integration_spec.md`
- `ai-agentic-embedded-base/specs/contracts/`
- `ai-agentic-embedded-base/specs/mesh_contracts.md`
- `ai-agentic-embedded-base/specs/yiacad_backend_architecture_spec.md`
- `ai-agentic-embedded-base/specs/yiacad_global_refonte_spec.md`
- `ai-agentic-embedded-base/specs/yiacad_tux004_orchestration_spec.md`
- `ai-agentic-embedded-base/specs/yiacad_uiux_apple_native_spec.md`
- `docs/AGENTIC_INTELLIGENCE_FEATURE_MAP_2026-03-21.md`
- `docs/AGENT_MODULE_ASSIGNMENTS_2026-03-20.md`
- `docs/AGENT_SPEC_MODULE_MATRIX_2026-03-20.md`
- `docs/CAD_AI_NATIVE_FORK_STRATEGY.md`
- `docs/CAD_AI_NATIVE_GUI_RUNBOOK_2026-03-20.md`
- `docs/CAD_AI_NATIVE_HOOKS_2026-03-20.md`
- `docs/FULL_OPERATOR_LANE_2026-03-20.md`
- `docs/KILL_LIFE_CONSOLIDATION_AUDIT_2026-03-21.md`
- `docs/MACHINE_ALIGNMENT_CONTRACT_2026-03-20.md`
- `docs/MACHINE_REGISTRY_2026-03-20.md`
- `docs/MACHINE_SYNC_STATUS_2026-03-20.md`
- `docs/MASCARADE_MODEL_PROFILES_KXKM_AI_2026-03-20.md`
- `docs/MASCARADE_OPS_OBSERVABILITY_FEATURE_MAP_2026-03-21.md`
- `docs/MASCARADE_TOWER_RUNTIME_2026-03-21.md`
- `docs/MESH_DIRTYSET_CLEANUP_2026-03-20.md`
- `docs/MESH_SYNC_INCIDENT_REGISTER_2026-03-20.md`
- `docs/OSS_AI_NATIVE_CAD_RESEARCH_2026-03-20.md`
- `docs/PROVIDER_RUNTIME_COMPAT_2026-03-20.md`
- `docs/REFACTOR_MANIFEST_2026-03-20.md`
- `docs/TRI_REPO_MESH_CONTRACT_2026-03-20.md`
- `docs/WEB_RESEARCH_AGENTIC_STACK_2026-03-20.md`
- `docs/WEB_RESEARCH_MASCARADE_OBSERVABILITY_2026-03-21.md`
- `docs/WEB_RESEARCH_OPEN_SOURCE_2026-03-20.md`
- `docs/YIACAD_APPLE_UI_UX_AUDIT_2026-03-20.md`
- `docs/YIACAD_APPLE_UI_UX_FEATURE_MAP_2026-03-20.md`
- `docs/YIACAD_APPLE_UI_UX_OSS_RESEARCH_2026-03-20.md`
- `docs/YIACAD_AUTONOMOUS_LOT_CHAIN_2026-03-21.md`
- `docs/YIACAD_BACKEND_ARCHITECTURE_2026-03-20.md`
- `docs/YIACAD_BACKEND_OPERATOR_PROOF_2026-03-21.md`
- `docs/YIACAD_BACKEND_SERVICE_2026-03-21.md`
- `docs/YIACAD_EXHAUSTIVE_REFOUNTE_AUDIT_2026-03-20.md`
- `docs/YIACAD_GLOBAL_AI_INTEGRATION_ASSESSMENT_2026-03-20.md`
- `docs/YIACAD_GLOBAL_FEATURE_MAP_2026-03-20.md`
- `docs/YIACAD_GLOBAL_OSS_RESEARCH_2026-03-20.md`
- `docs/YIACAD_GLOBAL_REFACTOR_AUDIT_2026-03-20.md`
- `docs/YIACAD_NATIVE_UI_INSERTION_POINTS_2026-03-20.md`
- `docs/YIACAD_OPERATOR_INDEX_2026-03-21.md`
- `docs/YIACAD_OPERATOR_LOG_CONTRACT_2026-03-21.md`
- `docs/YIACAD_PROOFS_TUI_2026-03-21.md`
- `docs/YIACAD_REVIEW_SESSION_2026-03-21.md`
- `docs/YIACAD_TUX004_FEATURE_MAP_2026-03-20.md`
- `docs/YIACAD_UIUX_OUTPUT_CONTRACT_2026-03-20.md`
- `docs/plans/19_todo_mesh_tri_repo.md`
- `docs/plans/20_plan_refonte_ui_ux_yiacad_apple_native.md`
- `docs/plans/20_todo_refonte_ui_ux_yiacad_apple_native.md`
- `docs/plans/21_plan_refonte_globale_yiacad.md`
- `docs/plans/21_todo_refonte_globale_yiacad.md`
- `docs/plans/22_plan_integration_intelligence_agentique.md`
- `docs/plans/22_todo_integration_intelligence_agentique.md`
- `specs/agentic_intelligence_integration_spec.md`
- `specs/contracts/`
- `specs/mesh_contracts.md`
- `specs/yiacad_backend_architecture_spec.md`
- `specs/yiacad_global_refonte_spec.md`
- `specs/yiacad_tux004_orchestration_spec.md`
- `specs/yiacad_uiux_apple_native_spec.md`
- `test/test_intelligence_tui_contract.py`
- `test/test_log_ops_contract.py`
- `test/test_machine_registry_contract.py`
- `test/test_runtime_ai_gateway_contract.py`
- `test/test_yiacad_native_surface_contract.py`
- `test/test_yiacad_uiux_tui_contract.py`
- `test/test_zeroclaw_n8n_workflow_contract.py`
- `tools/cad/`
- `tools/cockpit/agent_matrix_tui.sh`
- `tools/cockpit/full_operator_lane.sh`
- `tools/cockpit/full_operator_lane_sync.sh`
- `tools/cockpit/intelligence_program_tui.sh`
- `tools/cockpit/intelligence_tui.sh`
- `tools/cockpit/json_contract.sh`
- `tools/cockpit/log_ops.sh`
- `tools/cockpit/machine_registry.sh`
- `tools/cockpit/mascarade_dispatch_mesh.sh`
- `tools/cockpit/mascarade_incident_registry.sh`
- `tools/cockpit/mascarade_incidents_tui.sh`
- `tools/cockpit/mascarade_logs_tui.sh`
- `tools/cockpit/mascarade_models_tui.sh`
- `tools/cockpit/mascarade_runtime_health.sh`
- `tools/cockpit/mesh_dirtyset_sync.sh`
- `tools/cockpit/mesh_health_check.sh`
- `tools/cockpit/mesh_sync_preflight.sh`
- `tools/cockpit/refonte_tui.sh`
- `tools/cockpit/render_daily_operator_summary.sh`
- `tools/cockpit/render_mascarade_incident_brief.sh`
- `tools/cockpit/render_mascarade_incident_queue.sh`
- `tools/cockpit/render_mascarade_incident_watch.sh`
- `tools/cockpit/render_mascarade_watch_history.sh`
- `tools/cockpit/render_weekly_refonte_summary.sh`
- `tools/cockpit/run_alignment_daily.sh`
- `tools/cockpit/runtime_ai_gateway.sh`
- `tools/cockpit/ssh_healthcheck.sh`
- `tools/cockpit/yiacad_backend_proof.sh`
- `tools/cockpit/yiacad_backend_service_tui.sh`
- `tools/cockpit/yiacad_logs_tui.sh`
- `tools/cockpit/yiacad_operator_index.sh`
- `tools/cockpit/yiacad_proofs_tui.sh`
- `tools/cockpit/yiacad_refonte_tui.sh`
- `tools/cockpit/yiacad_uiux_tui.sh`
- `tools/ops/`
- `tools/specs/mesh_contract_check.py`
- `workflows/embedded-operator-live.json`

## Gouvernance intelligence

- status: `done`
- open_task_count: `0`
- memory: `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/artifacts/cockpit/intelligence_program/latest.json`
- next actions:
  - No open tasks detected in docs/plans/22_todo_integration_intelligence_agentique.md.

## Matrice lot -> owner -> dépendances -> rollback

## Lots detectes

### 1. `zeroclaw-integrations` — Runtime local ZeroClaw / n8n

- owner: team=PM, agent=PM-Mesh, repo=Kill_LIFE
- dependencies: `none`
- rollback:
  - Revenir à la lane `zeroclaw` manuelle si le container n8n échoue de manière persistante.
  - Rejouer `bash tools/run_autonomous_next_lots.sh run --no-write` puis arbitrer manuellement.
Fermer la lane d'integrations locales ZeroClaw/n8n, les evidences I-205 associees, puis resynchroniser les plans versionnes d'enchainement autonome et le cockpit local.

- references: `specs/zeroclaw_dual_hw_todo.md`, `docs/plans/18_plan_enchainement_autonome_des_lots_utiles.md`
- validations: `2` done, `0` advisory, `0` blocked
- handoff: lot_id=zeroclaw-integrations, owner_repo=Kill_LIFE, owner_agent=PM-Mesh, owner_subagent=none, status=done
- write_set: specs/zeroclaw_dual_hw_todo.md, tools/cockpit/lot_chain.sh, tools/cockpit/run_next_lots_autonomously.sh

### 2. `mesh-governance` — Gouvernance mesh tri-repo

- owner: team=PM, agent=PM-Mesh, repo=Kill_LIFE
- dependencies: `zeroclaw-integrations`
- rollback:
  - Retirer le lot `mesh-governance` du déclenchement auto si la convergence reste bloquée.
  - Conserver le contrat mesh en mode lecture seule et documenter la dérogation.
Versionner le contrat tri-repo, verrouiller les ownerships agents, et outiller le preflight de synchro continue sans ecraser le travail des autres contributeurs.

- references: `docs/TRI_REPO_MESH_CONTRACT_2026-03-20.md`, `docs/plans/12_plan_gestion_des_agents.md`, `specs/03_plan.md`
- validations: `5` done, `0` advisory, `0` blocked
- handoff: lot_id=mesh-governance, owner_repo=Kill_LIFE, owner_agent=PM-Mesh, owner_subagent=none, status=done
- write_set: docs/TRI_REPO_MESH_CONTRACT_2026-03-20.md, docs/MACHINE_SYNC_STATUS_2026-03-20.md, docs/plans/19_todo_mesh_tri_repo.md, tools/cockpit/mesh_sync_preflight.sh, tools/cockpit/ssh_healthcheck.sh

### 3. `mcp-runtime` — Alignement MCP runtime local

- owner: team=Architect-Firmware, agent=Runtime-Companion, repo=Kill_LIFE
- dependencies: `zeroclaw-integrations`
- rollback:
  - Désactiver les changements MCP introduits dans le lot et revenir à la configuration de référence.
  - Conserver la preuve de doc dans `docs/MCP_SETUP.md` et relancer uniquement en mode validation.
Stabiliser les launchers MCP, le bootstrap Mac, la resolution du repo compagnon et la doc operateur associee.

- references: `docs/plans/15_plan_mcp_runtime_alignment.md`, `docs/plans/17_plan_target_architecture_mcp_agentics_2028.md`
- validations: `3` done, `2` advisory, `0` blocked
- handoff: lot_id=mcp-runtime, owner_repo=Kill_LIFE, owner_agent=Runtime-Companion, owner_subagent=none, status=degraded
- write_set: docs/MCP_SETUP.md, tools/bootstrap_mac_mcp.sh, tools/lib/runtime_home.sh, tools/run_github_dispatch_mcp.sh

### 4. `cad-mcp-host` — Runtime CAD host-first

- owner: team=Architect-Firmware, agent=Embedded-CAD, repo=Kill_LIFE
- dependencies: `mcp-runtime`
- rollback:
  - Retour automatique au mode container-only (`tools/hw/cad_stack.sh`).
  - Conserver les chemins explicites de script pour éviter une dérive host-first.
Qualifier KiCad, FreeCAD et OpenSCAD en host-first sur macOS tout en gardant le fallback conteneur operable.

- references: `docs/plans/16_plan_cad_modeling_stack.md`, `docs/plans/17_plan_target_architecture_mcp_agentics_2028.md`
- validations: `4` done, `0` advisory, `0` blocked
- handoff: lot_id=cad-mcp-host, owner_repo=Kill_LIFE, owner_agent=Embedded-CAD, owner_subagent=none, status=done
- write_set: docs/MCP_SETUP.md, tools/hw/cad_stack.sh, tools/hw/run_kicad_mcp.sh

### 5. `yiacad-fusion` — Fusion KiCad + FreeCAD IA-native

- owner: team=CAD-Fusion, agent=CAD-Fusion, repo=Kill_LIFE
- dependencies: `cad-mcp-host`
- rollback:
  - Geler la branche `kill-life-ai-native` et revenir au mode container-only (`tools/hw/cad_stack.sh`).
  - Conserver les artefacts YiACAD (`artifacts/cad-fusion`) et la synthese hebdomadaire comme preuve.
  - Basculer l'execution en mode `status` + `clean-logs` si le smoke bloque.
Mettre en place le lot YiACAD (`prepare`, `smoke`, `status`, `logs`, `clean-logs`) et la synthese operateur associee sans fusion automatique de `main`.

- references: `docs/CAD_AI_NATIVE_FORK_STRATEGY.md`, `docs/OSS_AI_NATIVE_CAD_RESEARCH_2026-03-20.md`, `docs/plans/18_todo_enchainement_autonome_des_lots_utiles.md`
- validations: `2` done, `1` advisory, `0` blocked
- handoff: lot_id=yiacad-fusion, owner_repo=Kill_LIFE, owner_agent=CAD-Fusion, owner_subagent=none, status=degraded
- write_set: docs/CAD_AI_NATIVE_FORK_STRATEGY.md, docs/OSS_AI_NATIVE_CAD_RESEARCH_2026-03-20.md, tools/cad/ai_native_forks.sh, tools/cad/yiacad_fusion_lot.sh, tools/cockpit/refonte_tui.sh, tools/cockpit/render_weekly_refonte_summary.sh

### 6. `python-local` — Execution Python repo-locale

- owner: team=Architect-Firmware, agent=Firmware, repo=Kill_LIFE
- dependencies: `mcp-runtime`, `cad-mcp-host`
- rollback:
  - Revenir à l'exécution Python système si la venv locale est instable.
  - Limiter les changements au lot `tools/test_python.sh` jusqu'à stabilisation.
Garder les scripts et smokes sur l'interpreteur repo-local plutot que sur le Python systeme.

- references: `docs/plans/15_plan_mcp_runtime_alignment.md`
- validations: `1` done, `0` advisory, `0` blocked
- handoff: lot_id=python-local, owner_repo=Kill_LIFE, owner_agent=Firmware, owner_subagent=none, status=done
- write_set: tools/test_python.sh, tools/run_validate_specs_mcp.sh, tools/validate_specs_mcp_smoke.py

## Questions a poser seulement si besoin reel

- Aucune question bloquante detectee sur ce cycle.

## Commandes operateur

- `bash tools/run_autonomous_next_lots.sh status`
- `bash tools/run_autonomous_next_lots.sh run`
- `bash tools/run_autonomous_next_lots.sh json`
- `bash tools/cockpit/render_weekly_refonte_summary.sh`

