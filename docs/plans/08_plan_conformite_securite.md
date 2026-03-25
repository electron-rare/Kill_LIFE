# 8) Plan de conformité & sécurité

## Objectif
Valider les profils, auditer les scripts/workflows, appliquer la politique anti‑prompt‑injection, et définir le sandboxing.

## Labels recommandés
- `type:compliance` + `ai:plan`

## Étapes

### 1. Profils conformité
- [x] Choisir un profil (ex : `iot_wifi_eu`) — Delivered: `docs/COMPLIANCE.md` + `specs/constraints.yaml` (profile prototype, 5 standards)
- [x] Vérifier les exigences : radio, EMC, LVD, étiquetage — Delivered: `tools/compliance/check_emc_radio_lvd.py` (checks profile coverage per category)

### 2. Audit CI & secrets
- [x] Vérifier permissions des workflows (`permissions:` minimales) — Delivered: `.github/workflows/ci_cd_audit.yml`
- [x] Vérifier usage secrets (pas d’echo, pas de logs) — Delivered: `.github/workflows/secret_scan.yml`
- [x] Activer branch protection + checks requis — Delivered: `tools/setup_branch_protection.sh` (run with --dry-run first; requires `gh` admin access)

### 3. Anti prompt injection
- [x] Sanitizer activé avant injection prompt — Delivered: `tools/ai/sanitize_issue.py`
- [x] Scope guard par label `ai:*` — Delivered: `tools/scope_guard.py` + `tools/scope_policy.py`
- [x] Denylist pour chemins sensibles — Delivered: `tools/scope_policy.py`
- [x] Procédure incident (`ai:hold`) — Delivered: `docs/security/anti_prompt_injection_policy.md`

### 4. Sandboxing
- [x] Les agents write‑capable passent via safe outputs — Delivered: MCP service boundary in `docs/MCP_SERVICE_BOUNDARY.md`
- [x] OpenClaw : VM/Docker isolé, actions non destructives — Obsolete: superseded by ZeroClaw dual orchestrator (`tools/ai/zeroclaw_dual_bootstrap.sh`)

### 5. Evidence pack
- [x] Checklists remplies — Delivered: `docs/evidence/checklist_badge_evidence_pack.md`
- [x] Export du profil compliance — Delivered: `docs/COMPLIANCE.md`
- [x] Résultats gates CI — Delivered: `.github/workflows/evidence_pack.yml`

## Gates
- Label enforcement + scope guard
- Compliance checks (si activés)

## Critère de sortie
✅ Profil choisi, politiques en place, CI verrouillée, et runbook incident validé.

## Références
- `docs/COMPLIANCE.md`
- `docs/security/anti_prompt_injection_policy.md`