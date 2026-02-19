# Workflow — Créatif / narration / contenu

## But
Produire une expérience (narration, scripts, audio/texte, triggers) **versionnée** et intégrable dans le firmware/hardware.

## Phases

### 1) Bible / règles
- Ton, univers, règles, contraintes de production
- Label : `ai:spec`

### 2) Scénarisation
- Structure : scènes, progression, graph (triggers → actions)
- Label : `ai:plan`

### 3) Production assets
- Scripts + manifests + placeholders
- Formats : mp3 mono/stéréo, durées, langues, voix
- Label : `ai:impl` (contenu) + `ai:docs` (guide d’intégration)

### 4) Playtest & itération
- Notes, corrections, versioning
- Label : `ai:qa` (si tu ajoutes tests/validateurs sur manifests)

## Gates
- Manifests valides
- Assets référencés existent
- Evidence pack (liste assets + checksums)

## Evidence pack
Voir `docs/evidence/creative_pack.md`.
