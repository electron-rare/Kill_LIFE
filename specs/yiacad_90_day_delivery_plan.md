# Plan - YiACAD 90 day delivery

## Intent

Turn the 2026 stack target into a concrete 90 day delivery plan anchored from `2026-03-29`.

## Time window

- Wave 1: `2026-03-29` to `2026-04-27`
- Wave 2: `2026-04-28` to `2026-05-27`
- Wave 3: `2026-05-28` to `2026-06-26`

## Success definition at day 90

- YiACAD desktop can author and review real projects through integrated `KiCad 10` and `FreeCAD 1.1` lanes.
- YiACAD web can review, comment, inspect artifacts, and follow CI state on the same projects.
- `KiBot` and `KiAuto` run as pinned Linux/Docker automation lanes behind YiACAD backend actions.
- product outputs are normalized through `context.json` and `uiux_output.json`.
- CI/CD blocks contract drift, backend regressions, web regressions, and manufacturing lane failures.

## Wave 1 - Freeze the product boundary

### Objectives

- freeze the 2026 SOT docs and ADR
- align desktop/web/backend specs on one boundary
- finish the shared action registry and engine capability model
- make web and TUI consume backend-first actions only
- define pinned runtime policy for `KiCad`, `FreeCAD`, `KiBot`, `KiAuto`

### Deliverables

- canonical action registry
- engine capability matrix
- version floor enforcement in backend health
- desktop shell skeleton for project, review center, artifacts, and command palette
- fixture-backed contract tests for `review`, `sync`, `manufacturing`, `status`

### Exit criteria

- no client path calls CAD engines directly
- action/status/degraded semantics are shared across desktop, web, and TUI
- tests exist for every core action family

## Wave 2 - Land integrated authoring and manufacturing lanes

### Objectives

- ship the first YiACAD KiCad extension on `IPC API`
- ship the first YiACAD FreeCAD workbench package
- complete `KiBot` manufacturing package action
- complete `KiAuto` validation action on fixture projects
- expose artifacts, evidence, and next steps coherently in desktop and web

### Deliverables

- KiCad palette + review + artifact hooks
- FreeCAD workbench with YiACAD status/review/sync entrypoints
- pinned runner image or Dockerfile for manufacturing jobs
- manufacturing evidence pack and result normalization
- stable read models for artifact browsing in web

### Exit criteria

- one real KiCad project can pass through review, export, and manufacturing package
- one real FreeCAD-linked project can pass through sync and artifact publication
- Linux CI runs the manufacturing lane without ad hoc local setup

## Wave 3 - Release-quality hardening

### Objectives

- harden release gates
- add nightly extended CAD matrix
- package the desktop shell for internal release
- ship review approvals and CI visibility in web
- produce release evidence and operator runbooks

### Deliverables

- internal desktop package
- release-grade CI summaries and evidence artifacts
- nightly matrix for engine smokes and representative fixtures
- operator dashboard for project, engines, CI, and artifacts
- release checklist and rollback playbook

### Exit criteria

- all blocking CI lanes are green on representative fixtures
- desktop package is installable by internal users
- web review and artifacts surface are usable without local shell knowledge
- evidence pack is sufficient for release go/no-go

## Cross-cutting QA plan

### Unit

- action registry
- engine version parsing
- degraded reason mapping
- artifact indexing

### Contract

- backend request/response schemas
- `yiacad_context_broker`
- `yiacad_uiux_output`
- worker payload compatibility

### Integration

- desktop -> backend
- web worker -> backend
- backend -> KiCad adapter
- backend -> FreeCAD adapter
- backend -> KiBot/KiAuto lanes

### End-to-end

- open project -> run review -> inspect artifacts
- run ECAD/MCAD sync -> publish output
- run manufacturing package -> inspect evidence
- fail one engine -> observe `degraded` or `blocked`

## Dependencies and risks

- platform package lag after upstream releases
- fixture scarcity for mixed ECAD/MCAD projects
- Linux runner image drift for manufacturing jobs
- FreeCAD addon/workbench compatibility drift
- temptation to bypass the backend for quick wins

## Tracking

- plan anchor: `specs/03_plan.md`
- task tracker: `specs/04_tasks.md`
- product boundary: `specs/yiacad_tux004_orchestration_spec.md`
- backend boundary: `specs/yiacad_backend_architecture_spec.md`
- CI/CD target state: `specs/yiacad_plugin_workbench_ci_plan.md`
