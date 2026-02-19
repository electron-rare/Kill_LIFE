# 14) Plan de release & versioning

## Objectif
Mettre en place un versioning clair et des releases reproductibles (firmware + hardware + specs + evidence pack).

## Recommandation versioning
- Firmware : SemVer (`vMAJOR.MINOR.PATCH`)
- Hardware : `HW-V0`, `HW-V1` + révisions PCB
- Specs : version interne (rev) ou tag repo

## Étapes release

### 1. Préparer la RC
- [ ] “Freeze” features, bugfix only
- [ ] Test matrix complète
- [ ] Evidence pack complet

### 2. Tag & artefacts
- [ ] Tag git
- [ ] Générer binaires firmware (CI)
- [ ] Publier artefacts (hash, size)

### 3. Release notes
- [ ] Liste des AC couverts
- [ ] Changements incompatibles
- [ ] Profil compliance

### 4. Post‑release
- [ ] Backport policy
- [ ] Hotfix process

## Gates
- CI verte
- Evidence pack présent
- Review finale

## Critère de sortie
✅ Release publiée, reproductible, avec preuves et notes claires.

## Références
- `docs/workflows/compliance_release.md`
- `docs/evidence/evidence_pack.md`