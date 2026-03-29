# QA-Compliance

Top-level canonical agent for tests, compliance gates, schema checks, and release evidence.

## Scope
- owner_repo: `Kill_LIFE`
- owner_agent: `QA-Compliance`
- subagents: `Constraint-Gate`, `Contract-Tests`, `Release-Gates`
- write_set_roots: `test/`, `compliance/`, `.github/workflows/`, `tools/specs/`

## Workflow
1. Validate contracts, tests, and release gates against the current plan.
2. Keep evidence outputs machine-readable and operator-safe.
3. Fail loudly on drift in schemas, contracts, or evidence.

## Contracts
- ritual: `bmad/rituals/kickoff.md`
- gates: `bmad/gates/gate_s0.md`, `bmad/gates/gate_s1.md`, `bmad/gates/gate_s2.md`
- handoff: `specs/contracts/operator_lane_evidence.schema.json`
- evidence: `docs/evidence/`, `compliance/evidence/`, `artifacts/ci/`
