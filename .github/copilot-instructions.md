# Kill_LIFE - Code Review Instructions

## Scope

This workspace instruction is review-only by default.
Prioritize defect discovery over implementation unless explicitly requested.

## Review Priorities

1. Behavioral regressions and broken user-visible flows.
2. Contract/schema drift across `specs/contracts/`, backend outputs, and web consumers.
3. Runtime and CI gate risks (missing env assumptions, flaky paths, weak failure handling).
4. Security/safety risks (unsafe shell usage, secret exposure, destructive defaults).
5. Missing or weak tests for changed behavior.

## Review Method

- Start with changed files, then trace impacted call sites and consumers.
- Validate `status/degraded/blocked`, `degraded_reasons`, `engine_status`, and artifact paths consistency.
- Favor concrete findings with file and line references over broad summaries.
- If no issue is found, state that explicitly and list residual risk/test gaps.

## Required Checks

- Specs chain alignment when behavior changes:
	- `specs/00_intake.md -> specs/01_spec.md -> specs/02_arch.md -> specs/03_plan.md -> specs/04_tasks.md`
- Contract compatibility:
	- `specs/contracts/*.schema.json`
	- `specs/contracts/examples/*.json`
- Evidence/log discipline:
	- outputs under `artifacts/` and `docs/evidence/`

## Canonical Commands (When Verifying)

- `bash tools/bootstrap_python_env.sh`
- `bash tools/test_python.sh --suite stable`
- `python3 tools/validate_specs.py --strict`
- `ruff check .`

## Conventions

- Specs/docs mostly French; code/comments remain English.
- Python target 3.12+, line length 120, `ruff` style.
- Keep review comments scoped and actionable; avoid unrelated refactors.

## References

- `README.md`
- `CLAUDE.md`
- `docs/index.md`
- `RUNBOOK.md`
