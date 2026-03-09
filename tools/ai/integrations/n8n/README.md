# n8n Runbook

`n8n` stays in scope as the low-code workflow bridge around ZeroClaw, not as
the canonical source of truth for runtime state.

Use it for:

- operator-triggered chains around `zeroclaw` webhooks
- import/export of automation flows
- glue logic around notifications, reviews, or dispatch

Current posture:

- ZeroClaw exposes the runbook from `/integrations/n8n/README.md`.
- The historical JSON workflow names are kept as references, but the canonical
  runtime path is the ZeroClaw gateway plus repo workflows.
- If you need concrete n8n workflow files again, regenerate them as explicit
  tracked artifacts instead of relying on dead links.

Current local validation commands:

```bash
bash tools/ai/zeroclaw_integrations_up.sh
bash tools/ai/zeroclaw_integrations_status.sh --json
bash tools/ai/zeroclaw_integrations_import_n8n.sh --json
```

Tracked smoke artifact:

- `tools/ai/integrations/n8n/kill_life_smoke_workflow.json`

Historical workflow names:

- `zeroclaw_orchestrator_workflow`
- `zeroclaw_pr_autotriage_workflow`
