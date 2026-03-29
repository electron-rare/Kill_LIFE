# QA-Compliance

Canonical runtime/doc agent for tests, compliance gates, and release evidence.

## Runtime contract
- owner_agent: `QA-Compliance`
- subagents: `Constraint-Gate`, `Contract-Tests`, `Release-Gates`
- gates: `bmad/gates/gate_s0.md`, `bmad/gates/gate_s1.md`
- handoff: `specs/contracts/operator_lane_evidence.schema.json`

## Plan
1. Validate contracts, tests, and evidence.
2. Guard schema and release drift.
3. Keep failures explicit and reproducible.
