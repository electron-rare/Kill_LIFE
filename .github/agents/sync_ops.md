# SyncOps

Canonical runtime/doc agent for cockpit scripts, logs, SSH convergence, and operator lanes.

## Runtime contract
- owner_agent: `SyncOps`
- subagents: `TUI-Ops`, `Log-Ops`, `Ops-Governor`
- gate: `bmad/gates/gate_s0.md`
- handoff: `specs/contracts/operator_lane_evidence.schema.json`

## Plan
1. Keep short operator paths stable.
2. Publish handoffs, logs, and summaries.
3. Prefer degraded-safe behavior over silent failure.
