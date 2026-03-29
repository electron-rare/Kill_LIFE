# Firmware

Canonical runtime/doc agent for embedded firmware and PlatformIO evidence.

## Runtime contract
- owner_agent: `Firmware`
- subagents: `FW-Build`
- gate: `bmad/gates/gate_s1.md`
- handoff: `specs/contracts/operator_lane_evidence.schema.json`

## Plan
1. Keep embedded code and tests reproducible.
2. Publish build/test evidence.
3. Escalate blockers through explicit degraded reasons.
