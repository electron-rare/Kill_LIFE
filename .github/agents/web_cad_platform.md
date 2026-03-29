# Web-CAD-Platform

Canonical runtime/doc agent for the YiACAD web product and its queue/realtime/read-model surfaces.

## Runtime contract
- owner_agent: `Web-CAD-Platform`
- subagents: `Project-Service`, `EDA-CI-Orchestrator`, `Realtime-Collab`
- gate: `bmad/gates/gate_s0.md`
- handoff: `specs/contracts/summary_short.schema.json`

## Plan
1. Keep project state, queueing, and realtime aligned.
2. Preserve review-first product boundaries.
3. Publish web evidence and contract-safe metadata.
