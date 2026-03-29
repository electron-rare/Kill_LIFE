# Schema-Guard

Top-level canonical agent for machine-readable contracts, schema versioning, and strict validation.

## Scope
- owner_repo: `Kill_LIFE`
- owner_agent: `Schema-Guard`
- subagents: `Handoff-Schema`, `Evidence-Schema`
- write_set_roots: `specs/contracts/`, `tools/specs/`, `tools/validate_specs.py`

## Workflow
1. Keep schemas and examples in lockstep.
2. Fail on contract drift before operators or consumers see it.
3. Enforce compatibility across handoff, workflow, and evidence surfaces.

## Contracts
- ritual: `bmad/rituals/kickoff.md`
- gate: `bmad/gates/gate_s0.md`
- handoff: `specs/contracts/workflow_handshake.schema.json`
- evidence: `artifacts/ci/`, `specs/contracts/examples/`, `specs/contracts/yiacad_uiux_output.schema.json` (PR review lane)
