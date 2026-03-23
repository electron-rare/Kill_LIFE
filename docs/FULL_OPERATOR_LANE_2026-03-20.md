# Full operator lane - 2026-03-20

## Scope

This lot closes the operator path `crazy_life -> Kill_LIFE -> mascarade` while staying multi-contributor safe.

## Runtime contract

- Workflow source of truth: `workflows/embedded-operator-live.json`
- Gateway execution surface: `/api/killlife/workflows/:id/run`
- Live provider bridge:
  - container-safe runner: `tools/ops/operator_live_provider_smoke.js`
  - parity/debug runner: `tools/ops/operator_live_provider_smoke.py`
- Mascarade endpoints:
  - `/api/agents/providers`
  - `/v1/chat/completions` on `core`
- Evidence contract: `specs/contracts/operator_lane_evidence.schema.json`

## Mermaid

```mermaid
flowchart LR
    CLUI[crazy_life UI / Crazy Lane] --> CLAPI[crazy_life API]
    CLAPI --> KLRUN[Kill_LIFE workflow run]
    KLRUN --> KLSCRIPT[operator_live_provider_smoke.js]
    KLSCRIPT --> MAPISUM[/mascarade api/agents/providers]
    KLSCRIPT --> MCHAT[/mascarade core /v1/chat/completions]
    MCHAT --> PROVIDER[LLM provider]
    KLSCRIPT --> EVIDENCE[artifacts/operator_lane/live_provider_result.json]
    EVIDENCE --> CLAPI
    CLUI --> OPS[OpsHub / Infrastructure]
    OPS --> MMON[mascarade runtime posture]
```

## Acceptance map

| Surface | Path | Expected outcome |
| --- | --- | --- |
| Dry-run | `mode=local`, `dry_run=true` | `run_id` created and evidence refs previewed |
| Live provider | `mode=local`, `dry_run=false` | provider selected or explicit `degraded/blocked` result persisted |
| Operator evidence | `artifacts/operator_lane/live_provider_result.json` | JSON readable from the cockpit |
| TUI runbook | `bash tools/cockpit/full_operator_lane.sh <cmd>` | timestamped log + JSON summary |

## Validated state on `clems`

- Dry-run proof:
  - command: `bash tools/cockpit/full_operator_lane.sh dry-run --json`
  - result: `success`
  - run id: `4a9adf87-1695-4321-86a2-e066a0988533`
- Live proof:
  - command: `bash tools/cockpit/full_operator_lane.sh live --json`
  - result: `success`
  - run id: `5ef4909f-8747-4634-a6a6-d131692787b0`
  - provider: `claude`
  - model: `claude-sonnet-4-6`

## Compatibility notes from the validated run

- `mascarade-api` did not have `python3`; the live bridge had to move to Node for container execution.
- The current runtime rejected `system` as a chat message role and only succeeded once the prompt was hoisted to the top-level `system` field.
- The most stable path in this lot was to let the runtime choose its own default model; explicit `openai:*` forcing was not reproducibly stable.
- The operator runners are now aligned with that rule: `model` is only sent on explicit operator override.
- The proof note and official source links are captured in `docs/PROVIDER_RUNTIME_COMPAT_2026-03-20.md`.

## TUI

- `bash tools/cockpit/full_operator_lane.sh status`
- `bash tools/cockpit/full_operator_lane.sh dry-run`
- `bash tools/cockpit/full_operator_lane.sh live`
- `bash tools/cockpit/full_operator_lane.sh all`
- `bash tools/cockpit/full_operator_lane.sh purge`
- `bash tools/cockpit/full_operator_lane_sync.sh --json`
