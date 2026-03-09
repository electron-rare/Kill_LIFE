# Tasks enchainement autonome des lots utiles

Last updated: 2026-03-09

## Cadre

- Plan actif: `specs/03_plan.md`
- Statut detaille: `artifacts/cockpit/useful_lots_status.md`
- Lane runtime/MCP/CAD: `docs/plans/18_plan_enchainement_autonome_des_lots_utiles.md`
- Question operateur si besoin reel: `artifacts/cockpit/next_question.md`

## Execution

<!-- BEGIN AUTO LOT-CHAIN TASKS -->
- [x] T-LC-001 - Keep the README/repo coherence lot clean via the dedicated audit loop.
  - Evidence: `artifacts/doc/readme_repo_audit.md`
- [x] T-LC-002 - Keep the exported spec mirror synchronized with the canonical `specs/` tree.
  - Evidence: `artifacts/specs/mirror_sync_report.md`
- [x] T-LC-003 - Keep the upstream MCP/CAD runtime lane docs synchronized with the current local state.
  - Evidence: `docs/plans/18_plan_enchainement_autonome_des_lots_utiles.md`
- [x] T-LC-004 - Revalidate the strict spec contract after each auto-fix run.
  - Evidence: `python3 tools/validate_specs.py --strict --require-mirror-sync`
- [x] T-LC-005 - Re-run the stable Python suite after the chained lots.
  - Evidence: `bash tools/test_python.sh --suite stable`
- [ ] T-LC-006 - Choose the next manual lot once automation reaches a real fork.
  - Evidence: `artifacts/cockpit/next_question.md`
<!-- END AUTO LOT-CHAIN TASKS -->
