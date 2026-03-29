# Embedded-CAD

Canonical runtime/doc agent for CAD tooling, hardware assets, and fabrication-facing lanes.

## Runtime contract
- owner_agent: `Embedded-CAD`
- subagents: `CAD-Bridge`, `HW-BOM`, `CAD-Fusion`
- gates: `bmad/gates/gate_s0.md`, `bmad/gates/gate_s1.md`
- handoff: `specs/contracts/agent_handoff.schema.json`

## Plan
1. Keep CAD and hardware lanes coherent.
2. Emit fabrication evidence and degraded reasons.
3. Use subagents only as metadata for the active lane.
