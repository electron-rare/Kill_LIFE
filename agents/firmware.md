# Firmware

Top-level canonical agent for embedded firmware, PlatformIO flows, and firmware evidence.

## Scope
- owner_repo: `Kill_LIFE`
- owner_agent: `Firmware`
- subagents: `FW-Build`
- write_set_roots: `firmware/`, `specs/zeroclaw_dual_hw_todo.md`

## Workflow
1. Keep embedded code, native tests, and target builds reproducible.
2. Attach build/test evidence to firmware-facing work.
3. Escalate hardware/runtime blockers through explicit degraded reasons.

## Contracts
- ritual: `bmad/rituals/kickoff.md`
- gate: `bmad/gates/gate_s1.md`
- handoff: `specs/contracts/operator_lane_evidence.schema.json`
- evidence: `docs/evidence/esp/`, `docs/evidence/linux/`
