# 6) Plan d’intégration CI/CD

## Objectif
Automatiser build, tests, compliance, scope guard, evidence pack — et rendre la fusion impossible sans preuves.

## Labels recommandés
- `type:agentics` + `ai:plan`

## Pipelines minimales

### 1. Gates “repo sécurité”
- [ ] PR label enforcement (`ai:*` obligatoire)
- [ ] scope guard (label → allowlist)
- [ ] sanitizer check (tests unitaires sur `sanitize_issue.py` si ajoutés)

### 2. Gates “spec-driven”
- [ ] lint specs (format, RFC2119)
- [ ] génération docs (si applicable)

### 3. Gates “firmware”
- [ ] build PlatformIO (matrix envs)
- [ ] tests `native`
- [ ] format/lint (clang-format, etc.)

### 4. Gates “hardware” (optionnels)
- [ ] exports KiCad (PDF/renders)
- [ ] ERC/DRC (si outillage intégré)
- [ ] BOM export

## Evidence pack
Standardiser un dossier artefacts par run :
- `artifacts/<run-id>/logs/*`
- `artifacts/<run-id>/exports/*`
- `artifacts/<run-id>/reports/*`

## Étapes d’implémentation
- [ ] Définir la matrice de build (envs PIO)
- [ ] Ajouter upload d’artefacts (logs)
- [ ] Branch protection : checks requis
- [ ] (Option) Environnements protégés pour étapes sensibles

## Critère de sortie
✅ Merge impossible sans CI verte, et chaque PR produit un evidence pack minimum.

## Références
- `docs/evidence/evidence_pack.md`
- `.github/workflows/*`