# Workflow — Compliance / QA / Release

## But
Fiabiliser, prouver, livrer : test matrix, evidence pack, versioning et release reproductible.

## Phases

### 1) Validation plan
- Profil conformité (pays/zone)
- Test matrix (unit/integration/HIL/endurance/power)
- Label : `ai:plan`

### 2) Impl tests & gates
- Ajout/renforcement tests
- Packaging artifacts
- Label : `ai:qa`

### 3) Release
- Notes de release, versioning
- Artifacts (bins, exports, rapports)
- Label : `ai:docs`

## Gates
- Tous status checks requis (CI)
- Scope guard OK
- Evidence pack complet
- Route parity frontend/backend API (si surface web exposée)

## Evidence pack
Voir `docs/evidence/evidence_pack.md`.
