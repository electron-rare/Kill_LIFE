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
bash tools/ai/zeroclaw_integrations_lot.sh verify
bash tools/ai/zeroclaw_integrations_up.sh
bash tools/ai/zeroclaw_integrations_status.sh --json
bash tools/ai/zeroclaw_integrations_import_n8n.sh --json
```

Current runtime bootstrap:

- `bash tools/ai/zeroclaw_integrations_up.sh` auto-provisions the local `mascarade-n8n` container if Docker is running but the container is still missing.
- Official runtime basis: `docker.n8n.io/n8nio/n8n` on port `5678`, with a persistent volume per container name.
- Readiness is validated through `http://127.0.0.1:5678/healthz` in addition to the editor root URL, because first boot and editor startup can lag behind the health endpoint.
- Workflow activation path: reuse the tracked workflow when it is already active, otherwise prefer `n8n publish:workflow --id=<ID>` after import, with legacy fallback `n8n update:workflow --id=<ID> --active=true`.
- Activation proof now checks `n8n list:workflow --active=true --onlyId`, so `active=true` is no longer assumed.
- Runtime scripts fail fast on local Docker CLI timeouts and report a blocker instead of hanging indefinitely.
- If the local DB already contains the tracked workflow with the exact stored nodes/connections and `active=true`, the import script now skips the CLI path and returns success immediately.
- Recovery note: if local SQLite state is corrupted or still contains an obsolete workflow revision, preserve the volume backup and reset only the n8n DB files before reprovisioning the container.

Tracked smoke artifact:

- `tools/ai/integrations/n8n/kill_life_smoke_workflow.json`
  - current trigger: yearly `Schedule Trigger`, so the workflow stays activable without creating noisy frequent runs

Historical workflow names:

- `zeroclaw_orchestrator_workflow`
- `zeroclaw_pr_autotriage_workflow`

<iframe src="https://github.com/sponsors/electron-rare/card" title="Sponsor electron-rare" height="225" width="600" style="border: 0;"></iframe>
