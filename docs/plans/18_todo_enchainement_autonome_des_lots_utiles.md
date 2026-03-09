# 18) TODO enchainement autonome des lots utiles

Last updated: 2026-03-09 06:24:48

Ce fichier est regenere localement par `tools/autonomous_next_lots.py`.

## `zeroclaw-integrations` — Runtime local ZeroClaw / n8n

- done: lot detecte (Fermer la lane d'integrations locales ZeroClaw/n8n, les evidences I-205 associees et la documentation/spec sync qui l'accompagne.)
- done: `bash tools/ai/zeroclaw_integrations_up.sh --json`
  resume: {"container": "mascarade-n8n", "container_exists": true, "container_running": true, "container_status": "Up 16 hours (healthy)", "internal_http_ok": true, "host_http_ok": true, "n8n_url": "http://127.0.0.1:5678/", "workflow_ids": ["kill-life-n8n-smoke"], "active_workflow_ids": ["kill-life-n8n-smoke"]}
- done: `bash tools/ai/zeroclaw_integrations_status.sh --json`
  resume: {"container": "mascarade-n8n", "container_exists": true, "container_running": true, "container_status": "Up 16 hours (healthy)", "internal_http_ok": true, "host_http_ok": true, "n8n_url": "http://127.0.0.1:5678/", "workflow_ids": ["kill-life-n8n-smoke"], "active_workflow_ids": ["kill-life-n8n-smoke"]}
- done: `bash tools/ai/zeroclaw_integrations_import_n8n.sh --json`
  resume: {"workflow_id": "kill-life-n8n-smoke", "input_file": "/home/clems/Kill_LIFE/tools/ai/integrations/n8n/kill_life_smoke_workflow.json", "container": "mascarade-n8n", "import_action": "skipped", "publish_action": "published", "active": true}
- done: `python3 tools/validate_specs.py --strict --require-mirror-sync`
  resume: - compliance stdout: OK: compliance profile 'prototype' validated. |   required standards: 5 |   evidence items: 4
- done: `bash tools/test_python.sh --suite stable`
  resume: ---------------------------------------------------------------------- | Ran 3 tests in 0.020s | OK

