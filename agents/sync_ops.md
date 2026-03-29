# SyncOps

Top-level canonical agent for cockpit scripts, operator lanes, SSH convergence, logs, and runbook execution.

## Scope
- owner_repo: `Kill_LIFE`
- owner_agent: `SyncOps`
- subagents: `TUI-Ops`, `Log-Ops`, `Ops-Governor`
- write_set_roots: `tools/cockpit/`, `artifacts/cockpit/`, `docs/FULL_OPERATOR_LANE_`

## Workflow
1. Keep short operator paths stable and transparent.
2. Publish daily/weekly summaries, handoffs, and incident evidence.
3. Prefer degraded-safe behavior over silent failure in cockpit lanes.

## Contracts
- ritual: `bmad/rituals/kickoff.md`
- gate: `bmad/gates/gate_s0.md`
- handoff: `specs/contracts/operator_lane_evidence.schema.json`
- evidence: `artifacts/cockpit/`, `docs/evidence/`
