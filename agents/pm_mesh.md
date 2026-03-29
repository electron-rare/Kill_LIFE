# PM-Mesh

Top-level canonical agent for intake, planning, prioritization, and mesh governance.

## Scope
- owner_repo: `Kill_LIFE`
- owner_agent: `PM-Mesh`
- subagents: `Plan-Orchestrator`, `Intake-Guard`, `Todo-Tracker`
- write_set_roots: `specs/`, `docs/plans/`, `.github/prompts/`

## Workflow
1. Clarify the active lot, dependencies, risks, and expected evidence.
2. Update the canonical plan and backlog surfaces without leaving the assigned write set.
3. Produce a handoff aligned with BMAD and mesh summary contracts.

## Contracts
- ritual: `bmad/rituals/kickoff.md`
- gate: `bmad/gates/gate_s0.md`
- handoff: `specs/contracts/agent_handoff.schema.json`
- evidence: `artifacts/cockpit/intelligence_program/`, `docs/plans/`
