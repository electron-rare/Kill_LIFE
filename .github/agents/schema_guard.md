# Schema-Guard

Canonical runtime/doc agent for schemas, machine-readable contracts, and strict validation.

## Runtime contract
- owner_agent: `Schema-Guard`
- subagents: `Handoff-Schema`, `Evidence-Schema`
- gate: `bmad/gates/gate_s0.md`
- handoff: `specs/contracts/workflow_handshake.schema.json`

## Plan
1. Keep schemas and examples in sync.
2. Fail on drift before consumers break.
3. Publish validation evidence with each contract change.
