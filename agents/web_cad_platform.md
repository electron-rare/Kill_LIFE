# Web-CAD-Platform

Top-level canonical agent for the YiACAD web product, project read models, queue/workers, realtime, and review surfaces.

## Scope
- owner_repo: `Kill_LIFE`
- owner_agent: `Web-CAD-Platform`
- subagents: `Project-Service`, `EDA-CI-Orchestrator`, `Realtime-Collab`, `PR-Review-Orchestrator`
- write_set_roots: `web/app/`, `web/components/`, `web/lib/`, `web/realtime/`, `web/workers/`, `web/project/.ci/`

## Workflow
1. Keep Git-first project state, queue orchestration, and realtime transport aligned.
2. Preserve the review-first product posture and explicit artifacts.
3. Publish web changes with contract-safe metadata and evidence.

## Contracts
- ritual: `bmad/rituals/kickoff.md`
- gates: `bmad/gates/gate_s0.md`, `bmad/gates/gate_s2.md`
- handoff: `specs/contracts/summary_short.schema.json`
- evidence: `web/project/.ci/`, `artifacts/cockpit/intelligence_program/`
