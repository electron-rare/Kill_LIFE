# Kill_LIFE Workspace Instructions

## Scope

Kill_LIFE is the control plane repo for spec-first governance, cockpit operations, runtime/MCP health, YiACAD web/CAD integration, firmware, and hardware evidence.
Use these instructions for all work in this repository.

## Canonical Entry Points

- Product and consolidation context: `README.md`
- Operator navigation: `docs/index.md`
- Build, test, and architecture reference: `CLAUDE.md`
- Runbooks: `RUNBOOK.md` and `docs/RUNBOOK.md`
- Spec-first source of truth: `specs/README.md`
- Cockpit and TUI entry points: `tools/cockpit/README.md`

## Build And Test

Prefer the repo commands already documented in `CLAUDE.md`. Default validation commands are:

- `bash tools/bootstrap_python_env.sh`
- `bash tools/test_python.sh --suite stable`
- `python3 tools/validate_specs.py --strict`
- `ruff check .`

Use domain-specific commands when relevant:

- Web: `cd web && npm install`, `cd web && npm run build`, `cd web && npx playwright test`
- Firmware: `cd firmware && pio run -e esp32s3_waveshare`, `cd firmware && pio test -e native`
- Hardware: `make hw SCHEM=hardware/esp32_minimal/esp32_minimal.kicad_sch`, `bash tools/hw/hw_export.sh`
- Runtime and cockpit: `bash tools/cockpit/runtime_ai_gateway.sh --action status --refresh --json`

## Architecture

Key boundaries:

- `specs/` is the source of truth: `00_intake -> 01_spec -> 02_arch -> 03_plan -> 04_tasks`
- `kill_life/` contains the Python control-plane and server logic
- `tools/cockpit/` is the canonical operator and runtime surface
- `web/` is the YiACAD Next.js frontend and worker surface
- `firmware/` is the PlatformIO firmware project
- `hardware/` contains KiCad schematics and manufacturing sources
- `specs/contracts/` defines runtime and artifact contracts that consumers rely on

## Conventions

- Specs and docs are mostly French; code and comments stay in English.
- Preserve the existing `ready`, `degraded`, `blocked` status discipline when touching runtime, cockpit, or evidence outputs.
- Keep artifact paths stable and consumable by operators; prefer `artifacts/` and `docs/evidence/`.
- When behavior changes, check whether related specs, contracts, examples, and runbooks also need updates.
- Prefer link-out to existing docs instead of duplicating long operational guidance in code comments or instructions.

## Common Pitfalls

- This repo may already be dirty; do not revert unrelated user changes.
- Many workflows depend on generated JSON or evidence artifacts; avoid changing field names or paths casually.
- The web, CAD, and cockpit surfaces share contracts indirectly through `specs/contracts/`; validate those links before closing a task.
- For execution-heavy tasks, prefer explicit `--json` outputs and operator-facing evidence.

## Area-Specific Guidance

Use the specialized instruction files when your change touches those areas:

- `.github/instructions/web.instructions.md` for `web/`
- `.github/instructions/firmware.instructions.md` for `firmware/`
- `.github/instructions/cad.instructions.md` for CAD and hardware tooling
- `.github/instructions/ops.instructions.md` for cockpit, evidence, and workflows

## Review Default

Unless explicitly asked to implement, default to a review mindset in this workspace: focus on behavioral regressions, contract drift, runtime risks, security issues, and missing tests.