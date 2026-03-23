# 18) TODO enchainement autonome des lots utiles

Last updated: 2026-03-21 15:02:39

Ce fichier est regenere localement par `tools/autonomous_next_lots.py`.

## `intelligence-governance`

- status: done
- open_task_count: 0
- next: No open tasks detected in docs/plans/22_todo_integration_intelligence_agentique.md.
- evidence: /Users/electron/Documents/Lelectron_rare/Kill_LIFE/artifacts/cockpit/intelligence_program/latest.json

## `zeroclaw-integrations` — Runtime local ZeroClaw / n8n

- done: lot detecte (Fermer la lane d'integrations locales ZeroClaw/n8n, les evidences I-205 associees, puis resynchroniser les plans versionnes d'enchainement autonome et le cockpit local.)
- done: `bash tools/ai/zeroclaw_integrations_lot.sh verify --json`
  resume: {"lot_id": "zeroclaw-integrations-n8n", "syntax_ok": true, "overall_status": "ready", "blockers": [], "status": {"status": "ready", "reason": "", "container": "mascarade-n8n", "container_exists": true, "container_running": true, "container_status": "Up 3 minutes", "internal_http_ok": true, "host_http_ok": true, "n8n_url": "http://127.0.0.1:5678/", "n8n_health_url": "http://127.0.0.1:5678/healthz", "tracked_workflow_id": "kill-life-n8n-smoke", "runtime_alerts": [], "workflow_probe_status": "not_queried", "active_probe_status": "not_queried", "workflow_ids": [], "active_workflow_ids": []}, "import": {"workflow_id": "kill-life-n8n-smoke", "input_file": "/Users/electron/Documents/Lelectron_rare/Kill_LIFE/tools/ai/integrations/n8n/kill_life_smoke_workflow.json", "container": "mascarade-n8n", "import_action": "skipped", "publish_action": "skipped", "active": true}}
- done: `bash tools/test_python.sh --suite stable`
  resume: ---------------------------------------------------------------------- | Ran 3 tests in 0.035s | OK
- handoff lot_id: zeroclaw-integrations
  owner_repo=Kill_LIFE
  owner_agent=PM-Mesh
  owner_team=PM
  dependencies=none
  rollback=Revenir à la lane `zeroclaw` manuelle si le container n8n échoue de manière persistante. | Rejouer `bash tools/run_autonomous_next_lots.sh run --no-write` puis arbitrer manuellement.
  write_set=specs/zeroclaw_dual_hw_todo.md, tools/cockpit/lot_chain.sh, tools/cockpit/run_next_lots_autonomously.sh

## `mesh-governance` — Gouvernance mesh tri-repo

- done: lot detecte (Versionner le contrat tri-repo, verrouiller les ownerships agents, et outiller le preflight de synchro continue sans ecraser le travail des autres contributeurs.)
- done: `bash tools/cockpit/mesh_sync_preflight.sh --json`
  resume:   ] | } | WARN 2026-03-21 15:01:49 +0100 Mesh sync preflight degraded: downgrade to controlled lots for affected repos
- done: `bash tools/cockpit/ssh_healthcheck.sh --json`
  resume:   ] | } | INFO 2026-03-21 15:01:55 +0100 SSH health-check: all targets reachable
- done: `python3 tools/specs/mesh_contract_check.py --schema specs/contracts/agent_handoff.schema.json --instance specs/contracts/examples/agent_handoff.mesh.json`
  resume:   "schema": "specs/contracts/agent_handoff.schema.json", |   "instance": "specs/contracts/examples/agent_handoff.mesh.json" | }
- done: `python3 tools/specs/mesh_contract_check.py --schema specs/contracts/repo_snapshot.schema.json --instance specs/contracts/examples/repo_snapshot.mesh.json`
  resume:   "schema": "specs/contracts/repo_snapshot.schema.json", |   "instance": "specs/contracts/examples/repo_snapshot.mesh.json" | }
- done: `python3 tools/specs/mesh_contract_check.py --schema specs/contracts/workflow_handshake.schema.json --instance specs/contracts/examples/workflow_handshake.mesh.json`
  resume:   "schema": "specs/contracts/workflow_handshake.schema.json", |   "instance": "specs/contracts/examples/workflow_handshake.mesh.json" | }
- handoff lot_id: mesh-governance
  owner_repo=Kill_LIFE
  owner_agent=PM-Mesh
  owner_team=PM
  dependencies=zeroclaw-integrations
  rollback=Retirer le lot `mesh-governance` du déclenchement auto si la convergence reste bloquée. | Conserver le contrat mesh en mode lecture seule et documenter la dérogation.
  write_set=docs/TRI_REPO_MESH_CONTRACT_2026-03-20.md, docs/MACHINE_SYNC_STATUS_2026-03-20.md, docs/plans/19_todo_mesh_tri_repo.md, tools/cockpit/mesh_sync_preflight.sh, tools/cockpit/ssh_healthcheck.sh

## `mcp-runtime` — Alignement MCP runtime local

- done: lot detecte (Stabiliser les launchers MCP, le bootstrap Mac, la resolution du repo compagnon et la doc operateur associee.)
- done: `bash tools/bootstrap_mac_mcp.sh codex`
  resume: codex mcp add openscad --env MASCARADE_DIR=/Users/electron/Documents/Lelectron_rare/Github_Repos/Perso/mascarade-main -- bash /Users/electron/Documents/Lelectron_rare/Kill_LIFE/tools/run_openscad_mcp.sh | codex mcp add huggingface --url https://huggingface.co/mcp --bearer-token-env-var HUGGINGFACE_API_KEY | codex mcp add playwright -- npx -y @playwright/mcp@latest
- done: `bash tools/bootstrap_mac_mcp.sh json`
  resume:     } |   } | }
- done: `.venv/bin/python tools/validate_specs_mcp_smoke.py --json --quick`
  resume: {"status": "ready", "protocol_version": "2025-03-26", "server_name": "validate-specs", "tool_count": 2, "checks": ["initialize", "tools/list"], "error": null}
- advisory: `.venv/bin/python tools/knowledge_base_mcp_smoke.py --json --quick`
  resume: {"status": "degraded", "protocol_version": "2025-03-26", "server_name": "knowledge-base", "provider": "memos", "tool_count": 4, "checks": ["initialize", "tools/list"], "secret_configured": false, "live_validation": "missing_secret", "error": "memos auth missing"}
- advisory: `.venv/bin/python tools/github_dispatch_mcp_smoke.py --json --quick`
  resume: {"status": "degraded", "protocol_version": "2025-03-26", "server_name": "github-dispatch", "tool_count": 3, "checks": ["initialize", "tools/list"], "token_configured": false, "live_requested": false, "live_validation": "missing_secret", "error": "GitHub dispatch auth missing"}
- handoff lot_id: mcp-runtime
  owner_repo=Kill_LIFE
  owner_agent=Runtime-Companion
  owner_team=Architect-Firmware
  dependencies=zeroclaw-integrations
  rollback=Désactiver les changements MCP introduits dans le lot et revenir à la configuration de référence. | Conserver la preuve de doc dans `docs/MCP_SETUP.md` et relancer uniquement en mode validation.
  write_set=docs/MCP_SETUP.md, tools/bootstrap_mac_mcp.sh, tools/lib/runtime_home.sh, tools/run_github_dispatch_mcp.sh

## `cad-mcp-host` — Runtime CAD host-first

- done: lot detecte (Qualifier KiCad, FreeCAD et OpenSCAD en host-first sur macOS tout en gardant le fallback conteneur operable.)
- done: `bash tools/hw/run_kicad_mcp.sh --doctor`
  resume: KICAD_PYTHON_STDERR_LOG_LEVEL=WARNING | REQUESTED_RUNTIME=auto | SELECTED_RUNTIME=container
- done: `bash tools/hw/cad_stack.sh doctor`
  resume: PlatformIO Core, version 6.1.19 | [kill_life:cad] OK: CAD doctor checks executed successfully. | OpenSCAD version 2021.01
- done: `.venv/bin/python tools/freecad_mcp_smoke.py --quick --json`
  resume: {"status": "ready", "protocol_version": "2025-03-26", "server_name": "freecad", "tool_count": 4, "checks": ["initialize", "tools/list", "get_runtime_info"], "error": null}
- done: `.venv/bin/python tools/openscad_mcp_smoke.py --quick --json`
  resume: {"status": "ready", "protocol_version": "2025-03-26", "server_name": "openscad", "tool_count": 4, "checks": ["initialize", "tools/list", "get_runtime_info"], "error": null}
- handoff lot_id: cad-mcp-host
  owner_repo=Kill_LIFE
  owner_agent=Embedded-CAD
  owner_team=Architect-Firmware
  dependencies=mcp-runtime
  rollback=Retour automatique au mode container-only (`tools/hw/cad_stack.sh`). | Conserver les chemins explicites de script pour éviter une dérive host-first.
  write_set=docs/MCP_SETUP.md, tools/hw/cad_stack.sh, tools/hw/run_kicad_mcp.sh

## `yiacad-fusion` — Fusion KiCad + FreeCAD IA-native

- done: lot detecte (Mettre en place le lot YiACAD (`prepare`, `smoke`, `status`, `logs`, `clean-logs`) et la synthese operateur associee sans fusion automatique de `main`.)
- done: `bash tools/cad/yiacad_fusion_lot.sh --action prepare`
  resume: - remotes: |   - origin -> https://github.com/FreeCAD/FreeCAD.git |   - upstream -> https://github.com/FreeCAD/FreeCAD.git
- done: `bash tools/cad/yiacad_fusion_lot.sh --action status`
  resume:   - origin -> https://github.com/FreeCAD/FreeCAD.git |   - upstream -> https://github.com/FreeCAD/FreeCAD.git | Last log: /Users/electron/Documents/Lelectron_rare/Kill_LIFE/artifacts/cad-fusion/yiacad-fusion-last.log
- advisory: `bash tools/cad/yiacad_fusion_lot.sh --action smoke`
  resume:   - upstream -> https://github.com/FreeCAD/FreeCAD.git | ## smoke_failures | - KiCad MCP host smoke
- handoff lot_id: yiacad-fusion
  owner_repo=Kill_LIFE
  owner_agent=CAD-Fusion
  owner_team=CAD-Fusion
  dependencies=cad-mcp-host
  rollback=Geler la branche `kill-life-ai-native` et revenir au mode container-only (`tools/hw/cad_stack.sh`). | Conserver les artefacts YiACAD (`artifacts/cad-fusion`) et la synthese hebdomadaire comme preuve. | Basculer l'execution en mode `status` + `clean-logs` si le smoke bloque.
  write_set=docs/CAD_AI_NATIVE_FORK_STRATEGY.md, docs/OSS_AI_NATIVE_CAD_RESEARCH_2026-03-20.md, tools/cad/ai_native_forks.sh, tools/cad/yiacad_fusion_lot.sh, tools/cockpit/refonte_tui.sh, tools/cockpit/render_weekly_refonte_summary.sh

## `python-local` — Execution Python repo-locale

- done: lot detecte (Garder les scripts et smokes sur l'interpreteur repo-local plutot que sur le Python systeme.)
- done: `bash tools/test_python.sh --venv-dir .venv --suite stable`
  resume: ---------------------------------------------------------------------- | Ran 3 tests in 0.075s | OK
- handoff lot_id: python-local
  owner_repo=Kill_LIFE
  owner_agent=Firmware
  owner_team=Architect-Firmware
  dependencies=mcp-runtime, cad-mcp-host
  rollback=Revenir à l'exécution Python système si la venv locale est instable. | Limiter les changements au lot `tools/test_python.sh` jusqu'à stabilisation.
  write_set=tools/test_python.sh, tools/run_validate_specs_mcp.sh, tools/validate_specs_mcp_smoke.py

