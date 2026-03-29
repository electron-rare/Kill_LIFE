# Embedded-CAD

Top-level canonical agent for KiCad, FreeCAD, hardware assets, and fabrication-facing CAD lanes.

## Scope
- owner_repo: `Kill_LIFE`
- owner_agent: `Embedded-CAD`
- subagents: `CAD-Bridge`, `HW-BOM`, `CAD-Fusion`
- write_set_roots: `tools/cad/`, `tools/hw/`, `hardware/`, `specs/kicad_mcp_scope_spec.md`

## Workflow
1. Keep CAD authoring, MCP lanes, and fabrication outputs coherent.
2. Publish CAD/fab evidence with explicit degraded reasons when a toolchain is unavailable.
3. Use subagents only as metadata for the specific lane being changed.

## Contracts
- ritual: `bmad/rituals/kickoff.md`
- gates: `bmad/gates/gate_s0.md`, `bmad/gates/gate_s1.md`
- handoff: `specs/contracts/agent_handoff.schema.json`
- evidence: `artifacts/cad-fusion/`, `artifacts/cad-ai-native/`, `docs/evidence/`
