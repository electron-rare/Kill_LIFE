# 6) Plan d’intégration CI/CD

## Objectif
Automatiser build, tests, compliance, scope guard, evidence pack — et rendre la fusion impossible sans preuves.

## Labels recommandés
- `type:agentics` + `ai:plan`

## Pipelines minimales

### 1. Gates “repo sécurité”
- [x] PR label enforcement (`ai:*` obligatoire) — Delivered: `.github/workflows/ci.yml`
- [x] scope guard (label → allowlist) — Delivered: `tools/scope_guard.py` + `tools/scope_policy.py`
- [x] sanitizer check (tests unitaires sur `sanitize_issue.py` si ajoutés) — Delivered: `tools/ai/sanitize_issue.py`

### 2. Gates “spec-driven”
- [x] lint specs (format, RFC2119) — Delivered: `tools/validate_specs.py`
- [x] génération docs (si applicable) — Delivered: `.github/workflows/jekyll-gh-pages.yml` + `pages_publish.yml`

### 3. Gates “firmware”
- [x] build PlatformIO (matrix envs) — Delivered: `firmware/platformio.ini` + `tools/build_firmware.py`
- [x] tests `native` — Delivered: `firmware/test/test_basic.cpp` + `tools/test_firmware.py`
- [x] format/lint (clang-format, etc.) — Delivered: `firmware/.clang-format` + `tools/ci/lint_firmware.sh` + CI job `firmware-lint`

### 4. Gates “hardware” (optionnels)
- [x] exports KiCad (PDF/renders) — Delivered: `tools/hw/exports.py` + `tools/hw/hw_gate.sh` + CI job `hardware-gate`
- [x] ERC/DRC (si outillage intégré) — Delivered: `tools/hw/exports.py` (ERC json + DRC json) + CI job `hardware-gate`
- [x] BOM export — Delivered: `tools/hw/exports.py` (bom.csv + netlist.xml) + CI job `hardware-gate`

## Evidence pack
Standardiser un dossier artefacts par run :
- `artifacts/<run-id>/logs/*`
- `artifacts/<run-id>/exports/*`
- `artifacts/<run-id>/reports/*`

## Étapes d’implémentation
- [x] Définir la matrice de build (envs PIO) — Delivered: `firmware/platformio.ini`
- [x] Ajouter upload d’artefacts (logs) — Delivered: `.github/workflows/evidence_pack.yml`
- [x] Branch protection : checks requis — Delivered: `tools/ci/branch_protection.sh` (configures required checks via gh API)
- [x] (Option) Environnements protégés pour étapes sensibles — Delivered: `tools/ci/protected_environments.sh` (staging + production environments via gh API)

## Critère de sortie
✅ Merge impossible sans CI verte, et chaque PR produit un evidence pack minimum.

## Références
- `docs/evidence/evidence_pack.md`
- `.github/workflows/*`