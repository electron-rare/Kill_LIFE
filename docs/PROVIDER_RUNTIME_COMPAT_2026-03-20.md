# Provider runtime compatibility - 2026-03-20

## Purpose

This note captures the real runtime contract observed while closing the `Full operator lane` lot on `clems@192.168.0.120`.

## Runtime facts observed on 2026-03-20

- The live operator lane is now validated through `mascarade-api` with a container-safe local action runner:
  - `tools/ops/operator_live_provider_smoke.js`
- The parity helper `tools/ops/operator_live_provider_smoke.py` is kept for host-side use and offline debugging.
- The validated live call on `clems` succeeded with:
  - provider: `claude`
  - model: `claude-sonnet-4-6`
  - run id: `5ef4909f-8747-4634-a6a6-d131692787b0`
- The validated dry-run on `clems` succeeded with:
  - run id: `4a9adf87-1695-4321-86a2-e066a0988533`

## Compatibility issues found

### 1. Container runtime did not have `python3`

- The original local action used `python3 tools/ops/operator_live_provider_smoke.py`.
- Inside `mascarade-api`, this failed with `spawn python3 ENOENT`.
- Decision:
  - the container-executed bridge now uses `node tools/ops/operator_live_provider_smoke.js`
  - the Python helper remains as a parity/debug script

### 2. The current provider stack rejects `system` as a chat message role

- `mascarade-core` logs showed repeated failures with:
  - `messages: Unexpected role "system". The Messages API accepts a top-level system parameter`
- Decision:
  - the smoke payload now sends `system` as a top-level field
  - `messages` now start at the user turn

### 3. Explicit provider/model forcing was not the stable path today

- Explicit `openai:*` forcing was not reproducibly stable during this lot.
- The runtime succeeded when the chat request let the server choose its default model.
- Decision:
  - the smoke leaves `model` unset unless an explicit operator override is requested
  - provider/model are inferred from the actual response body when present

## Adoption policy for the operator lane

- Default mode:
  - do not force `model`
  - let the runtime choose the currently healthy default model
- Explicit override mode:
  - keep `--provider` and `--model` available for diagnostics
  - send `model` only when the operator explicitly requests it
  - surface failures as `degraded` instead of crashing the workflow
- Operator proof:
  - evidence stays in `artifacts/operator_lane/live_provider_result.json`
  - the runbook remains `bash tools/cockpit/full_operator_lane.sh [dry-run|live|all]`

## T-OL-005 closure note

- The operator smoke runners no longer inject a `model` automatically from provider/profile selection.
- The runtime default path remains the canonical path.
- Explicit `--model` stays available for diagnostics only.

## Official web research used

### Anthropic

- Anthropic documents that the Messages API uses a top-level `system` parameter rather than a `system` role in `messages`:
  - https://docs.anthropic.com/de/api/migrating-from-text-completions-to-messages
- Anthropic also documents that OpenAI SDK compatibility hoists `system` / `developer` messages and is not the preferred production path:
  - https://docs.anthropic.com/en/api/openai-sdk

### OpenAI

- OpenAI still documents Chat Completions as an available API surface and explicitly discusses `system` and `user` messages in compatibility guidance:
  - https://developers.openai.com/api/reference/overview

## Follow-up tasks

- Restore `mesh_sync_preflight` visibility for the staged `Kill_LIFE-main` and `crazy_life-main` lanes on `clems`.
- Propagate the runtime-normalized operator lane patchset to the remaining mesh lanes without overwriting non-mesh worktrees.
- Reintroduce explicit provider/model probes only after the runtime default path remains stable over several passes.
