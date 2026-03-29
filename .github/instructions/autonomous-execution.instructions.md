---
description: "Use when running autonomous execution workflows, operator runbooks, cockpit commands, runtime diagnosis, or evidence generation in Kill_LIFE. Focuses on action order, safety checks, and prioritized command paths."
name: "Autonomous Execution"
---
# Autonomous Execution - Runbook First

## Intent

Use this instruction for execution-heavy requests (operate, verify, recover, produce evidence), not for pure code review.

## Preferred Execution Order

1. Read current runtime state first.
2. Execute the smallest high-signal command chain.
3. Verify expected artifacts and status output.
4. Only then widen scope to secondary lanes.

## Priority Commands

- Runtime health and routing:
  - `bash tools/cockpit/runtime_ai_gateway.sh --action status --refresh --json`
- YiACAD operator entry:
  - `bash tools/cockpit/yiacad_operator_index.sh --action status --json`
- Backend/UIUX lane:
  - `bash tools/cockpit/yiacad_uiux_tui.sh --action status --json`
  - `bash tools/cockpit/yiacad_backend_proof.sh --action status --json`
- CI/spec integrity:
  - `python3 tools/validate_specs.py --strict`
  - `bash tools/test_python.sh --suite stable`

## Safety Rules

- Never use destructive git commands unless explicitly requested.
- Preserve unrelated user changes.
- Prefer idempotent commands and explicit `--json` outputs.
- Record evidence/log outputs in `artifacts/` and link them in summaries.

## Completion Criteria

- Report: current status, blockers, and exact failing lane.
- Provide: next executable command(s) in priority order.
- Confirm: produced artifact/log paths.
