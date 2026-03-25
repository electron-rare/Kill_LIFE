# 14) Plan de release & versioning

## Objectif
Mettre en place un versioning clair et des releases reproductibles (firmware + hardware + specs + evidence pack).

## Recommandation versioning
- Firmware : SemVer (`vMAJOR.MINOR.PATCH`)
- Hardware : `HW-V0`, `HW-V1` + révisions PCB
- Specs : version interne (rev) ou tag repo

## Étapes release

### 1. Préparer la RC
- [x] “Freeze” features, bugfix only — Delivered: `tools/ci/release_prep.sh <version>` creates `release/` branch (bugfix-only by policy)
- [x] Test matrix complète — Delivered: `tools/test_python.sh --suite stable` + `firmware/test/`
- [x] Evidence pack complet — Delivered: `.github/workflows/evidence_pack.yml` + `tools/collect_evidence.py`

### 2. Tag & artefacts
- [x] Tag git — Delivered: `tools/ci/release_prep.sh <version> --tag` + `.github/workflows/release_signing.yml` triggers on `v*` tags
- [x] Générer binaires firmware (CI) — Delivered: `tools/build_firmware.py` + `.github/workflows/ci.yml`
- [x] Publier artefacts (hash, size) — Delivered: `.github/workflows/release_signing.yml` + `.github/workflows/sbom_validation.yml`

### 3. Release notes
- [x] Liste des AC couverts — Delivered: `tools/ci/generate_changelog.py` extracts AC references from commit messages
- [x] Changements incompatibles — Delivered: `tools/ci/generate_changelog.py` detects BREAKING CHANGE and `!` conventional-commit markers
- [x] Profil compliance — Delivered: `docs/COMPLIANCE.md`

### 4. Post‑release
- [x] Backport policy — Delivered: `tools/ci/release_policy.py --show` (documents eligible backport criteria)
- [x] Hotfix process — Delivered: `tools/ci/release_policy.py --show` (step-by-step hotfix workflow from tag to cherry-pick)

## Gates
- CI verte
- Evidence pack présent
- Review finale

## Critère de sortie
✅ Release publiée, reproductible, avec preuves et notes claires.

## Références
- `docs/workflows/compliance_release.md`
- `docs/evidence/evidence_pack.md`