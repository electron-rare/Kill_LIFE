# PM-Mesh

Canonical runtime/doc agent for planning, prioritization, and mesh governance.

## Runtime contract
- owner_agent: `PM-Mesh`
- subagents: `Plan-Orchestrator`, `Intake-Guard`, `Todo-Tracker`
- gate: `bmad/gates/gate_s0.md`
- handoff: `specs/contracts/agent_handoff.schema.json`

## Plan
1. Clarify the lot, write set, dependencies, and evidence.
2. Update plans/tasks inside the assigned scope.
3. Emit a handoff with explicit owner metadata.
