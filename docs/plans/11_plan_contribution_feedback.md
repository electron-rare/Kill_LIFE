# 11) Plan de contribution & feedback

## Objectif
Canaliser issues/PR, proposer des profils, enrichir les standards, et intégrer le feedback sans casser la sécurité.

## Labels recommandés
- `type:process` + `ai:docs` (ou `ai:plan` si changements structure)

## Étapes

### 1. Templates d’issues
- [x] Feature — Delivered: `.github/ISSUE_TEMPLATE/systems-engineering.yml`
- [x] Bug — Obsolete: no dedicated bug template, but `consulting-intake.yml` covers it
- [x] Compliance/Release — Delivered: `.github/ISSUE_TEMPLATE/compliance-release.yml`
- [x] Agentics update — Delivered: `.github/ISSUE_TEMPLATE/rnd-spike.yml`

### 2. Process PR
- [x] Labels `ai:*` obligatoires — Delivered: `.github/workflows/ci.yml`
- [x] Scope guard doit passer — Delivered: `tools/scope_guard.py`
- [x] Evidence pack minimal — Delivered: `.github/workflows/evidence_pack.yml`
- [x] Review obligatoire sur paths sensibles — Delivered: `.github/CODEOWNERS` (requires @electron review on .github/, tools/security/, compliance/, tools/ai/)

### 3. Proposer un profil compliance
- [x] Ouvrir issue `type:compliance` — Delivered: `.github/ISSUE_TEMPLATE/compliance-release.yml`
- [x] Fournir exigences et sources — Delivered: `docs/COMPLIANCE.md`
- [x] Ajouter tests/gates — Delivered: `tools/compliance/compliance_gate_tests.py` (CI-ready gate: profile, standards, plan, evidence, EMC/radio checks)

### 4. Boucle feedback
- [x] Triage hebdo — Delivered: `tools/cockpit/render_daily_operator_summary.sh` + `render_weekly_refonte_summary.sh`
- [x] “Decision log” (ADR) — Delivered: `docs/templates/ADR.md`

## Critère de sortie
✅ Contributions fluides, règles claires, aucun élargissement accidentel des privilèges.

## Références
- `.github/ISSUE_TEMPLATE/*`
- `docs/LABELS.md`